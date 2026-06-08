# db-clickhouse

ClickHouse analytics store assets.

- `init/*.sql` — schema bootstrap, run by the container on first boot
  (mounted at `/docker-entrypoint-initdb.d`). Holds `metric_snapshot` (MergeTree, partitioned
  by day) and the `metric_daily` rollup the Analytics screen reads.

ClickHouse has no row-level security, so every backend query is explicitly scoped by
`workspace_id` (see `MetricService`).
