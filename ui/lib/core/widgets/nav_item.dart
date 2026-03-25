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
  });

  final String label;
  final IconData icon;
  final String route;
  final List<NavItem> children;

  /// Whether this item is an expandable service group.
  final bool isServiceGroup;

  /// Service ID if this is a service group or sub-feature.
  final String? serviceId;

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
            )),
      ],
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

/// Items pinned to the bottom of the sidebar.
const List<NavItem> bottomNavItems = [
  NavItem(label: 'Settings', icon: Icons.settings_outlined, route: '/settings'),
  NavItem(label: 'Support', icon: Icons.help_outline, route: '/support'),
  NavItem(label: 'Logout', icon: Icons.logout, route: '/logout'),
];
