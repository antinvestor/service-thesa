import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../data/settings_providers.dart';

class SettingsAnalyticsPage extends ConsumerWidget {
  const SettingsAnalyticsPage({super.key, required this.service});

  final ServiceDefinition service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(settingsStatsProvider);
    final asyncModules = ref.watch(settingsModulesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Settings Service',
            breadcrumbs: ['Services', service.label, 'Dashboard'],
          ),
          const SizedBox(height: 24),
          // KPI cards
          asyncStats.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => _ErrorCard(
              message: 'Failed to load statistics',
              detail: err.toString(),
              onRetry: () => ref.invalidate(settingsStatsProvider),
            ),
            data: (stats) => _KpiRow(stats: stats),
          ),
          const SizedBox(height: 24),
          // Module distribution
          asyncModules.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (modules) => _ModuleDistribution(modules: modules),
          ),
        ],
      ),
    );
  }
}

// ── KPI Row ─────────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});

  final SettingsStats stats;

  @override
  Widget build(BuildContext context) {
    final isDesktop = screenSizeOf(context) == ScreenSize.desktop;
    final cards = [
      _KpiData(
        icon: Icons.tune,
        label: 'Total Settings',
        value: '${stats.totalSettings}',
        color: AppColors.tertiary,
      ),
      _KpiData(
        icon: Icons.widgets_outlined,
        label: 'Modules',
        value: '${stats.moduleCount}',
        color: AppColors.primary,
      ),
      _KpiData(
        icon: Icons.category_outlined,
        label: 'Object Types',
        value: '${stats.objectTypeCount}',
        color: AppColors.success,
      ),
      _KpiData(
        icon: Icons.translate,
        label: 'Languages',
        value: '${stats.languageCount}',
        color: Colors.orange,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: _KpiCard(data: cards[i])),
          ],
        ],
      );
    }
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards.map((d) => _KpiCard(data: d)).toList(),
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, size: 24, color: data.color),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data.value,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(data.label,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.onSurfaceMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Module Distribution ─────────────────────────────────────────────────────

class _ModuleDistribution extends StatelessWidget {
  const _ModuleDistribution({required this.modules});

  final List<SettingsModuleInfo> modules;

  @override
  Widget build(BuildContext context) {
    final isDesktop = screenSizeOf(context) == ScreenSize.desktop;
    final totalSettings =
        modules.fold<int>(0, (sum, m) => sum + m.settingCount);

    return isDesktop
        ? IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    flex: 3,
                    child:
                        _ModuleBarChart(modules: modules, total: totalSettings)),
                const SizedBox(width: 20),
                Expanded(
                    flex: 2,
                    child: _ScopeOverview(modules: modules)),
              ],
            ),
          )
        : Column(
            children: [
              _ModuleBarChart(modules: modules, total: totalSettings),
              const SizedBox(height: 20),
              _ScopeOverview(modules: modules),
            ],
          );
  }
}

class _ModuleBarChart extends StatelessWidget {
  const _ModuleBarChart({required this.modules, required this.total});

  final List<SettingsModuleInfo> modules;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings by Module',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Distribution across ${modules.length} modules',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 20),
          if (modules.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No settings configured',
                    style: TextStyle(color: AppColors.onSurfaceMuted)),
              ),
            )
          else
            for (final mod in modules) ...[
              _ModuleBar(
                name: mod.name,
                count: mod.settingCount,
                total: total,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _ModuleBar extends StatelessWidget {
  const _ModuleBar({
    required this.name,
    required this.count,
    required this.total,
  });

  final String name;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    final percent = (fraction * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ),
            Text('$count ($percent%)',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            backgroundColor: AppColors.surfaceVariant,
            color: AppColors.tertiary,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _ScopeOverview extends StatelessWidget {
  const _ScopeOverview({required this.modules});

  final List<SettingsModuleInfo> modules;

  @override
  Widget build(BuildContext context) {
    // Collect unique objects and languages across all modules
    final allObjects = <String>{};
    final allLanguages = <String>{};
    for (final mod in modules) {
      allObjects.addAll(mod.objectTypes);
      allLanguages.addAll(mod.languages);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scope Overview',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          _ScopeSection(
            icon: Icons.category_outlined,
            label: 'Object Types',
            items: allObjects.toList()..sort(),
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          _ScopeSection(
            icon: Icons.translate,
            label: 'Languages',
            items: allLanguages.toList()..sort(),
            color: Colors.orange,
          ),
          const SizedBox(height: 16),
          _ScopeSection(
            icon: Icons.widgets_outlined,
            label: 'Modules',
            items: modules.map((m) => m.name).toList(),
            color: AppColors.tertiary,
          ),
        ],
      ),
    );
  }
}

class _ScopeSection extends StatelessWidget {
  const _ScopeSection({
    required this.icon,
    required this.label,
    required this.items,
    required this.color,
  });

  final IconData icon;
  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${items.length}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text('None configured',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map((item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(item,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
      ],
    );
  }
}

// ── Error Card ──────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(detail,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.onSurfaceMuted)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
