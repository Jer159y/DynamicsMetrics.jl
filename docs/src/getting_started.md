# Getting Started

This chapter develops a complete workflow from one deterministic prediction to
a reusable metric report.

## Load the package

```julia
using DynamicsMetrics
```

## Prepare truth and prediction

DynamicsMetrics expects deterministic trajectories in `state × time` layout:

```julia
truth = [
    0.0  1.0  2.0  3.0
    1.0  2.0  3.0  4.0
]

prediction = [
    0.0  1.1  1.8  3.2
    1.0  1.8  3.3  3.9
]
```

Both arrays must refer to the same state variables, sample times, and forecast
interval.

## Evaluate one metric

```julia
result = evaluate(RMSE(), truth, prediction)
```

A scalar evaluation returns a `MetricResult`:

```julia
result.name
result.value
result.parameters
result.metadata
```

The fields separate the numerical answer from the information required to
interpret it.

## Select a reduction

Pointwise metrics commonly support:

```julia
evaluate(RMSE(reduction=:global), truth, prediction)
evaluate(RMSE(reduction=:state),  truth, prediction)
evaluate(RMSE(reduction=:time),   truth, prediction)
evaluate(RMSE(reduction=:none),   truth, prediction)
```

- `:global` returns one number.
- `:state` returns one value per state variable.
- `:time` returns one value per sample.
- `:none` returns unreduced elementwise values.

Series-valued evaluations return `MetricSeries`, with numerical output in
`.values` and an associated `.axis`.

## Use physical sample spacing

Pass `dt` to metrics that expose time, lag, or frequency axes:

```julia
error_series = evaluate(
    ErrorOverTime(norm=:rmse),
    truth,
    prediction;
    dt=0.25,
)
```

Then:

```julia
error_series.axis
error_series.values
```

The first time sample corresponds to time zero unless a metric supports and is
given a different `start` value.

## Discard an initial interval

Many metric evaluations accept `discard`:

```julia
result = evaluate(
    RMSE(),
    truth,
    prediction;
    discard=100,
)
```

This removes the first `discard` time samples from both arrays before
evaluation. It is useful for excluding washout, synchronization, or transient
periods. The discarded interval must be chosen and reported explicitly.

## Compare normalized error

```julia
std_nrmse = evaluate(NRMSE(scale=:std), truth, prediction)
range_nrmse = evaluate(NRMSE(scale=:range), truth, prediction)
rms_nrmse = evaluate(NRMSE(scale=:rms), truth, prediction)
```

Normalization is calculated from truth. A zero or non-finite normalization
scale raises an error.

## Estimate a forecast horizon

```julia
horizon = evaluate(
    ForecastHorizon(
        threshold=0.4,
        normalization=:none,
        norm=:rmse,
        interpolate=true,
    ),
    truth,
    prediction;
    dt=0.25,
)
```

Inspect both the returned value and crossing metadata:

```julia
horizon.value
horizon.metadata.crossed
horizon.metadata.crossing_index
```

A horizon metric answers a different question from average RMSE: it identifies
when the selected time-resolved error first exceeds a threshold.

## Evaluate a metric suite

```julia
suite = MetricSuite(
    RMSE(),
    MAE(),
    NRMSE(scale=:range),
    RelativeL2Error(),
)

report = evaluate(suite, truth, prediction)
```

Access results by stable metric name:

```julia
report[:rmse]
report[:mae].value
```

A suite is useful when the same evaluation protocol is applied to many models,
random seeds, parameter settings, or datasets.

## Summarize and save a report

```julia
rows = report_summary(report)
table = report_table(report)

println(table)
```

`report_summary` returns structured rows. `report_table` returns a rendered
text table.

Serialize a report:

```julia
serialize_report("metrics.toml", report)
restored = deserialize_report("metrics.toml")
```

Write the table:

```julia
write_report_table("metrics.txt", report)
```

The file path is the first argument.

## Evaluate an ensemble

Ensemble predictions use `state × time × ensemble`:

```julia
predictions = cat(
    prediction,
    prediction .+ 0.1,
    prediction .- 0.1;
    dims=3,
)
```

Then:

```julia
mean_prediction = evaluate(EnsembleMean(), truth, predictions)
spread = evaluate(EnsembleSpread(reduction=:time), truth, predictions)

mean_error = evaluate(
    EnsembleMeanError(metric=RMSE()),
    truth,
    predictions,
)

member_error = evaluate(
    MemberwiseError(metric=RMSE()),
    truth,
    predictions,
)
```

The ensemble mean, ensemble spread, mean-prediction error, and memberwise error
answer distinct questions and should not be conflated.

## Recommended evaluation workflow

For research use, a practical baseline is:

1. pointwise accuracy with `RMSE`, `MAE`, or `NRMSE`;
2. a threshold-based forecast horizon;
3. temporal or spectral diagnostics;
4. distributional or covariance comparison;
5. dynamical diagnostics appropriate to the system;
6. ensemble diagnostics when predictions are probabilistic;
7. a serialized `MetricReport` with preprocessing and experiment metadata.

No fixed combination is universally correct. The metric set should reflect the
scientific properties that the model is expected to preserve.
