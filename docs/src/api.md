# API Reference

## Core interface

```@docs
DynamicsMetrics.AbstractMetric
DynamicsMetrics.AbstractMetricResult
DynamicsMetrics.evaluate
DynamicsMetrics.metricname
DynamicsMetrics.metricparameters
DynamicsMetrics.supports_reduction
DynamicsMetrics.validate_reduction
```

## Result types and accessors

```@docs
DynamicsMetrics.MetricResult
DynamicsMetrics.MetricSeries
DynamicsMetrics.MetricReport
```

## Metric suites

```@docs
DynamicsMetrics.MetricSuite
```

## Pointwise metrics

```@docs
DynamicsMetrics.RMSE
DynamicsMetrics.MAE
DynamicsMetrics.NRMSE
DynamicsMetrics.RelativeL2Error
DynamicsMetrics.ErrorOverTime
```

## Forecast horizons

```@docs
DynamicsMetrics.ValidPredictionTime
DynamicsMetrics.ForecastHorizon
```

## Temporal diagnostics

```@docs
DynamicsMetrics.Autocorrelation
DynamicsMetrics.PowerSpectralDensity
DynamicsMetrics.SpectralEntropy
```

## Statistical metrics

```@docs
DynamicsMetrics.CovarianceError
DynamicsMetrics.WassersteinDistance
DynamicsMetrics.JensenShannonDivergence
```

## Dynamical diagnostics

```@docs
DynamicsMetrics.PermutationIrreversibility
DynamicsMetrics.RecurrenceQuantification
```

## Ensemble metrics

```@docs
DynamicsMetrics.EnsembleMean
DynamicsMetrics.EnsembleSpread
DynamicsMetrics.EnsembleMeanError
DynamicsMetrics.MemberwiseError
DynamicsMetrics.PredictionIntervalCoverage
```

## Reporting

```@docs
DynamicsMetrics.report_summary
DynamicsMetrics.report_table
DynamicsMetrics.serialize_report
DynamicsMetrics.deserialize_report
DynamicsMetrics.write_report_table
```

## Reproducibility metadata

```@docs
DynamicsMetrics.reproduction_metadata
```

## Package module
```@docs
DynamicsMetrics
```