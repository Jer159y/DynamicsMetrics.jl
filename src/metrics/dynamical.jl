"""
    PermutationIrreversibility(; order=3, delay=1, reduction=:state,
                               base=2, pseudocount=0.0)

Time-reversal irreversibility based on ordinal-pattern distributions.

For each time series, the forward ordinal-pattern distribution is compared with
the ordinal-pattern distribution of the reversed trajectory using the
Jensen–Shannon divergence.

Supported reductions:

- `:state`: compute one irreversibility value per state variable.
- `:global`: flatten all states and compute one value.

The embedding order must be at least 2, and the delay must be positive.
"""
struct PermutationIrreversibility <: AbstractMetric
    order::Int
    delay::Int
    reduction::Symbol
    base::Float64
    pseudocount::Float64

    function PermutationIrreversibility(
        ;
        order::Integer=3,
        delay::Integer=1,
        reduction::Symbol=:state,
        base::Real=2,
        pseudocount::Real=0.0,
    )
        order >= 2 || throw(ArgumentError(
            "`order` must be at least 2; received $order."
        ))
        delay >= 1 || throw(ArgumentError(
            "`delay` must be positive; received $delay."
        ))
        reduction in (:state, :global) || throw(ArgumentError(
            "PermutationIrreversibility supports only `reduction=:state` or " *
            "`reduction=:global`; received `$reduction`."
        ))
        isfinite(base) || throw(ArgumentError(
            "`base` must be finite; received $base."
        ))
        base > 0 && base != 1 || throw(ArgumentError(
            "`base` must be positive and different from one; received $base."
        ))
        isfinite(pseudocount) || throw(ArgumentError(
            "`pseudocount` must be finite; received $pseudocount."
        ))
        pseudocount >= 0 || throw(ArgumentError(
            "`pseudocount` must be nonnegative; received $pseudocount."
        ))

        return new(
            Int(order),
            Int(delay),
            reduction,
            Float64(base),
            Float64(pseudocount),
        )
    end
end

metricname(::PermutationIrreversibility) = :permutation_irreversibility
supports_reduction(::PermutationIrreversibility, reduction::Symbol) =
    reduction in (:state, :global)

