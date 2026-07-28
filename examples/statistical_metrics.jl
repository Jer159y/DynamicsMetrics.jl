using DynamicsMetrics

println("=== Statistical and climate-style metrics ===")

# The prediction has a shifted first state and a rescaled second state.
truth = [
    -2.0  -1.0   0.0   1.0   2.0
     0.0   1.0   0.0  -1.0   0.0
]

prediction = [
    -1.5  -0.5   0.5   1.5   2.5
     0.0   1.4   0.0  -1.4   0.0
]

covariance_error = evaluate(
    CovarianceError(norm=:frobenius, relative=false),
    truth,
    prediction,
)

wasserstein = evaluate(
    WassersteinDistance(reduction=:state),
    truth,
    prediction,
)

js = evaluate(
    JensenShannonDivergence(
        bins=8,
        reduction=:state,
        base=2,
        range=:combined,
    ),
    truth,
    prediction,
)

println("Covariance error:             ", covariance_error.value)
println("Wasserstein distance by state: ", wasserstein.values)
println("JS divergence by state:        ", js.values)

println("\nInterpretation:")
println("  - CovarianceError compares second-order dependence structure.")
println("  - WassersteinDistance compares empirical sample locations.")
println("  - JensenShannonDivergence compares histogram-based distributions.")
