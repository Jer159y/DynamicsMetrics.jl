"""
    DynamicsMetrics

Model-agnostic metrics and diagnostics for evaluating predictions,
reconstructions, and state estimates of dynamical systems.

`DynamicsMetrics` uses `state × time` as the canonical matrix layout and
`state × time × ensemble` for ensemble predictions.
"""
module DynamicsMetrics

using LinearAlgebra
using Statistics
using Random
using TOML

include("core/abstract_metric.jl")
include("core/results.jl")
include("core/validation.jl")
include("core/reductions.jl")
include("core/suites.jl")

include("metrics/pointwise.jl")
include("metrics/horizon.jl")
include("metrics/temporal.jl")
include("metrics/statistical.jl")
include("metrics/dynamical.jl")

include("ensemble/summaries.jl")

include("reporting/report.jl")
include("reporting/tables.jl")

export AbstractMetric,
       AbstractMetricResult,
       MetricResult,
       MetricSeries,
       MetricReport,
       MetricSuite,
       evaluate

export RMSE,
       MAE,
       NRMSE,
       RelativeL2Error,
       ErrorOverTime

export ValidPredictionTime,
       ForecastHorizon

export Autocorrelation,
       PowerSpectralDensity,
       SpectralEntropy

export CovarianceError,
       WassersteinDistance,
       QuantileWassersteinDistance,
       JensenShannonDivergence

export PermutationIrreversibility,
       RecurrenceQuantification,
       GridVisitationDistance

export EnsembleMean,
       EnsembleSpread,
       EnsembleMeanError,
       MemberwiseError,
       PredictionIntervalCoverage

export report_summary,
       reproduction_metadata,
       serialize_report,
       deserialize_report,
       report_table,
       write_report_table

end
