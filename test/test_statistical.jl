@testset "Statistical metrics" begin
    truth = [0.0 1.0 2.0 3.0; 1.0 2.0 3.0 4.0]

    @testset "Identity of indiscernibles" begin
        @test evaluate(CovarianceError(), truth, truth).value ≈ 0.0
        @test evaluate(
            WassersteinDistance(reduction=:global), truth, truth
        ).value ≈ 0.0
        @test evaluate(
            JensenShannonDivergence(
                bins=4,
                reduction=:global,
            ),
            truth,
            truth,
        ).value ≈ 0.0 atol=1e-12
    end

    @testset "Wasserstein known value" begin
        prediction = truth .+ 2.0
        global_result = evaluate(
            WassersteinDistance(reduction=:global), truth, prediction
        )
        state_result = evaluate(
            WassersteinDistance(reduction=:state), truth, prediction
        )
        @test global_result.value ≈ 2.0
        @test state_result.values ≈ [2.0, 2.0]
    end

    @testset "Covariance invariance to translation" begin
        shifted = truth .+ 10.0
        @test evaluate(CovarianceError(), truth, shifted).value ≈ 0.0
    end

    @testset "Jensen-Shannon bounds" begin
        prediction = truth .+ 10.0
        result = evaluate(
            JensenShannonDivergence(
                bins=8,
                reduction=:global,
                base=2,
            ),
            truth,
            prediction,
        )
        @test 0.0 <= result.value <= 1.0 + eps()
    end
end
