import 'package:antinvestor_ui_core/antinvestor_ui_core.dart' show PageHeader;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';

/// Static support / help page reached from the sidebar Support item.
///
/// Until a ticketing integration lands this is an informational page —
/// support contacts, documentation links, and the running app version —
/// so the Support nav item resolves to real content instead of a
/// "Page Not Found" route error.
class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static const _supportEmail = 'info@antinvestor.com';
  static const _supportPhone = '+256757546244';
  static const _docsUrl = 'https://docs.stawi.org';

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Support',
                breadcrumbs: ['Home', 'Support'],
              ),
              const SizedBox(height: 24),
              _card(
                context,
                icon: Icons.mail_outline,
                title: 'Email support',
                subtitle: _supportEmail,
                onTap: () => _launch('mailto:$_supportEmail'),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                icon: Icons.phone_outlined,
                title: 'Call support',
                subtitle: _supportPhone,
                onTap: () => _launch('tel:$_supportPhone'),
              ),
              const SizedBox(height: 12),
              _card(
                context,
                icon: Icons.menu_book_outlined,
                title: 'Documentation',
                subtitle: _docsUrl,
                onTap: () => _launch(_docsUrl),
              ),
              const SizedBox(height: 24),
              Text(
                'Antinvestor Admin Console',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.tertiary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
