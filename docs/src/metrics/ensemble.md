# Ensemble Evaluation

An ensemble prediction has layout:

```text
state × time × ensemble
```

Truth has layout `state × time`.

## Ensemble mean

```julia
EnsembleMean()
```

For members ``\widehat X^{(m)}``:

```math
\overline X
=
\frac{1}{M}\sum_{m=1}^{M}\widehat X^{(m)}.
```

```julia
mean_result = evaluate(EnsembleMean(), truth, predictions)
mean_prediction = mean_result.values
```

The truth argument participates in shape validation even though the mean itself
is computed from ensemble predictions.

## Ensemble spread

```julia
EnsembleSpread(
    ;
    corrected=false,
    reduction=:global,
)
```

Spread measures dispersion across ensemble members. `corrected` selects the
sample-variance correction convention where applicable.

```julia
spread = evaluate(
    EnsembleSpread(
        corrected=false,
        reduction=:time,
    ),
    truth,
    predictions,
)
```

Low spread is not automatically good: an underdispersed ensemble can be
confident and wrong.

## Error of the ensemble mean

```julia
EnsembleMeanError(metric=RMSE())
```

This first computes the ensemble mean, then evaluates the selected deterministic
metric against truth:

```julia
result = evaluate(
    EnsembleMeanError(metric=RMSE()),
    truth,
    predictions,
)
```

It measures the central forecast, not member diversity.

## Memberwise error

```julia
MemberwiseError(metric=RMSE())
```

```julia
result = evaluate(
    MemberwiseError(metric=RMSE()),
    truth,
    predictions,
)
```

This evaluates each member separately and returns the collection of member
errors. It reveals heterogeneity that ensemble-mean error can hide.

## Prediction interval coverage

```julia
PredictionIntervalCoverage(
    ;
    lower=0.05,
    upper=0.95,
    reduction=:global,
)
```

At each state and time, empirical ensemble quantiles define an interval.
Coverage is the fraction of truth values lying inside that interval.

```julia
coverage = evaluate(
    PredictionIntervalCoverage(
        lower=0.05,
        upper=0.95,
        reduction=:global,
    ),
    truth,
    predictions,
)
```

Nominal 90% intervals do not guarantee 90% empirical coverage. Coverage should
be interpreted together with interval width or spread; arbitrarily wide
intervals can achieve high coverage.

## Recommended ensemble report

At minimum, evaluate:

- ensemble-mean error;
- ensemble spread;
- memberwise error distribution;
- interval coverage.

These quantities jointly describe accuracy, diversity, and calibration.
