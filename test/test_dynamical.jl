@testset "Dynamical diagnostics" begin
    periodic = reshape(repeat([0.0, 1.0, 0.0, -1.0], 8), 1, :)

    @testset "Grid visitation distance" begin
        truth = [1.0 2.0 3.0 4.0; 4.0 3.0 2.0 1.0]

        @test evaluate(GridVisitationDistance(), truth, truth).value ≈ 0.0

        far_away = truth .+ 1000.0
        far_result = evaluate(
            GridVisitationDistance(bins_per_dim=10), truth, far_away,
        )
        @test far_result.value ≈ 1.0

        result = evaluate(
            GridVisitationDistance(bins_per_dim=10, dims=1:2, pad_frac=0.1),
            truth,
            truth,
        )
        @test result isa MetricResult
        @test 0.0 <= result.value <= 1.0

        @test_throws ArgumentError GridVisitationDistance(bins_per_dim=0)
        @test_throws ArgumentError GridVisitationDistance(pad_frac=-1.0)
    end

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
