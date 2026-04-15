package analytics

// RegisterDefaultServices registers all standard Antinvestor service analytics
// definitions. Each service uses structured MetricQuery objects that reference
// OTel metric names and attributes. The MetricsBackend implementation
// translates these into the backend's native query language.
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
				Query: MetricQuery{Metric: "payment_transactions_total", Aggregation: AggSum}},
			{Key: "total_volume", Label: "Total Volume", Unit: "currency", Icon: "attach_money",
				Query: MetricQuery{Metric: "payment_amount_total", Aggregation: AggSum}},
			{Key: "success_rate", Label: "Success Rate", Unit: "percent", Icon: "check_circle",
				Query: MetricQuery{
					Numerator:   &MetricQuery{Metric: "payment_transactions_total", Aggregation: AggSum, Filters: map[string]string{"status": "success"}},
					Denominator: &MetricQuery{Metric: "payment_transactions_total", Aggregation: AggSum},
				}},
			{Key: "avg_processing_time", Label: "Avg Processing", Unit: "duration", Icon: "timer",
				Query: MetricQuery{
					DurationMetric:      "payment_processing_duration_seconds_sum",
					DurationCountMetric: "payment_processing_duration_seconds_count",
					Multiplier:          1000, // seconds → milliseconds
				}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "payment_volume", Label: "Payment Volume",
				Query: MetricQuery{Metric: "payment_transactions_total", Aggregation: AggSum}},
			{Key: "payment_amount", Label: "Payment Amount",
				Query: MetricQuery{Metric: "payment_amount_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "payment_routes", Label: "By Route", AllowedGroupBy: []string{"route"},
				Query: MetricQuery{Metric: "payment_transactions_total", Aggregation: AggSum}},
			{Key: "payment_status", Label: "By Status", AllowedGroupBy: []string{"status"},
				Query: MetricQuery{Metric: "payment_transactions_total", Aggregation: AggSum}},
		},
		TopN: []TopNDefinition{
			{Key: "top_recipients", Label: "Top Recipients", MaxLimit: 50,
				Query: MetricQuery{Metric: "payment_amount_total", Aggregation: AggSum, GroupBy: "recipient"}},
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
				Query: MetricQuery{Metric: "profile_created_total", Aggregation: AggSum}},
			{Key: "active_profiles", Label: "Active Profiles", Unit: "count", Icon: "person",
				Query: MetricQuery{Metric: "profile_active_total", Aggregation: AggGauge}},
			{Key: "new_registrations", Label: "New Registrations", Unit: "count", Icon: "person_add",
				Query: MetricQuery{Metric: "profile_registrations_total", Aggregation: AggSum}},
			{Key: "verification_rate", Label: "Verification Rate", Unit: "percent", Icon: "verified",
				Query: MetricQuery{
					Numerator:   &MetricQuery{Metric: "profile_verified_total", Aggregation: AggGauge},
					Denominator: &MetricQuery{Metric: "profile_created_total", Aggregation: AggGauge},
				}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "registrations", Label: "Registrations",
				Query: MetricQuery{Metric: "profile_registrations_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "profile_types", Label: "By Type", AllowedGroupBy: []string{"profile_type"},
				Query: MetricQuery{Metric: "profile_created_total", Aggregation: AggSum}},
		},
		TopN: []TopNDefinition{
			{Key: "top_active_profiles", Label: "Most Active Profiles", MaxLimit: 50,
				Query: MetricQuery{Metric: "profile_activity_total", Aggregation: AggSum, GroupBy: "display_name"}},
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
				Query: MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum}},
			{Key: "delivery_rate", Label: "Delivery Rate", Unit: "percent", Icon: "mark_email_read",
				Query: MetricQuery{
					Numerator:   &MetricQuery{Metric: "notification_delivered_total", Aggregation: AggSum},
					Denominator: &MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum},
				}},
			{Key: "open_rate", Label: "Open Rate", Unit: "percent", Icon: "visibility",
				Query: MetricQuery{
					Numerator:   &MetricQuery{Metric: "notification_opened_total", Aggregation: AggSum},
					Denominator: &MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum},
				}},
			{Key: "failed_count", Label: "Failed", Unit: "count", Icon: "error",
				Query: MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum, Filters: map[string]string{"status": "failed"}}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "notifications_sent", Label: "Notifications Sent",
				Query: MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "notification_channels", Label: "By Channel", AllowedGroupBy: []string{"channel"},
				Query: MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum}},
			{Key: "notification_status", Label: "By Status", AllowedGroupBy: []string{"status"},
				Query: MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum}},
		},
		TopN: []TopNDefinition{
			{Key: "top_templates", Label: "Top Templates", MaxLimit: 50,
				Query: MetricQuery{Metric: "notification_sent_total", Aggregation: AggSum, GroupBy: "template_name"}},
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
				Query: MetricQuery{Metric: "billing_subscriptions_active", Aggregation: AggGauge}},
			{Key: "mrr", Label: "Monthly Revenue", Unit: "currency", Icon: "trending_up",
				Query: MetricQuery{Metric: "billing_monthly_recurring_revenue", Aggregation: AggGauge}},
			{Key: "outstanding_invoices", Label: "Outstanding", Unit: "currency", Icon: "receipt_long",
				Query: MetricQuery{Metric: "billing_invoices_outstanding_amount", Aggregation: AggGauge}},
			{Key: "churn_rate", Label: "Churn Rate", Unit: "percent", Icon: "trending_down",
				Query: MetricQuery{
					Numerator:   &MetricQuery{Metric: "billing_subscriptions_cancelled_total", Aggregation: AggSum},
					Denominator: &MetricQuery{Metric: "billing_subscriptions_active", Aggregation: AggGauge},
				}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "revenue", Label: "Revenue",
				Query: MetricQuery{Metric: "billing_invoice_paid_amount_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "subscription_plans", Label: "By Plan", AllowedGroupBy: []string{"plan_name"},
				Query: MetricQuery{Metric: "billing_subscriptions_active", Aggregation: AggGauge}},
		},
		TopN: []TopNDefinition{
			{Key: "top_customers", Label: "Top Customers by Revenue", MaxLimit: 50,
				Query: MetricQuery{Metric: "billing_invoice_paid_amount_total", Aggregation: AggSum, GroupBy: "customer_name"}},
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
				Query: MetricQuery{Metric: "files_uploaded_total", Aggregation: AggSum}},
			{Key: "total_storage", Label: "Storage Used", Unit: "bytes", Icon: "storage",
				Query: MetricQuery{Metric: "files_storage_bytes", Aggregation: AggGauge}},
			{Key: "uploads_today", Label: "Uploads Today", Unit: "count", Icon: "upload",
				Query: MetricQuery{Metric: "files_uploaded_total", Aggregation: AggSum}},
			{Key: "avg_file_size", Label: "Avg File Size", Unit: "bytes", Icon: "description",
				Query: MetricQuery{
					DurationMetric:      "files_upload_size_bytes_sum",
					DurationCountMetric: "files_upload_size_bytes_count",
					Multiplier:          1, // bytes, no conversion
				}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "upload_volume", Label: "Uploads",
				Query: MetricQuery{Metric: "files_uploaded_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "file_types", Label: "By Type", AllowedGroupBy: []string{"content_type"},
				Query: MetricQuery{Metric: "files_uploaded_total", Aggregation: AggSum}},
		},
		TopN: []TopNDefinition{
			{Key: "top_uploaders", Label: "Top Uploaders", MaxLimit: 50,
				Query: MetricQuery{Metric: "files_uploaded_total", Aggregation: AggSum, GroupBy: "uploader"}},
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
				Query: MetricQuery{Metric: "geolocation_areas_total", Aggregation: AggGauge}},
			{Key: "total_routes", Label: "Total Routes", Unit: "count", Icon: "route",
				Query: MetricQuery{Metric: "geolocation_routes_total", Aggregation: AggGauge}},
			{Key: "geo_events", Label: "Geo Events", Unit: "count", Icon: "place",
				Query: MetricQuery{Metric: "geolocation_events_total", Aggregation: AggSum}},
			{Key: "active_trackers", Label: "Active Trackers", Unit: "count", Icon: "gps_fixed",
				Query: MetricQuery{Metric: "geolocation_events_total", Aggregation: AggCountDistinct, GroupBy: "device_id"}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "geo_event_volume", Label: "Geo Events",
				Query: MetricQuery{Metric: "geolocation_events_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "event_types", Label: "By Event Type", AllowedGroupBy: []string{"event_type"},
				Query: MetricQuery{Metric: "geolocation_events_total", Aggregation: AggSum}},
		},
		TopN: []TopNDefinition{
			{Key: "top_areas", Label: "Most Active Areas", MaxLimit: 50,
				Query: MetricQuery{Metric: "geolocation_events_total", Aggregation: AggSum, GroupBy: "area_name"}},
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
				Query: MetricQuery{Metric: "settings_configured_total", Aggregation: AggGauge}},
			{Key: "recent_changes", Label: "Recent Changes", Unit: "count", Icon: "edit",
				Query: MetricQuery{Metric: "settings_changes_total", Aggregation: AggSum}},
			{Key: "modules_count", Label: "Modules", Unit: "count", Icon: "widgets",
				Query: MetricQuery{Metric: "settings_configured_total", Aggregation: AggCountDistinct, GroupBy: "module"}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "setting_changes", Label: "Configuration Changes",
				Query: MetricQuery{Metric: "settings_changes_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "settings_by_module", Label: "By Module", AllowedGroupBy: []string{"module"},
				Query: MetricQuery{Metric: "settings_configured_total", Aggregation: AggGauge}},
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
				Query: MetricQuery{Metric: "tenancy_tenants_total", Aggregation: AggGauge}},
			{Key: "total_partitions", Label: "Total Partitions", Unit: "count", Icon: "account_tree",
				Query: MetricQuery{Metric: "tenancy_partitions_total", Aggregation: AggGauge}},
			{Key: "active_users", Label: "Active Users", Unit: "count", Icon: "group",
				Query: MetricQuery{Metric: "tenancy_access_total", Aggregation: AggCountDistinct, GroupBy: "user_id"}},
			{Key: "new_tenants", Label: "New Tenants", Unit: "count", Icon: "add_business",
				Query: MetricQuery{Metric: "tenancy_tenants_created_total", Aggregation: AggSum}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "tenant_growth", Label: "Tenant Growth",
				Query: MetricQuery{Metric: "tenancy_tenants_created_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "tenants_by_plan", Label: "By Plan", AllowedGroupBy: []string{"plan"},
				Query: MetricQuery{Metric: "tenancy_tenants_total", Aggregation: AggGauge}},
		},
		TopN: []TopNDefinition{
			{Key: "top_tenants", Label: "Largest Tenants", MaxLimit: 50,
				Query: MetricQuery{Metric: "tenancy_tenant_users_total", Aggregation: AggGauge, GroupBy: "tenant_name"}},
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
				Query: MetricQuery{Metric: "audit_entries_total", Aggregation: AggSum}},
			{Key: "unique_actors", Label: "Unique Actors", Unit: "count", Icon: "people",
				Query: MetricQuery{Metric: "audit_entries_total", Aggregation: AggCountDistinct, GroupBy: "actor_id"}},
			{Key: "integrity_checks", Label: "Integrity Checks", Unit: "count", Icon: "verified",
				Query: MetricQuery{Metric: "audit_integrity_checks_total", Aggregation: AggSum}},
			{Key: "anomalies", Label: "Anomalies", Unit: "count", Icon: "warning",
				Query: MetricQuery{Metric: "audit_anomalies_detected_total", Aggregation: AggSum}},
		},
		TimeSeries: []TimeSeriesDefinition{
			{Key: "audit_volume", Label: "Audit Volume",
				Query: MetricQuery{Metric: "audit_entries_total", Aggregation: AggSum}},
		},
		Distributions: []DistributionDefinition{
			{Key: "audit_actions", Label: "By Action", AllowedGroupBy: []string{"action"},
				Query: MetricQuery{Metric: "audit_entries_total", Aggregation: AggSum}},
			{Key: "audit_services", Label: "By Service", AllowedGroupBy: []string{"service"},
				Query: MetricQuery{Metric: "audit_entries_total", Aggregation: AggSum}},
		},
		TopN: []TopNDefinition{
			{Key: "top_actors", Label: "Most Active Actors", MaxLimit: 50,
				Query: MetricQuery{Metric: "audit_entries_total", Aggregation: AggSum, GroupBy: "actor_name"}},
		},
	}
}
