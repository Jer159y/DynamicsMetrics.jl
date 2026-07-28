using DynamicsMetrics

println("=== Evaluating a metric suite ===")

truth = [
    0.0  1.0  2.0  3.0
    1.0  2.0  3.0  4.0
]

prediction = [
    0.0  1.1  1.8  3.2
    1.0  1.8  3.3  3.9
]

suite = MetricSuite(
    RMSE(),
    MAE(),
    NRMSE(scale=:range),
    RelativeL2Error(),
)

report = evaluate(suite, truth, prediction)

println("Metrics stored in the report:")
for name in keys(report.results)
    println("  ", name, " => ", report[name].value)
end

println("\nDirect lookup")
println("  report[:rmse].value = ", report[:rmse].value)
println("  report[:mae].value  = ", report[:mae].value)

println("\nInterpretation: MetricSuite evaluates a consistent collection of metrics")
println("and returns one MetricReport that can be indexed by metric name.")
