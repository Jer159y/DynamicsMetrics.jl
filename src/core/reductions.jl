"""
    SUPPORTED_REDUCTIONS

Reduction modes recognized by the core package.

- `:global`: aggregate over every state and time sample.
- `:state`: aggregate over time and return one value per state variable.
- `:time`: aggregate over state and return one value per time sample.
- `:none`: return elementwise values without aggregation.
"""
const SUPPORTED_REDUCTIONS = (:global, :state, :time, :none)

"""
    validate_reduction_symbol(reduction::Symbol) -> Symbol

Validate that `reduction` is one of the package-wide reduction symbols and
return it unchanged.
"""
function validate_reduction_symbol(reduction::Symbol)::Symbol
    reduction in SUPPORTED_REDUCTIONS && return reduction

    throw(ArgumentError(
        "Unsupported reduction `$reduction`. Supported reductions are " *
        "$(join(string.(SUPPORTED_REDUCTIONS), ", "))."
    ))
end

"""
    reduction_dims(data, reduction::Symbol)

Return the dimensions reduced by `reduction` for a vector or a canonical
`state × time` matrix.

This helper is mainly intended for metric implementations. For vectors,
`:state` and `:global` both aggregate over the time dimension, while `:time`
and `:none` preserve the elementwise series.
"""
function reduction_dims(data::AbstractArray, reduction::Symbol)
    validate_reduction_symbol(reduction)
    nd = ndims(data)

    nd in (1, 2) || throw(ArgumentError(
        "`reduction_dims` supports vectors and matrices; received ndims=$nd."
    ))

    if nd == 1
        if reduction in (:global, :state)
            return (1,)
        end
        return ()
    end

    if reduction === :global
        return (1, 2)
    elseif reduction === :state
        return (2,)
    elseif reduction === :time
        return (1,)
    end

    return ()
end

"""
    reduce_values(f, values, reduction::Symbol)

Apply reduction function `f` to `values` according to the canonical
`state × time` convention.

`f` must accept either an array or a `dims` keyword, as do functions such as
`sum`, `mean`, and `maximum`.

# Output convention

- `:global`: scalar
- `:state`: vector with one value per state variable
- `:time`: vector with one value per time sample
- `:none`: the original `values` object

Singleton dimensions produced by Julia's `dims` reductions are removed with
`vec`, yielding a stable vector-valued public API.
"""
function reduce_values(f, values::AbstractArray, reduction::Symbol)
    validate_reduction_symbol(reduction)
    nd = ndims(values)

    nd in (1, 2) || throw(ArgumentError(
        "`reduce_values` supports vectors and matrices; received ndims=$nd."
    ))

    reduction === :none && return values

    if nd == 1
        if reduction in (:global, :state)
            return f(values)
        elseif reduction === :time
            return values
        end
    end

    if reduction === :global
        return f(values)
    elseif reduction === :state
        return vec(f(values; dims=2))
    elseif reduction === :time
        return vec(f(values; dims=1))
    end

    error("Unreachable reduction branch for `$reduction`.")
end

"""
    reduce_mean(values, reduction::Symbol)

Compute a mean reduction under the canonical `state × time` convention.
"""
reduce_mean(values::AbstractArray, reduction::Symbol) =
    reduce_values(mean, values, reduction)

"""
    reduce_sum(values, reduction::Symbol)

Compute a sum reduction under the canonical `state × time` convention.
"""
reduce_sum(values::AbstractArray, reduction::Symbol) =
    reduce_values(sum, values, reduction)

"""
    reduce_root_mean(values, reduction::Symbol)

Compute the square root of the mean of `values` according to `reduction`.

This helper assumes `values` already contains nonnegative quantities, such as
squared errors. It is used by RMSE-like metrics.
"""
function reduce_root_mean(values::AbstractArray, reduction::Symbol)
    reduced = reduce_mean(values, reduction)
    return sqrt.(reduced)
end

"""
    reduced_axis(reduction, state_dimension, time_length; dt=nothing, start=0)

Return the natural axis associated with a reduced result.

- `:state` returns `1:state_dimension`.
- `:time` returns a step or physical-time axis.
- `:global` and `:none` return `nothing`.
"""
function reduced_axis(
    reduction::Symbol,
    state_dimension::Integer,
    time_length::Integer;
    dt=nothing,
    start::Real=0,
)
    validate_reduction_symbol(reduction)

    state_dimension > 0 || throw(ArgumentError(
        "`state_dimension` must be positive; received $state_dimension."
    ))
    time_length > 0 || throw(ArgumentError(
        "`time_length` must be positive; received $time_length."
    ))

    if reduction === :state
        return Base.OneTo(state_dimension)
    elseif reduction === :time
        return timeaxis(time_length; dt=dt, start=start)
    end

    return nothing
end
