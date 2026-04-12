-- 004: Continuous aggregates for pre-computed rollups.
--
-- These materialized views are maintained automatically by TimescaleDB.
-- Dashboard queries for hourly/daily rollups hit these instead of scanning
-- raw hypertables, giving sub-millisecond response times regardless of
-- total data volume.

-- Payment hourly rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.payments_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', created_at) AS bucket,
    tenant_id,
    partition_id,
    route,
    status,
    count(*)                AS total_count,
    coalesce(sum(amount), 0) AS total_volume,
    coalesce(avg(processing_ms), 0) AS avg_processing
FROM analytics.payments
GROUP BY bucket, tenant_id, partition_id, route, status
WITH NO DATA;

SELECT add_continuous_aggregate_policy('analytics.payments_hourly',
    start_offset  => INTERVAL '3 days',
    end_offset    => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- Notification hourly rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.notifications_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', created_at) AS bucket,
    tenant_id,
    partition_id,
    channel,
    status,
    count(*)     AS total_count,
    count(*) FILTER (WHERE delivered) AS delivered_count,
    count(*) FILTER (WHERE opened)    AS opened_count
FROM analytics.notifications
GROUP BY bucket, tenant_id, partition_id, channel, status
WITH NO DATA;

SELECT add_continuous_aggregate_policy('analytics.notifications_hourly',
    start_offset  => INTERVAL '3 days',
    end_offset    => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- Audit hourly rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.audit_entries_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', created_at) AS bucket,
    tenant_id,
    partition_id,
    action,
    service,
    count(*)                     AS total_count,
    count(DISTINCT actor_id)     AS unique_actors
FROM analytics.audit_entries
GROUP BY bucket, tenant_id, partition_id, action, service
WITH NO DATA;

SELECT add_continuous_aggregate_policy('analytics.audit_entries_hourly',
    start_offset  => INTERVAL '3 days',
    end_offset    => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

-- File upload daily rollup
CREATE MATERIALIZED VIEW IF NOT EXISTS analytics.files_daily
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 day', created_at) AS bucket,
    tenant_id,
    partition_id,
    content_type,
    count(*)                       AS upload_count,
    coalesce(sum(size_bytes), 0)   AS total_bytes
FROM analytics.files
GROUP BY bucket, tenant_id, partition_id, content_type
WITH NO DATA;

SELECT add_continuous_aggregate_policy('analytics.files_daily',
    start_offset  => INTERVAL '7 days',
    end_offset    => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);
