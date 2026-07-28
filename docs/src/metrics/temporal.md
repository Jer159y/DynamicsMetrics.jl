# Temporal Diagnostics

Temporal diagnostics analyze one trajectory. They are not pointwise
truth-versus-prediction metrics.

To compare truth and prediction, evaluate the same diagnostic on both and then
compare the resulting structures explicitly.

## Autocorrelation

```julia
Autocorrelation(
    ;
    maxlag,
    demean=true,
    normalize=true,
    reduction=:state,
)
```

For a demeaned scalar signal ``x_t``, the implementation uses a finite-sample
lag product with a fixed full-series energy denominator. Conceptually:

```math
\rho(k)
=
\frac{\sum_{t=1}^{T-k}(x_t-\bar x)(x_{t+k}-\bar x)}
     {\sum_{t=1}^{T}(x_t-\bar x)^2}.
```

For non-demeaned data, the same structure is applied without subtracting the
mean. Normalization controls whether a correlation-like or unnormalized
quantity is returned.

```julia
acf = evaluate(
    Autocorrelation(
        maxlag=20,
        demean=true,
        normalize=true,
        reduction=:state,
    ),
    trajectory;
    dt=0.1,
)
```

The `.axis` field gives lag values.

## Power spectral density

```julia
PowerSpectralDensity(
    ;
    detrend=:mean,
    one_sided=true,
    reduction=:state,
)
```

Supported detrending modes include:

- `:none`;
- `:mean`.

`detrend` is a `Symbol`, not a Boolean.

```julia
psd = evaluate(
    PowerSpectralDensity(
        detrend=:mean,
        one_sided=true,
        reduction=:state,
    ),
    trajectory;
    dt=0.1,
)
```

The `.axis` field contains frequencies. The scaling is appropriate for
comparisons within the package's documented convention; report `dt`,
detrending, and one-sided/two-sided choice.

## Spectral entropy

```julia
SpectralEntropy(
    ;
    detrend=:mean,
    reduction=:state,
    normalize=true,
)
```

Given nonnegative spectral weights ``P_j`` normalized to probabilities
``p_j=P_j/\sum_kP_k``, spectral entropy is:

```math
H = -\sum_j p_j\log p_j.
```

When normalized, entropy is divided by the maximum entropy for the number of
included frequency bins, yielding a value in the unit interval when the
spectrum is valid.

```julia
entropy = evaluate(
    SpectralEntropy(
        detrend=:mean,
        reduction=:state,
        normalize=true,
    ),
    trajectory,
)
```

Low entropy indicates concentrated spectral power. High entropy indicates
broad spectral dispersion. It does not by itself distinguish deterministic
chaos from stochastic broadband behavior.

## Comparing trajectories

A common workflow is:

```julia
truth_psd = evaluate(metric, truth; dt=dt)
prediction_psd = evaluate(metric, prediction; dt=dt)
```

Then compare aligned frequency axes and values. DynamicsMetrics does not
automatically convert two diagnostic outputs into one discrepancy score unless
a dedicated metric defines that operation.
