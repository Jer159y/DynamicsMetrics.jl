# API Reference

## Core interface

```@docs
AbstractMetric
AbstractMetricResult
evaluate
metricname
metricparameters
supports_reduction
validate_reduction
```

## Result types and accessors

```@docs
MetricResult
MetricSeries
MetricReport
value
parameters
metadata
```

## Metric suites

```@docs
MetricSuite
```

## Pointwise metrics

```@docs
RMSE
MAE
NRMSE
RelativeL2Error
ErrorOverTime
```

## Forecast horizons

```@docs
ValidPredictionTime
ForecastHorizon
```

## Temporal diagnostics

```@docs
Autocorrelation
PowerSpectralDensity
SpectralEntropy
```

## Statistical metrics

```@docs
CovarianceError
WassersteinDistance
JensenShannonDivergence
```

## Dynamical diagnostics

```@docs
PermutationIrreversibility
RecurrenceQuantification
```

## Ensemble metrics

```@docs
EnsembleMean
EnsembleSpread
EnsembleMeanError
MemberwiseError
PredictionIntervalCoverage
```

## Reporting

```@docs
report_summary
report_table
serialize_report
deserialize_report
write_report_table
```
