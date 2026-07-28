@testset "Dynamical diagnostics" begin
    periodic = reshape(repeat([0.0, 1.0, 0.0, -1.0], 8), 1, :)

    @testset "Permutation irreversibility" begin
        result = evaluate(
            PermutationIrreversibility(
                order=3,
                delay=1,
                reduction=:global,
            ),
            periodic,
        )
        @test result isa MetricResult
        @test result.value >= 0.0
        @test isfinite(result.value)
    end

    @testset "Recurrence quantification" begin
        result = evaluate(
            RecurrenceQuantification(
                radius=0.1,
                metric=:euclidean,
                theiler=0,
                min_diagonal=2,
            ),
            periodic,
        )
        @test result isa MetricReport
        for key in (
            :recurrence_rate,
            :determinism,
            :average_diagonal_length,
            :longest_diagonal_length,
        )
            @test haskey(result.results, key)
            @test isfinite(result[key].value)
        end
        @test 0.0 <= result[:recurrence_rate].value <= 1.0
        @test 0.0 <= result[:determinism].value <= 1.0
    end
end
