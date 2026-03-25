import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../theme/app_colors.dart';

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
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              onPressed: onMenuTap,
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
            ),
          if (showMenuButton) const SizedBox(width: 8),
          // Search bar
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search analytics, portfolios, or users...',
                  prefixIcon: const Icon(Icons.search,
                      size: 20, color: AppColors.onSurfaceMuted),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Action icons
          _HeaderIconButton(
              icon: Icons.notifications_outlined, tooltip: 'Notifications'),
          _HeaderIconButton(icon: Icons.history, tooltip: 'History'),
          _HeaderIconButton(icon: Icons.apps, tooltip: 'Apps'),
          const SizedBox(width: 12),
          // User avatar section
          _UserAvatar(ref: ref),
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
  const _UserAvatar({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final userInfo = ref.watch(userInfoProvider);

    final name = userInfo.whenOrNull(
          data: (info) =>
              info?['name'] as String? ??
              info?['preferred_username'] as String? ??
              'Admin',
        ) ??
        'Admin';

    final initials = name
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleSmall),
            Text('Admin Console',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(width: 10),
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
