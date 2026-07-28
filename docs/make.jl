using Documenter
using DynamicsMetrics

DocMeta.setdocmeta!(
    DynamicsMetrics,
    :DocTestSetup,
    :(using DynamicsMetrics);
    recursive=true,
)

makedocs(
    modules=[DynamicsMetrics],
    authors="DynamicsMetrics.jl contributors",
    sitename="DynamicsMetrics.jl",
    clean=true,
    doctest=false,
    checkdocs=:exports,
    warnonly=[:missing_docs],
    format=Documenter.HTML(
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical=nothing,
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Data Contract" => "data_conventions.md",
        "Metrics" => [
            "Pointwise Errors" => "metrics/pointwise.md",
            "Forecast Horizons" => "metrics/horizon.md",
            "Temporal Diagnostics" => "metrics/temporal.md",
            "Statistical Metrics" => "metrics/statistical.md",
            "Dynamical Diagnostics" => "metrics/dynamical.md",
            "Ensemble Evaluation" => "metrics/ensemble.md",
            "Reporting" => "metrics/reporting.md",
        ],
        "Package Design" => "design.md",
        "Extending DynamicsMetrics" => "extending.md",
        "API Reference" => "api.md",
    ],
)

# Enable this after replacing the repository placeholder and configuring
# documentation deployment in GitHub Actions.
#
if get(ENV, "CI", "false") == "true"
    deploydocs(
        repo="github.com/Jer159y/DynamicsMetrics.jl.git",
        devbranch="main",
    )
end
