"""
    ValidPredictionTime(; threshold=0.4, normalization=:std,
                        norm=:rmse, interpolate=false)

Valid prediction time (VPT): the first time at which a normalized prediction
error reaches or exceeds a prescribed threshold.

For each time sample `t`, an error curve is constructed over the state
dimension. The supported state-aggregation norms are:

- `:rmse`: root mean squared error over states.
- `:mae`: mean absolute error over states.
- `:l2`: Euclidean error over states.

The error curve may be normalized using:

- `:std`: global standard deviation of the truth trajectory.
- `:range`: global range of the truth trajectory.
- `:rms`: global root mean square of the truth trajectory.
- `:none`: no normalization.

If `interpolate=true`, the threshold crossing time is estimated by linear
interpolation between the last valid point and the first invalid point.

The returned `MetricResult` value is expressed in physical time when `dt` is
provided, and in sample steps otherwise.

If the threshold is never crossed, the returned value is the full effective
prediction horizon.
"""
struct ValidPredictionTime <: AbstractMetric
    threshold::Float64
    normalization::Symbol
    norm::Symbol
    interpolate::Bool

    function ValidPredictionTime(
        ;
        threshold::Real=0.4,
        normalization::Symbol=:std,
        norm::Symbol=:rmse,
        interpolate::Bool=false,
    )
        isfinite(threshold) || throw(ArgumentError(
            "`threshold` must be finite; received $threshold."
        ))
        threshold > 0 || throw(ArgumentError(
            "`threshold` must be positive; received $threshold."
        ))

        normalization in (:std, :range, :rms, :none) ||
            throw(ArgumentError(
                "Unsupported normalization `$normalization`. Supported values " *
                "are `:std`, `:range`, `:rms`, and `:none`."
            ))

        norm in (:rmse, :mae, :l2) || throw(ArgumentError(
            "Unsupported VPT norm `$norm`. Supported values are " *
            "`:rmse`, `:mae`, and `:l2`."
        ))

        return new(
            Float64(threshold),
            normalization,
            norm,
            interpolate,
        )
    end
end

metricname(::ValidPredictionTime) = :valid_prediction_time
supports_reduction(::ValidPredictionTime, reduction::Symbol) =
    reduction === :time

"""
    ForecastHorizon(; threshold, normalization=:none,
                    norm=:rmse, interpolate=false)

General first-threshold-crossing forecast horizon.

This metric has the same computation as `ValidPredictionTime` but exposes the
public metric name `:forecast_horizon`. It is useful when the threshold is not
intended to represent a conventional VPT definition.
"""
struct ForecastHorizon <: AbstractMetric
    threshold::Float64
    normalization::Symbol
    norm::Symbol
    interpolate::Bool

    function ForecastHorizon(
        ;
        threshold::Real,
        normalization::Symbol=:none,
        norm::Symbol=:rmse,
        interpolate::Bool=false,
    )
        vpt = ValidPredictionTime(
            threshold=threshold,
            normalization=normalization,
            norm=norm,
            interpolate=interpolate,
        )

        return new(
            vpt.threshold,
            vpt.normalization,
            vpt.norm,
            vpt.interpolate,
        )
    end
end

metricname(::ForecastHorizon) = :forecast_horizon
supports_reduction(::ForecastHorizon, reduction::Symbol) =
    reduction === :time

