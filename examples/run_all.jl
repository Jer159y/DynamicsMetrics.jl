println("=== Running all DynamicsMetrics.jl examples ===")

const EXAMPLE_FILES = [
    "basic_pointwise.jl",
    "metric_suite.jl",
    "forecast_horizon.jl",
    "temporal_diagnostics.jl",
    "statistical_metrics.jl",
    "dynamical_diagnostics.jl",
    "ensemble_evaluation.jl",
    "reporting.jl",
]

package_root = normpath(joinpath(@__DIR__, ".."))

for file in EXAMPLE_FILES
    path = joinpath(@__DIR__, file)
    println("\n>>> Running ", file)

    command = `$(Base.julia_cmd()) --project=$(package_root) --startup-file=no $(path)`
    run(command)
end

println("\nAll examples completed successfully.")
