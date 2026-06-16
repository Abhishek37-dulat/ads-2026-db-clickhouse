-- Relay analytics store. Hourly per-deployment facts, partitioned by day.
-- Mirrors tech-design.html §09 (ClickHouse — metric facts).
-- Mounted into the clickhouse container's /docker-entrypoint-initdb.d on first boot.

CREATE TABLE IF NOT EXISTS relay.metric_snapshot
(
    workspace_id  UUID,
    deployment_id UUID,
    campaign_id   UUID,
    platform      LowCardinality(String),
    ts            DateTime,                  -- hour grain
    impressions   UInt64,
    clicks        UInt64,
    spend         Decimal(12, 2),
    conversions   UInt64,
    revenue       Decimal(12, 2),
    ingested_at   DateTime DEFAULT now()
)
ENGINE = MergeTree
PARTITION BY toYYYYMMDD(ts)
ORDER BY (workspace_id, deployment_id, ts);

-- Daily rollup the Analytics screen reads from.
CREATE MATERIALIZED VIEW IF NOT EXISTS relay.metric_daily
ENGINE = SummingMergeTree
PARTITION BY toYYYYMM(day)
ORDER BY (workspace_id, campaign_id, platform, day)
AS
SELECT
    workspace_id,
    campaign_id,
    platform,
    toDate(ts)                AS day,
    sum(impressions)          AS impressions,
    sum(clicks)               AS clicks,
    sum(spend)                AS spend,
    sum(conversions)          AS conversions,
    sum(revenue)              AS revenue
FROM relay.metric_snapshot
GROUP BY workspace_id, campaign_id, platform, day;

-- Idempotent provider imports. Re-syncing the same provider/day replaces the previous version.
CREATE TABLE IF NOT EXISTS relay.provider_metric_snapshot
(
    workspace_id  UUID,
    deployment_id UUID,
    campaign_id   UUID,
    platform      LowCardinality(String),
    ts            DateTime,
    impressions   UInt64,
    clicks        UInt64,
    spend         Decimal(12, 2),
    conversions   UInt64,
    revenue       Decimal(12, 2),
    currency      LowCardinality(String),
    source_key    String,
    updated_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMMDD(ts)
ORDER BY (workspace_id, deployment_id, ts, source_key);

-- Provider action breakdowns, also hourly and idempotent.
CREATE TABLE IF NOT EXISTS relay.provider_action_snapshot
(
    workspace_id  UUID,
    deployment_id UUID,
    campaign_id   UUID,
    platform      LowCardinality(String),
    ts            DateTime,
    action_type   String,
    action_count  Decimal(18, 4),
    action_value  Decimal(18, 4),
    currency      LowCardinality(String),
    source_key    String,
    updated_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = ReplacingMergeTree(updated_at)
PARTITION BY toYYYYMMDD(ts)
ORDER BY (workspace_id, deployment_id, ts, action_type, source_key);
