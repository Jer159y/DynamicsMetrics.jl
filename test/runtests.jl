using Test
using Random
using DynamicsMetrics

@testset "DynamicsMetrics.jl" begin
    include("test_core.jl")
    include("test_pointwise.jl")
    include("test_horizon.jl")
    include("test_temporal.jl")
    include("test_statistical.jl")
    include("test_dynamical.jl")
    include("test_ensemble.jl")
    include("test_reporting.jl")
end
