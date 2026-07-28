const POINTWISE_TRUTH = [
    1.0 2.0 3.0
    2.0 4.0 6.0
]

const POINTWISE_PREDICTION = [
    1.0 2.5 2.5
    2.0 3.0 7.0
]

@testset "Pointwise metrics" begin
    @testset "RMSE" begin
        result = evaluate(RMSE(), POINTWISE_TRUTH, POINTWISE_PREDICTION)
        @test result isa MetricResult
        @test result.value ≈ sqrt(2.5 / 6)

        state = evaluate(
            RMSE(reduction=:state),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        )
        time = evaluate(
            RMSE(reduction=:time),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        )
        none = evaluate(
            RMSE(reduction=:none),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        )

        @test state isa MetricSeries
        @test state.values ≈ [sqrt(0.5 / 3), sqrt(2.0 / 3)]
        @test length(state.axis) == 2
        @test time.values ≈ [0.0, sqrt(0.625), sqrt(0.625)]
        @test length(time.axis) == 3
        @test size(none.values) == size(POINTWISE_TRUTH)
        @test none.values == abs.(POINTWISE_PREDICTION .- POINTWISE_TRUTH)
    end

    @testset "MAE" begin
        result = evaluate(MAE(), POINTWISE_TRUTH, POINTWISE_PREDICTION)
        @test result.value ≈ 0.5
        @test evaluate(
            MAE(reduction=:state),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        ).values ≈ [1 / 3, 2 / 3]
    end

    @testset "Relative L2 error" begin
        result = evaluate(
            RelativeL2Error(),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        )
        @test result.value ≈ sqrt(2.5 / 70.0)
        @test_throws ArgumentError evaluate(
            RelativeL2Error(), zeros(2, 3), ones(2, 3)
        )
    end

    @testset "NRMSE" begin
        truth = [0.0 1.0 2.0; 0.0 2.0 4.0]
        prediction = truth .+ 1.0

        result = evaluate(
            NRMSE(scale=:range), truth, prediction
        )
        @test result.value ≈ 1 / 4

        state = evaluate(
            NRMSE(scale=:range, reduction=:state), truth, prediction
        )
        @test state.values ≈ [1 / 2, 1 / 4]

        @test_throws ArgumentError evaluate(
            NRMSE(scale=:std), ones(2, 4), zeros(2, 4)
        )
    end

    @testset "Error over time" begin
        rmse = evaluate(
            ErrorOverTime(norm=:rmse),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION;
            dt=0.25,
        )
        mae = evaluate(
            ErrorOverTime(norm=:mae),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        )
        l2 = evaluate(
            ErrorOverTime(norm=:l2),
            POINTWISE_TRUTH,
            POINTWISE_PREDICTION,
        )

        @test rmse.values ≈ [0.0, sqrt(0.625), sqrt(0.625)]
        @test rmse.axis ≈ [0.0, 0.25, 0.5]
        @test mae.values ≈ [0.0, 0.75, 0.75]
        @test l2.values ≈ [0.0, sqrt(1.25), sqrt(1.25)]
    end
end
