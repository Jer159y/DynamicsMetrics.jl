"""
    report_table(report; digits=6, series=:summary)

Return a plain-text table summarizing a `MetricReport`.

This function has no display-backend dependency and is suitable for terminals,
logs, documentation, and reproducible text artifacts.

The `series` policy accepts:

- `:summary`: summarize series by mean, standard deviation, minimum, and maximum.
- `:omit`: show only scalar metrics.
"""
function report_table(
    report::MetricReport;
    digits::Integer=6,
    series::Symbol=:summary,
)
    digits >= 0 || throw(ArgumentError(
        "`digits` must be nonnegative; received $digits."
    ))
    series in (:summary, :omit) || throw(ArgumentError(
        "`report_table` supports `series=:summary` or `series=:omit`; " *
        "received `$series`."
    ))

    rows = report_summary(report; series=series)
    headers = ["Metric", "Kind", "Value / Summary"]
    rendered = Vector{NTuple{3,String}}()

    for row in rows
        if row.kind === :scalar
            description = _format_report_value(row.value, digits)
            push!(rendered, (string(row.name), "scalar", description))
        else
            description = string(
                "mean=", _format_report_value(row.mean, digits),
                ", std=", _format_report_value(row.std, digits),
                ", min=", _format_report_value(row.minimum, digits),
                ", max=", _format_report_value(row.maximum, digits),
                ", shape=", row.shape,
            )
            push!(rendered, (
                string(row.name),
                "series",
                description,
            ))
        end
    end

    widths = [
        maximum(length.([headers[column]; [row[column] for row in rendered]]))
        for column in 1:3
    ]

    io = IOBuffer()
    _write_table_row(io, Tuple(headers), widths)
    println(io, join([repeat("-", width) for width in widths], "-+-"))

    for row in rendered
        _write_table_row(io, row, widths)
    end

    return String(take!(io))
end

"""
    write_report_table(path, report; kwargs...)

Write [`report_table`](@ref) output to a UTF-8 text file and return `path`.
"""
function write_report_table(
    path::AbstractString,
    report::MetricReport;
    kwargs...,
)
    isempty(path) && throw(ArgumentError(
        "`path` must not be empty."
    ))

    open(path, "w") do io
        write(io, report_table(report; kwargs...))
    end

    return path
end

function _format_report_value(value, digits::Integer)
    if value isa AbstractFloat
        return string(round(value; digits=digits))
    elseif value isa Real || value isa Bool || value isa Symbol
        return string(value)
    end

    return sprint(show, value)
end

function _write_table_row(
    io::IO,
    row::NTuple{3,String},
    widths::AbstractVector{<:Integer},
)
    println(
        io,
        rpad(row[1], widths[1]), " | ",
        rpad(row[2], widths[2]), " | ",
        rpad(row[3], widths[3]),
    )
end
