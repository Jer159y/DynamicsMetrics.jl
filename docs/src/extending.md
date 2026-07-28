# Extending DynamicsMetrics

This chapter outlines the expected structure of a new metric.

## Define a metric type

```julia
struct Bias <: AbstractMetric
    reduction::Symbol

    function Bias(; reduction::Symbol=:global)
        reduction in (:global, :state, :time, :none) ||
            throw(ArgumentError("unsupported reduction"))
        new(reduction)
    end
end
```

Metric objects should be immutable unless caching or stateful behavior is
essential.

## Define a stable name

```julia
DynamicsMetrics.metricname(::Bias) = :bias
```

The fallback derives a snake-case name, but an explicit stable name is preferred
for public metrics.

## Declare supported reductions

```julia
DynamicsMetrics.supports_reduction(
    ::Bias,
    reduction::Symbol,
) = reduction in (:global, :state, :time, :none)
```

## Implement `evaluate`

Conceptually:

```julia
function DynamicsMetrics.evaluate(
    metric::Bias,
    truth::AbstractMatrix,
    prediction::AbstractMatrix;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    # Validate through package helpers when implementing inside the package.
    # Compute according to metric.reduction.
    # Return MetricResult or MetricSeries.
end
```

External extensions should rely only on exported public helpers. If validation
or result construction requires internal functions, propose a public extension
interface before depending on internals.

## Choose a result type

Use `MetricResult` for one scalar-like value:

```julia
MetricResult(
    :bias,
    computed_value,
    (reduction=metric.reduction,),
    metadata,
)
```

Use `MetricSeries` for an array with an interpretable axis:

```julia
MetricSeries(
    :bias,
    values,
    axis,
    (reduction=metric.reduction,),
    metadata,
)
```

Use `MetricReport` when one evaluation naturally returns several named metric
results, as in recurrence quantification.

## Document the mathematics

A public metric docstring should specify:

- constructor signature and defaults;
- mathematical definition;
- input layout;
- supported reductions;
- keywords;
- output type and shape;
- zero-denominator behavior;
- non-finite behavior;
- complex-data support;
- computational complexity;
- references where appropriate.

## Add tests

Tests should cover:

- a hand-checkable value;
- every supported reduction;
- result type and shape;
- metric parameters;
- metadata;
- invalid constructor values;
- shape mismatch;
- non-finite input;
- zero normalization or denominator;
- complex input when relevant.

Run:

```julia
using Pkg
Pkg.test()
```

## Add an example

Public user-facing behavior should appear in a lightweight example or in an
existing example file.

Run all examples:

```bash
julia --project=. examples/run_all.jl
```

## Add documentation

Add the metric to:

- the relevant metric chapter;
- the API reference;
- README metric overview if it changes package scope;
- release notes.

## Backward compatibility

Before version 1.0, APIs may evolve, but changes should still be deliberate.
After registration, avoid changing:

- metric names;
- constructor defaults;
- result field meanings;
- reduction semantics;
- serialized schema;

without deprecation or a clearly documented version boundary.
