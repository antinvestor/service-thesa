import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'service_definition.dart';

/// Callback that builds the analytics page for a service.
typedef ServiceAnalyticsBuilder = Widget Function(
    BuildContext context, ServiceDefinition service);

/// Callback that builds the entity list page for a sub-feature.
typedef SubFeaturePageBuilder = Widget Function(
    BuildContext context, ServiceDefinition service, SubFeatureDefinition feature);

/// Callback that builds a detail page for a specific entity within a sub-feature.
typedef EntityDetailPageBuilder = Widget Function(
    BuildContext context, ServiceDefinition service,
    SubFeatureDefinition feature, String entityId);

/// Registration entry binding a service definition to its page builders.
class ServiceRegistration {
  const ServiceRegistration({
    required this.definition,
    required this.analyticsBuilder,
    required this.featureBuilders,
    this.detailBuilders = const {},
  });

  final ServiceDefinition definition;

  /// Builds the service analytics/dashboard page.
  final ServiceAnalyticsBuilder analyticsBuilder;

  /// Maps sub-feature IDs to their page builders.
  final Map<String, SubFeaturePageBuilder> featureBuilders;

  /// Maps sub-feature IDs to their entity detail page builders.
  final Map<String, EntityDetailPageBuilder> detailBuilders;
}

/// Central registry of all admin services.
///
/// Services register themselves here during app initialization.
/// The sidebar and router read from this registry to auto-generate
/// navigation and routes.
class ServiceRegistry {
  ServiceRegistry._();

  static final ServiceRegistry instance = ServiceRegistry._();

  final Map<String, ServiceRegistration> _services = {};

  /// Register a service with its page builders.
  void register(ServiceRegistration registration) {
    _services[registration.definition.id] = registration;
  }

  /// All registered service definitions, ordered by registration.
  List<ServiceDefinition> get services =>
      _services.values.map((r) => r.definition).toList();

  /// All registrations.
  List<ServiceRegistration> get registrations => _services.values.toList();

  /// Look up a registration by service ID.
  ServiceRegistration? getRegistration(String serviceId) =>
      _services[serviceId];

  /// Look up a service definition by ID.
  ServiceDefinition? getService(String serviceId) =>
      _services[serviceId]?.definition;

  /// Build the analytics page for a service.
  Widget buildAnalyticsPage(BuildContext context, String serviceId) {
    final reg = _services[serviceId];
    if (reg == null) {
      return Center(child: Text('Service "$serviceId" not found'));
    }
    return reg.analyticsBuilder(context, reg.definition);
  }

  /// Build the entity list page for a sub-feature.
  Widget buildFeaturePage(
      BuildContext context, String serviceId, String featureId) {
    final reg = _services[serviceId];
    if (reg == null) {
      return Center(child: Text('Service "$serviceId" not found'));
    }
    final feature = reg.definition.subFeatures
        .where((f) => f.id == featureId)
        .firstOrNull;
    if (feature == null) {
      return Center(child: Text('Feature "$featureId" not found'));
    }
    final builder = reg.featureBuilders[featureId];
    if (builder == null) {
      return Center(child: Text('No page builder for "$featureId"'));
    }
    return builder(context, reg.definition, feature);
  }

  /// Build the entity detail page for a specific entity within a sub-feature.
  Widget buildEntityDetailPage(
      BuildContext context, String serviceId, String featureId, String entityId) {
    final reg = _services[serviceId];
    if (reg == null) {
      return Center(child: Text('Service "$serviceId" not found'));
    }
    final feature = reg.definition.subFeatures
        .where((f) => f.id == featureId)
        .firstOrNull;
    if (feature == null) {
      return Center(child: Text('Feature "$featureId" not found'));
    }
    final builder = reg.detailBuilders[featureId];
    if (builder == null) {
      return Center(child: Text('No detail page for "$featureId"'));
    }
    return builder(context, reg.definition, feature, entityId);
  }

  /// Clear all registrations (useful for testing).
  void clear() => _services.clear();
}

/// Riverpod provider exposing the service registry.
final serviceRegistryProvider = Provider<ServiceRegistry>((ref) {
  return ServiceRegistry.instance;
});
