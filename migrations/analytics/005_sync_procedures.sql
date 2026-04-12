-- 005: Generic incremental sync procedures for FDW → hypertable population.
--
-- Each procedure:
--   1. Reads the last sync timestamp from analytics.sync_state
--   2. Pulls only new rows from the FDW foreign table (WHERE created_at > last_synced)
--   3. Inserts into the local hypertable with ON CONFLICT DO NOTHING
--   4. Updates sync_state with the new high-water mark and row count
--
-- Schedule these via TimescaleDB's add_job() or pg_cron.
--
-- IMPORTANT: Adjust the foreign table column names to match your actual
-- service database schemas before running.

-- ============================================================
-- Generic sync helper
-- ============================================================
-- Upserts the sync state after a successful sync run.
CREATE OR REPLACE FUNCTION analytics.update_sync_state(
    p_source TEXT,
    p_synced_at TIMESTAMPTZ,
    p_rows BIGINT
) RETURNS VOID
LANGUAGE sql AS $$
    INSERT INTO analytics.sync_state (source_table, last_synced_at, rows_synced, updated_at)
    VALUES (p_source, p_synced_at, p_rows, now())
    ON CONFLICT (source_table) DO UPDATE SET
        last_synced_at = EXCLUDED.last_synced_at,
        rows_synced = analytics.sync_state.rows_synced + EXCLUDED.rows_synced,
        last_error = NULL,
        updated_at = now();
$$;

-- Records a sync error without losing the last successful state.
CREATE OR REPLACE FUNCTION analytics.record_sync_error(
    p_source TEXT,
    p_error TEXT
) RETURNS VOID
LANGUAGE sql AS $$
    INSERT INTO analytics.sync_state (source_table, last_error, updated_at)
    VALUES (p_source, p_error, now())
    ON CONFLICT (source_table) DO UPDATE SET
        last_error = EXCLUDED.last_error,
        updated_at = now();
$$;

-- ============================================================
-- Payment sync
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_payments()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'payments';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.payments (id, tenant_id, partition_id, created_at, route, status, state, amount, currency, recipient, processing_ms)
    SELECT id, tenant_id, partition_id, created_at, route, status, state, amount, currency, recipient_id, processing_ms
    FROM fdw_payment.payments
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('payments', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('payments', SQLERRM);
END;
$$;

-- ============================================================
-- Profile sync
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_profiles()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'profiles';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.profiles (id, tenant_id, partition_id, created_at, last_active, profile_type, verified, display_name)
    SELECT id, tenant_id, partition_id, created_at, last_active, profile_type, verified, display_name
    FROM fdw_profile.profiles
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('profiles', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('profiles', SQLERRM);
END;
$$;

-- ============================================================
-- Notification sync
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_notifications()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'notifications';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.notifications (id, tenant_id, partition_id, created_at, channel, status, template_name, delivered, opened)
    SELECT id, tenant_id, partition_id, created_at, channel, status, template_name, delivered, opened
    FROM fdw_notification.notifications
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('notifications', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('notifications', SQLERRM);
END;
$$;

-- ============================================================
-- Audit sync
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_audit_entries()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'audit_entries';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.audit_entries (id, tenant_id, partition_id, created_at, action, service, actor_id, actor_name)
    SELECT id, tenant_id, partition_id, created_at, action, service, actor_id, actor_name
    FROM fdw_audit.audit_entries
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('audit_entries', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('audit_entries', SQLERRM);
END;
$$;

-- ============================================================
-- Billing sync (subscriptions + invoices)
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_subscriptions()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'subscriptions';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.subscriptions (id, tenant_id, partition_id, created_at, updated_at, status, plan_name, monthly_amount)
    SELECT id, tenant_id, partition_id, created_at, updated_at, status, plan_name, monthly_amount
    FROM fdw_billing.subscriptions
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('subscriptions', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('subscriptions', SQLERRM);
END;
$$;

CREATE OR REPLACE PROCEDURE analytics.sync_invoices()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'invoices';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.invoices (id, tenant_id, partition_id, created_at, paid_at, status, amount, customer_name)
    SELECT id, tenant_id, partition_id, created_at, paid_at, status, amount, customer_name
    FROM fdw_billing.invoices
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('invoices', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('invoices', SQLERRM);
END;
$$;

-- ============================================================
-- Files sync
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_files()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'files';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.files (id, tenant_id, partition_id, created_at, content_type, size_bytes, uploader)
    SELECT id, tenant_id, partition_id, created_at, content_type, size_bytes, uploader_id
    FROM fdw_files.files
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('files', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('files', SQLERRM);
END;
$$;

-- ============================================================
-- Geolocation sync (areas, routes, events)
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_geo_events()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'geo_events';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.geo_events (id, tenant_id, partition_id, created_at, event_type, device_id, area_name)
    SELECT id, tenant_id, partition_id, created_at, event_type, device_id, area_name
    FROM fdw_geolocation.geo_events
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('geo_events', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('geo_events', SQLERRM);
END;
$$;

-- ============================================================
-- Settings sync (settings + setting_changes)
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_settings()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'settings';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.settings (id, tenant_id, partition_id, created_at, module)
    SELECT id, tenant_id, partition_id, created_at, module
    FROM fdw_settings.settings
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('settings', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('settings', SQLERRM);
END;
$$;

CREATE OR REPLACE PROCEDURE analytics.sync_setting_changes()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'setting_changes';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.setting_changes (id, tenant_id, partition_id, changed_at, module, setting_key, actor_id)
    SELECT id, tenant_id, partition_id, changed_at, module, setting_key, actor_id
    FROM fdw_settings.setting_changes
    WHERE changed_at > v_last AND changed_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('setting_changes', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('setting_changes', SQLERRM);
END;
$$;

-- ============================================================
-- Tenancy sync (tenants, partitions, access_logs)
-- ============================================================
CREATE OR REPLACE PROCEDURE analytics.sync_tenants()
LANGUAGE plpgsql AS $$
DECLARE
    v_last TIMESTAMPTZ;
    v_now  TIMESTAMPTZ := now();
    v_rows BIGINT;
BEGIN
    SELECT last_synced_at INTO v_last
    FROM analytics.sync_state WHERE source_table = 'tenants';
    IF v_last IS NULL THEN v_last := '1970-01-01'::TIMESTAMPTZ; END IF;

    INSERT INTO analytics.tenants (id, tenant_id, partition_id, created_at, tenant_name, plan)
    SELECT id, tenant_id, partition_id, created_at, name, plan
    FROM fdw_tenancy.tenants
    WHERE created_at > v_last AND created_at <= v_now
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    PERFORM analytics.update_sync_state('tenants', v_now, v_rows);
EXCEPTION WHEN OTHERS THEN
    PERFORM analytics.record_sync_error('tenants', SQLERRM);
END;
$$;

-- ============================================================
-- Schedule sync jobs (every 5 minutes)
-- ============================================================
SELECT add_job('analytics.sync_payments',        '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_profiles',        '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_notifications',   '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_audit_entries',   '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_subscriptions',   '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_invoices',        '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_files',           '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_geo_events',      '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_settings',        '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_setting_changes', '5 minutes', if_not_exists => TRUE);
SELECT add_job('analytics.sync_tenants',         '5 minutes', if_not_exists => TRUE);
