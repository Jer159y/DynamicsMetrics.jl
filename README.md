# DynamicsMetrics.jl

A model-independent Julia package for evaluating predictions, simulations, and ensembles of dynamical systems.

<!--
Replace YOUR_GITHUB_USERNAME below after the repository URL is finalized.

[![Build Status](https://github.com/YOUR_GITHUB_USERNAME/DynamicsMetrics.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/YOUR_GITHUB_USERNAME/DynamicsMetrics.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://YOUR_GITHUB_USERNAME.github.io/DynamicsMetrics.jl/dev/)
[![Coverage](https://codecov.io/gh/YOUR_GITHUB_USERNAME/DynamicsMetrics.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/YOUR_GITHUB_USERNAME/DynamicsMetrics.jl)
-->

## Overview

`DynamicsMetrics.jl` provides a consistent interface for evaluating time-series
predictions produced by dynamical-system models.

The package is deliberately independent of any forecasting or simulation
framework. It can be used with outputs from:

- reservoir computers and echo state networks;
- recurrent neural networks and Transformers;
- neural ordinary differential equations and physics-informed neural networks;
- Koopman and operator-learning methods;
- Kalman filters and state-space models;
- ordinary and partial differential equation solvers;
- reduced-order models;
- probabilistic and ensemble forecasting systems.

The central API is:

```julia
metric = RMSE()
result = evaluate(metric, truth, prediction)
```

Metrics are represented by explicit objects, and evaluation returns structured
result types rather than unlabelled numbers. This makes metric configuration,
metadata, reporting, testing, and downstream analysis reproducible.

## Why DynamicsMetrics.jl?

Pointwise errors such as RMSE are useful, but they are rarely sufficient for
dynamical systems.

A prediction can have a short pointwise forecast horizon while still
reproducing the correct long-term distribution, spectral structure, recurrence
properties, or ensemble uncertainty. Conversely, a small average error does
not guarantee that a model captures temporal organization or attractor
geometry.

`DynamicsMetrics.jl` therefore provides multiple complementary classes of
evaluation:

- pointwise trajectory errors;
- forecast-horizon metrics;
- temporal and spectral diagnostics;
- statistical and distributional comparisons;
- dynamical diagnostics;
- ensemble summaries and calibration metrics;
- structured reports and serialization.

## Features

- A uniform `evaluate(metric, ...)` interface.
- Model-independent array-based input.
- Strict and documented data conventions.
- Global, statewise, timewise, and elementwise reductions where applicable.
- Structured scalar, series, and report results.
- Metric suites for reproducible multi-metric evaluation.
- Support for deterministic and ensemble forecasts.
- Temporal, spectral, statistical, and dynamical diagnostics.
- Human-readable tables and TOML serialization.
- Lightweight examples with no external data dependencies.
- A test suite covering the public API.

## Installation

### Current development version

Until the package is registered in Julia's General Registry, install it directly
from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/YOUR_GITHUB_USERNAME/DynamicsMetrics.jl")
```

For local development:

```julia
using Pkg
Pkg.develop(path="/path/to/DynamicsMetrics")
```

Then load the package:

```julia
using DynamicsMetrics
```

### After General Registry registration

Once registered, installation will be:

```julia
using Pkg
Pkg.add("DynamicsMetrics")
```

## Quick start

```julia
using DynamicsMetrics

truth = [
    1.0  2.0  3.0
    2.0  4.0  6.0
]

prediction = [
    1.0  2.5  2.5
    2.0  3.0  7.0
]

rmse = evaluate(RMSE(), truth, prediction)
mae = evaluate(MAE(), truth, prediction)
relative_l2 = evaluate(RelativeL2Error(), truth, prediction)

println(rmse.value)
println(mae.value)
println(relative_l2.value)
```

Each metric returns a structured result object. Scalar metrics expose `.value`;
series-valued metrics expose `.values` and, when applicable, `.axis`.

## Data conventions

DynamicsMetrics uses explicit array layouts.

### Deterministic trajectories

A trajectory must have shape:

```text
state × time
```

For a system with `n_state` variables observed at `n_time` samples:

```julia
size(trajectory) == (n_state, n_time)
```

Example:

```julia
trajectory = [
    x₁(t₁)  x₁(t₂)  x₁(t₃)
    x₂(t₁)  x₂(t₂)  x₂(t₃)
]
```

Rows represent state variables. Columns represent time samples.

### Ensemble predictions

An ensemble must have shape:

```text
state × time × ensemble
```

For `n_member` ensemble members:

```julia
size(predictions) == (n_state, n_time, n_member)
```

The deterministic truth remains:

```text
state × time
```

Example:

```julia
predictions[:, :, member]
```

selects one ensemble member.

### Sample spacing

Metrics that return a physical time, lag, or frequency axis accept `dt` as a
keyword argument:

```julia
result = evaluate(metric, truth, prediction; dt=0.1)
```

or, for a single-trajectory diagnostic:

```julia
result = evaluate(metric, trajectory; dt=0.1)
```

Unless otherwise documented, `dt=1` corresponds to sample-index units.

## Input policy

DynamicsMetrics follows a strict, non-magical input policy.

The package does **not** perform:

- automatic transposition;
- automatic normalization;
- automatic standardization;
- implicit state selection;
- silent removal of NaN or Inf values;
- implicit complex-to-real conversion;
- silent alignment of trajectories with different shapes;
- automatic interpolation between different time grids.

Inputs must already follow the documented layout and represent the comparison
the user intends to make.

This policy prevents convenient but scientifically ambiguous transformations
from being applied silently.

### Consequences

If data are stored as `time × state`, transpose them explicitly:

```julia
trajectory = permutedims(time_by_state_data)
```

If normalization is required, perform it explicitly or select a metric option
that defines the normalization:

```julia
result = evaluate(NRMSE(scale=:range), truth, prediction)
```

If complex-valued data should be compared through magnitude or phase, choose
the transformation explicitly:

```julia
magnitude_truth = abs.(truth)
magnitude_prediction = abs.(prediction)

phase_truth = angle.(truth)
phase_prediction = angle.(prediction)
```

Metrics that require real-valued input reject unsupported complex arrays rather
than silently discarding information.

## Design principles

### Model independence

Metrics receive arrays, not trained model objects. DynamicsMetrics does not
depend on a particular machine-learning, reservoir-computing, filtering, or
differential-equation package.

### Explicit configuration

Metric choices are represented in constructors:

```julia
RMSE(reduction=:state)

ForecastHorizon(
    threshold=0.4,
    normalization=:none,
    interpolate=true,
)

PowerSpectralDensity(
    detrend=:mean,
    one_sided=true,
    reduction=:state,
)
```

The metric object records the intended computation and can be stored,
inspected, tested, and reused.

### Structured results

Evaluation returns one of the package result types rather than an anonymous
array whenever additional context is useful.

Typical access patterns are:

```julia
result.value
result.values
result.axis
result.metadata
result.parameters
```

Not every field applies to every metric.

### Complementary evaluation

No single metric is assumed to characterize all aspects of dynamical
prediction quality. Users are encouraged to evaluate short-term accuracy,
long-term statistics, temporal structure, dynamical organization, and ensemble
uncertainty separately.

### Strict validation

Shape mismatches, unsupported options, NaN values, Inf values, and invalid
reductions are treated as errors. Silent coercion is avoided.

## Reduction modes

Metrics that support reductions use the following symbols:

| Reduction | Meaning |
|---|---|
| `:global` | Aggregate over all states and time samples |
| `:state` | Return one value per state variable |
| `:time` | Return one value per time sample |
| `:none` | Return unreduced elementwise values |

Example:

```julia
global_rmse = evaluate(RMSE(), truth, prediction)
state_rmse = evaluate(RMSE(reduction=:state), truth, prediction)
time_rmse = evaluate(RMSE(reduction=:time), truth, prediction)
raw_error = evaluate(RMSE(reduction=:none), truth, prediction)
```

The exact output shape depends on the metric and selected reduction.

## Available metrics

### Pointwise metrics

| Metric | Purpose |
|---|---|
| `RMSE` | Root mean squared trajectory error |
| `MAE` | Mean absolute trajectory error |
| `NRMSE` | Normalized root mean squared error |
| `RelativeL2Error` | Relative Euclidean trajectory error |
| `ErrorOverTime` | Time-resolved norm of the prediction error |

Example:

```julia
rmse = evaluate(RMSE(), truth, prediction)

statewise = evaluate(
    RMSE(reduction=:state),
    truth,
    prediction,
)

normalized = evaluate(
    NRMSE(scale=:range),
    truth,
    prediction,
)

error_series = evaluate(
    ErrorOverTime(norm=:rmse),
    truth,
    prediction;
    dt=0.25,
)
```

`ErrorOverTime` returns a series with the physical time axis determined by
`dt`.

### Forecast-horizon metrics

| Metric | Purpose |
|---|---|
| `ValidPredictionTime` | First time at which normalized prediction error crosses a threshold |
| `ForecastHorizon` | Threshold-based usable forecast horizon |

Example:

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
    dt=0.5,
)
```

When interpolation is enabled, the crossing time is estimated between adjacent
samples. Metadata records whether a crossing occurred and the corresponding
sample information.

### Temporal diagnostics

These metrics diagnose a single trajectory rather than compare truth and
prediction point by point.

| Metric | Purpose |
|---|---|
| `Autocorrelation` | Lag-dependent temporal dependence |
| `PowerSpectralDensity` | Distribution of signal power over frequency |
| `SpectralEntropy` | Spectral concentration or dispersion |

Example:

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

psd = evaluate(
    PowerSpectralDensity(
        detrend=:mean,
        one_sided=true,
        reduction=:state,
    ),
    trajectory;
    dt=0.1,
)

entropy = evaluate(
    SpectralEntropy(
        detrend=:mean,
        normalize=true,
        reduction=:state,
    ),
    trajectory,
)
```

### Statistical and distributional metrics

| Metric | Purpose |
|---|---|
| `CovarianceError` | Difference between truth and prediction covariance structure |
| `WassersteinDistance` | Distance between empirical state distributions |
| `JensenShannonDivergence` | Symmetric histogram-based distribution divergence |

Example:

```julia
covariance_error = evaluate(
    CovarianceError(
        norm=:frobenius,
        relative=false,
    ),
    truth,
    prediction,
)

wasserstein = evaluate(
    WassersteinDistance(reduction=:state),
    truth,
    prediction,
)

js = evaluate(
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

These metrics are useful when long-term or climate-level agreement matters even
after pointwise trajectories have diverged.

### Dynamical diagnostics

| Metric | Purpose |
|---|---|
| `PermutationIrreversibility` | Temporal asymmetry based on ordinal patterns |
| `RecurrenceQuantification` | Recurrence rate, determinism, and diagonal-line statistics |

Example:

```julia
irreversibility = evaluate(
    PermutationIrreversibility(
        order=3,
        delay=1,
        reduction=:global,
    ),
    trajectory,
)

rqa = evaluate(
    RecurrenceQuantification(
        radius=0.1,
        metric=:euclidean,
        theiler=0,
        min_diagonal=2,
    ),
    trajectory,
)

println(rqa[:recurrence_rate].value)
println(rqa[:determinism].value)
println(rqa[:average_diagonal_length].value)
println(rqa[:longest_diagonal_length].value)
```

These diagnostics characterize the temporal organization of one trajectory.
They should not be interpreted as substitutes for pointwise prediction error.

### Ensemble metrics

Ensemble metrics use the canonical layout:

```text
state × time × ensemble
```

| Metric | Purpose |
|---|---|
| `EnsembleMean` | Mean prediction across ensemble members |
| `EnsembleSpread` | Dispersion across ensemble members |
| `EnsembleMeanError` | Error of the ensemble-mean prediction |
| `MemberwiseError` | Error of each ensemble member |
| `PredictionIntervalCoverage` | Fraction of truth values covered by an ensemble interval |

Example:

```julia
ensemble_mean = evaluate(
    EnsembleMean(),
    truth,
    predictions,
)

spread = evaluate(
    EnsembleSpread(
        corrected=false,
        reduction=:time,
    ),
    truth,
    predictions,
)

mean_error = evaluate(
    EnsembleMeanError(metric=RMSE()),
    truth,
    predictions,
)

member_errors = evaluate(
    MemberwiseError(metric=RMSE()),
    truth,
    predictions,
)

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

Ensemble summaries preserve information that is lost when only the ensemble
mean is evaluated.

## Metric suites

Use `MetricSuite` to evaluate a predefined collection of metrics consistently.

```julia
using DynamicsMetrics

suite = MetricSuite(
    RMSE(),
    MAE(),
    NRMSE(scale=:range),
    RelativeL2Error(),
)

report = evaluate(suite, truth, prediction)
```

The returned `MetricReport` is indexed by metric name:

```julia
report[:rmse]
report[:mae]

println(report[:rmse].value)
```

A vector of metrics can also be evaluated when supported by the public API.

Metric names within one suite must be unique. If multiple differently
configured instances of the same metric are needed, evaluate them separately
or use a future labelled-suite interface.

## Reporting

A `MetricReport` can be converted to structured rows or a human-readable table.

```julia
summary = report_summary(report)
table = report_table(report)

println(table)
```

Reports can be serialized to TOML:

```julia
serialize_report("metrics.toml", report)
restored = deserialize_report("metrics.toml")
```

A rendered table can be written to disk:

```julia
write_report_table("metrics.txt", report)
```

The file path is the first argument for serialization and table-writing
functions.

## Examples

The `examples/` directory contains small deterministic programs covering the
public API.

| File | Topic |
|---|---|
| `basic_pointwise.jl` | Pointwise metrics and reductions |
| `metric_suite.jl` | Multi-metric evaluation |
| `forecast_horizon.jl` | Threshold-based forecast horizons |
| `temporal_diagnostics.jl` | Autocorrelation, PSD, and spectral entropy |
| `statistical_metrics.jl` | Covariance and distributional comparisons |
| `dynamical_diagnostics.jl` | Irreversibility and recurrence analysis |
| `ensemble_evaluation.jl` | Ensemble summaries, errors, and coverage |
| `reporting.jl` | Tables and TOML serialization |
| `run_all.jl` | Execute all examples in isolated Julia processes |

Run one example from the package root:

```bash
julia --project=. examples/basic_pointwise.jl
```

Run all examples:

```bash
julia --project=. examples/run_all.jl
```

The examples:

- use only Julia standard libraries and DynamicsMetrics;
- require no external datasets;
- use deterministic data;
- finish quickly;
- follow the canonical array layouts;
- are suitable for continuous integration.

## Testing

Run the complete test suite from the package root:

```julia
using Pkg
Pkg.test()
```

Run the examples after the tests:

```bash
julia --project=. examples/run_all.jl
```

A pull request should not be merged unless both commands succeed.

## Documentation

The full documentation will include:

- getting started;
- data conventions;
- mathematical definitions;
- metric-specific configuration;
- result types;
- ensemble evaluation;
- report generation;
- API reference;
- extension guidelines.

After documentation deployment is configured, links will be available for:

- development documentation;
- stable release documentation.

## Scope

DynamicsMetrics focuses on evaluation, not model training or simulation.

The package does not aim to:

- train forecasting models;
- integrate differential equations;
- generate benchmark datasets;
- choose a universally correct metric;
- automatically preprocess user data;
- infer state semantics;
- replace domain-specific scientific validation.

Instead, it provides reusable evaluation components that can be combined with
domain knowledge and model-specific workflows.

## Extending the package

New metrics should:

1. subtype `AbstractMetric`;
2. define an `evaluate` method;
3. return an appropriate structured result;
4. validate input layout and parameters;
5. document mathematical meaning and assumptions;
6. include unit tests;
7. include or update a public example when appropriate.

Conceptually:

```julia
struct MyMetric <: AbstractMetric
    # configuration
end

function DynamicsMetrics.evaluate(
    metric::MyMetric,
    truth::AbstractMatrix,
    prediction::AbstractMatrix;
    kwargs...,
)
    # validate inputs
    # compute the metric
    # return a structured result
end
```

Internal helpers are not part of the stability promise unless explicitly
exported and documented.

## Reproducibility recommendations

For scientific use:

- record the package version;
- record every metric constructor and parameter;
- record the sample spacing `dt`;
- record preprocessing performed before evaluation;
- preserve the state ordering;
- preserve the selected forecast interval;
- save structured reports alongside figures and tables;
- use fixed random seeds for stochastic ensemble generation;
- evaluate multiple complementary metrics.

A metric value is meaningful only together with its definition, configuration,
data interval, and preprocessing choices.

## Contributing

Contributions are welcome.

Before opening a pull request:

```julia
using Pkg
Pkg.test()
```

and:

```bash
julia --project=. examples/run_all.jl
```

Contributions should include:

- tests for new behavior;
- docstrings for public API;
- updated examples when user-facing behavior changes;
- no silent changes to data conventions;
- explicit compatibility updates for new dependencies.

For substantial API changes, open an issue before implementation so that data
layout, result types, naming, and backward compatibility can be discussed.

## Citation

A formal software citation will be added before the first archived release.

For now, cite the repository and the exact version or commit used in the
analysis. After a DOI or `CITATION.cff` file is available, use the citation
provided there.

Suggested temporary form:

```text
DynamicsMetrics.jl contributors. DynamicsMetrics.jl: model-independent
evaluation metrics for dynamical-system predictions. Version <VERSION>,
<YEAR>. <REPOSITORY URL>.
```

## License

See [`LICENSE`](LICENSE) for the terms under which DynamicsMetrics.jl is
distributed.

## Status

DynamicsMetrics.jl is under active development.

The public API is being prepared for an initial registered release. Before
version `1.0`, some constructor options, result fields, and metric definitions
may evolve. Version constraints and release notes should be checked when
reproducing long-lived research workflows.
