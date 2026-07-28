"""
    AbstractMetric

Abstract supertype for all metric definitions in `DynamicsMetrics.jl`.

A concrete metric subtype stores the configuration required to evaluate one
diagnostic. Metric objects should be immutable whenever practical.

# Interface

Every concrete subtype should implement:

```julia
metricname(metric::MyMetric) -> Symbol
evaluate(metric::MyMetric, truth, prediction; kwargs...)
```

The fallback `metricname` method derives a snake-case symbol from the concrete
type name. Defining an explicit method is recommended whenever the desired
public name differs from that convention.
"""
abstract type AbstractMetric end

"""
    AbstractMetricResult

Abstract supertype for structured results returned by metric evaluations.

Concrete result types are defined separately from metric definitions so that
scalar, vector-valued, and report-level results can share a common interface.
"""
abstract type AbstractMetricResult end

"""
    metricname(metric::AbstractMetric) -> Symbol

Return the stable public name of `metric`.

The fallback converts the concrete type name from CamelCase to snake_case.

# Examples

```julia
struct RootMeanSquaredError <: AbstractMetric end

metricname(RootMeanSquaredError())
# :root_mean_squared_error
```

Concrete metrics may define an explicit method:

```julia
metricname(::RootMeanSquaredError) = :rmse
```
"""
function metricname(metric::AbstractMetric)::Symbol
    return _snakecase_symbol(nameof(typeof(metric)))
end

"""
    evaluate(metric::AbstractMetric, truth, prediction; kwargs...)

Evaluate `metric` on `truth` and `prediction`.

This fallback throws a `MethodError`-style `ArgumentError` with guidance for
metric implementers. Every concrete metric subtype must provide a more specific
method.

The package uses `state × time` as the canonical matrix layout.
"""
function evaluate(
    metric::AbstractMetric,
    truth,
    prediction;
    kwargs...,
)
    throw(ArgumentError(
        "No `evaluate` method is implemented for metric type " *
        "$(typeof(metric)). Define " *
        "`DynamicsMetrics.evaluate(metric::$(nameof(typeof(metric))), " *
        "truth, prediction; kwargs...)`."
    ))
end

"""
    supports_reduction(metric::AbstractMetric, reduction::Symbol) -> Bool

Return whether `metric` supports the requested reduction mode.

The default implementation supports only `:global`. Metrics that provide
state-wise, time-wise, or unreduced outputs should extend this function.

Common reduction symbols are:

- `:global`
- `:state`
- `:time`
- `:none`
"""
supports_reduction(::AbstractMetric, reduction::Symbol) = reduction === :global

"""
    validate_reduction(metric::AbstractMetric, reduction::Symbol) -> Symbol

Validate a reduction mode and return it unchanged.

An informative `ArgumentError` is thrown when the metric does not support the
requested reduction.
"""
function validate_reduction(
    metric::AbstractMetric,
    reduction::Symbol,
)::Symbol
    supports_reduction(metric, reduction) && return reduction

    throw(ArgumentError(
        "Metric `$(metricname(metric))` does not support reduction " *
        "`$reduction`."
    ))
end

"""
    metricparameters(metric::AbstractMetric) -> NamedTuple

Return the public configuration of a metric as a named tuple.

The default implementation reflects over the fields of the concrete metric
type. Metrics may override this method when fields contain internal caches or
other values that should not appear in result metadata.
"""
function metricparameters(metric::AbstractMetric)::NamedTuple
    names = fieldnames(typeof(metric))
    values = ntuple(i -> getfield(metric, i), fieldcount(typeof(metric)))
    return NamedTuple{names}(values)
end

"""
    _snakecase_symbol(name::Symbol) -> Symbol

Convert a CamelCase type name to a snake_case symbol.

This is an internal helper used by the fallback `metricname` implementation.
"""
function _snakecase_symbol(name::Symbol)::Symbol
    text = String(name)

    # Separate acronym-to-word and lower-to-upper boundaries:
    # `NRMSEMetric` -> `NRMSE_Metric`
    # `RootMean`    -> `Root_Mean`
    text = replace(text, r"([A-Z]+)([A-Z][a-z])" => s"\1_\2")
    text = replace(text, r"([a-z0-9])([A-Z])" => s"\1_\2")

    return Symbol(lowercase(text))
end
