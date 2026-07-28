"""
    MetricResult

Structured scalar metric result.
"""
struct MetricResult{T,P,M} <: AbstractMetricResult
    name::Symbol
    value::T
    parameters::P
    metadata::M
end

"""
    MetricSeries

Structured vector-valued metric result.
"""
struct MetricSeries{A,X,P,M} <: AbstractMetricResult
    name::Symbol
    values::A
    axis::X
    parameters::P
    metadata::M
end

"""
    MetricReport

Collection of metric results.
"""
struct MetricReport
    results::Dict{Symbol,AbstractMetricResult}
    metadata::NamedTuple
end

value(r::MetricResult) = r.value
value(r::MetricSeries) = r.values

parameters(r::Union{MetricResult,MetricSeries}) = r.parameters
metadata(r::Union{MetricResult,MetricSeries,MetricReport}) = r.metadata

Base.getindex(r::MetricReport, key::Symbol) = r.results[key]

function Base.show(io::IO, r::MetricResult)
    print(io, "MetricResult(", r.name, " => ", r.value, ")")
end

function Base.show(io::IO, r::MetricSeries)
    print(io,
        "MetricSeries(",
        r.name,
        ", ",
        length(r.values),
        " values)")
end

function Base.show(io::IO, r::MetricReport)
    print(io,
        "MetricReport(",
        length(r.results),
        " metrics)")
end
