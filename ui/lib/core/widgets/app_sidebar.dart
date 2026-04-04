import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/service_registry.dart';
import '../theme/app_colors.dart';
import 'nav_item.dart';

/// Notifier tracking which service group is currently expanded in the sidebar.
class ExpandedServiceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? serviceId) => state = serviceId;
}

final expandedServiceProvider =
    NotifierProvider<ExpandedServiceNotifier, String?>(
  ExpandedServiceNotifier.new,
);

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    this.collapsed = false,
    this.onToggleCollapse,
  });

  final String currentRoute;
  final ValueChanged<String> onNavigate;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(serviceRegistryProvider);
    final navItems = buildMainNavItems(registry);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? 72 : 272,
      decoration: const BoxDecoration(
        color: AppColors.sidebarBg,
      ),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                // Main nav items (standalone + service groups)
                for (final item in navItems)
                  if (item.isServiceGroup)
                    _ServiceGroupTile(
                      item: item,
                      currentRoute: currentRoute,
                      collapsed: collapsed,
                      onNavigate: onNavigate,
                    )
                  else
                    _NavTile(
                      item: item,
                      isActive: _isActive(item.route),
                      collapsed: collapsed,
                      onTap: () => onNavigate(item.route),
                    ),
              ],
            ),
          ),
          const Divider(color: AppColors.sidebarActiveBg, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: bottomNavItems
                  .map((item) => _NavTile(
                        item: item,
                        isActive: _isActive(item.route),
                        collapsed: collapsed,
                        onTap: () => onNavigate(item.route),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 12 : 20,
        vertical: 24,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: collapsed ? onToggleCollapse : null,
            child: Tooltip(
              message: collapsed ? 'Expand sidebar' : '',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.diamond_outlined,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
          if (collapsed) ...[
            // When collapsed, clicking logo expands the sidebar
            if (onToggleCollapse != null)
              Expanded(
                child: GestureDetector(
                  onTap: onToggleCollapse,
                  child: const SizedBox.shrink(),
                ),
              ),
          ] else ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Antinvestor',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    'Admin Console',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.sidebarText.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),
            if (onToggleCollapse != null)
              IconButton(
                onPressed: onToggleCollapse,
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.sidebarText, size: 20),
                splashRadius: 16,
              ),
          ],
        ],
      ),
    );
  }

  bool _isActive(String route) {
    if (route == '/') return currentRoute == '/';
    return currentRoute.startsWith(route);
  }
}

// ─── Service Group Tile ──────────────────────────────────────────────────────

/// An expandable sidebar group for a registered service.
/// Clicking the group header expands/collapses and navigates to analytics.
/// Sub-items navigate to the feature's entity list page.
class _ServiceGroupTile extends ConsumerStatefulWidget {
  const _ServiceGroupTile({
    required this.item,
    required this.currentRoute,
    required this.collapsed,
    required this.onNavigate,
  });

  final NavItem item;
  final String currentRoute;
  final bool collapsed;
  final ValueChanged<String> onNavigate;

  @override
  ConsumerState<_ServiceGroupTile> createState() => _ServiceGroupTileState();
}

class _ServiceGroupTileState extends ConsumerState<_ServiceGroupTile>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  bool get _isServiceActive =>
      widget.currentRoute.startsWith(widget.item.route);

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expandedId = ref.watch(expandedServiceProvider);
    final isExpanded = expandedId == widget.item.serviceId;

    // Sync animation with state.
    if (isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }

    // Auto-expand when navigating to this service.
    if (_isServiceActive && !isExpanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(expandedServiceProvider.notifier).set(
            widget.item.serviceId);
      });
    }

    if (widget.collapsed) {
      return _buildCollapsedTile(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupHeader(context, isExpanded),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              children: widget.item.children.map((child) {
                final isChildActive = _isChildActive(child.route);
                return _NavTile(
                  item: child,
                  isActive: isChildActive,
                  collapsed: false,
                  onTap: () => widget.onNavigate(child.route),
                  compact: true,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedTile(BuildContext context) {
    final bg = _isServiceActive
        ? AppColors.sidebarActiveBg
        : _hovered
            ? AppColors.sidebarHoverBg.withValues(alpha: 0.5)
            : Colors.transparent;
    final fg =
        _isServiceActive ? AppColors.sidebarActiveText : AppColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              // Show a popup menu with children when collapsed
              final renderBox = context.findRenderObject() as RenderBox;
              final offset = renderBox.localToGlobal(Offset.zero);
              final items = <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: widget.item.route,
                  child: Text(widget.item.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const PopupMenuDivider(height: 1),
                ...widget.item.children.map((child) => PopupMenuItem<String>(
                      value: child.route,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(child.icon, size: 16,
                              color: _isChildActive(child.route)
                                  ? AppColors.tertiary
                                  : null),
                          const SizedBox(width: 8),
                          Text(child.label,
                              style: TextStyle(
                                fontWeight: _isChildActive(child.route)
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              )),
                        ],
                      ),
                    )),
              ];
              showMenu<String>(
                context: context,
                position: RelativeRect.fromLTRB(
                    offset.dx + 72, offset.dy, 0, 0),
                items: items,
              ).then((value) {
                if (value != null) widget.onNavigate(value);
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Tooltip(
                  message: widget.item.label,
                  child: Icon(widget.item.icon, color: fg, size: 22),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupHeader(BuildContext context, bool isExpanded) {
    final bg = _isServiceActive
        ? AppColors.sidebarActiveBg
        : _hovered
            ? AppColors.sidebarHoverBg.withValues(alpha: 0.5)
            : Colors.transparent;
    final fg =
        _isServiceActive ? AppColors.sidebarActiveText : AppColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              // Toggle expansion.
              final current = ref.read(expandedServiceProvider);
              ref.read(expandedServiceProvider.notifier).set(
                  current == widget.item.serviceId
                      ? null
                      : widget.item.serviceId);
              // Navigate to analytics on expand.
              if (current != widget.item.serviceId) {
                widget.onNavigate(widget.item.route);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(widget.item.icon, color: fg, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: fg,
                            fontWeight: _isServiceActive
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.chevron_right,
                        color: fg.withValues(alpha: 0.5), size: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isChildActive(String route) {
    if (route == widget.item.route) {
      // Analytics sub-item: active only if exactly on service root.
      return widget.currentRoute == route;
    }
    return widget.currentRoute.startsWith(route);
  }
}

// ─── Standard Nav Tile ───────────────────────────────────────────────────────

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.isActive,
    required this.collapsed,
    required this.onTap,
    this.compact = false,
  });

  final NavItem item;
  final bool isActive;
  final bool collapsed;
  final VoidCallback onTap;
  final bool compact;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isActive
        ? AppColors.sidebarActiveBg
        : _hovered
            ? AppColors.sidebarHoverBg.withValues(alpha: 0.5)
            : Colors.transparent;

    final fg =
        widget.isActive ? AppColors.sidebarActiveText : AppColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.collapsed ? 0 : 12,
                vertical: widget.compact ? 8 : 10,
              ),
              child: widget.collapsed
                  ? Center(
                      child: Tooltip(
                        message: widget.item.label,
                        child:
                            Icon(widget.item.icon, color: fg, size: 22),
                      ),
                    )
                  : Row(
                      children: [
                        Icon(widget.item.icon, color: fg,
                            size: widget.compact ? 18 : 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.item.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: fg,
                                  fontSize: widget.compact ? 13 : null,
                                  fontWeight: widget.isActive
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
