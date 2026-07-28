using DynamicsMetrics

println("=== Basic pointwise metrics ===")
println("Canonical layout: state × time")

truth = [
    1.0  2.0  3.0
    2.0  4.0  6.0
]

prediction = [
    1.0  2.5  2.5
    2.0  3.0  7.0
]

rmse = evaluate(RMSE(), truth, prediction)
mae = evaluate(MAE(), truth, prediction)
relative_l2 = evaluate(RelativeL2Error(), truth, prediction)
nrmse = evaluate(NRMSE(scale=:range), truth, prediction)

println("\nScalar results")
println("  RMSE:              ", rmse.value)
println("  MAE:               ", mae.value)
println("  relative L2 error: ", relative_l2.value)
println("  range NRMSE:       ", nrmse.value)

rmse_by_state = evaluate(RMSE(reduction=:state), truth, prediction)
rmse_by_time = evaluate(RMSE(reduction=:time), truth, prediction)
elementwise_error = evaluate(RMSE(reduction=:none), truth, prediction)

println("\nReduction modes")
println("  RMSE by state: ", rmse_by_state.values)
println("  RMSE by time:  ", rmse_by_time.values)
println("  absolute elementwise error:\n", elementwise_error.values)

time_error = evaluate(
    ErrorOverTime(norm=:rmse),
    truth,
    prediction;
    dt=0.25,
)

println("\nTime-resolved error")
println("  time axis:  ", time_error.axis)
println("  RMSE(t):    ", time_error.values)
println("\nInterpretation: the first sample is exact; errors appear afterward.")
