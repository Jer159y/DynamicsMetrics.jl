using DynamicsMetrics

println("=== Forecast horizon metrics ===")

truth = zeros(1, 6)
prediction = reshape([0.0, 0.1, 0.25, 0.45, 0.8, 1.1], 1, :)
dt = 0.5

vpt = evaluate(
    ValidPredictionTime(
        threshold=0.4,
        normalization=:none,
        norm=:rmse,
        interpolate=false,
    ),
    truth,
    prediction;
    dt=dt,
)

interpolated = evaluate(
    ForecastHorizon(
        threshold=0.4,
        normalization=:none,
        norm=:rmse,
        interpolate=true,
    ),
    truth,
    prediction;
    dt=dt,
)

no_crossing = evaluate(
    ForecastHorizon(
        threshold=2.0,
        normalization=:none,
    ),
    truth,
    prediction;
    dt=dt,
)

println("First sampled threshold crossing: ", vpt.value)
println("Crossing sample index:           ", vpt.metadata.crossing_index)
println("Interpolated crossing time:      ", interpolated.value)
println("No-crossing full horizon:        ", no_crossing.value)
println("No-crossing flag:                ", no_crossing.metadata.crossed)

println("\nInterpretation: with dt=0.5, returned values are expressed in physical time.")
