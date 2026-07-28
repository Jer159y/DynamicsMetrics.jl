# DynamicsMetrics.jl

`DynamicsMetrics.jl` is a model-independent Julia package for evaluating
predictions, reconstructions, state estimates, simulations, and ensembles of
dynamical systems.

The package uses one central interface:

```julia
metric = RMSE()
result = evaluate(metric, truth, prediction)
```

Metrics are explicit configuration objects. Evaluations return structured
results containing the metric name, computed value or series, parameters, and
metadata required to interpret the result.

## What the package evaluates

DynamicsMetrics provides complementary evaluation tools for:

- pointwise trajectory accuracy;
- valid prediction time and forecast horizons;
- temporal dependence and spectral organization;
- empirical distributions and covariance structure;
- temporal irreversibility and recurrence structure;
- ensemble mean, spread, member quality, and interval coverage;
- reproducible metric suites and serialized reports.

A single scalar error is not assumed to summarize every scientifically
important property of a dynamical prediction.

## Installation

Until registration in Julia's General Registry, install from the repository:

```julia
using Pkg
Pkg.add(url="https://github.com/Jer159y/DynamicsMetrics.jl")
```

For local development:

```julia
using Pkg
Pkg.develop(path="/path/to/DynamicsMetrics")
```

After registry registration:

```julia
using Pkg
Pkg.add("DynamicsMetrics")
```

## Minimal example

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

result = evaluate(RMSE(), truth, prediction)
println(result.value)
```

The canonical deterministic layout is `state × time`. The canonical ensemble
layout is `state × time × ensemble`.

## Where to go next

- [Getting Started](@ref) develops a complete evaluation workflow.
- [Data Contract](@ref) specifies layouts, validation, time axes, and explicit preprocessing.
- Metric chapters give mathematical definitions and constructor options.
- [Package Design](@ref) explains the reasoning behind metric objects and structured results.
- [Extending DynamicsMetrics](@ref) describes how to add a new metric.
- [API Reference](@ref) lists the documented public interface.
