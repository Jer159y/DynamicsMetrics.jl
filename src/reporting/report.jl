const DYNAMICSMETRICS_VERSION = v"0.1.0-DEV"

"""
    report_summary(report; series=:summary)

Convert a `MetricReport` into a deterministic vector of named tuples suitable
for tables or downstream processing.

The `series` policy controls how `MetricSeries` values are represented:

- `:summary`: record size, minimum, maximum, mean, and standard deviation.
- `:values`: retain a copy of the complete values and axis.
- `:omit`: omit series-valued metrics.

Scalar `MetricResult` entries always appear in the output.
"""
function report_summary(
    report::MetricReport;
    series::Symbol=:summary,
)
    series in (:summary, :values, :omit) || throw(ArgumentError(
        "Unsupported series policy `$series`. Supported values are " *
        "`:summary`, `:values`, and `:omit`."
    ))

    rows = NamedTuple[]

    for name in _ordered_report_names(report)
        result = report.results[name]

        if result isa MetricResult
            push!(rows, (
                name=name,
                kind=:scalar,
                value=value(result),
                parameters=parameters(result),
            ))
        elseif result isa MetricSeries
            series === :omit && continue

            values = value(result)

            if series === :values
                push!(rows, (
                    name=name,
                    kind=:series,
                    value=copy(values),
                    axis=copy(result.axis),
                    parameters=parameters(result),
                ))
            else
                numeric_values = collect(float.(vec(values)))
                isempty(numeric_values) && throw(ArgumentError(
                    "Cannot summarize empty MetricSeries `$name`."
                ))

                push!(rows, (
                    name=name,
                    kind=:series_summary,
                    length=length(numeric_values),
                    shape=size(values),
                    minimum=minimum(numeric_values),
                    maximum=maximum(numeric_values),
                    mean=mean(numeric_values),
                    std=std(numeric_values; corrected=false),
                    parameters=parameters(result),
                ))
            end
        else
            throw(ArgumentError(
                "Unsupported report result type $(typeof(result)) for `$name`."
            ))
        end
    end

    return rows
end

"""
    reproduction_metadata(; labels=(;), extra=(;))

Create deterministic package-level metadata for serialized reports.

No timestamps or random identifiers are inserted automatically, because those
would make otherwise identical reports differ across runs. Users may supply
such information explicitly through `extra`.
"""
function reproduction_metadata(
    ;
    labels::NamedTuple=(;),
    extra::NamedTuple=(;),
)
    return merge(
        (
            package=:DynamicsMetrics,
            package_version=string(DYNAMICSMETRICS_VERSION),
            julia_version=string(VERSION),
        ),
        labels,
        extra,
    )
end

"""
    serialize_report(path, report; labels=(;), metadata=(;))

Serialize a `MetricReport` to a machine-readable TOML file.

Arrays are stored with explicit shape and flattened data, preserving the
package's canonical layout without implicit transposition. Symbol and version
values are encoded as strings.

Returns `path`.
"""
function serialize_report(
    path::AbstractString,
    report::MetricReport;
    labels::NamedTuple=(;),
    metadata::NamedTuple=(;),
)
    isempty(path) && throw(ArgumentError(
        "`path` must not be empty."
    ))

    payload = Dict{String,Any}(
        "format" => "DynamicsMetrics.MetricReport",
        "format_version" => 1,
        "reproduction" => _toml_value(
            reproduction_metadata(labels=labels, extra=metadata)
        ),
        "report_metadata" => _toml_value(report.metadata),
        "metric_order" => string.(_ordered_report_names(report)),
        "results" => Dict{String,Any}(),
    )

    serialized_results = payload["results"]::Dict{String,Any}

    for name in _ordered_report_names(report)
        serialized_results[string(name)] =
            _serialize_metric_result(report.results[name])
    end

    open(path, "w") do io
        TOML.print(io, payload; sorted=true)
    end

    return path
end

"""
    deserialize_report(path)

Read a report produced by [`serialize_report`](@ref).

The reconstructed report preserves result names, values, axes, parameters, and
metadata. TOML string keys in parameter and metadata mappings are converted to
symbols.
"""
function deserialize_report(path::AbstractString)
    isfile(path) || throw(ArgumentError(
        "Report file does not exist: $path"
    ))

    payload = TOML.parsefile(path)

    get(payload, "format", nothing) == "DynamicsMetrics.MetricReport" ||
        throw(ArgumentError(
            "File `$path` is not a DynamicsMetrics MetricReport."
        ))

    get(payload, "format_version", nothing) == 1 || throw(ArgumentError(
        "Unsupported report format version " *
        "$(get(payload, "format_version", nothing))."
    ))

    result_table = get(payload, "results", nothing)
    result_table isa AbstractDict || throw(ArgumentError(
        "Serialized report is missing a valid `results` table."
    ))

    order = Symbol.(get(payload, "metric_order", collect(keys(result_table))))
    results = Dict{Symbol,AbstractMetricResult}()

    for name in order
        key = string(name)
        haskey(result_table, key) || throw(ArgumentError(
            "Serialized report metric order references missing result `$key`."
        ))
        results[name] = _deserialize_metric_result(name, result_table[key])
    end

    report_metadata = _symbolize_mapping(
        get(payload, "report_metadata", Dict{String,Any}())
    )

    return MetricReport(results, _as_namedtuple(report_metadata))
