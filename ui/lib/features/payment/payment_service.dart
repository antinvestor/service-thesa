import 'package:antinvestor_ui_ledger/antinvestor_ui_ledger.dart' as ledger_lib;
import 'package:antinvestor_ui_payment/antinvestor_ui_payment.dart'
    as payment_lib;
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/ledger_detail_page.dart';
import 'pages/ledgers_page.dart';
import 'pages/payment_analytics_page.dart';
import 'pages/payments_page.dart';

/// Payment Service definition with enhanced sub-features from UI libraries.
const paymentServiceDef = ServiceDefinition(
  id: 'payment',
  label: 'Payment Service',
  icon: Icons.payment_outlined,
  description: 'Manage payments, ledgers, transactions, and reconciliation',
  subFeatures: [
    SubFeatureDefinition(
      id: 'payments',
      label: 'Payments',
      icon: Icons.credit_card_outlined,
      description: 'View and manage payments',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'ledgers',
      label: 'Ledgers',
      icon: Icons.account_balance_outlined,
      description: 'Manage ledgers, accounts, and transactions',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'transactions',
      label: 'Transactions',
      icon: Icons.receipt_outlined,
      description: 'View and manage ledger transactions',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'accounts',
      label: 'Accounts',
      icon: Icons.account_balance_wallet_outlined,
      description: 'View ledger accounts and balances',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'links',
      label: 'Payment Links',
      icon: Icons.link_outlined,
      description: 'Create and manage payment links',
    ),
    SubFeatureDefinition(
      id: 'send',
      label: 'Send Payment',
      icon: Icons.send_outlined,
      description: 'Send a new payment',
    ),
  ],
);

void registerPaymentService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: paymentServiceDef,
      analyticsBuilder: (context, service) =>
          PaymentAnalyticsPage(service: service),
      featureBuilders: {
        // Thesa's own admin pages
        'payments': (context, service, feature) =>
            PaymentsPage(service: service, feature: feature),
        'ledgers': (context, service, feature) =>
            LedgersPage(service: service, feature: feature),
        // Screens from UI libraries
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
            LedgerDetailPage(ledgerId: entityId),
        'transactions': (context, service, feature, entityId) =>
            ledger_lib.TransactionDetailScreen(transactionId: entityId),
        'accounts': (context, service, feature, entityId) =>
            ledger_lib.AccountDetailScreen(accountId: entityId),
      },
    ),
  );
}
