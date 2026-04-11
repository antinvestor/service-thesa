import 'package:antinvestor_ui_billing/antinvestor_ui_billing.dart';
import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Billing service definition for the admin sidebar.
const billingServiceDef = ServiceDefinition(
  id: 'billing',
  label: 'Billing Service',
  icon: Icons.receipt_long_outlined,
  activeIcon: Icons.receipt_long,
  description:
      'Manage catalogs, subscriptions, invoices, usage metering, and credits',
  subFeatures: [
    SubFeatureDefinition(
      id: 'catalogs',
      label: 'Catalogs',
      icon: Icons.menu_book_outlined,
      description: 'Plan catalogs with pricing components and tiers',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'subscriptions',
      label: 'Subscriptions',
      icon: Icons.autorenew_outlined,
      description: 'Customer subscription lifecycle',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'invoices',
      label: 'Invoices',
      icon: Icons.description_outlined,
      description: 'Invoice management and payment recording',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'usage',
      label: 'Usage Events',
      icon: Icons.bar_chart_outlined,
      description: 'Usage event ingestion and history',
    ),
    SubFeatureDefinition(
      id: 'runs',
      label: 'Billing Runs',
      icon: Icons.play_circle_outline,
      description: 'Execute and monitor billing runs',
    ),
    SubFeatureDefinition(
      id: 'credits',
      label: 'Credits',
      icon: Icons.account_balance_wallet_outlined,
      description: 'Grant and manage prepaid credits',
    ),
    SubFeatureDefinition(
      id: 'discounts',
      label: 'Discounts',
      icon: Icons.local_offer_outlined,
      description: 'Create and manage discount rules',
    ),
  ],
);

/// Register the Billing Service with the global service registry.
void registerBillingService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: billingServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
            service: 'billing',
            title: 'Billing Analytics',
            metrics: [
              'active_subscriptions',
              'mrr',
              'outstanding_invoices',
              'churn_rate',
            ],
            charts: [
              ChartConfig.timeSeries('revenue', label: 'Revenue'),
              ChartConfig.distribution('subscription_plans',
                  groupBy: 'plan_name', label: 'By Plan'),
            ],
            tables: [
              TableConfig.topN('top_customers',
                  label: 'Top Customers by Revenue', limit: 10),
            ],
          ),
      featureBuilders: {
        'catalogs': (context, service, feature) => const CatalogListScreen(),
        'subscriptions': (context, service, feature) =>
            const SubscriptionListScreen(),
        'invoices': (context, service, feature) => const InvoiceListScreen(),
        'usage': (context, service, feature) => const UsageEventsScreen(),
        'runs': (context, service, feature) => const BillingRunScreen(),
        'credits': (context, service, feature) => const CreditScreen(),
        'discounts': (context, service, feature) => const DiscountListScreen(),
      },
      detailBuilders: {
        'catalogs': (context, service, feature, entityId) =>
            CatalogDetailScreen(catalogId: entityId),
        'subscriptions': (context, service, feature, entityId) =>
            SubscriptionDetailScreen(subscriptionId: entityId),
        'invoices': (context, service, feature, entityId) =>
            InvoiceDetailScreen(invoiceId: entityId),
      },
    ),
  );
}
