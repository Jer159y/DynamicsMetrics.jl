"""
    Autocorrelation(; maxlag=nothing, demean=true, normalize=true,
                    reduction=:state)

Autocorrelation of a univariate or multivariate trajectory.

The canonical input layout is `state × time`. For matrix input, autocorrelation
is computed independently for each state variable.

Supported reductions:

- `:state`: return one autocorrelation curve per state variable.
- `:global`: flatten all state variables and compute one global curve.

`maxlag=nothing` uses all available lags from zero to `time_length - 1`.
"""
struct Autocorrelation <: AbstractMetric
    maxlag::Union{Nothing,Int}
    demean::Bool
    normalize::Bool
    reduction::Symbol

    function Autocorrelation(
        ;
        maxlag::Union{Nothing,Integer}=nothing,
        demean::Bool=true,
        normalize::Bool=true,
        reduction::Symbol=:state,
    )
        maxlag === nothing || maxlag >= 0 || throw(ArgumentError(
            "`maxlag` must be nonnegative or `nothing`; received $maxlag."
        ))

        reduction in (:state, :global) || throw(ArgumentError(
            "Autocorrelation supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))

        return new(
            maxlag === nothing ? nothing : Int(maxlag),
            demean,
            normalize,
            reduction,
        )
    end
end

metricname(::Autocorrelation) = :autocorrelation
supports_reduction(::Autocorrelation, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::Autocorrelation,
    data;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = _validate_single_timeseries(
        data;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    require_real(checked.data, :data)

    maxlag = metric.maxlag === nothing ?
        checked.metadata.time_length - 1 :
        metric.maxlag

    maxlag < checked.metadata.time_length || throw(ArgumentError(
        "`maxlag=$maxlag` must be smaller than the effective time length " *
        "$(checked.metadata.time_length)."
    ))

    values = if metric.reduction === :global
        _autocorrelation_vector(
            vec(checked.data),
            maxlag;
            demean=metric.demean,
            normalize=metric.normalize,
        )
    elseif checked.data isa AbstractVector
        _autocorrelation_vector(
            checked.data,
            maxlag;
            demean=metric.demean,
            normalize=metric.normalize,
        )
    else
        result = Matrix{Float64}(
            undef,
            size(checked.data, 1),
            maxlag + 1,
        )

        for state in axes(checked.data, 1)
            result[state, :] .= _autocorrelation_vector(
                @view(checked.data[state, :]),
                maxlag;
                demean=metric.demean,
                normalize=metric.normalize,
            )
        end

        result
    end

    lag_axis = dt === nothing ?
        collect(0:maxlag) :
        collect((0:maxlag) .* float(dt))

    result_metadata = merge(
        checked.metadata,
        (
            maxlag=maxlag,
            demean=metric.demean,
            normalize=metric.normalize,
            lag_units=dt === nothing ? :samples : :time,
        ),
    )

    return MetricSeries(
        metricname(metric),
        values,
        lag_axis,
        metricparameters(metric),
        result_metadata,
    )
end

"""
    PowerSpectralDensity(; detrend=:mean, one_sided=true,
                         reduction=:state)

Periodogram estimate of the power spectral density.

This implementation intentionally uses a direct discrete Fourier transform so
that the package core does not require an FFT dependency. It is suitable for
validation, small and medium trajectories, and reference testing.

Supported detrending policies:

- `:none`
- `:mean`

Supported reductions:

- `:state`: one spectrum per state variable.
- `:global`: flatten all states and compute one spectrum.
"""
struct PowerSpectralDensity <: AbstractMetric
    detrend::Symbol
    one_sided::Bool
    reduction::Symbol

    function PowerSpectralDensity(
        ;
        detrend::Symbol=:mean,
        one_sided::Bool=true,
        reduction::Symbol=:state,
    )
        detrend in (:none, :mean) || throw(ArgumentError(
            "Unsupported detrend policy `$detrend`. Supported values are " *
            "`:none` and `:mean`."
        ))

        reduction in (:state, :global) || throw(ArgumentError(
            "PowerSpectralDensity supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))

        return new(detrend, one_sided, reduction)
    end
end

metricname(::PowerSpectralDensity) = :power_spectral_density
supports_reduction(::PowerSpectralDensity, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::PowerSpectralDensity,
    data;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = _validate_single_timeseries(
        data;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    require_real(checked.data, :data)

    sample_spacing = dt === nothing ? 1.0 : float(dt)

    if metric.reduction === :global
        frequencies, spectrum = _periodogram(
            vec(checked.data),
            sample_spacing;
            detrend=metric.detrend,
            one_sided=metric.one_sided,
        )
        values = spectrum
    elseif checked.data isa AbstractVector
        frequencies, spectrum = _periodogram(
            checked.data,
            sample_spacing;
            detrend=metric.detrend,
            one_sided=metric.one_sided,
        )
        values = spectrum
    else
        frequencies, first_spectrum = _periodogram(
            @view(checked.data[1, :]),
            sample_spacing;
            detrend=metric.detrend,
            one_sided=metric.one_sided,
        )

        values = Matrix{Float64}(
            undef,
            size(checked.data, 1),
            length(first_spectrum),
        )
        values[1, :] .= first_spectrum

        for state in 2:size(checked.data, 1)
            _, spectrum = _periodogram(
                @view(checked.data[state, :]),
                sample_spacing;
                detrend=metric.detrend,
                one_sided=metric.one_sided,
            )
            values[state, :] .= spectrum
        end
    end

    result_metadata = merge(
        checked.metadata,
        (
            detrend=metric.detrend,
            one_sided=metric.one_sided,
            sampling_interval=sample_spacing,
            frequency_units=dt === nothing ? :cycles_per_sample : :inverse_time,
            algorithm=:direct_dft_periodogram,
        ),
    )

    return MetricSeries(
        metricname(metric),
        values,
        frequencies,
        metricparameters(metric),
        result_metadata,
    )
end

"""
    SpectralEntropy(; detrend=:mean, base=2, reduction=:state,
                    normalize=true)

Shannon entropy of the normalized periodogram.

For spectral probabilities `pₖ`, spectral entropy is

```math
H = -sum_k p_k log_b(p_k).
```

When `normalize=true`, entropy is divided by the maximum possible entropy
`log_b(number_of_bins)` and lies in `[0, 1]` up to floating-point error.

Supported reductions:

- `:state`: one entropy value per state variable.
- `:global`: one entropy value for the flattened trajectory.
"""
struct SpectralEntropy <: AbstractMetric
    detrend::Symbol
    base::Float64
    reduction::Symbol
    normalize::Bool

    function SpectralEntropy(
        ;
        detrend::Symbol=:mean,
        base::Real=2,
        reduction::Symbol=:state,
        normalize::Bool=true,
    )
        detrend in (:none, :mean) || throw(ArgumentError(
            "Unsupported detrend policy `$detrend`. Supported values are " *
            "`:none` and `:mean`."
        ))

        isfinite(base) || throw(ArgumentError(
            "`base` must be finite; received $base."
        ))
        base > 0 && base != 1 || throw(ArgumentError(
            "`base` must be positive and different from one; received $base."
        ))

        reduction in (:state, :global) || throw(ArgumentError(
            "SpectralEntropy supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))

        return new(detrend, Float64(base), reduction, normalize)
    end
end

metricname(::SpectralEntropy) = :spectral_entropy
supports_reduction(::SpectralEntropy, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::SpectralEntropy,
    data;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = _validate_single_timeseries(
        data;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    require_real(checked.data, :data)
    sample_spacing = dt === nothing ? 1.0 : float(dt)

    values = if metric.reduction === :global
        _, spectrum = _periodogram(
            vec(checked.data),
            sample_spacing;
            detrend=metric.detrend,
            one_sided=true,
        )
        _spectral_entropy(
            spectrum;
            base=metric.base,
            normalize=metric.normalize,
        )
    elseif checked.data isa AbstractVector
        _, spectrum = _periodogram(
            checked.data,
            sample_spacing;
            detrend=metric.detrend,
            one_sided=true,
        )
        _spectral_entropy(
            spectrum;
            base=metric.base,
            normalize=metric.normalize,
        )
    else
        result = Vector{Float64}(undef, size(checked.data, 1))

        for state in axes(checked.data, 1)
            _, spectrum = _periodogram(
                @view(checked.data[state, :]),
                sample_spacing;
                detrend=metric.detrend,
                one_sided=true,
            )
            result[state] = _spectral_entropy(
                spectrum;
                base=metric.base,
                normalize=metric.normalize,
            )
        end

        result
    end

    result_metadata = merge(
        checked.metadata,
        (
            detrend=metric.detrend,
            entropy_base=metric.base,
            normalized=metric.normalize,
            algorithm=:periodogram_shannon_entropy,
        ),
    )

    if values isa Number
        return MetricResult(
            metricname(metric),
            values,
            metricparameters(metric),
            result_metadata,
        )
    end

    return MetricSeries(
        metricname(metric),
        values,
        collect(1:length(values)),
        metricparameters(metric),
        result_metadata,
    )
end

function _validate_single_timeseries(
    data;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    _validate_nonfinite_policy(nonfinite)
    _validate_dt(dt)
    _validate_discard(discard)

    array = _validate_timeseries_input(data, :data)
    ntime = _time_length(array)

    ntime > 0 || throw(ArgumentError(
        "Time series must contain at least one sample."
    ))
    discard < ntime || throw(ArgumentError(
        "`discard=$discard` removes all $ntime available time samples."
    ))

    view_data = discard_transient(array, discard)

    if nonfinite === :error
        _require_finite(view_data, :data)
    end

    metadata = (
        original_shape=size(array),
        effective_shape=size(view_data),
        state_dimension=_state_dimension(view_data),
        time_length=_time_length(view_data),
        discard=Int(discard),
        dt=dt === nothing ? nothing : float(dt),
        nonfinite=nonfinite,
    )

    return (data=view_data, metadata=metadata)
end

function _autocorrelation_vector(
    values::AbstractVector,
    maxlag::Integer;
    demean::Bool=true,
    normalize::Bool=true,
)
    n = length(values)
    centered = demean ? values .- mean(values) : collect(values)
    result = Vector{Float64}(undef, maxlag + 1)

    denominator = sum(abs2, centered)

    if normalize && iszero(denominator)
        throw(ArgumentError(
            "Autocorrelation normalization is undefined for a constant or " *
            "zero-energy trajectory."
        ))
    end

    for lag in 0:maxlag
        numerator = 0.0
        count = n - lag

        @inbounds for index in 1:count
            numerator += centered[index] * centered[index + lag]
        end

        result[lag + 1] = normalize ?
            numerator / denominator :
            numerator / count
    end

    return result
end

function _periodogram(
    values::AbstractVector,
    dt::Real;
    detrend::Symbol=:mean,
    one_sided::Bool=true,
)
    n = length(values)
    n > 1 || throw(ArgumentError(
        "Power spectral density requires at least two time samples."
    ))

    signal = detrend === :mean ?
        Float64.(values .- mean(values)) :
        Float64.(values)

    nfreq = one_sided ? fld(n, 2) + 1 : n
    spectrum = Vector{Float64}(undef, nfreq)
    frequencies = Vector{Float64}(undef, nfreq)

    for k in 0:(nfreq - 1)
        coefficient = 0.0 + 0.0im

        @inbounds for index in 0:(n - 1)
            angle = -2π * k * index / n
            coefficient += signal[index + 1] * cis(angle)
        end

        power = abs2(coefficient) * dt / n

        if one_sided && k != 0 && !(iseven(n) && k == n ÷ 2)
            power *= 2
        end

        spectrum[k + 1] = power
        frequencies[k + 1] = k / (n * dt)
    end

    return frequencies, spectrum
end

function _spectral_entropy(
    spectrum::AbstractVector;
    base::Real=2,
    normalize::Bool=true,
)
    total_power = sum(spectrum)

    total_power > 0 || throw(ArgumentError(
        "Spectral entropy is undefined for a zero-power spectrum."
    ))

    probabilities = spectrum ./ total_power
    entropy = 0.0

    for probability in probabilities
        if probability > 0
            entropy -= probability * (log(probability) / log(base))
        end
    end

    if normalize
        maximum_entropy = log(length(probabilities)) / log(base)
        maximum_entropy > 0 || return 0.0
        entropy /= maximum_entropy
    end

    return entropy
end
