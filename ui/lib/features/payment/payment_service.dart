import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';
import 'pages/ledgers_page.dart';
import 'pages/payment_analytics_page.dart';
import 'pages/payments_page.dart';

const paymentServiceDef = ServiceDefinition(
  id: 'payment',
  label: 'Payment Service',
  icon: Icons.payment_outlined,
  description: 'Manage payments, ledgers, and transactions',
  subFeatures: [
    SubFeatureDefinition(
      id: 'payments',
      label: 'Payments',
      icon: Icons.credit_card_outlined,
      description: 'View and manage payments',
    ),
    SubFeatureDefinition(
      id: 'ledgers',
      label: 'Ledgers',
      icon: Icons.account_balance_outlined,
      description: 'Manage ledgers and accounts',
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
        'payments': (context, service, feature) =>
            PaymentsPage(service: service, feature: feature),
        'ledgers': (context, service, feature) =>
            LedgersPage(service: service, feature: feature),
      },
    ),
  );
}
