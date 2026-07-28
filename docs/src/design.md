# Package Design

## Why metric objects?

The interface:

```julia
evaluate(RMSE(reduction=:state), truth, prediction)
```

makes configuration explicit and inspectable. A metric object can be stored in
an experiment configuration, included in a suite, reproduced later, and
attached to result metadata.

A keyword-only function call can compute the same number, but it provides a
weaker abstraction for composing heterogeneous metrics.

## Why one `evaluate` function?

A common function creates a uniform user workflow while Julia's multiple
dispatch preserves metric-specific implementation.

It supports deterministic comparison:

```julia
evaluate(metric, truth, prediction)
```

single-trajectory diagnostics:

```julia
evaluate(metric, trajectory)
```

and ensemble evaluation:

```julia
evaluate(metric, truth, predictions)
```

without requiring unrelated models to share an inheritance hierarchy.

## Why arrays instead of model objects?

DynamicsMetrics evaluates outputs, not training procedures. Array input keeps
the package independent of ReservoirComputing.jl, Flux.jl, DifferentialEquations.jl,
and other modeling ecosystems.

Model-specific adapters can prepare arrays outside the core package.

## Why structured results?

A bare number does not identify:

- which metric produced it;
- which reduction was used;
- whether it is scalar or series-valued;
- what axis accompanies it;
- which parameters and validation metadata apply.

`MetricResult`, `MetricSeries`, and `MetricReport` preserve this context.

## Why strict layouts?

Automatic transpose and shape guessing are convenient until they silently
reinterpret valid-looking data. Scientific software should prefer explicit
failure over ambiguous success.

The fixed layouts are:

```text
state × time
state × time × ensemble
```

## Why explicit reduction?

Global, statewise, and timewise errors answer different questions. Reduction is
therefore a constructor parameter rather than an undocumented implementation
detail.

## Why no automatic preprocessing?

Normalization, interpolation, filtering, phase unwrapping, and transient
removal can materially change conclusions. They must be intentional,
reproducible parts of the analysis.

## Stability boundary

Exported and documented names form the intended public API. Internal helper
functions may change without notice before version 1.0.

Metric definitions and default parameters should be treated as part of the
scientific API: changing them requires tests, documentation, and release notes.