end

function _ordered_report_names(report::MetricReport)
    if hasproperty(report.metadata, :metric_names)
        requested = collect(Symbol.(report.metadata.metric_names))
        available = Set(keys(report.results))

        all(name -> name in available, requested) && return requested
    end

    if hasproperty(report.metadata, :result_names)
        requested = collect(Symbol.(report.metadata.result_names))
        available = Set(keys(report.results))

        all(name -> name in available, requested) && return requested
    end

    return sort!(collect(keys(report.results)); by=string)
end

function _serialize_metric_result(result::MetricResult)
    return Dict{String,Any}(
        "kind" => "scalar",
        "name" => string(result.name),
        "value" => _toml_value(result.value),
        "parameters" => _toml_value(result.parameters),
        "metadata" => _toml_value(result.metadata),
    )
end

function _serialize_metric_result(result::MetricSeries)
    return Dict{String,Any}(
        "kind" => "series",
        "name" => string(result.name),
        "values" => _serialize_array(result.values),
        "axis" => _serialize_array(result.axis),
        "parameters" => _toml_value(result.parameters),
        "metadata" => _toml_value(result.metadata),
    )
end

function _deserialize_metric_result(
    expected_name::Symbol,
    table::AbstractDict,
)
    stored_name = Symbol(get(table, "name", string(expected_name)))
    stored_name == expected_name || throw(ArgumentError(
        "Serialized result key `$expected_name` contains result name " *
        "`$stored_name`."
    ))

    parameters_value = _as_namedtuple(
        _symbolize_mapping(get(table, "parameters", Dict{String,Any}()))
    )
    metadata_value = _as_namedtuple(
        _symbolize_mapping(get(table, "metadata", Dict{String,Any}()))
    )

    kind = get(table, "kind", nothing)

    if kind == "scalar"
        return MetricResult(
            stored_name,
            _decode_toml_value(get(table, "value", nothing)),
            parameters_value,
            metadata_value,
        )
    elseif kind == "series"
        return MetricSeries(
            stored_name,
            _deserialize_array(table["values"]),
            _deserialize_array(table["axis"]),
            parameters_value,
            metadata_value,
        )
    end

    throw(ArgumentError(
        "Unsupported serialized metric result kind `$kind`."
    ))
end

function _serialize_array(value::AbstractArray)
    encoded = _toml_value.(collect(vec(value)))

    return Dict{String,Any}(
        "shape" => collect(size(value)),
        "data" => encoded,
    )
end

function _deserialize_array(table::AbstractDict)
    shape = Tuple(Int.(table["shape"]))
    data = _decode_toml_value.(table["data"])

    prod(shape) == length(data) || throw(DimensionMismatch(
        "Serialized array shape $shape requires $(prod(shape)) elements, " *
        "but $(length(data)) were stored."
    ))

    return reshape(collect(data), shape)
end

function _toml_value(value)
    if value isa NamedTuple
        return Dict(string(key) => _toml_value(getfield(value, key))
                    for key in keys(value))
    elseif value isa AbstractDict
        return Dict(string(key) => _toml_value(item)
                    for (key, item) in value)
    elseif value isa Tuple
        return [_toml_value(item) for item in value]
    elseif value isa AbstractArray
        return _serialize_array(value)
    elseif value isa Symbol
        return Dict("__type__" => "Symbol", "value" => string(value))
    elseif value isa VersionNumber
        return Dict("__type__" => "VersionNumber", "value" => string(value))
    elseif value === nothing
        return Dict("__type__" => "Nothing")
    elseif value isa Real || value isa AbstractString || value isa Bool
        return value
    end

    return Dict(
        "__type__" => "StringRepresentation",
        "julia_type" => string(typeof(value)),
        "value" => sprint(show, value),
    )
end

function _decode_toml_value(value)
    if value isa AbstractDict
        type_tag = get(value, "__type__", nothing)

        if type_tag == "Symbol"
            return Symbol(value["value"])
        elseif type_tag == "VersionNumber"
            return VersionNumber(value["value"])
        elseif type_tag == "Nothing"
            return nothing
        elseif type_tag == "StringRepresentation"
            return value["value"]
        elseif haskey(value, "shape") && haskey(value, "data")
            return _deserialize_array(value)
        end

        return _symbolize_mapping(value)
    elseif value isa AbstractVector
        return _decode_toml_value.(value)
    end

    return value
end

function _symbolize_mapping(mapping::AbstractDict)
    return Dict{Symbol,Any}(
        Symbol(key) => _decode_toml_value(value)
        for (key, value) in mapping
    )
end

function _as_namedtuple(mapping::AbstractDict{Symbol})
    names = sort!(collect(keys(mapping)); by=string)
    return NamedTuple{Tuple(names)}(Tuple(mapping[name] for name in names))
end
