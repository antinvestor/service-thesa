import 'package:antinvestor_ui_geolocation/antinvestor_ui_geolocation.dart';
import 'package:flutter/material.dart';

import '../../core/services/service_definition.dart';
import '../../core/services/service_registry.dart';

/// Geolocation service definition for the admin sidebar.
const geolocationServiceDef = ServiceDefinition(
  id: 'geolocation',
  label: 'Geolocation',
  icon: Icons.map_outlined,
  activeIcon: Icons.map,
  description: 'Manage geographic areas, routes, and location tracking',
  subFeatures: [
    SubFeatureDefinition(
      id: 'areas',
      label: 'Areas',
      icon: Icons.square_foot_outlined,
      description: 'Define and manage geographic areas and zones',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'routes',
      label: 'Routes',
      icon: Icons.route_outlined,
      description: 'Create and manage routes with waypoints',
      hasDetailPage: true,
    ),
    SubFeatureDefinition(
      id: 'events',
      label: 'Events',
      icon: Icons.place_outlined,
      description: 'View geo-fence enter/exit/dwell events',
    ),
  ],
);

/// Register the Geolocation Service with the global service registry.
void registerGeolocationService() {
  ServiceRegistry.instance.register(
    ServiceRegistration(
      definition: geolocationServiceDef,
      analyticsBuilder: (context, service) => const AreaListScreen(),
      featureBuilders: {
        'areas': (context, service, feature) => const AreaListScreen(),
        'routes': (context, service, feature) => const RouteListScreen(),
        'events': (context, service, feature) => const GeoEventsScreen(),
      },
      detailBuilders: {
        'areas': (context, service, feature, entityId) =>
            AreaDetailScreen(areaId: entityId),
        'routes': (context, service, feature, entityId) =>
            RouteDetailScreen(routeId: entityId),
      },
    ),
  );
}
