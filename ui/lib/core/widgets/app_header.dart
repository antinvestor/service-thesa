import 'package:antinvestor_auth_runtime/antinvestor_auth_runtime.dart';
import 'package:antinvestor_ui_notification/antinvestor_ui_notification.dart'
    show NotificationBadge;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/search_provider.dart';
import '../services/tenant_context.dart';
import '../theme/app_colors.dart';
import 'tenant_picker.dart';

/// Provider that loads the current user info from the ID token claims
/// exposed by the auth runtime. Returns `null` when the user is not
/// authenticated or no claims are available yet.
final userInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final runtime = ref.watch(authRuntimeProvider);
  if (!runtime.isAuthenticated) return null;
  final claims = await runtime.getClaims();
  if (claims.isEmpty) return null;
  return claims;
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
          // Global search bar — drives server-side search for the active page
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _GlobalSearchField(compact: isCompact),
            ),
          ),
          const SizedBox(width: 12),
          // Tenant context picker
          const Flexible(child: TenantPicker()),
          const SizedBox(width: 8),
          // Action icons — hide on very narrow screens
          if (!isCompact) ...[
            // Live notification badge from antinvestor_ui_notification
            Consumer(builder: (context, ref, _) {
              final profileId = ref.watch(jwtTenantContextProvider).whenOrNull(
                    data: (ctx) => ctx.profileId,
                  ) ?? '';
              return IconButton(
                onPressed: () => context.go('/services/notification/notifications'),
                tooltip: 'Notifications',
                icon: NotificationBadge(
                  recipientId: profileId,
                  child: Icon(Icons.notifications_outlined,
                      size: 22, color: AppColors.onSurfaceMuted),
                ),
              );
            }),
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

/// Search field wired to [globalSearchQueryProvider].
/// Debounces input to avoid excessive provider updates.
class _GlobalSearchField extends ConsumerStatefulWidget {
  const _GlobalSearchField({this.compact = false});

  final bool compact;

  @override
  ConsumerState<_GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<_GlobalSearchField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Sync initial value from provider (e.g. after route restore).
    final initial = ref.read(globalSearchQueryProvider);
    if (initial.isNotEmpty) _controller.text = initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for external clears (e.g. route changes).
    ref.listen<String>(globalSearchQueryProvider, (prev, next) {
      if (next.isEmpty && _controller.text.isNotEmpty) {
        _controller.clear();
      }
    });

    return TextField(
      controller: _controller,
      onChanged: (value) {
        ref.read(globalSearchQueryProvider.notifier).update(value.trim());
      },
      decoration: InputDecoration(
        hintText: widget.compact
            ? 'Search...'
            : 'Search by name, contact, or ID...',
        prefixIcon: const Icon(Icons.search,
            size: 20, color: AppColors.onSurfaceMuted),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _controller.clear();
                  ref.read(globalSearchQueryProvider.notifier).clear();
                },
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
