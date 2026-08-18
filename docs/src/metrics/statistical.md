# Statistical Metrics

Statistical metrics compare long-run or sample-distribution properties after
pointwise trajectories may have diverged.

## Covariance error

```julia
CovarianceError(
    ;
    norm=:frobenius,
    relative=false,
)
```

Let ``C_X`` and ``C_{\widehat X}`` be state covariance matrices. The default
error is based on their Frobenius difference:

```math
\|C_{\widehat X}-C_X\|_F.
```

With relative normalization, the covariance difference is divided by the truth
covariance norm.

```julia
result = evaluate(
    CovarianceError(
        norm=:frobenius,
        relative=false,
    ),
    truth,
    prediction,
)
```

Covariance agreement captures second-order dependence but not higher-order
structure or temporal ordering.

## Wasserstein distance

```julia
WassersteinDistance(; reduction=:state)
```

The statewise one-dimensional empirical Wasserstein distance compares sorted
sample locations. For equal sample counts, it can be expressed as:

```math
W_1(X_i,\widehat X_i)
=
\frac{1}{T}\sum_{t=1}^{T}
\left|X_{i,(t)}-\widehat X_{i,(t)}\right|,
```

where parentheses denote order statistics.

```julia
result = evaluate(
    WassersteinDistance(reduction=:state),
    truth,
    prediction,
)
```

Statewise marginal Wasserstein distances do not capture cross-state
dependence.

## Quantile Wasserstein distance

```julia
QuantileWassersteinDistance(; n_quantiles=200, reduction=:state)
```

`WassersteinDistance` requires truth and prediction to have equal sample
counts. `QuantileWassersteinDistance` instead compares both samples'
inverse-CDFs on a common probability grid of `n_quantiles` points, so it
remains well-defined when truth and prediction have very different sample
counts -- for example, a long reference trajectory compared against a short
candidate segment.

```julia
result = evaluate(
    QuantileWassersteinDistance(n_quantiles=200, reduction=:state),
    truth,
    prediction,
)
```

For equal-length samples this converges toward `WassersteinDistance`'s value
as `n_quantiles` grows, but the two are not numerically identical for finite
`n_quantiles`.

## Jensen--Shannon divergence

```julia
JensenShannonDivergence(
    ;
    bins,
    reduction=:state,
    base=2,
    range=:combined,
)
```

For histogram distributions ``P`` and ``Q`` and
``M=(P+Q)/2``:

```math
\operatorname{JS}(P,Q)
=
\frac{1}{2}\operatorname{KL}(P\|M)
+
\frac{1}{2}\operatorname{KL}(Q\|M).
```

```julia
result = evaluate(
    JensenShannonDivergence(
        bins=32,
        reduction=:state,
        base=2,
        range=:combined,
    ),
    truth,
    prediction,
)
```

The result depends on bin count, histogram range, and logarithm base. These
parameters must be reported.

## Climate-style evaluation

For chaotic systems, pointwise error often grows rapidly even when the model
reproduces long-run behavior. Statistical metrics can therefore complement a
forecast horizon.

They do not prove dynamical equivalence. A shuffled trajectory can preserve a
marginal distribution while destroying temporal structure. Combine
distributional metrics with temporal and dynamical diagnostics.
