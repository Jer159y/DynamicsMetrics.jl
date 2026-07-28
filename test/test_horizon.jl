@testset "Horizon metrics" begin
    truth = zeros(1, 5)
    prediction = reshape([0.0, 0.2, 0.5, 0.8, 1.0], 1, :)

    @testset "ValidPredictionTime" begin
        result = evaluate(
            ValidPredictionTime(
                threshold=0.5,
                normalization=:none,
                interpolate=false,
            ),
            truth,
            prediction;
            dt=0.25,
        )
        @test result.value ≈ 0.5
        @test result.metadata.crossed
        @test result.metadata.crossing_index == 3
    end

    @testset "Interpolated crossing" begin
        result = evaluate(
            ForecastHorizon(
                threshold=0.35,
                normalization=:none,
                interpolate=true,
            ),
            truth,
            prediction;
            dt=1.0,
        )
        @test result.value ≈ 1.5
    end

    @testset "No crossing" begin
        result = evaluate(
            ForecastHorizon(threshold=2.0),
            truth,
            prediction;
            dt=0.5,
        )
        @test result.value ≈ 2.0
        @test !result.metadata.crossed
        @test result.metadata.crossing_index === nothing
    end

    @test_throws ArgumentError ValidPredictionTime(threshold=0.0)
    @test_throws ArgumentError ForecastHorizon(threshold=1.0, norm=:bad)
end
