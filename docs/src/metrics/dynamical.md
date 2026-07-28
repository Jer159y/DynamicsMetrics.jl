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
