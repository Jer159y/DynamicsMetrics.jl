"""
    validate_timeseries(truth, prediction; discard=0, dt=nothing, nonfinite=:error)

Validate a pair of univariate or multivariate time series.

The canonical layout is:

```text
state × time
```

Vectors are interpreted as univariate time series. Matrices must have identical
shape. The function returns validated, transient-discarded views together with
metadata describing the effective input.

# Keyword arguments

- `discard::Integer=0`: Number of initial time samples to remove.
- `dt=nothing`: Optional positive physical time step.
- `nonfinite::Symbol=:error`: Policy for non-finite values. Version 0.1 supports
  only `:error`.

# Returns

A named tuple with fields:

```julia
(
    truth,
    prediction,
    metadata,
)
```

The returned arrays are views whenever possible.

# Errors

Throws:

- `ArgumentError` for unsupported input types, invalid `discard`, invalid `dt`,
  empty effective data, or unsupported `nonfinite` policy.
- `DimensionMismatch` when truth and prediction shapes differ.
"""
function validate_timeseries(
    truth,
    prediction;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    _validate_nonfinite_policy(nonfinite)
    _validate_dt(dt)
    _validate_discard(discard)

    truth_array = _validate_timeseries_input(truth, :truth)
    prediction_array = _validate_timeseries_input(prediction, :prediction)

    size(truth_array) == size(prediction_array) || throw(DimensionMismatch(
        "Truth and prediction must have identical shape. " *
        "Received truth size $(size(truth_array)) and prediction size " *
        "$(size(prediction_array)). The canonical layout is `state × time`."
    ))

    ntime = _time_length(truth_array)
    ntime > 0 || throw(ArgumentError(
        "Time series must contain at least one time sample."
    ))

    discard < ntime || throw(ArgumentError(
        "`discard=$discard` removes all $ntime available time samples. " *
        "`discard` must be smaller than the time length."
    ))

    truth_view = discard_transient(truth_array, discard)
    prediction_view = discard_transient(prediction_array, discard)

    if nonfinite === :error
        _require_finite(truth_view, :truth)
        _require_finite(prediction_view, :prediction)
    end

    metadata = (
        original_shape = size(truth_array),
        effective_shape = size(truth_view),
        state_dimension = _state_dimension(truth_view),
        time_length = _time_length(truth_view),
        discard = Int(discard),
        dt = dt === nothing ? nothing : float(dt),
        nonfinite = nonfinite,
    )

    return (
        truth = truth_view,
        prediction = prediction_view,
        metadata = metadata,
    )
end

"""
    validate_ensemble(truth, predictions; discard=0, dt=nothing, nonfinite=:error)

Validate a truth time series and a three-dimensional ensemble prediction array.

The canonical ensemble layout is:

```text
state × time × ensemble
```

The truth may be a vector or matrix. A vector truth is treated as
`1 × time` and must correspond to an ensemble of size
`1 × time × members`.

The function returns transient-discarded views and metadata.
"""
function validate_ensemble(
    truth,
    predictions;
    discard::Integer=0,
    dt=nothing,
    nonfinite::Symbol=:error,
)
    _validate_nonfinite_policy(nonfinite)
    _validate_dt(dt)
    _validate_discard(discard)

    truth_array = _validate_timeseries_input(truth, :truth)

    predictions isa AbstractArray || throw(ArgumentError(
        "`predictions` must be an AbstractArray with layout " *
        "`state × time × ensemble`."
    ))

    ndims(predictions) == 3 || throw(ArgumentError(
        "`predictions` must be three-dimensional with layout " *
        "`state × time × ensemble`; received ndims=$(ndims(predictions))."
    ))

    eltype(predictions) <: Number || throw(ArgumentError(
        "`predictions` must contain numeric values; received " *
        "eltype $(eltype(predictions))."
    ))

    truth_state = _state_dimension(truth_array)
    truth_time = _time_length(truth_array)

    size(predictions, 1) == truth_state || throw(DimensionMismatch(
        "Truth state dimension $truth_state does not match ensemble state " *
        "dimension $(size(predictions, 1))."
    ))

    size(predictions, 2) == truth_time || throw(DimensionMismatch(
        "Truth time length $truth_time does not match ensemble time length " *
        "$(size(predictions, 2))."
    ))

    size(predictions, 3) > 0 || throw(ArgumentError(
        "Ensemble predictions must contain at least one member."
    ))

    truth_time > 0 || throw(ArgumentError(
        "Time series must contain at least one time sample."
    ))

    discard < truth_time || throw(ArgumentError(
        "`discard=$discard` removes all $truth_time available time samples. " *
        "`discard` must be smaller than the time length."
    ))

    truth_view = discard_transient(truth_array, discard)
    predictions_view = @view predictions[:, (discard + 1):end, :]

    if nonfinite === :error
        _require_finite(truth_view, :truth)
        _require_finite(predictions_view, :predictions)
    end

    metadata = (
        original_truth_shape = size(truth_array),
        original_prediction_shape = size(predictions),
        effective_truth_shape = size(truth_view),
        effective_prediction_shape = size(predictions_view),
        state_dimension = truth_state,
        time_length = size(predictions_view, 2),
        ensemble_size = size(predictions_view, 3),
        discard = Int(discard),
        dt = dt === nothing ? nothing : float(dt),
        nonfinite = nonfinite,
    )

    return (
        truth = truth_view,
        predictions = predictions_view,
        metadata = metadata,
    )
end

"""
    discard_transient(data, discard)

Return a view of `data` with the first `discard` time samples removed.

Supported layouts:

- vector: `time`
- matrix: `state × time`
- 3D array: `state × time × ensemble`
"""
function discard_transient(data::AbstractArray, discard::Integer)
    _validate_discard(discard)

    nd = ndims(data)

    if nd == 1
        discard < length(data) || throw(ArgumentError(
            "`discard=$discard` removes all $(length(data)) samples."
        ))
        return @view data[(discard + 1):end]
    elseif nd == 2
        discard < size(data, 2) || throw(ArgumentError(
            "`discard=$discard` removes all $(size(data, 2)) time samples."
        ))
        return @view data[:, (discard + 1):end]
    elseif nd == 3
        discard < size(data, 2) || throw(ArgumentError(
            "`discard=$discard` removes all $(size(data, 2)) time samples."
        ))
        return @view data[:, (discard + 1):end, :]
    end

    throw(ArgumentError(
        "`discard_transient` supports vectors, matrices, and three-dimensional " *
        "ensemble arrays; received ndims=$nd."
    ))
end

"""
    timeaxis(n; dt=nothing, start=0)

Construct a time axis of length `n`.

When `dt === nothing`, an integer step axis beginning at `start` is returned.
When `dt` is provided, it must be finite and positive.
"""
function timeaxis(
    n::Integer;
    dt=nothing,
    start::Real=0,
)
    n > 0 || throw(ArgumentError(
        "`n` must be positive; received $n."
    ))
    isfinite(start) || throw(ArgumentError(
        "`start` must be finite; received $start."
    ))

    _validate_dt(dt)

    if dt === nothing
        return range(start; step=1, length=n)
    end

    return range(float(start); step=float(dt), length=n)
end

"""
    require_real(data, name=:data)

Validate that `data` has a real-valued element type.

Metrics that are not defined for complex-valued data should call this helper
explicitly rather than silently applying `real`, `abs`, or `angle`.
"""
function require_real(data, name::Symbol=:data)
    eltype(data) <: Real && return data

    throw(ArgumentError(
        "`$name` must be real-valued for this metric; received eltype " *
        "$(eltype(data)). Complex-valued data must be transformed explicitly."
    ))
end

function _validate_timeseries_input(data, name::Symbol)
    data isa AbstractArray || throw(ArgumentError(
        "`$name` must be an AbstractVector or AbstractMatrix."
    ))

    nd = ndims(data)
    nd in (1, 2) || throw(ArgumentError(
        "`$name` must be a vector or matrix with canonical layout " *
        "`state × time`; received ndims=$nd."
    ))

    eltype(data) <: Number || throw(ArgumentError(
        "`$name` must contain numeric values; received eltype $(eltype(data))."
    ))

    if nd == 2
        size(data, 1) > 0 || throw(ArgumentError(
            "`$name` must contain at least one state variable."
        ))
    end

    return data
end

function _validate_discard(discard::Integer)
    discard >= 0 || throw(ArgumentError(
        "`discard` must be nonnegative; received $discard."
    ))
    return discard
end

function _validate_dt(dt)
    dt === nothing && return nothing

    dt isa Real || throw(ArgumentError(
        "`dt` must be `nothing` or a real scalar; received $(typeof(dt))."
    ))

    isfinite(dt) || throw(ArgumentError(
        "`dt` must be finite; received $dt."
    ))

    dt > 0 || throw(ArgumentError(
        "`dt` must be positive; received $dt."
    ))

    return dt
end

function _validate_nonfinite_policy(policy::Symbol)
    policy === :error && return policy

    throw(ArgumentError(
        "Unsupported `nonfinite` policy `$policy`. Version 0.1 supports only " *
        "`nonfinite=:error`."
    ))
end

function _require_finite(data, name::Symbol)
    for (index, value) in pairs(data)
        if !isfinite(value)
            throw(ArgumentError(
                "`$name` contains a non-finite value at index $index: $value. " *
                "DynamicsMetrics.jl does not repair or discard non-finite " *
                "values silently."
            ))
        end
    end

    return data
end

_state_dimension(data::AbstractVector) = 1
_state_dimension(data::AbstractMatrix) = size(data, 1)

_time_length(data::AbstractVector) = length(data)
_time_length(data::AbstractMatrix) = size(data, 2)
