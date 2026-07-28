@testset "Temporal diagnostics" begin
    constant_signal = ones(1, 16)
    alternating = reshape(repeat([1.0, -1.0], 8), 1, :)

    @testset "Autocorrelation" begin
        result = evaluate(
            Autocorrelation(
                maxlag=4,
                demean=false,
                normalize=true,
                reduction=:state,
            ),
            constant_signal,
        )

        expected = reshape([1.0, 15 / 16, 14 / 16, 13 / 16, 12 / 16], 1, :)

        @test result isa MetricSeries
        @test size(result.values) == (1, 5)
        @test result.values ≈ expected
        @test result.axis == collect(0:4)
        @test length(result.axis) == 5
    end

    @testset "Power spectral density" begin
        result = evaluate(
            PowerSpectralDensity(
                detrend=:none,
                reduction=:state,
            ),
            alternating;
            dt=1.0,
        )

        @test result isa MetricSeries
        @test size(result.values, 1) == 1
        @test all(isfinite, result.values)
        @test all(result.values .>= 0)
        @test length(result.axis) == size(result.values, 2)

        peak_index = argmax(vec(result.values))
        @test result.axis[peak_index] ≈ 0.5
    end

    @testset "Spectral entropy" begin
        result = evaluate(
            SpectralEntropy(
                detrend=:none,
                reduction=:global,
                normalize=true,
            ),
            alternating,
        )

        @test result isa MetricResult
        @test isfinite(result.value)
        @test 0.0 <= result.value <= 1.0
        @test result.value ≈ 0.0 atol=1e-12
    end
end
