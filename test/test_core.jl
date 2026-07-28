@testset "Core API" begin
    truth = [1.0 2.0 3.0; 2.0 4.0 6.0]
    prediction = copy(truth)

    result = evaluate(RMSE(), truth, prediction)
    @test result isa MetricResult
    @test result.name === :rmse
    @test result.value == 0.0
    @test result.parameters.reduction === :global
    @test result.metadata.state_dimension == 2
    @test result.metadata.time_length == 3

    @testset "Suite evaluation" begin
        suite = MetricSuite(RMSE(), MAE())
        report = evaluate(suite, truth, prediction)
        @test report isa MetricReport
        @test haskey(report.results, :rmse)
        @test haskey(report.results, :mae)
        @test report[:rmse].value == 0.0
        @test report[:mae].value == 0.0
    end

    @testset "Input validation" begin
        @test_throws DimensionMismatch evaluate(
            RMSE(), randn(2, 5), randn(3, 5)
        )
        @test_throws ArgumentError evaluate(
            RMSE(), [1.0 NaN], [1.0 2.0]
        )
        @test_throws ArgumentError RMSE(reduction=:invalid)
        @test_throws ArgumentError evaluate(
            RMSE(), truth, prediction; discard=3
        )
    end
end
