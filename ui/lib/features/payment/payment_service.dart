import 'package:antinvestor_ui_core/analytics/analytics_dashboard.dart';
import 'package:antinvestor_ui_ledger/antinvestor_ui_ledger.dart' as ledger_lib;
import 'package:antinvestor_ui_payment/antinvestor_ui_payment.dart'
    as payment_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Payment Service definition with enhanced sub-features from UI libraries.
const paymentServiceDef = ServiceDefinition(
  id: 'payment',
  label: 'Payment Service',
  icon: Icons.payment_outlined,
  description: 'Manage payments, ledgers, transactions, and reconciliation',
  requiredPermissions: {'payment_search'},
  subFeatures: [
    SubFeatureDefinition(
      id: 'payments',
      label: 'Payments',
      icon: Icons.credit_card_outlined,
      description: 'View and manage payments',
      hasDetailPage: true,
      requiredPermissions: {'payment_search'},
    ),
    SubFeatureDefinition(
      id: 'ledgers',
      label: 'Ledgers',
      icon: Icons.account_balance_outlined,
      description: 'Manage ledgers, accounts, and transactions',
      hasDetailPage: true,
      requiredPermissions: {'ledger_view'},
    ),
    SubFeatureDefinition(
      id: 'transactions',
      label: 'Transactions',
      icon: Icons.receipt_outlined,
      description: 'View and manage ledger transactions',
      hasDetailPage: true,
      requiredPermissions: {'transaction_view'},
    ),
    SubFeatureDefinition(
      id: 'accounts',
      label: 'Accounts',
      icon: Icons.account_balance_wallet_outlined,
      description: 'View ledger accounts and balances',
      hasDetailPage: true,
      requiredPermissions: {'account_view'},
    ),
    SubFeatureDefinition(
      id: 'links',
      label: 'Payment Links',
      icon: Icons.link_outlined,
      description: 'Create and manage payment links',
      requiredPermissions: {'payment_link_create'},
    ),
    SubFeatureDefinition(
      id: 'send',
      label: 'Send Payment',
      icon: Icons.send_outlined,
      description: 'Send a new payment',
      requiredPermissions: {'payment_send'},
    ),
  ],
);

void registerPaymentService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: paymentServiceDef,
      analyticsBuilder: (context, service) => const AnalyticsDashboard(
            service: 'payment',
            title: 'Payment Analytics',
            metrics: [
              'total_payments',
              'total_volume',
              'success_rate',
              'avg_processing_time',
            ],
            charts: [
              ChartConfig.timeSeries('payment_volume',
                  label: 'Payment Volume'),
              ChartConfig.distribution('payment_routes',
                  groupBy: 'route', label: 'By Route'),
              ChartConfig.timeSeries('payment_amount',
                  label: 'Payment Amount'),
              ChartConfig.distribution('payment_status',
                  groupBy: 'status', label: 'By Status'),
            ],
            tables: [
              TableConfig.topN('top_recipients',
                  label: 'Top Recipients', limit: 10),
            ],
          ),
      featureBuilders: {
        'payments': (context, service, feature) =>
            const payment_lib.PaymentSearchScreen(),
        'ledgers': (context, service, feature) =>
            const ledger_lib.LedgerListScreen(),
        'transactions': (context, service, feature) =>
            const ledger_lib.TransactionListScreen(),
        'accounts': (context, service, feature) =>
            const ledger_lib.AccountListScreen(),
        'links': (context, service, feature) =>
            const payment_lib.PaymentLinksScreen(),
        'send': (context, service, feature) =>
            const payment_lib.PaymentSendScreen(),
      },
      detailBuilders: {
        'payments': (context, service, feature, entityId) =>
            payment_lib.PaymentDetailScreen(paymentId: entityId),
        'ledgers': (context, service, feature, entityId) =>
            ledger_lib.LedgerDetailScreen(ledgerId: entityId),
        'transactions': (context, service, feature, entityId) =>
            ledger_lib.TransactionDetailScreen(transactionId: entityId),
        'accounts': (context, service, feature, entityId) =>
            ledger_lib.AccountDetailScreen(accountId: entityId),
      },
    ),
  );
}
