"""
    EnsembleMean()

Compute the ensemble mean over the third array dimension.

The canonical ensemble layout is:

```text
state × time × ensemble
```

The result is returned as a `MetricSeries` whose values have layout
`state × time`.
"""
struct EnsembleMean <: AbstractMetric end

metricname(::EnsembleMean) = :ensemble_mean

function evaluate(
    metric::EnsembleMean,
    truth,
    predictions;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_ensemble(
        truth,
        predictions;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    values = dropdims(mean(checked.predictions; dims=3); dims=3)
    axis = timeaxis(checked.metadata.time_length; dt=dt)

    return MetricSeries(
        metricname(metric),
        values,
        axis,
        metricparameters(metric),
        checked.metadata,
    )
end

"""
    EnsembleSpread(; corrected=false, reduction=:time)

Compute ensemble spread as the standard deviation across ensemble members.

Supported reductions:

- `:none`: return spread with layout `state × time`.
- `:state`: average spread over time, returning one value per state.
- `:time`: average spread over state, returning one value per time.
- `:global`: average all spread values into one scalar.
"""
struct EnsembleSpread <: AbstractMetric
    corrected::Bool
    reduction::Symbol

    function EnsembleSpread(
        ;
        corrected::Bool=false,
        reduction::Symbol=:time,
    )
        validate_reduction_symbol(reduction)
        return new(corrected, reduction)
    end
end

metricname(::EnsembleSpread) = :ensemble_spread
supports_reduction(::EnsembleSpread, reduction::Symbol) =
    reduction in SUPPORTED_REDUCTIONS

function evaluate(
    metric::EnsembleSpread,
    truth,
    predictions;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_ensemble(
        truth,
        predictions;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    ensemble_size = checked.metadata.ensemble_size
    minimum_members = metric.corrected ? 2 : 1

    ensemble_size >= minimum_members || throw(ArgumentError(
        "Ensemble spread with corrected=$(metric.corrected) requires at least " *
        "$minimum_members ensemble members; received $ensemble_size."
    ))

    spread = dropdims(
        std(
            checked.predictions;
            dims=3,
            corrected=metric.corrected,
        );
        dims=3,
    )

    reduced = reduce_mean(spread, metric.reduction)
    result_metadata = merge(
        checked.metadata,
        (
            corrected=metric.corrected,
            unreduced_shape=size(spread),
        ),
    )

    if reduced isa Number
        return MetricResult(
            metricname(metric),
            reduced,
            metricparameters(metric),
            result_metadata,
        )
    end

    axis = reduced_axis(
        metric.reduction,
        checked.metadata.state_dimension,
        checked.metadata.time_length;
        dt=dt,
    )

    return MetricSeries(
        metricname(metric),
        reduced,
        axis,
        metricparameters(metric),
        result_metadata,
    )
end

"""
    EnsembleMeanError(; metric=RMSE())

Evaluate a pointwise metric on the ensemble mean prediction.

The wrapped metric must return a subtype of `AbstractMetricResult` when
evaluated on a standard truth/prediction pair.
"""
struct EnsembleMeanError{M<:AbstractMetric} <: AbstractMetric
    metric::M
end

EnsembleMeanError(; metric::AbstractMetric=RMSE()) =
    EnsembleMeanError(metric)

metricname(::EnsembleMeanError) = :ensemble_mean_error

function metricparameters(metric::EnsembleMeanError)
    return (
        wrapped_metric=metricname(metric.metric),
        wrapped_parameters=metricparameters(metric.metric),
    )
end

function evaluate(
    metric::EnsembleMeanError,
    truth,
    predictions;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_ensemble(
        truth,
        predictions;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    ensemble_mean = dropdims(
        mean(checked.predictions; dims=3);
        dims=3,
    )

    result = evaluate(
        metric.metric,
        checked.truth,
        ensemble_mean;
        discard=0,
        dt=dt,
        nonfinite=nonfinite,
    )

    wrapped_name = _result_name(result)
    result_metadata = merge(
        metadata(result),
        (
            ensemble_size=checked.metadata.ensemble_size,
            wrapped_metric=wrapped_name,
        ),
    )

    if result isa MetricResult
        return MetricResult(
            metricname(metric),
            value(result),
            metricparameters(metric),
            result_metadata,
        )
    elseif result isa MetricSeries
        return MetricSeries(
            metricname(metric),
            value(result),
            result.axis,
            metricparameters(metric),
            result_metadata,
        )
    end

    throw(ArgumentError(
        "Wrapped metric $(typeof(metric.metric)) returned unsupported result " *
        "type $(typeof(result))."
    ))
end

"""
    MemberwiseError(; metric=RMSE(reduction=:global))

Evaluate a scalar pointwise metric independently for every ensemble member.

The wrapped metric must return a scalar `MetricResult`.
"""
struct MemberwiseError{M<:AbstractMetric} <: AbstractMetric
    metric::M
end

MemberwiseError(; metric::AbstractMetric=RMSE(reduction=:global)) =
    MemberwiseError(metric)

metricname(::MemberwiseError) = :memberwise_error

function metricparameters(metric::MemberwiseError)
    return (
        wrapped_metric=metricname(metric.metric),
        wrapped_parameters=metricparameters(metric.metric),
    )
end

function evaluate(
    metric::MemberwiseError,
    truth,
    predictions;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_ensemble(
        truth,
        predictions;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    values = Vector{Float64}(undef, checked.metadata.ensemble_size)

    for member in 1:checked.metadata.ensemble_size
        result = evaluate(
            metric.metric,
            checked.truth,
            @view(checked.predictions[:, :, member]);
            discard=0,
            dt=dt,
            nonfinite=nonfinite,
        )

        result isa MetricResult || throw(ArgumentError(
            "MemberwiseError requires the wrapped metric to return a scalar " *
            "`MetricResult`; received $(typeof(result)) for member $member."
        ))

        scalar = value(result)
        scalar isa Real || throw(ArgumentError(
            "MemberwiseError requires real scalar metric values; received " *
            "$(typeof(scalar)) for member $member."
        ))

        values[member] = float(scalar)
    end

    result_metadata = merge(
        checked.metadata,
        (
            wrapped_metric=metricname(metric.metric),
            member_mean=mean(values),
            member_std=std(values; corrected=false),
            best_member=argmin(values),
            worst_member=argmax(values),
        ),
    )

    return MetricSeries(
        metricname(metric),
        values,
        collect(1:length(values)),
        metricparameters(metric),
        result_metadata,
    )
end

"""
    PredictionIntervalCoverage(; lower=0.05, upper=0.95,
                               reduction=:global)

Empirical coverage of an ensemble prediction interval.

For each state and time sample, the lower and upper ensemble quantiles are
computed and coverage is one when the truth lies inside the closed interval.

Supported reductions:

- `:global`
- `:state`
- `:time`
- `:none`
"""
struct PredictionIntervalCoverage <: AbstractMetric
    lower::Float64
    upper::Float64
    reduction::Symbol

    function PredictionIntervalCoverage(
        ;
        lower::Real=0.05,
        upper::Real=0.95,
        reduction::Symbol=:global,
    )
        isfinite(lower) && isfinite(upper) || throw(ArgumentError(
            "Coverage quantiles must be finite."
        ))
        0 <= lower < upper <= 1 || throw(ArgumentError(
            "Coverage quantiles must satisfy `0 ≤ lower < upper ≤ 1`; " *
            "received lower=$lower and upper=$upper."
        ))
        validate_reduction_symbol(reduction)

        return new(Float64(lower), Float64(upper), reduction)
    end
end

metricname(::PredictionIntervalCoverage) = :prediction_interval_coverage
supports_reduction(::PredictionIntervalCoverage, reduction::Symbol) =
    reduction in SUPPORTED_REDUCTIONS

function evaluate(
    metric::PredictionIntervalCoverage,
    truth,
    predictions;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_ensemble(
        truth,
        predictions;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    truth_matrix = checked.truth isa AbstractVector ?
        reshape(checked.truth, 1, :) :
        checked.truth

    lower_bound = _ensemble_quantile(checked.predictions, metric.lower)
    upper_bound = _ensemble_quantile(checked.predictions, metric.upper)

    covered = (
        (truth_matrix .>= lower_bound) .&
        (truth_matrix .<= upper_bound)
    )

    coverage = reduce_mean(Float64.(covered), metric.reduction)

    result_metadata = merge(
        checked.metadata,
        (
            lower_quantile=metric.lower,
            upper_quantile=metric.upper,
            nominal_coverage=metric.upper - metric.lower,
        ),
    )

    if coverage isa Number
        return MetricResult(
            metricname(metric),
            coverage,
            metricparameters(metric),
            result_metadata,
        )
    end

    axis = reduced_axis(
        metric.reduction,
        checked.metadata.state_dimension,
        checked.metadata.time_length;
        dt=dt,
    )

    return MetricSeries(
        metricname(metric),
        coverage,
        axis,
        metricparameters(metric),
        result_metadata,
    )
end

function _ensemble_quantile(
    predictions::AbstractArray{<:Number,3},
    probability::Real,
)
    nstate, ntime, nensemble = size(predictions)
    output = Matrix{Float64}(undef, nstate, ntime)

    for state in 1:nstate
        for time in 1:ntime
            samples = sort(Float64.(collect(@view predictions[state, time, :])))
            output[state, time] = _linear_quantile(samples, probability)
        end
    end

    return output
end

function _linear_quantile(
    sorted_values::AbstractVector,
    probability::Real,
)
    n = length(sorted_values)
    n > 0 || throw(ArgumentError(
        "Quantile calculation requires at least one sample."
    ))

    n == 1 && return sorted_values[1]

    position = 1 + (n - 1) * probability
    lower_index = floor(Int, position)
    upper_index = ceil(Int, position)

    lower_index == upper_index && return sorted_values[lower_index]

    fraction = position - lower_index
    return (
        (1 - fraction) * sorted_values[lower_index] +
        fraction * sorted_values[upper_index]
    )
end
