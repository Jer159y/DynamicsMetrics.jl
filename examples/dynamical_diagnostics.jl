using DynamicsMetrics

println("=== Dynamical diagnostics ===")

periodic = reshape(repeat([0.0, 1.0, 0.0, -1.0], 12), 1, :)

irreversibility = evaluate(
    PermutationIrreversibility(
        order=3,
        delay=1,
        reduction=:global,
    ),
    periodic,
)

rqa = evaluate(
    RecurrenceQuantification(
        radius=0.1,
        metric=:euclidean,
        theiler=0,
        min_diagonal=2,
    ),
    periodic,
)

println("Permutation irreversibility: ", irreversibility.value)
println("Recurrence rate:             ", rqa[:recurrence_rate].value)
println("Determinism:                 ", rqa[:determinism].value)
println("Average diagonal length:     ", rqa[:average_diagonal_length].value)
println("Longest diagonal length:     ", rqa[:longest_diagonal_length].value)

println("\nInterpretation: these functions diagnose one trajectory's temporal")
println("asymmetry and recurrence structure; they are not pointwise errors.")
