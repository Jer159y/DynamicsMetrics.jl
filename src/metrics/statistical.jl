"""
    CovarianceError(; norm=:frobenius, relative=false, corrected=false)

Difference between the state covariance matrices of truth and prediction.

The canonical input layout is `state × time`. Vectors are treated as
single-state trajectories.

Supported matrix norms:

- `:frobenius`
- `:spectral`
- `:maximum`

When `relative=true`, the covariance difference is divided by the norm of the
truth covariance matrix. A zero truth covariance norm raises an error.
"""
struct CovarianceError <: AbstractMetric
    norm::Symbol
    relative::Bool
    corrected::Bool

    function CovarianceError(
        ;
        norm::Symbol=:frobenius,
        relative::Bool=false,
        corrected::Bool=false,
    )
        norm in (:frobenius, :spectral, :maximum) || throw(ArgumentError(
            "Unsupported covariance norm `$norm`. Supported values are " *
            "`:frobenius`, `:spectral`, and `:maximum`."
        ))

        return new(norm, relative, corrected)
    end
end

metricname(::CovarianceError) = :covariance_error

function evaluate(
    metric::CovarianceError,
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
    require_real(checked.prediction, :prediction)

    truth_covariance = _state_covariance(
        checked.truth;
        corrected=metric.corrected,
    )
    prediction_covariance = _state_covariance(
        checked.prediction;
        corrected=metric.corrected,
    )

    difference = prediction_covariance - truth_covariance
    value = _matrix_error_norm(difference, metric.norm)

    truth_norm = _matrix_error_norm(truth_covariance, metric.norm)

    if metric.relative
        _require_nonzero_scale(truth_norm, :truth_covariance_norm)
        value /= truth_norm
    end

    result_metadata = merge(
        checked.metadata,
        (
            norm=metric.norm,
            relative=metric.relative,
            corrected=metric.corrected,
            truth_covariance=truth_covariance,
            prediction_covariance=prediction_covariance,
            truth_covariance_norm=truth_norm,
        ),
    )

    return MetricResult(
        metricname(metric),
        value,
        metricparameters(metric),
        result_metadata,
    )
end

"""
    WassersteinDistance(; reduction=:state)

Empirical first Wasserstein distance between truth and prediction samples.

For one-dimensional empirical samples of equal length, the distance is the mean
absolute difference between their sorted values.

Supported reductions:

- `:state`: compute one distance per state variable.
- `:global`: flatten all states and compute one distance.
"""
struct WassersteinDistance <: AbstractMetric
    reduction::Symbol

    function WassersteinDistance(; reduction::Symbol=:state)
        reduction in (:state, :global) || throw(ArgumentError(
            "WassersteinDistance supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))
        return new(reduction)
    end
end

metricname(::WassersteinDistance) = :wasserstein_distance
supports_reduction(::WassersteinDistance, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::WassersteinDistance,
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
    require_real(checked.prediction, :prediction)

    result = if metric.reduction === :global
        _wasserstein_1d(vec(checked.truth), vec(checked.prediction))
    elseif checked.truth isa AbstractVector
        _wasserstein_1d(checked.truth, checked.prediction)
    else
        distances = Vector{Float64}(undef, size(checked.truth, 1))
        for state in axes(checked.truth, 1)
            distances[state] = _wasserstein_1d(
                @view(checked.truth[state, :]),
                @view(checked.prediction[state, :]),
            )
        end
        distances
    end

    if result isa Number
        return MetricResult(
            metricname(metric),
            result,
            metricparameters(metric),
            checked.metadata,
        )
    end

    return MetricSeries(
        metricname(metric),
        result,
        collect(1:length(result)),
        metricparameters(metric),
        checked.metadata,
    )
end

"""
    QuantileWassersteinDistance(; n_quantiles=200, reduction=:state)

Quantile-matched empirical first Wasserstein distance between truth and
prediction samples of possibly different length.

Unlike `WassersteinDistance`, which requires equal sample counts and compares
sorted values directly, `QuantileWassersteinDistance` compares both samples'
inverse-CDFs on a common probability grid of `n_quantiles` points. This stays
well-defined when truth and prediction have very different sample counts —
for example, a long reference trajectory compared against a short candidate
segment.

For equal-length samples this converges toward `WassersteinDistance`'s value
as `n_quantiles` grows, but the two are not numerically identical for finite
`n_quantiles`.

Supported reductions:

- `:state`: compute one distance per state variable.
- `:global`: flatten all states and compute one distance.

Unlike most metrics in this package, `truth` and `prediction` may have
different time lengths; only their state dimension must match.
"""
struct QuantileWassersteinDistance <: AbstractMetric
    n_quantiles::Int
    reduction::Symbol

    function QuantileWassersteinDistance(
        ;
        n_quantiles::Integer=200,
        reduction::Symbol=:state,
    )
        n_quantiles >= 1 || throw(ArgumentError(
            "`n_quantiles` must be positive; received $n_quantiles."
        ))
        reduction in (:state, :global) || throw(ArgumentError(
            "QuantileWassersteinDistance supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))
        return new(Int(n_quantiles), reduction)
    end
end

metricname(::QuantileWassersteinDistance) = :quantile_wasserstein_distance
supports_reduction(::QuantileWassersteinDistance, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::QuantileWassersteinDistance,
    truth,
    prediction;
    nonfinite::Symbol=:error,
)
    checked_truth = _validate_quantile_input(truth, :truth; nonfinite=nonfinite)
    checked_prediction = _validate_quantile_input(prediction, :prediction; nonfinite=nonfinite)

    _state_dimension(checked_truth) == _state_dimension(checked_prediction) ||
        throw(DimensionMismatch(
            "Truth and prediction must have the same number of state " *
            "variables. Received truth state dimension " *
            "$(_state_dimension(checked_truth)) and prediction state " *
            "dimension $(_state_dimension(checked_prediction))."
        ))

    result = if metric.reduction === :global
        _quantile_wasserstein_1d(vec(checked_truth), vec(checked_prediction), metric.n_quantiles)
    elseif checked_truth isa AbstractVector
        _quantile_wasserstein_1d(checked_truth, checked_prediction, metric.n_quantiles)
    else
        distances = Vector{Float64}(undef, size(checked_truth, 1))
        for state in axes(checked_truth, 1)
            distances[state] = _quantile_wasserstein_1d(
                @view(checked_truth[state, :]),
                @view(checked_prediction[state, :]),
                metric.n_quantiles,
            )
        end
        distances
    end

    result_metadata = (
        truth_time_length=_time_length(checked_truth),
        prediction_time_length=_time_length(checked_prediction),
        state_dimension=_state_dimension(checked_truth),
        n_quantiles=metric.n_quantiles,
        nonfinite=nonfinite,
    )

    if result isa Number
        return MetricResult(
            metricname(metric),
            result,
            metricparameters(metric),
            result_metadata,
        )
    end

    return MetricSeries(
        metricname(metric),
        result,
        collect(1:length(result)),
        metricparameters(metric),
        result_metadata,
    )
end

function _quantile_wasserstein_1d(
    x::AbstractVector,
    y::AbstractVector,
    n_quantiles::Integer,
)
    probs = range(1 / (n_quantiles + 1), n_quantiles / (n_quantiles + 1); length=n_quantiles)
    qx = quantile(vec(x), probs)
    qy = quantile(vec(y), probs)
    return mean(abs.(qx .- qy))
end

function _validate_quantile_input(data, name::Symbol; nonfinite::Symbol)
    _validate_nonfinite_policy(nonfinite)
    array = _validate_timeseries_input(data, name)

    _time_length(array) > 0 || throw(ArgumentError(
        "`$name` must contain at least one time sample."
    ))

    require_real(array, name)

    if nonfinite === :error
        _require_finite(array, name)
    end

    return array
end

"""
    JensenShannonDivergence(; bins=50, reduction=:state,
                            base=2, range=:combined)

Histogram-based Jensen–Shannon divergence between truth and prediction.

Supported reductions:

- `:state`: one divergence per state variable.
- `:global`: flatten all states before histogramming.

Supported histogram ranges:

- `:combined`: use the minimum and maximum over truth and prediction.
- `:truth`: use the truth range and clamp prediction samples to edge bins.

The divergence is bounded by one when `base=2`.
"""
struct JensenShannonDivergence <: AbstractMetric
    bins::Int
    reduction::Symbol
    base::Float64
    range::Symbol

    function JensenShannonDivergence(
        ;
        bins::Integer=50,
        reduction::Symbol=:state,
        base::Real=2,
        range::Symbol=:combined,
    )
        bins >= 2 || throw(ArgumentError(
            "`bins` must be at least 2; received $bins."
        ))

        reduction in (:state, :global) || throw(ArgumentError(
            "JensenShannonDivergence supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))

        isfinite(base) || throw(ArgumentError(
            "`base` must be finite; received $base."
        ))
        base > 0 && base != 1 || throw(ArgumentError(
            "`base` must be positive and different from one; received $base."
        ))

        range in (:combined, :truth) || throw(ArgumentError(
            "Unsupported histogram range `$range`. Supported values are " *
            "`:combined` and `:truth`."
        ))

        return new(Int(bins), reduction, Float64(base), range)
    end
end

metricname(::JensenShannonDivergence) = :jensen_shannon_divergence
supports_reduction(::JensenShannonDivergence, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::JensenShannonDivergence,
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
    require_real(checked.prediction, :prediction)

    result = if metric.reduction === :global
        _js_divergence(
            vec(checked.truth),
            vec(checked.prediction);
            bins=metric.bins,
            base=metric.base,
            range_policy=metric.range,
        )
    elseif checked.truth isa AbstractVector
        _js_divergence(
            checked.truth,
            checked.prediction;
            bins=metric.bins,
            base=metric.base,
            range_policy=metric.range,
        )
    else
        divergences = Vector{Float64}(undef, size(checked.truth, 1))
        for state in axes(checked.truth, 1)
            divergences[state] = _js_divergence(
                @view(checked.truth[state, :]),
                @view(checked.prediction[state, :]);
                bins=metric.bins,
                base=metric.base,
                range_policy=metric.range,
            )
        end
        divergences
    end

    result_metadata = merge(
        checked.metadata,
        (
            bins=metric.bins,
            entropy_base=metric.base,
            histogram_range=metric.range,
        ),
    )

    if result isa Number
        return MetricResult(
            metricname(metric),
            result,
            metricparameters(metric),
            result_metadata,
        )
    end

    return MetricSeries(
        metricname(metric),
        result,
        collect(1:length(result)),
        metricparameters(metric),
        result_metadata,
    )
end

function _state_covariance(
    values::AbstractVector;
    corrected::Bool=false,
)
    n = length(values)
    minimum_samples = corrected ? 2 : 1
    n >= minimum_samples || throw(ArgumentError(
        "Covariance with corrected=$corrected requires at least " *
        "$minimum_samples samples; received $n."
    ))

    centered = values .- mean(values)
    denominator = corrected ? n - 1 : n
    return reshape(sum(abs2, centered) / denominator, 1, 1)
end

function _state_covariance(
    values::AbstractMatrix;
    corrected::Bool=false,
)
    n = size(values, 2)
    minimum_samples = corrected ? 2 : 1
    n >= minimum_samples || throw(ArgumentError(
        "Covariance with corrected=$corrected requires at least " *
        "$minimum_samples time samples; received $n."
    ))

    centered = values .- mean(values; dims=2)
    denominator = corrected ? n - 1 : n
    return Matrix(centered * transpose(centered) / denominator)
end

function _matrix_error_norm(
    matrix::AbstractMatrix,
    norm_name::Symbol,
)
    if norm_name === :frobenius
        return norm(matrix)
    elseif norm_name === :spectral
        return opnorm(matrix, 2)
    elseif norm_name === :maximum
        return maximum(abs, matrix)
    end

    error("Unreachable matrix norm branch for `$norm_name`.")
end

function _wasserstein_1d(
    truth::AbstractVector,
    prediction::AbstractVector,
)
    length(truth) == length(prediction) || throw(DimensionMismatch(
        "Empirical Wasserstein distance currently requires equal sample " *
        "counts; received $(length(truth)) and $(length(prediction))."
    ))

    isempty(truth) && throw(ArgumentError(
        "Wasserstein distance requires at least one sample."
    ))

    return mean(abs.(sort(collect(truth)) .- sort(collect(prediction))))
end

function _js_divergence(
    truth::AbstractVector,
    prediction::AbstractVector;
    bins::Integer,
    base::Real,
    range_policy::Symbol,
)
    lower, upper = _histogram_bounds(truth, prediction, range_policy)

    if lower == upper
        return all(==(lower), prediction) ? 0.0 : 1.0
    end

    truth_counts = _histogram_counts(truth, bins, lower, upper)
    prediction_counts = _histogram_counts(prediction, bins, lower, upper)

    truth_probability = truth_counts ./ sum(truth_counts)
    prediction_probability = prediction_counts ./ sum(prediction_counts)
    midpoint = (truth_probability .+ prediction_probability) ./ 2

    return 0.5 * _kl_discrete(truth_probability, midpoint, base) +
           0.5 * _kl_discrete(prediction_probability, midpoint, base)
end

function _histogram_bounds(
    truth::AbstractVector,
    prediction::AbstractVector,
    range_policy::Symbol,
)
    isempty(truth) && throw(ArgumentError(
        "Histogram divergence requires at least one truth sample."
    ))
    isempty(prediction) && throw(ArgumentError(
        "Histogram divergence requires at least one prediction sample."
    ))

    if range_policy === :combined
        return (
            min(minimum(truth), minimum(prediction)),
            max(maximum(truth), maximum(prediction)),
        )
    elseif range_policy === :truth
        return (minimum(truth), maximum(truth))
    end

    error("Unreachable histogram range branch for `$range_policy`.")
end

function _histogram_counts(
    values::AbstractVector,
    bins::Integer,
    lower::Real,
    upper::Real,
)
    counts = zeros(Float64, bins)
    width = (upper - lower) / bins

    for value in values
        index = if value <= lower
            1
        elseif value >= upper
            bins
        else
            floor(Int, (value - lower) / width) + 1
        end

        counts[index] += 1
    end

    return counts
end

function _kl_discrete(
    p::AbstractVector,
    q::AbstractVector,
    base::Real,
)
    divergence = 0.0
    log_base = log(base)

    for index in eachindex(p, q)
        probability = p[index]

        if probability > 0
            q[index] > 0 || return Inf
            divergence += probability * (
                log(probability / q[index]) / log_base
            )
        end
    end

    return divergence
end
