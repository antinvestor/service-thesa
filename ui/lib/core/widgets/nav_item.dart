import 'package:flutter/material.dart';

import '../services/service_definition.dart';
import '../services/service_registry.dart';

/// Represents a navigation destination in the sidebar.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.children = const [],
    this.isServiceGroup = false,
    this.serviceId,
    this.requiredPermissions = const {},
  });

  final String label;
  final IconData icon;
  final String route;
  final List<NavItem> children;

  /// Whether this item is an expandable service group.
  final bool isServiceGroup;

  /// Service ID if this is a service group or sub-feature.
  final String? serviceId;

  /// Proto-defined permission keys required to see this item.
  final Set<String> requiredPermissions;

  bool get hasChildren => children.isNotEmpty;

  /// Create a nav item from a [ServiceDefinition].
  /// The service becomes an expandable group with Analytics + sub-features.
  factory NavItem.fromService(ServiceDefinition service) {
    return NavItem(
      label: service.label,
      icon: service.icon,
      route: service.analyticsRoute,
      isServiceGroup: true,
      serviceId: service.id,
      requiredPermissions: service.requiredPermissions,
      children: [
        NavItem(
          label: 'Analytics',
          icon: Icons.insights_outlined,
          route: service.analyticsRoute,
          serviceId: service.id,
        ),
        ...service.subFeatures.map((f) => NavItem(
              label: f.label,
              icon: f.icon,
              route: service.featureRoute(f.id),
              serviceId: service.id,
              requiredPermissions: f.requiredPermissions,
            )),
      ],
    );
  }

  /// Filter this item and its children by proto-defined permissions.
  /// Returns null if the user lacks the required permissions.
  NavItem? filterByPermissions(Set<String> userPermissions) {
    if (requiredPermissions.isNotEmpty &&
        userPermissions.intersection(requiredPermissions).isEmpty) {
      return null;
    }

    final filteredChildren = children
        .map((c) => c.filterByPermissions(userPermissions))
        .whereType<NavItem>()
        .toList();

    if (!isServiceGroup &&
        route.isEmpty &&
        filteredChildren.isEmpty &&
        children.isNotEmpty) {
      return null;
    }

    return NavItem(
      label: label,
      icon: icon,
      route: route,
      isServiceGroup: isServiceGroup,
      serviceId: serviceId,
      requiredPermissions: requiredPermissions,
      children: filteredChildren,
    );
  }
}

/// Standalone top-level items (not services).
const List<NavItem> standaloneNavItems = [
  NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/'),
];

/// Build the full nav item list: standalone items + registered services.
List<NavItem> buildMainNavItems(ServiceRegistry registry) {
  return [
    ...standaloneNavItems,
    ...registry.services.map((s) => NavItem.fromService(s)),
  ];
}

/// Build nav items filtered by the user's resolved permissions.
/// Services and sub-features without the required permissions are removed.
List<NavItem> buildFilteredNavItems(
    ServiceRegistry registry, Set<String> userPermissions) {
  final items = buildMainNavItems(registry);
  if (userPermissions.isEmpty) return items; // No permissions resolved yet
  return items
      .map((item) => item.filterByPermissions(userPermissions))
      .whereType<NavItem>()
      .toList();
}

/// Items pinned to the bottom of the sidebar.
const List<NavItem> bottomNavItems = [
  NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  NavItem(label: 'Support', icon: Icons.help_outline, route: '/support'),
  NavItem(label: 'Logout', icon: Icons.logout, route: '/logout'),
];
