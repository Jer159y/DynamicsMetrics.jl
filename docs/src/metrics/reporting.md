# Reporting

DynamicsMetrics separates metric computation from presentation and storage.

## Metric reports

A `MetricSuite` evaluation returns `MetricReport`:

```julia
suite = MetricSuite(RMSE(), MAE())
report = evaluate(suite, truth, prediction)
```

Access a result by stable name:

```julia
report[:rmse]
report[:mae]
```

## Structured summary

```julia
rows = report_summary(report)
```

`report_summary` returns a vector of named tuples, not a rendered string. Each
row describes one report entry and includes fields such as:

```julia
row.name
row.kind
row.value
row.parameters
```

Structured rows are convenient for subsequent programmatic processing.

## Text table

```julia
table = report_table(report)
println(table)
```

`report_table` renders a human-readable representation.

Write it directly:

```julia
write_report_table("metrics.txt", report)
```

The file path is the first argument.

## TOML serialization

```julia
serialize_report("metrics.toml", report)
restored = deserialize_report("metrics.toml")
```

The path is the first argument to `serialize_report`.

Optional labels and metadata may be supplied where supported:

```julia
serialize_report(
    "metrics.toml",
    report;
    labels=(model="ESN", system="Lorenz96"),
    metadata=(seed=1234, dt=0.05),
)
```

Use plain serializable values for custom metadata.

## Reproducibility

A serialized report should accompany:

- package version;
- model identifier;
- dataset or system identifier;
- state ordering;
- evaluated interval;
- preprocessing;
- `dt`;
- random seed;
- code revision.

The report stores metric parameters but cannot infer omitted experimental
context.
