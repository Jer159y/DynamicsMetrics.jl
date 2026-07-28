# Pointwise Errors

Pointwise metrics compare aligned truth and prediction arrays.

Let ``X \in \mathbb{R}^{d\times T}`` be truth and
``\widehat X \in \mathbb{R}^{d\times T}`` be prediction. Define:

```math
E = \widehat X - X.
```

## RMSE

```julia
RMSE(; reduction=:global)
```

Global root mean squared error is:

```math
\operatorname{RMSE}(X,\widehat X)
=
\sqrt{\frac{1}{dT}
\sum_{i=1}^{d}\sum_{t=1}^{T}|E_{i,t}|^2}.
```

Statewise RMSE retains one value per state:

```math
\operatorname{RMSE}_i
=
\sqrt{\frac{1}{T}\sum_{t=1}^{T}|E_{i,t}|^2}.
```

Timewise RMSE retains one value per sample:

```math
\operatorname{RMSE}_t
=
\sqrt{\frac{1}{d}\sum_{i=1}^{d}|E_{i,t}|^2}.
```

With `reduction=:none`, the result is ``|E|`` elementwise.

```julia
global_result = evaluate(RMSE(), truth, prediction)
state_result = evaluate(RMSE(reduction=:state), truth, prediction)
time_result = evaluate(RMSE(reduction=:time), truth, prediction)
```

## MAE

```julia
MAE(; reduction=:global)
```

```math
\operatorname{MAE}(X,\widehat X)
=
\frac{1}{dT}
\sum_{i=1}^{d}\sum_{t=1}^{T}|E_{i,t}|.
```

MAE is less sensitive to isolated large errors than RMSE.

```julia
result = evaluate(MAE(reduction=:state), truth, prediction)
```

## NRMSE

```julia
NRMSE(; scale=:std, reduction=:global, corrected=false)
```

NRMSE divides the RMSE numerator by a truth-derived scale:

```math
\operatorname{NRMSE}
=
\frac{\operatorname{RMSE}(X,\widehat X)}{s(X)}.
```

Supported scales:

- `:std`: standard deviation of truth;
- `:range`: maximum minus minimum;
- `:rms`: root mean square of truth.

For `reduction=:state`, each state is normalized independently. For the other
reductions, a global truth scale is used.

```julia
evaluate(NRMSE(scale=:std), truth, prediction)
evaluate(NRMSE(scale=:range), truth, prediction)
evaluate(NRMSE(scale=:rms), truth, prediction)
```

A zero or non-finite normalization scale is rejected.

## Relative L2 error

```julia
RelativeL2Error(; reduction=:global)
```

```math
\operatorname{RelL2}
=
\frac{\|\widehat X-X\|_2}{\|X\|_2}.
```

For `:state` or `:time`, numerator and denominator are computed along the
corresponding retained geometry. A zero truth norm is rejected.

## Error over time

```julia
ErrorOverTime(; norm=:rmse)
```

This metric always returns one value per time sample. Supported norms are:

```math
e_t^{\mathrm{RMSE}}
=
\sqrt{\frac{1}{d}\sum_i |E_{i,t}|^2},
```

```math
e_t^{\mathrm{MAE}}
=
\frac{1}{d}\sum_i |E_{i,t}|,
```

and:

```math
e_t^{L2}
=
\sqrt{\sum_i |E_{i,t}|^2}.
```

```julia
result = evaluate(
    ErrorOverTime(norm=:rmse),
    truth,
    prediction;
    dt=0.1,
    start=0.0,
)
```

Use `.axis` for time and `.values` for the error series.

## Common keywords

Pointwise evaluations support common validation keywords including:

- `discard`;
- `dt`;
- `nonfinite`.

Consult the API reference and docstrings for the exact method signature.

## Interpretation guidance

Report the reduction and units with every value. Global pointwise metrics can
hide state-specific failures and do not characterize long-term distributions,
spectra, recurrence structure, or uncertainty.
