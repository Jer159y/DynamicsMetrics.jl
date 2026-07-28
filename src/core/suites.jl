"""
    MetricSuite

An ordered collection of metrics evaluated on the same truth and prediction
arrays.

Metric names must be unique because results are stored and accessed by their
public `Symbol` names.

# Constructors

```julia
MetricSuite(metrics)
MetricSuite(metric₁, metric₂, ...)
```

# Examples

```julia
suite = MetricSuite(RMSE(), MAE())
report = evaluate(suite, truth, prediction)
```
"""
struct MetricSuite
    metrics::Vector{AbstractMetric}

    function MetricSuite(metrics::AbstractVector{<:AbstractMetric})
        stored = AbstractMetric[metric for metric in metrics]
        _validate_metric_names(stored)
        return new(stored)
    end
end

MetricSuite(metrics::AbstractMetric...) = MetricSuite(collect(metrics))

Base.length(suite::MetricSuite) = length(suite.metrics)
Base.isempty(suite::MetricSuite) = isempty(suite.metrics)
Base.iterate(suite::MetricSuite, state...) = iterate(suite.metrics, state...)
Base.getindex(suite::MetricSuite, index::Integer) = suite.metrics[index]
Base.eltype(::Type{MetricSuite}) = AbstractMetric

"""
    metricnames(suite::MetricSuite) -> Vector{Symbol}

Return metric names in suite evaluation order.
"""
metricnames(suite::MetricSuite) = metricname.(suite.metrics)

"""
    evaluate(suite::MetricSuite, truth, prediction; metadata=(;), kwargs...)

Evaluate every metric in `suite` on the same input data and return a
`MetricReport`.

All keyword arguments except `metadata` are forwarded unchanged to each metric.
This allows shared options such as `discard`, `dt`, or `nonfinite` to be supplied
once, provided that the concrete metrics accept those keywords.

The `metadata` keyword adds report-level metadata and is not forwarded to
individual metrics.

# Result requirements

Each metric evaluation must return an `AbstractMetricResult`, and the result
name must match `metricname(metric)`. Violations raise an informative error.

# Examples

```julia
suite = MetricSuite(RMSE(), MAE())

report = evaluate(
    suite,
    truth,
    prediction;
    discard=100,
    metadata=(experiment="lorenz96",),
)
```
"""
function evaluate(
    suite::MetricSuite,
    truth,
    prediction;
    metadata::NamedTuple=(;),
    kwargs...,
)
    results = Dict{Symbol,AbstractMetricResult}()

    for metric in suite
        name = metricname(metric)
        result = evaluate(metric, truth, prediction; kwargs...)

        result isa AbstractMetricResult || throw(ArgumentError(
            "Metric `$name` returned $(typeof(result)); metric evaluations " *
            "must return a subtype of `AbstractMetricResult`."
        ))

        _result_name(result) == name || throw(ArgumentError(
            "Metric `$name` returned a result named `$(_result_name(result))`. " *
            "A metric result name must match `metricname(metric)`."
        ))

        results[name] = result
    end

    report_metadata = merge(
        (
            metric_names = Tuple(metricnames(suite)),
            metric_count = length(suite),
        ),
        metadata,
    )

    return MetricReport(results, report_metadata)
end

"""
    evaluate(metrics, truth, prediction; kwargs...)

Convenience method that constructs a `MetricSuite` from a vector or tuple of
metrics and evaluates it.
"""
function evaluate(
    metrics::AbstractVector{<:AbstractMetric},
    truth,
    prediction;
    kwargs...,
)
    return evaluate(MetricSuite(metrics), truth, prediction; kwargs...)
end

function evaluate(
    metrics::Tuple{Vararg{AbstractMetric}},
    truth,
    prediction;
    kwargs...,
)
    return evaluate(MetricSuite(metrics...), truth, prediction; kwargs...)
end

"""
    _validate_metric_names(metrics)

Ensure that all metrics have unique public names.
"""
function _validate_metric_names(metrics::AbstractVector{<:AbstractMetric})
    names = metricname.(metrics)
    duplicate_names = _duplicates(names)

    isempty(duplicate_names) || throw(ArgumentError(
        "Metric names in a `MetricSuite` must be unique. Duplicate names: " *
        join(string.(duplicate_names), ", ") *
        ". Configure distinct metrics with distinct public names or evaluate " *
        "them in separate suites."
    ))

    return metrics
end

function _duplicates(values)
    seen = Set{eltype(values)}()
    duplicates = Set{eltype(values)}()

    for item in values
        if item in seen
            push!(duplicates, item)
        else
            push!(seen, item)
        end
    end

    return sort!(collect(duplicates); by=string)
end

_result_name(result::MetricResult) = result.name
_result_name(result::MetricSeries) = result.name

function _result_name(result::AbstractMetricResult)
    hasproperty(result, :name) || throw(ArgumentError(
        "Custom metric result type $(typeof(result)) must expose a `name` " *
        "property or extend `DynamicsMetrics._result_name`."
    ))

    name = getproperty(result, :name)
    name isa Symbol || throw(ArgumentError(
        "The `name` property of $(typeof(result)) must be a `Symbol`; " *
        "received $(typeof(name))."
    ))

    return name
end
