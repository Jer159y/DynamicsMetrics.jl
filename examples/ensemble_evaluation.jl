using DynamicsMetrics

println("=== Ensemble evaluation ===")
println("Canonical layout: state × time × ensemble")

truth = [
    1.0  2.0  3.0  4.0
    2.0  4.0  6.0  8.0
]

# Three members: negatively biased, exact, and positively biased.
predictions = cat(
    truth .- 1.0,
    truth,
    truth .+ 1.0;
    dims=3,
)

ensemble_mean = evaluate(EnsembleMean(), truth, predictions)
spread = evaluate(
    EnsembleSpread(corrected=false, reduction=:time),
    truth,
    predictions,
)
mean_error = evaluate(
    EnsembleMeanError(metric=RMSE()),
    truth,
    predictions,
)
memberwise_error = evaluate(
    MemberwiseError(metric=RMSE()),
    truth,
    predictions,
)
coverage = evaluate(
    PredictionIntervalCoverage(
        lower=0.0,
        upper=1.0,
        reduction=:global,
    ),
    truth,
    predictions,
)

println("Ensemble mean:\n", ensemble_mean.values)
println("Spread over time:       ", spread.values)
println("RMSE of ensemble mean:  ", mean_error.value)
println("RMSE of each member:    ", memberwise_error.values)
println("Best member index:      ", memberwise_error.metadata.best_member)
println("Prediction coverage:    ", coverage.value)

println("\nInterpretation: symmetric member biases cancel in the ensemble mean,")
println("while memberwise errors and spread retain uncertainty information.")
