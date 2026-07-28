using DynamicsMetrics

println("=== Reporting and serialization ===")

truth = [
    1.0  2.0  3.0
    2.0  4.0  6.0
]
prediction = truth .+ 0.5

report = evaluate(
    MetricSuite(RMSE(), MAE(), RelativeL2Error()),
    truth,
    prediction,
)

summary = report_summary(report)
table = report_table(report)

println("Structured summary:")
for row in summary
    println("  ", row)
end

println("\nRendered table:")
println(table)

mktempdir() do directory
    toml_path = joinpath(directory, "metrics.toml")
    table_path = joinpath(directory, "metrics.txt")

    serialize_report(toml_path, report)
    write_report_table(table_path, report)

    restored = deserialize_report(toml_path)

    println("Temporary TOML path: ", toml_path)
    println("Temporary table path: ", table_path)
    println("Restored RMSE:        ", restored[:rmse].value)
end

println("\nInterpretation: reports can be rendered for people and serialized for")
println("reproducible downstream analysis without leaving persistent example files.")
