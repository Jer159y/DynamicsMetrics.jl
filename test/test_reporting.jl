@testset "Reporting" begin
    truth = [1.0 2.0 3.0; 2.0 4.0 6.0]
    prediction = truth .+ 0.5
    report = evaluate(MetricSuite(RMSE(), MAE()), truth, prediction)

    @testset "Summary and table" begin
        summary = report_summary(report)

        @test summary isa AbstractVector
        @test all(row -> row isa NamedTuple, summary)
        @test Set(row.name for row in summary) == Set([:rmse, :mae])
        @test all(row -> row.kind == :scalar, summary)

        summary_by_name = Dict(row.name => row for row in summary)
        @test summary_by_name[:rmse].value ≈ report[:rmse].value
        @test summary_by_name[:mae].value ≈ report[:mae].value

        table = report_table(report)
        @test table isa AbstractString
        @test occursin("rmse", lowercase(table))
        @test occursin("mae", lowercase(table))
    end

    @testset "TOML round trip" begin
        mktempdir() do directory
            report_path = joinpath(directory, "report.toml")
            table_path = joinpath(directory, "report.txt")

            serialize_report(report_path, report)
            @test isfile(report_path)
            @test !isempty(read(report_path, String))

            restored = deserialize_report(report_path)
            @test restored isa MetricReport
            @test restored[:rmse].value ≈ report[:rmse].value
            @test restored[:mae].value ≈ report[:mae].value

            write_report_table(table_path, report)
            @test isfile(table_path)

            table_text = read(table_path, String)
            @test !isempty(table_text)
            @test occursin("rmse", lowercase(table_text))
            @test occursin("mae", lowercase(table_text))
        end
    end
end