function evaluate(
    metric::PermutationIrreversibility,
    data;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = _validate_single_timeseries(
        data;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    require_real(checked.data, :data)

    required_length = (metric.order - 1) * metric.delay + 1
    checked.metadata.time_length >= required_length || throw(ArgumentError(
        "Permutation irreversibility with order=$(metric.order) and " *
        "delay=$(metric.delay) requires at least $required_length samples; " *
        "received $(checked.metadata.time_length)."
    ))

    result = if metric.reduction === :global
        _permutation_irreversibility(
            vec(checked.data),
            metric.order,
            metric.delay;
            base=metric.base,
            pseudocount=metric.pseudocount,
        )
    elseif checked.data isa AbstractVector
        _permutation_irreversibility(
            checked.data,
            metric.order,
            metric.delay;
            base=metric.base,
            pseudocount=metric.pseudocount,
        )
    else
        values = Vector{Float64}(undef, size(checked.data, 1))
        for state in axes(checked.data, 1)
            values[state] = _permutation_irreversibility(
                @view(checked.data[state, :]),
                metric.order,
                metric.delay;
                base=metric.base,
                pseudocount=metric.pseudocount,
            )
        end
        values
    end

    result_metadata = merge(
        checked.metadata,
        (
            order=metric.order,
            delay=metric.delay,
            entropy_base=metric.base,
            pseudocount=metric.pseudocount,
            method=:ordinal_pattern_js_divergence,
        ),
    )

    if result isa Number
        return MetricResult(
            metricname(metric),
            result,
            metricparameters(metric),
            result_metadata,
        )
    end

    return MetricSeries(
        metricname(metric),
        result,
        collect(1:length(result)),
        metricparameters(metric),
        result_metadata,
    )
end

"""
    RecurrenceQuantification(; radius, metric=:euclidean,
                             theiler=0, min_diagonal=2)

Basic recurrence quantification analysis (RQA).

The recurrence matrix is constructed from pairwise distances between state
vectors in time:

```text
R[i,j] = distance(xᵢ, xⱼ) ≤ radius
```

Supported distance metrics:

- `:euclidean`
- `:maximum`
- `:manhattan`

The metric returns a `MetricReport` containing:

- `:recurrence_rate`
- `:determinism`
- `:average_diagonal_length`
- `:longest_diagonal_length`

The Theiler window excludes near-diagonal temporal neighbors satisfying
`abs(i-j) <= theiler`.
"""
struct RecurrenceQuantification <: AbstractMetric
    radius::Float64
    metric::Symbol
    theiler::Int
    min_diagonal::Int

    function RecurrenceQuantification(
        ;
        radius::Real,
        metric::Symbol=:euclidean,
        theiler::Integer=0,
        min_diagonal::Integer=2,
    )
        isfinite(radius) || throw(ArgumentError(
            "`radius` must be finite; received $radius."
        ))
        radius >= 0 || throw(ArgumentError(
            "`radius` must be nonnegative; received $radius."
        ))
        metric in (:euclidean, :maximum, :manhattan) || throw(ArgumentError(
            "Unsupported recurrence distance `$metric`. Supported values are " *
            "`:euclidean`, `:maximum`, and `:manhattan`."
        ))
        theiler >= 0 || throw(ArgumentError(
            "`theiler` must be nonnegative; received $theiler."
        ))
        min_diagonal >= 1 || throw(ArgumentError(
            "`min_diagonal` must be positive; received $min_diagonal."
        ))

        return new(
            Float64(radius),
            metric,
            Int(theiler),
            Int(min_diagonal),
        )
    end
end

metricname(::RecurrenceQuantification) = :recurrence_quantification

function evaluate(
    metric::RecurrenceQuantification,
    data;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    checked = _validate_single_timeseries(
        data;
        discard=discard,
        dt=dt,
        nonfinite=nonfinite,
    )

    require_real(checked.data, :data)

    trajectory = checked.data isa AbstractVector ?
        reshape(checked.data, 1, :) :
        checked.data

    ntime = size(trajectory, 2)
    ntime >= 2 || throw(ArgumentError(
        "Recurrence quantification requires at least two time samples."
    ))

    metric.theiler < ntime || throw(ArgumentError(
        "`theiler=$(metric.theiler)` must be smaller than the effective time " *
        "length $ntime."
    ))

    recurrence = _recurrence_matrix(
        trajectory,
        metric.radius,
        metric.metric,
        metric.theiler,
    )

    admissible_pairs = _admissible_pair_count(ntime, metric.theiler)
    recurrent_points = count(recurrence)

    recurrence_rate = admissible_pairs == 0 ?
        0.0 :
        recurrent_points / admissible_pairs

    diagonal_lengths = _diagonal_line_lengths(
        recurrence;
        min_length=metric.min_diagonal,
    )

    diagonal_points = sum(diagonal_lengths)
    determinism = recurrent_points == 0 ?
        0.0 :
        diagonal_points / recurrent_points

    average_diagonal_length = isempty(diagonal_lengths) ?
        0.0 :
        mean(diagonal_lengths)

    longest_diagonal_length = isempty(diagonal_lengths) ?
        0 :
        maximum(diagonal_lengths)

    common_metadata = merge(
        checked.metadata,
        (
            radius=metric.radius,
            distance_metric=metric.metric,
            theiler=metric.theiler,
            min_diagonal=metric.min_diagonal,
            recurrent_points=recurrent_points,
            admissible_pairs=admissible_pairs,
            diagonal_line_count=length(diagonal_lengths),
        ),
    )

    results = Dict{Symbol,AbstractMetricResult}(
        :recurrence_rate => MetricResult(
            :recurrence_rate,
            recurrence_rate,
            metricparameters(metric),
            common_metadata,
        ),
        :determinism => MetricResult(
            :determinism,
            determinism,
            metricparameters(metric),
            common_metadata,
        ),
        :average_diagonal_length => MetricResult(
            :average_diagonal_length,
            average_diagonal_length,
            metricparameters(metric),
            common_metadata,
        ),
        :longest_diagonal_length => MetricResult(
            :longest_diagonal_length,
            longest_diagonal_length,
            metricparameters(metric),
            common_metadata,
        ),
    )

    report_metadata = merge(
        common_metadata,
        (
            metric_name=metricname(metric),
            result_names=(
                :recurrence_rate,
                :determinism,
                :average_diagonal_length,
                :longest_diagonal_length,
            ),
        ),
    )

    return MetricReport(results, report_metadata)
end

function _permutation_irreversibility(
    values::AbstractVector,
    order::Integer,
    delay::Integer;
    base::Real=2,
    pseudocount::Real=0.0,
)
    forward_counts = _ordinal_pattern_counts(values, order, delay)
    reverse_counts = _ordinal_pattern_counts(reverse(values), order, delay)

    patterns = union(keys(forward_counts), keys(reverse_counts))
    isempty(patterns) && return 0.0

    p = Float64[]
    q = Float64[]

    for pattern in patterns
        push!(p, get(forward_counts, pattern, 0) + pseudocount)
        push!(q, get(reverse_counts, pattern, 0) + pseudocount)
    end

    sum_p = sum(p)
    sum_q = sum(q)

    sum_p > 0 || throw(ArgumentError(
        "Forward ordinal-pattern distribution has zero total mass."
    ))
    sum_q > 0 || throw(ArgumentError(
        "Reverse ordinal-pattern distribution has zero total mass."
    ))

    p ./= sum_p
    q ./= sum_q
    midpoint = (p .+ q) ./ 2

    return 0.5 * _kl_discrete(p, midpoint, base) +
           0.5 * _kl_discrete(q, midpoint, base)
end

function _ordinal_pattern_counts(
    values::AbstractVector,
    order::Integer,
    delay::Integer,
)
    final_start = length(values) - (order - 1) * delay
    final_start >= 1 || return Dict{Tuple{Vararg{Int}},Int}()

    counts = Dict{Tuple{Vararg{Int}},Int}()

    for start in 1:final_start
        window = [
            values[start + (offset - 1) * delay]
            for offset in 1:order
        ]

        permutation = sortperm(
            eachindex(window);
            by=index -> (window[index], index),
        )
        pattern = Tuple(permutation)
        counts[pattern] = get(counts, pattern, 0) + 1
    end

    return counts
end

function _recurrence_matrix(
    trajectory::AbstractMatrix,
    radius::Real,
    metric::Symbol,
    theiler::Integer,
)
    ntime = size(trajectory, 2)
    recurrence = falses(ntime, ntime)

    for i in 1:ntime
        for j in 1:ntime
            abs(i - j) <= theiler && continue

            distance = _state_distance(
                @view(trajectory[:, i]),
                @view(trajectory[:, j]),
                metric,
            )

            recurrence[i, j] = distance <= radius
        end
    end

    return recurrence
end

function _state_distance(
    x::AbstractVector,
    y::AbstractVector,
    metric::Symbol,
)
    if metric === :euclidean
        return sqrt(sum(abs2, x .- y))
    elseif metric === :maximum
        return maximum(abs.(x .- y))
    elseif metric === :manhattan
        return sum(abs.(x .- y))
    end

    error("Unreachable recurrence distance branch for `$metric`.")
end

function _admissible_pair_count(
    ntime::Integer,
    theiler::Integer,
)
    count = 0

    for i in 1:ntime
        for j in 1:ntime
            abs(i - j) <= theiler && continue
            count += 1
        end
    end

    return count
end

function _diagonal_line_lengths(
    recurrence::AbstractMatrix{Bool};
    min_length::Integer=2,
)
    nrows, ncols = size(recurrence)
    lengths = Int[]

    for offset in -(nrows - 1):(ncols - 1)
        row_start = max(1, 1 - offset)
        col_start = max(1, 1 + offset)
        available = min(nrows - row_start + 1, ncols - col_start + 1)

        current = 0

        for step in 0:(available - 1)
            if recurrence[row_start + step, col_start + step]
                current += 1
            else
                if current >= min_length
                    push!(lengths, current)
                end
                current = 0
            end
        end

        if current >= min_length
            push!(lengths, current)
        end
    end

    return lengths
end
