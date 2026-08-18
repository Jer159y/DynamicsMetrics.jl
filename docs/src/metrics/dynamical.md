# Dynamical Diagnostics

Dynamical diagnostics characterize temporal organization beyond pointwise
error and marginal distributions.

## Permutation irreversibility

```julia
PermutationIrreversibility(
    ;
    order=3,
    delay=1,
    reduction=:global,
)
```

Ordinal patterns are formed from delayed vectors:

```math
(x_t,x_{t+\tau},\ldots,x_{t+(m-1)\tau}),
```

where ``m`` is `order` and ``\tau`` is `delay`.

Permutation irreversibility compares the observed probabilities of ordinal
patterns with their time-reversed counterparts. A value near zero indicates
symmetry under this finite ordinal representation; a larger value indicates
temporal asymmetry.

```julia
result = evaluate(
    PermutationIrreversibility(
        order=3,
        delay=1,
        reduction=:global,
    ),
    trajectory,
)
```

Interpretation depends strongly on embedding order, delay, data length, ties,
and noise.

## Recurrence quantification

```julia
RecurrenceQuantification(
    ;
    radius,
    metric=:euclidean,
    theiler=0,
    min_diagonal=2,
)
```

For state vectors ``x_i`` and ``x_j``, a recurrence matrix is defined by:

```math
R_{ij}
=
\mathbf{1}\!\left[d(x_i,x_j)\leq\varepsilon\right],
```

where ``\varepsilon`` is `radius`.

```julia
rqa = evaluate(
    RecurrenceQuantification(
        radius=0.1,
        metric=:euclidean,
        theiler=0,
        min_diagonal=2,
    ),
    trajectory,
)
```

The result is a report containing quantities such as:

```julia
rqa[:recurrence_rate].value
rqa[:determinism].value
rqa[:average_diagonal_length].value
rqa[:longest_diagonal_length].value
```

### Recurrence rate

The proportion of eligible recurrence-matrix entries that are recurrent.

### Determinism

The proportion of recurrent points belonging to diagonal lines whose length is
at least `min_diagonal`.

### Diagonal lengths

Average and longest diagonal-line lengths summarize repeated evolution over
similar state-space paths.

## Grid visitation distance

```julia
GridVisitationDistance(; bins_per_dim=40, dims=1:2, pad_frac=0.05)
```

Unlike permutation irreversibility and recurrence quantification, which
diagnose one trajectory, grid visitation distance compares truth and
prediction directly: how much of the explored state space each one visits,
and how often.

A fixed grid is built once from `truth`'s observed range along `dims` (padded
by `pad_frac`) and reused for both trajectories, so a prediction that leaves
the truth's explored region is penalized rather than silently rebinned onto
its own range. Time samples falling outside every grid cell are counted in
one additional "outside" bucket, so a trajectory that diverges completely off
the attractor still receives a well-defined, maximal distance instead of
being dropped.

```julia
result = evaluate(
    GridVisitationDistance(
        bins_per_dim=40,
        dims=1:2,
        pad_frac=0.05,
    ),
    truth,
    prediction,
)
```

The distance is bounded in `[0, 1]`: `0` means truth and prediction visited
the sampled state-space region with identical relative frequency; `1` means no
overlap at all.

Grid cell count grows as `bins_per_dim^length(dims)`, so this metric is
intended for low-dimensional state spaces (2-3 dimensions); high-dimensional
systems will produce a sparse, uninformative grid.

## Parameter sensitivity

RQA values depend strongly on:

- state scaling;
- distance metric;
- recurrence radius;
- Theiler window;
- minimum line length;
- sampling interval;
- trajectory duration.

Comparisons require the same preprocessing and parameters.

## Computational cost

A direct recurrence matrix requires quadratic memory and time in the number of
samples. Use care for very long trajectories and document any subsampling.
