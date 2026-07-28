@testset "Ensemble metrics" begin
    truth = [1.0 2.0 3.0; 2.0 4.0 6.0]
    predictions = cat(
        truth .- 1.0,
        truth,
        truth .+ 1.0;
        dims=3,
    )

    @testset "Ensemble mean" begin
        result = evaluate(EnsembleMean(), truth, predictions)
        @test result isa MetricSeries
        @test result.values ≈ truth
        @test size(result.values) == size(truth)
    end

    @testset "Ensemble spread" begin
        result = evaluate(
            EnsembleSpread(corrected=false, reduction=:none),
            truth,
            predictions,
        )
        @test result isa MetricSeries
        @test size(result.values) == size(truth)
        @test all(result.values .≈ sqrt(2 / 3))

        global_result = evaluate(
            EnsembleSpread(corrected=false, reduction=:global),
            truth,
            predictions,
        )
        @test global_result.value ≈ sqrt(2 / 3)
    end

    @testset "Mean and memberwise errors" begin
        mean_error = evaluate(
            EnsembleMeanError(metric=RMSE()), truth, predictions
        )
        @test mean_error.value ≈ 0.0

        memberwise = evaluate(
            MemberwiseError(metric=RMSE()), truth, predictions
        )
        @test memberwise isa MetricSeries
        @test memberwise.values ≈ [1.0, 0.0, 1.0]
        @test memberwise.metadata.best_member == 2
    end

    @testset "Prediction interval coverage" begin
        coverage = evaluate(
            PredictionIntervalCoverage(
                lower=0.0,
                upper=1.0,
                reduction=:global,
            ),
            truth,
            predictions,
        )
        @test coverage.value ≈ 1.0
    end

    @test_throws DimensionMismatch evaluate(
        EnsembleMean(), truth, randn(3, 3, 4)
    )
end
