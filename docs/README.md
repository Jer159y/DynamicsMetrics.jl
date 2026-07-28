# DynamicsMetrics.jl documentation

This directory contains the Documenter.jl site.

## Install documentation dependencies

From the package root:

```julia
using Pkg
Pkg.activate("docs")
Pkg.develop(PackageSpec(path=pwd()))
Pkg.instantiate()
```

The `Pkg.develop` step connects the documentation environment to the local
package checkout.

## Build locally

From the package root:

```bash
julia --project=docs docs/make.jl
```

Open:

```text
docs/build/index.html
```

## Strict build check

The current setup reports missing exported docstrings as warnings so the
initial site can be built while documentation coverage is completed.

Before the first registered release, change:

```julia
warnonly=[:missing_docs]
```

to a stricter policy after all exported symbols have docstrings.

## Deployment

After the GitHub repository URL is finalized:

1. replace `YOUR_GITHUB_USERNAME` in `docs/make.jl`;
2. uncomment `deploydocs`;
3. add the documentation GitHub Actions workflow;
4. configure GitHub Pages to publish from `gh-pages`.

Do not commit `docs/build/`.
