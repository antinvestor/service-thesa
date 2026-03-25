import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_header.dart';
import 'app_sidebar.dart';
import 'responsive_layout.dart';

/// Provider for sidebar collapsed state.
final sidebarCollapsedProvider = NotifierProvider<SidebarCollapsedNotifier, bool>(
  SidebarCollapsedNotifier.new,
);

class SidebarCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

/// The main responsive shell: sidebar + header + content area.
/// - Desktop: persistent sidebar + header + content
/// - Tablet: collapsed sidebar (icons only) + header + content
/// - Mobile: drawer sidebar + header + content
class ResponsiveScaffold extends ConsumerStatefulWidget {
  const ResponsiveScaffold({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.child,
  });

  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final Widget child;

  @override
  ConsumerState<ResponsiveScaffold> createState() => _ResponsiveScaffoldState();
}

class _ResponsiveScaffoldState extends ConsumerState<ResponsiveScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final screenSize = screenSizeOf(context);
    final collapsed = ref.watch(sidebarCollapsedProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: screenSize == ScreenSize.mobile
          ? Drawer(
              child: AppSidebar(
                currentRoute: widget.currentRoute,
                onNavigate: (route) {
                  Navigator.of(context).pop();
                  widget.onNavigate(route);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          // Sidebar: hidden on mobile, collapsed on tablet, full on desktop
          if (screenSize != ScreenSize.mobile)
            AppSidebar(
              currentRoute: widget.currentRoute,
              onNavigate: widget.onNavigate,
              collapsed: screenSize == ScreenSize.tablet ? true : collapsed,
              onToggleCollapse: screenSize == ScreenSize.desktop
                  ? () => ref.read(sidebarCollapsedProvider.notifier).toggle()
                  : null,
            ),
          // Main content area
          Expanded(
            child: Column(
              children: [
                AppHeader(
                  showMenuButton: screenSize == ScreenSize.mobile,
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
