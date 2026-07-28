# Data Contract

DynamicsMetrics uses strict data conventions. The package validates inputs but
does not guess how an array should be interpreted.

## Deterministic layout

A deterministic time series has shape:

```text
state × time
```

If there are ``d`` state variables and ``T`` samples, then:

```julia
size(trajectory) == (d, T)
```

The entry `trajectory[i, j]` is state ``i`` at time sample ``j``.

A one-dimensional system should normally be represented as a one-row matrix:

```julia
trajectory = reshape(values, 1, :)
```

## Ensemble layout

An ensemble prediction has shape:

```text
state × time × ensemble
```

For ``M`` members:

```julia
size(predictions) == (d, T, M)
```

The slice:

```julia
predictions[:, :, member]
```

is one deterministic trajectory.

Truth remains `state × time`.

## Alignment requirements

Truth and prediction must already be aligned in:

- state ordering;
- time ordering;
- sample spacing;
- forecast start;
- forecast length;
- physical units;
- preprocessing convention.

Equal array sizes are necessary but do not prove scientific alignment.

## No automatic transpose

DynamicsMetrics does not infer whether an input is `time × state`.

Convert explicitly:

```julia
state_by_time = permutedims(time_by_state)
```

Automatic transpose would be ambiguous when dimensions have similar sizes or
when a one-state trajectory is represented as a vector.

## No automatic normalization

The package does not standardize or rescale input arrays automatically.

When normalization is part of a metric definition, it is selected explicitly:

```julia
NRMSE(scale=:std)
NRMSE(scale=:range)
NRMSE(scale=:rms)
```

If model training used normalized coordinates but scientific evaluation should
be performed in physical units, invert the training transformation before
calling `evaluate`.

## No implicit interpolation

Truth and prediction on different time grids must be aligned outside the
package. The interpolation method, extrapolation policy, and selected interval
can materially affect a metric and must therefore be explicit.

## No silent non-finite removal

NaN and Inf values are not silently deleted. Removing samples independently
from truth and prediction can destroy temporal alignment and bias results.

The default non-finite policy is an error. When an evaluation method supports a
different documented `nonfinite` option, select it explicitly and record it.

## Complex-valued data

Metrics based on absolute differences can naturally support complex values.
Metrics that require ordering, real histograms, standard deviations, or a
specific real-valued interpretation may reject complex arrays.

Do not silently discard the imaginary component.

Choose the scientific representation explicitly:

```julia
magnitude = abs.(complex_trajectory)
phase = angle.(complex_trajectory)
real_component = real.(complex_trajectory)
imag_component = imag.(complex_trajectory)
```

For phase data, consider unwrapping and circular-statistics requirements before
using ordinary Euclidean metrics.

## Time spacing

Use `dt` when sample-index units are insufficient:

```julia
result = evaluate(metric, truth, prediction; dt=0.1)
```

Depending on the metric, `dt` determines:

- the time axis of `ErrorOverTime`;
- valid-prediction-time units;
- lag units for autocorrelation;
- the frequency axis for power spectral density.

The package assumes uniform sample spacing.

## First sample and time origin

Time-indexed outputs normally use:

```math
t_j = t_0 + (j-1)\Delta t.
```

With the default start, the first retained sample is at time zero. Discarding
samples changes the evaluated data interval; it does not automatically add the
discarded duration to a returned axis unless the metric explicitly documents
that behavior.

## Discarding initial samples

The keyword:

```julia
discard=k
```

removes the first `k` samples before evaluation.

Use it for a scientifically defined transient, washout, synchronization, or
spin-up period. Do not tune `discard` solely to improve reported performance
without disclosing the choice.

## Reduction geometry

For an error array ``E \in \mathbb{R}^{d\times T}``:

- `:global` reduces over state and time;
- `:state` reduces over time and retains ``d`` outputs;
- `:time` reduces over state and retains ``T`` outputs;
- `:none` retains the full geometry.

Reduction changes the scientific question. For example, global RMSE can hide a
poorly predicted low-amplitude state, while statewise RMSE exposes it.

## Units and comparability

An unnormalized global metric can be dominated by state variables with large
physical scales. Before combining heterogeneous states, decide whether the
desired quantity is:

- error in physical units;
- dimensionless normalized error;
- a statewise collection;
- a weighted aggregate.

DynamicsMetrics does not infer scientifically appropriate weights.

## Validation examples

Correct deterministic input:

```julia
truth = randn(3, 100)
prediction = randn(3, 100)
evaluate(RMSE(), truth, prediction)
```

Incorrectly transposed prediction:

```julia
prediction = randn(100, 3)
evaluate(RMSE(), truth, prediction) # shape error
```

Correct ensemble input:

```julia
truth = randn(3, 100)
predictions = randn(3, 100, 20)
evaluate(EnsembleMean(), truth, predictions)
```

Incorrect ensemble ordering:

```julia
predictions = randn(20, 3, 100) # ensemble × state × time
```

Reorder explicitly before evaluation.

## Reproducibility checklist

Record:

- input array shapes;
- state names and ordering;
- units;
- `dt`;
- forecast start and end;
- `discard`;
- preprocessing transformations;
- metric constructors and parameters;
- package version;
- code commit;
- random seed for stochastic forecasts.

A metric value without this context may not be reproducible or comparable.
