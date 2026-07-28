# Forecast Horizons

Forecast-horizon metrics identify when a prediction ceases to satisfy a chosen
accuracy criterion.

## Time-resolved error

A horizon is based on a scalar error series ``e_t`` across state variables.
Supported norms include RMSE, MAE, and L2. Optional normalization changes the
scale against which the threshold is interpreted.

## Valid prediction time

```julia
ValidPredictionTime(
    ;
    threshold,
    normalization=:none,
    norm=:rmse,
    interpolate=false,
)
```

The valid prediction time is determined by the first sample for which the
selected error is strictly greater than the threshold.

```julia
result = evaluate(
    ValidPredictionTime(
        threshold=0.4,
        normalization=:none,
        norm=:rmse,
        interpolate=false,
    ),
    truth,
    prediction;
    dt=0.5,
)
```

Important metadata includes:

```julia
result.metadata.crossed
result.metadata.crossing_index
```

## Forecast horizon

```julia
ForecastHorizon(
    ;
    threshold,
    normalization=:none,
    norm=:rmse,
    interpolate=false,
)
```

`ForecastHorizon` uses the same threshold-crossing framework and provides a
forecast-horizon interpretation.

```julia
result = evaluate(
    ForecastHorizon(
        threshold=0.4,
        normalization=:none,
        norm=:rmse,
        interpolate=true,
    ),
    truth,
    prediction;
    dt=0.5,
)
```

## Interpolation

With `interpolate=false`, the returned crossing corresponds to the first
sampled failure.

With `interpolate=true`, a crossing time is estimated between the last valid
sample and the first invalid sample. This reduces grid quantization but assumes
that local interpolation is meaningful.

## No crossing

When the threshold is never crossed, the result represents the full evaluated
horizon and metadata records `crossed=false`.

Always inspect the crossing flag rather than inferring it only from the
numerical value.

## First-sample failure

If the first retained sample already exceeds the threshold, the valid horizon
is zero in the chosen time units.

## Sample spacing

Without physical spacing, results are interpreted in sample-step units. With:

```julia
dt=0.25
```

the horizon is expressed in physical time.

## Threshold selection

A threshold is part of the metric definition, not a universal constant. Its
meaning depends on:

- the error norm;
- normalization;
- state scaling;
- scientific tolerance;
- sample interval;
- whether the model is expected to track phase exactly.

Report all of these choices.

## Relationship to Lyapunov time

A forecast horizon is not automatically a Lyapunov time. Conversion requires a
reliable Lyapunov exponent and an explicit convention. Avoid calling a
threshold-crossing time a Lyapunov-scaled VPT unless the scaling was actually
performed.
