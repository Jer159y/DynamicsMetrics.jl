"""
    RMSE(; reduction=:global)

Root mean squared error between truth and prediction.

For errors `e = prediction - truth`, RMSE is

```math
sqrt{operatorname{mean}(|e|^2)}.
```

Supported reductions are `:global`, `:state`, `:time`, and `:none`.
With `reduction=:none`, the returned values are elementwise absolute errors,
because an unreduced root mean square reduces to `sqrt(abs2(e)) = abs(e)`.
"""
struct RMSE <: AbstractMetric
    reduction::Symbol

    function RMSE(; reduction::Symbol=:global)
        validate_reduction_symbol(reduction)
        return new(reduction)
    end
end

metricname(::RMSE) = :rmse
supports_reduction(::RMSE, reduction::Symbol) =
    reduction in SUPPORTED_REDUCTIONS

function evaluate(
    metric::RMSE,
    truth,
    prediction;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_timeseries(
        truth,
        prediction;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    errors_squared = abs2.(checked.prediction .- checked.truth)
    result = reduce_root_mean(errors_squared, metric.reduction)

    return _pointwise_result(
        metric,
        result,
        checked.metadata;
        dt=dt,
    )
end

"""
    MAE(; reduction=:global)

Mean absolute error between truth and prediction.

```math
operatorname{mean}(|prediction-truth|).
```

Supported reductions are `:global`, `:state`, `:time`, and `:none`.
"""
struct MAE <: AbstractMetric
    reduction::Symbol

    function MAE(; reduction::Symbol=:global)
        validate_reduction_symbol(reduction)
        return new(reduction)
    end
end

metricname(::MAE) = :mae
supports_reduction(::MAE, reduction::Symbol) =
    reduction in SUPPORTED_REDUCTIONS

function evaluate(
    metric::MAE,
    truth,
    prediction;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_timeseries(
        truth,
        prediction;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    absolute_errors = abs.(checked.prediction .- checked.truth)
    result = reduce_mean(absolute_errors, metric.reduction)

    return _pointwise_result(
        metric,
        result,
        checked.metadata;
        dt=dt,
    )
end

"""
    NRMSE(; scale=:std, reduction=:global, corrected=false)

Normalized root mean squared error.

The RMSE numerator is divided by a scale computed from the truth data.

Supported scales:

- `:std`: standard deviation of truth.
- `:range`: maximum minus minimum of truth.
- `:rms`: root mean square of truth.

For `reduction=:state`, normalization is performed independently for each state
variable. For `:global`, `:time`, and `:none`, one global truth scale is used.

A zero or non-finite normalization scale raises an `ArgumentError`.
"""
struct NRMSE <: AbstractMetric
    scale::Symbol
    reduction::Symbol
    corrected::Bool

    function NRMSE(
        ;
        scale::Symbol=:std,
        reduction::Symbol=:global,
        corrected::Bool=false,
    )
        scale in (:std, :range, :rms) || throw(ArgumentError(
            "Unsupported NRMSE scale `$scale`. Supported scales are " *
            "`:std`, `:range`, and `:rms`."
        ))
        validate_reduction_symbol(reduction)
        return new(scale, reduction, corrected)
    end
end

metricname(::NRMSE) = :nrmse
supports_reduction(::NRMSE, reduction::Symbol) =
    reduction in SUPPORTED_REDUCTIONS

function evaluate(
    metric::NRMSE,
    truth,
    prediction;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_timeseries(
        truth,
        prediction;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    require_real(checked.truth, :truth)

    squared_errors = abs2.(checked.prediction .- checked.truth)
    rmse = reduce_root_mean(squared_errors, metric.reduction)
    scale = _normalization_scale(
        checked.truth,
        metric.scale,
        metric.reduction;
        corrected=metric.corrected,
    )
    _require_nonzero_scale(scale, metric.scale)

    normalized = rmse ./ scale

    extra_metadata = merge(
        checked.metadata,
        (normalization_scale=scale,),
    )

    return _pointwise_result(
        metric,
        normalized,
        extra_metadata;
        dt=dt,
    )
end

"""
    RelativeL2Error(; reduction=:global)

Relative Euclidean error

```math
\frac{lVert prediction-truth\rVert_2}{lVert truth\rVert_2}.
```

With `reduction=:state`, one relative error is computed per state variable.
With `reduction=:time`, one relative error is computed per time sample.
With `reduction=:none`, elementwise relative absolute error is returned.

A zero truth norm or zero truth magnitude raises an `ArgumentError`.
"""
struct RelativeL2Error <: AbstractMetric
    reduction::Symbol

    function RelativeL2Error(; reduction::Symbol=:global)
        validate_reduction_symbol(reduction)
        return new(reduction)
    end
end

metricname(::RelativeL2Error) = :relative_l2_error
supports_reduction(::RelativeL2Error, reduction::Symbol) =
    reduction in SUPPORTED_REDUCTIONS

function evaluate(
    metric::RelativeL2Error,
    truth,
    prediction;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = validate_timeseries(
        truth,
        prediction;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    squared_errors = abs2.(checked.prediction .- checked.truth)
    squared_truth = abs2.(checked.truth)

    numerator = sqrt.(reduce_sum(squared_errors, metric.reduction))
    denominator = sqrt.(reduce_sum(squared_truth, metric.reduction))
    _require_nonzero_scale(denominator, :truth_l2_norm)

    relative_error = numerator ./ denominator

    return _pointwise_result(
        metric,
        relative_error,
        checked.metadata;
        dt=dt,
    )
end

"""
    ErrorOverTime(; norm=:rmse)

Time-resolved prediction error, aggregated over state variables.

Supported norms:

- `:rmse`: root mean squared error over states.
- `:mae`: mean absolute error over states.
- `:l2`: Euclidean error over states.

The result is always a `MetricSeries` with one value per time sample.
"""
struct ErrorOverTime <: AbstractMetric
    norm::Symbol

    function ErrorOverTime(; norm::Symbol=:rmse)
        norm in (:rmse, :mae, :l2) || throw(ArgumentError(
            "Unsupported time-error norm `$norm`. Supported values are " *
            "`:rmse`, `:mae`, and `:l2`."
        ))
        return new(norm)
    end
end

metricname(::ErrorOverTime) = :error_over_time
supports_reduction(::ErrorOverTime, reduction::Symbol) = reduction === :time

function evaluate(
    metric::ErrorOverTime,
    truth,
    prediction;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
    start::Real=0,
)
    checked = validate_timeseries(
        truth,
        prediction;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    difference = checked.prediction .- checked.truth

    values = if difference isa AbstractVector
        abs.(difference)
    elseif metric.norm === :rmse
        sqrt.(vec(mean(abs2.(difference); dims=1)))
    elseif metric.norm === :mae
        vec(mean(abs.(difference); dims=1))
    else
        sqrt.(vec(sum(abs2.(difference); dims=1)))
    end

    axis = timeaxis(length(values); dt=dt, start=start)

    result_metadata = merge(
        checked.metadata,
        (axis_start=start,),
    )

    return MetricSeries(
        metricname(metric),
        values,
        axis,
        metricparameters(metric),
        result_metadata,
    )
end

function _pointwise_result(
    metric::AbstractMetric,
    result,
    result_metadata::NamedTuple;
    dt=nothing,
)
    reduction = getfield(metric, :reduction)
    parameters = metricparameters(metric)

    if result isa Number
        return MetricResult(
            metricname(metric),
            result,
            parameters,
            result_metadata,
        )
    end

    axis = reduced_axis(
        reduction,
        result_metadata.state_dimension,
        result_metadata.time_length;
        dt=dt,
    )

    return MetricSeries(
        metricname(metric),
        result,
        axis,
        parameters,
        result_metadata,
    )
end

function _normalization_scale(
    truth::AbstractArray,
    scale::Symbol,
    reduction::Symbol;
    corrected::Bool=false,
)
    scale_reduction = reduction === :state ? :state : :global

    if scale === :std
        return _reduced_std(truth, scale_reduction; corrected=corrected)
    elseif scale === :range
        maximum_value = reduce_values(maximum, truth, scale_reduction)
        minimum_value = reduce_values(minimum, truth, scale_reduction)
        return maximum_value .- minimum_value
    elseif scale === :rms
        return reduce_root_mean(abs2.(truth), scale_reduction)
    end

    error("Unreachable normalization scale branch for `$scale`.")
end

function _reduced_std(
    values::AbstractArray,
    reduction::Symbol;
    corrected::Bool=false,
)
    if reduction === :global
        return std(values; corrected=corrected)
    elseif reduction === :state
        ndims(values) == 1 &&
            return std(values; corrected=corrected)
        return vec(std(values; dims=2, corrected=corrected))
    end

    throw(ArgumentError(
        "Standard-deviation normalization supports only `:global` and " *
        "`:state` scale reductions."
    ))
end

function _require_nonzero_scale(scale, label::Symbol)
    if scale isa Number
        isfinite(scale) || throw(ArgumentError(
            "Normalization quantity `$label` must be finite; received $scale."
        ))
        !iszero(scale) || throw(ArgumentError(
            "Normalization quantity `$label` is zero, so the normalized " *
            "metric is undefined."
        ))
        return scale
    end

    for (index, value) in pairs(scale)
        isfinite(value) || throw(ArgumentError(
            "Normalization quantity `$label` is non-finite at index $index: " *
            "$value."
        ))
        !iszero(value) || throw(ArgumentError(
            "Normalization quantity `$label` is zero at index $index, so the " *
            "normalized metric is undefined."
        ))
    end

    return scale
end
