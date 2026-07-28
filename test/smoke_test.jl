using DynamicsMetrics

truth = [
    1.0 2.0 3.0
    2.0 4.0 6.0
]

prediction = [
    1.0 2.5 2.5
    2.0 3.0 7.0
]

r1 = evaluate(RMSE(), truth, prediction)
r2 = evaluate(MAE(), truth, prediction)
r3 = evaluate(RelativeL2Error(), truth, prediction)

display(r1)
display(r2)
display(r3)