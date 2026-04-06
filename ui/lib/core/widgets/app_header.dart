import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../theme/app_colors.dart';
import 'tenant_picker.dart';

/// Provider that loads the current user info from the JWT token.
final userInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.getUserInfo();
});

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  const AppHeader({
    super.key,
    this.onMenuTap,
    this.showMenuButton = false,
  });

  final VoidCallback? onMenuTap;
  final bool showMenuButton;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 800;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
            ),
            const SizedBox(width: 8),
          ],
          // Search bar — flexible, collapses first
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: TextField(
                decoration: InputDecoration(
                  hintText: isCompact ? 'Search...' : 'Search analytics, portfolios, or users...',
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.onSurfaceMuted),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Tenant context picker
          const Flexible(child: TenantPicker()),
          const SizedBox(width: 8),
          // Action icons — hide on very narrow screens
          if (!isCompact) ...[
            _HeaderIconButton(
                icon: Icons.notifications_outlined, tooltip: 'Notifications'),
            _HeaderIconButton(icon: Icons.history, tooltip: 'History'),
            _HeaderIconButton(icon: Icons.apps, tooltip: 'Apps'),
            const SizedBox(width: 8),
          ],
          // User avatar section
          Flexible(child: _UserAvatar(ref: ref, compact: isCompact)),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, size: 22, color: AppColors.onSurfaceMuted),
      tooltip: tooltip,
      splashRadius: 18,
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.ref, this.compact = false});

  final WidgetRef ref;
  final bool compact;

  static String _resolveName(Map<String, dynamic>? info) {
    if (info == null) return 'Admin';

    final name = info['name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name.trim();

    final given = info['given_name'] as String? ?? '';
    final family = info['family_name'] as String? ?? '';
    final fullName = '$given $family'.trim();
    if (fullName.isNotEmpty) return fullName;

    final preferred = info['preferred_username'] as String?;
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }

    final email = info['email'] as String?;
    if (email != null && email.trim().isNotEmpty) return email.trim();

    return 'Admin';
  }

  static String _resolveSubtitle(Map<String, dynamic>? info) {
    if (info == null) return 'Admin Console';

    final email = info['email'] as String?;
    if (email != null && email.trim().isNotEmpty) return email.trim();

    final preferred = info['preferred_username'] as String?;
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }

    return 'Admin Console';
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = ref.watch(userInfoProvider);

    final claims = userInfo.whenOrNull(data: (info) => info);
    final name = _resolveName(claims);
    final subtitle = _resolveSubtitle(claims);

    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(name,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
                Text(subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ],
            ),
          ),
        if (!compact) const SizedBox(width: 10),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.tertiary,
          child: Text(
            initials.isNotEmpty ? initials : 'A',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}
