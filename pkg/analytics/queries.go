package analytics

// RegisterDefaultServices registers all standard Antinvestor service analytics
// definitions. Each service uses parameterized SQL:
//
//	$1 = start time, $2 = end time, $3 = tenant_id, $4 = partition_id
//	TopN queries additionally use $5 = limit
//	{{granularity}} is substituted from a validated allowlist
//	{{group_by}} is substituted from a per-definition allowlist
func RegisterDefaultServices(reg *Registry) error {
	services := []ServiceAnalytics{
		paymentAnalytics(),
		profileAnalytics(),
		notificationAnalytics(),
		billingAnalytics(),
		filesAnalytics(),
		geolocationAnalytics(),
		settingsAnalytics(),
		tenancyAnalytics(),
		auditAnalytics(),
	}
	for _, sa := range services {
		if err := reg.Register(sa); err != nil {
			return err
		}
	}
	return nil
}

func paymentAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "payment",
		ViewPermission: "analytics:payment:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_payments", Label: "Total Payments", Unit: "count", Icon: "payment",
				SQL: "SELECT count(*) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "total_volume", Label: "Total Volume", Unit: "currency", Icon: "attach_money",
				SQL: "SELECT coalesce(sum(amount), 0) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "success_rate", Label: "Success Rate", Unit: "percent", Icon: "check_circle",
				SQL: "SELECT coalesce(avg(case when status = 'success' then 100.0 else 0 end), 0) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "avg_processing_time", Label: "Avg Processing", Unit: "count", Icon: "timer",
				SQL: "SELECT coalesce(avg(processing_ms), 0) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "payment_volume", Label: "Payment Volume",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
			{Key: "payment_amount", Label: "Payment Amount",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, sum(amount) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "payment_routes", Label: "By Route", AllowedGroupBy: []string{"route"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
			{Key: "payment_status", Label: "By Status", AllowedGroupBy: []string{"status"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_recipients", Label: "Top Recipients", MaxLimit: 50,
				SQL: "SELECT recipient, sum(amount) FROM analytics.payments WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY recipient ORDER BY sum(amount) DESC LIMIT $5"},
		},
	}
}

func profileAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "profile",
		ViewPermission: "analytics:profile:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_profiles", Label: "Total Profiles", Unit: "count", Icon: "people",
				SQL: "SELECT count(*) FROM analytics.profiles WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "active_profiles", Label: "Active Profiles", Unit: "count", Icon: "person",
				SQL: "SELECT count(*) FROM analytics.profiles WHERE last_active >= $1 AND last_active < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "new_registrations", Label: "New Registrations", Unit: "count", Icon: "person_add",
				SQL: "SELECT count(*) FROM analytics.profiles WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "verification_rate", Label: "Verification Rate", Unit: "percent", Icon: "verified",
				SQL: "SELECT coalesce(avg(case when verified then 100.0 else 0 end), 0) FROM analytics.profiles WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "registrations", Label: "Registrations",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.profiles WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "profile_types", Label: "By Type", AllowedGroupBy: []string{"profile_type"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.profiles WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_active_profiles", Label: "Most Active Profiles", MaxLimit: 50,
				SQL: "SELECT display_name, activity_count FROM analytics.profile_activity WHERE period_start >= $1 AND period_start < $2 AND tenant_id = $3 AND partition_id = ANY($4) ORDER BY activity_count DESC LIMIT $5"},
		},
	}
}

func notificationAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "notification",
		ViewPermission: "analytics:notification:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_sent", Label: "Total Sent", Unit: "count", Icon: "send",
				SQL: "SELECT count(*) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "delivery_rate", Label: "Delivery Rate", Unit: "percent", Icon: "mark_email_read",
				SQL: "SELECT coalesce(avg(case when delivered then 100.0 else 0 end), 0) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "open_rate", Label: "Open Rate", Unit: "percent", Icon: "visibility",
				SQL: "SELECT coalesce(avg(case when opened then 100.0 else 0 end), 0) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "failed_count", Label: "Failed", Unit: "count", Icon: "error",
				SQL: "SELECT count(*) FROM analytics.notifications WHERE status = 'failed' AND created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "notifications_sent", Label: "Notifications Sent",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "notification_channels", Label: "By Channel", AllowedGroupBy: []string{"channel"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
			{Key: "notification_status", Label: "By Status", AllowedGroupBy: []string{"status"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_templates", Label: "Top Templates", MaxLimit: 50,
				SQL: "SELECT template_name, count(*) FROM analytics.notifications WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY template_name ORDER BY count(*) DESC LIMIT $5"},
		},
	}
}

func billingAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "billing",
		ViewPermission: "analytics:billing:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "active_subscriptions", Label: "Active Subscriptions", Unit: "count", Icon: "autorenew",
				SQL: "SELECT count(*) FROM analytics.subscriptions WHERE status = 'active' AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "mrr", Label: "Monthly Revenue", Unit: "currency", Icon: "trending_up",
				SQL: "SELECT coalesce(sum(monthly_amount), 0) FROM analytics.subscriptions WHERE status = 'active' AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "outstanding_invoices", Label: "Outstanding", Unit: "currency", Icon: "receipt_long",
				SQL: "SELECT coalesce(sum(amount), 0) FROM analytics.invoices WHERE status = 'pending' AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "churn_rate", Label: "Churn Rate", Unit: "percent", Icon: "trending_down",
				SQL: "SELECT coalesce(avg(case when status = 'cancelled' then 100.0 else 0 end), 0) FROM analytics.subscriptions WHERE updated_at >= $1 AND updated_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "revenue", Label: "Revenue",
				SQL: "SELECT date_trunc('{{granularity}}', paid_at) AS bucket, sum(amount) FROM analytics.invoices WHERE status = 'paid' AND paid_at >= $1 AND paid_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "subscription_plans", Label: "By Plan", AllowedGroupBy: []string{"plan_name"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.subscriptions WHERE status = 'active' AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_customers", Label: "Top Customers by Revenue", MaxLimit: 50,
				SQL: "SELECT customer_name, sum(amount) FROM analytics.invoices WHERE status = 'paid' AND paid_at >= $1 AND paid_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY customer_name ORDER BY sum(amount) DESC LIMIT $5"},
		},
	}
}

func filesAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "files",
		ViewPermission: "analytics:files:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_files", Label: "Total Files", Unit: "count", Icon: "folder",
				SQL: "SELECT count(*) FROM analytics.files WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "total_storage", Label: "Storage Used", Unit: "bytes", Icon: "storage",
				SQL: "SELECT coalesce(sum(size_bytes), 0) FROM analytics.files WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "uploads_today", Label: "Uploads Today", Unit: "count", Icon: "upload",
				SQL: "SELECT count(*) FROM analytics.files WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "avg_file_size", Label: "Avg File Size", Unit: "bytes", Icon: "description",
				SQL: "SELECT coalesce(avg(size_bytes), 0) FROM analytics.files WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "upload_volume", Label: "Uploads",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.files WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "file_types", Label: "By Type", AllowedGroupBy: []string{"content_type"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.files WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_uploaders", Label: "Top Uploaders", MaxLimit: 50,
				SQL: "SELECT uploader, count(*) FROM analytics.files WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY uploader ORDER BY count(*) DESC LIMIT $5"},
		},
	}
}

func geolocationAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "geolocation",
		ViewPermission: "analytics:geolocation:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_areas", Label: "Total Areas", Unit: "count", Icon: "map",
				SQL: "SELECT count(*) FROM analytics.geo_areas WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "total_routes", Label: "Total Routes", Unit: "count", Icon: "route",
				SQL: "SELECT count(*) FROM analytics.geo_routes WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "geo_events", Label: "Geo Events", Unit: "count", Icon: "place",
				SQL: "SELECT count(*) FROM analytics.geo_events WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "active_trackers", Label: "Active Trackers", Unit: "count", Icon: "gps_fixed",
				SQL: "SELECT count(distinct device_id) FROM analytics.geo_events WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "geo_event_volume", Label: "Geo Events",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.geo_events WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "event_types", Label: "By Event Type", AllowedGroupBy: []string{"event_type"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.geo_events WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_areas", Label: "Most Active Areas", MaxLimit: 50,
				SQL: "SELECT area_name, count(*) FROM analytics.geo_events WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY area_name ORDER BY count(*) DESC LIMIT $5"},
		},
	}
}

func settingsAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "settings",
		ViewPermission: "analytics:settings:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_settings", Label: "Total Settings", Unit: "count", Icon: "settings",
				SQL: "SELECT count(*) FROM analytics.settings WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "recent_changes", Label: "Recent Changes", Unit: "count", Icon: "edit",
				SQL: "SELECT count(*) FROM analytics.setting_changes WHERE changed_at >= $1 AND changed_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "modules_count", Label: "Modules", Unit: "count", Icon: "widgets",
				SQL: "SELECT count(distinct module) FROM analytics.settings WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "setting_changes", Label: "Configuration Changes",
				SQL: "SELECT date_trunc('{{granularity}}', changed_at) AS bucket, count(*) FROM analytics.setting_changes WHERE changed_at >= $1 AND changed_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "settings_by_module", Label: "By Module", AllowedGroupBy: []string{"module"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.settings WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
	}
}

func tenancyAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "tenancy",
		ViewPermission: "analytics:tenancy:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_tenants", Label: "Total Tenants", Unit: "count", Icon: "domain",
				SQL: "SELECT count(*) FROM analytics.tenants WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "total_partitions", Label: "Total Partitions", Unit: "count", Icon: "account_tree",
				SQL: "SELECT count(*) FROM analytics.partitions WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "active_users", Label: "Active Users", Unit: "count", Icon: "group",
				SQL: "SELECT count(distinct user_id) FROM analytics.access_logs WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "new_tenants", Label: "New Tenants", Unit: "count", Icon: "add_business",
				SQL: "SELECT count(*) FROM analytics.tenants WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "tenant_growth", Label: "Tenant Growth",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.tenants WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "tenants_by_plan", Label: "By Plan", AllowedGroupBy: []string{"plan"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.tenants WHERE created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_tenants", Label: "Largest Tenants", MaxLimit: 50,
				SQL: "SELECT tenant_name, user_count FROM analytics.tenant_stats WHERE period_end >= $1 AND period_end < $2 AND tenant_id = $3 AND partition_id = ANY($4) ORDER BY user_count DESC LIMIT $5"},
		},
	}
}

func auditAnalytics() ServiceAnalytics {
	return ServiceAnalytics{
		ServiceID:      "audit",
		ViewPermission: "analytics:audit:view",
		TenantScoped:   true,
		Metrics: []MetricDefinition{
			{Key: "total_entries", Label: "Audit Entries", Unit: "count", Icon: "history",
				SQL: "SELECT count(*) FROM analytics.audit_entries WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "unique_actors", Label: "Unique Actors", Unit: "count", Icon: "people",
				SQL: "SELECT count(distinct actor_id) FROM analytics.audit_entries WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "integrity_checks", Label: "Integrity Checks", Unit: "count", Icon: "verified",
				SQL: "SELECT count(*) FROM analytics.integrity_checks WHERE checked_at >= $1 AND checked_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
			{Key: "anomalies", Label: "Anomalies", Unit: "count", Icon: "warning",
				SQL: "SELECT count(*) FROM analytics.audit_anomalies WHERE detected_at >= $1 AND detected_at < $2 AND tenant_id = $3 AND partition_id = ANY($4)"},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "audit_volume", Label: "Audit Volume",
				SQL: "SELECT date_trunc('{{granularity}}', created_at) AS bucket, count(*) FROM analytics.audit_entries WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY bucket ORDER BY bucket"},
		},
		Distributions: []DistributionDefinition{
			{Key: "audit_actions", Label: "By Action", AllowedGroupBy: []string{"action"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.audit_entries WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
			{Key: "audit_services", Label: "By Service", AllowedGroupBy: []string{"service"},
				SQL: "SELECT {{group_by}}, count(*) FROM analytics.audit_entries WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY {{group_by}} ORDER BY count(*) DESC"},
		},
		TopN: []TopNDefinition{
			{Key: "top_actors", Label: "Most Active Actors", MaxLimit: 50,
				SQL: "SELECT actor_name, count(*) FROM analytics.audit_entries WHERE created_at >= $1 AND created_at < $2 AND tenant_id = $3 AND partition_id = ANY($4) GROUP BY actor_name ORDER BY count(*) DESC LIMIT $5"},
		},
	}
}
