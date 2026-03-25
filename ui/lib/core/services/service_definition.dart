import 'package:flutter/material.dart';

/// Defines a sub-feature within a service (e.g., "Tenants" under Partition Service).
/// Each sub-feature maps to an entity list page with CRUD capabilities.
class SubFeatureDefinition {
  const SubFeatureDefinition({
    required this.id,
    required this.label,
    required this.icon,
    this.description = '',
  });

  /// Unique identifier used in routing (e.g., 'tenants' → /services/partition/tenants).
  final String id;

  /// Display label in sidebar and breadcrumbs.
  final String label;

  /// Icon shown in the sidebar sub-item.
  final IconData icon;

  /// Short description for tooltips.
  final String description;
}

/// Defines an admin service that appears in the sidebar with nested navigation.
///
/// Each service has:
/// - An analytics/dashboard page (default when clicking the service)
/// - One or more sub-features, each providing an entity list page
///
/// Services register themselves via [ServiceRegistry] and the framework
/// auto-generates sidebar nav items and routes.
class ServiceDefinition {
  const ServiceDefinition({
    required this.id,
    required this.label,
    required this.icon,
    required this.subFeatures,
    this.description = '',
    this.activeIcon,
  });

  /// Unique identifier used in routing (e.g., 'partition' → /services/partition).
  final String id;

  /// Display label in the sidebar.
  final String label;

  /// Icon shown in sidebar when collapsed or as the service group icon.
  final IconData icon;

  /// Optional distinct icon for active state.
  final IconData? activeIcon;

  /// Short description for tooltips.
  final String description;

  /// Sub-features (entity types) available under this service.
  /// The sidebar shows these as nested items when the service is expanded.
  final List<SubFeatureDefinition> subFeatures;

  /// Route prefix for this service.
  String get routePrefix => '/services/$id';

  /// Route for the service analytics/dashboard page.
  String get analyticsRoute => routePrefix;

  /// Route for a specific sub-feature's entity list.
  String featureRoute(String featureId) => '$routePrefix/$featureId';
}