function evaluate(
    metric::Union{ValidPredictionTime,ForecastHorizon},
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

    require_real(checked.truth, :truth)

    raw_error = _horizon_error_curve(
        checked.truth,
        checked.prediction,
        metric.norm,
    )

    scale = _horizon_scale(
        checked.truth,
        metric.normalization,
    )

    normalized_error = metric.normalization === :none ?
        raw_error :
        raw_error ./ scale

    crossing = first_threshold_crossing(
        normalized_error,
        metric.threshold;
        dt=dt,
        start=start,
        interpolate=metric.interpolate,
    )

    result_metadata = merge(
        checked.metadata,
        (
            threshold = metric.threshold,
            normalization = metric.normalization,
            normalization_scale = scale,
            norm = metric.norm,
            interpolate = metric.interpolate,
            crossed = crossing.crossed,
            crossing_index = crossing.index,
            crossing_error = crossing.error,
            previous_error = crossing.previous_error,
            full_horizon = crossing.full_horizon,
            axis_start = start,
        ),
    )

    return MetricResult(
        metricname(metric),
        crossing.time,
        metricparameters(metric),
        result_metadata,
    )
end

"""
    first_threshold_crossing(values, threshold;
                             dt=nothing, start=0, interpolate=false)

Find the first index where `values[index] >= threshold`.

The returned named tuple contains:

- `time`: crossing time, or the full horizon if no crossing occurs.
- `index`: first crossing index, or `nothing`.
- `crossed`: whether a crossing occurred.
- `error`: error at the crossing index, or the final error.
- `previous_error`: preceding error value when available.
- `full_horizon`: total represented horizon.

Sample index 1 corresponds to `start`. Therefore, without interpolation, a
crossing at index `k` occurs at `start + (k - 1) * step`, where `step` is `dt`
or one sample.
"""
function first_threshold_crossing(
    values::AbstractVector,
    threshold::Real;
    dt=nothing,
    start::Real=0,
    interpolate::Bool=false,
)
    isempty(values) && throw(ArgumentError(
        "`values` must contain at least one sample."
    ))

    isfinite(threshold) || throw(ArgumentError(
        "`threshold` must be finite; received $threshold."
    ))

    isfinite(start) || throw(ArgumentError(
        "`start` must be finite; received $start."
    ))

    _validate_dt(dt)
    step = dt === nothing ? 1.0 : float(dt)

    for (index, value) in pairs(values)
        isfinite(value) || throw(ArgumentError(
            "`values` contains a non-finite entry at index $index: $value."
        ))
    end

    crossing_index = findfirst(value -> value >= threshold, values)
    full_horizon = float(start) + (length(values) - 1) * step

    if crossing_index === nothing
        return (
            time = full_horizon,
            index = nothing,
            crossed = false,
            error = values[end],
            previous_error = length(values) > 1 ? values[end - 1] : nothing,
            full_horizon = full_horizon,
        )
    end

    crossing_error = values[crossing_index]
    previous_error = crossing_index > 1 ?
        values[crossing_index - 1] :
        nothing

    crossing_time = float(start) + (crossing_index - 1) * step

    if interpolate && crossing_index > 1
        previous = values[crossing_index - 1]
        current = values[crossing_index]

        if current != previous
            fraction = (threshold - previous) / (current - previous)
            fraction = clamp(float(fraction), 0.0, 1.0)
            crossing_time = (
                float(start) +
                (crossing_index - 2 + fraction) * step
            )
        end
    end

    return (
        time = crossing_time,
        index = crossing_index,
        crossed = true,
        error = crossing_error,
        previous_error = previous_error,
        full_horizon = full_horizon,
    )
end

"""
    threshold_mask(values, threshold)

Return a Boolean vector indicating samples strictly below `threshold`.
"""
function threshold_mask(
    values::AbstractVector,
    threshold::Real,
)
    isfinite(threshold) || throw(ArgumentError(
        "`threshold` must be finite; received $threshold."
    ))

    return values .< threshold
end

function _horizon_error_curve(
    truth::AbstractVector,
    prediction::AbstractVector,
    norm::Symbol,
)
    return abs.(prediction .- truth)
end

function _horizon_error_curve(
    truth::AbstractMatrix,
    prediction::AbstractMatrix,
    norm::Symbol,
)
    difference = prediction .- truth

    if norm === :rmse
        return sqrt.(vec(mean(abs2.(difference); dims=1)))
    elseif norm === :mae
        return vec(mean(abs.(difference); dims=1))
    elseif norm === :l2
        return sqrt.(vec(sum(abs2.(difference); dims=1)))
    end

    error("Unreachable horizon norm branch for `$norm`.")
end

function _horizon_scale(
    truth::AbstractArray,
    normalization::Symbol,
)
    if normalization === :none
        return 1.0
    elseif normalization === :std
        scale = std(truth; corrected=false)
    elseif normalization === :range
        scale = maximum(truth) - minimum(truth)
    elseif normalization === :rms
        scale = sqrt(mean(abs2, truth))
    else
        error("Unreachable horizon normalization branch for `$normalization`.")
    end

    _require_nonzero_scale(scale, normalization)
    return scale
end
