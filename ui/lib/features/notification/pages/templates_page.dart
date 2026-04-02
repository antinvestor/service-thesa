import 'package:antinvestor_api_notification/antinvestor_api_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_definition.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/edit_dialog.dart';
import '../../../core/widgets/page_header.dart';
import '../data/notification_providers.dart';
import '../data/notification_repository.dart';

class TemplatesPage extends ConsumerWidget {
  const TemplatesPage({
    super.key,
    required this.service,
    required this.feature,
  });

  final ServiceDefinition service;
  final SubFeatureDefinition feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplates = ref.watch(templatesProvider);

    return asyncTemplates.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Failed to load templates',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(templatesProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (templates) => _TemplatesContent(
        templates: templates,
        service: service,
      ),
    );
  }
}

class _TemplatesContent extends ConsumerStatefulWidget {
  const _TemplatesContent({
    required this.templates,
    required this.service,
  });

  final List<Template> templates;
  final ServiceDefinition service;

  @override
  ConsumerState<_TemplatesContent> createState() => _TemplatesContentState();
}

class _TemplatesContentState extends ConsumerState<_TemplatesContent> {
  Template? _selected;

  Future<void> _createTemplate() async {
    final values = await showEditDialog(
      context: context,
      title: 'New Template',
      saveLabel: 'Create',
      fields: const [
        DialogField(key: 'name', label: 'Template Name', hint: 'e.g. welcome_email'),
        DialogField(key: 'languageCode', label: 'Language Code', hint: 'e.g. en'),
      ],
    );
    if (values == null || !mounted) return;

    try {
      final repo = await ref.read(notificationRepositoryProvider.future);
      await repo.saveTemplate(
        name: values['name'] ?? '',
        languageCode: values['languageCode'] ?? '',
      );
      ref.invalidate(templatesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Template created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Template list
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Templates',
                  breadcrumbs: ['Services', widget.service.label, 'Templates'],
                  actions: [
                    ElevatedButton.icon(
                      onPressed: _createTemplate,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Template'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (widget.templates.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          Icon(Icons.description_outlined,
                              size: 48, color: AppColors.onSurfaceMuted),
                          const SizedBox(height: 12),
                          const Text('No templates'),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.templates.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _TemplateRow(
                            template: widget.templates[i],
                            isSelected: _selected?.id == widget.templates[i].id,
                            onTap: () => setState(
                                () => _selected = widget.templates[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Detail panel
        if (_selected != null)
          SizedBox(
            width: 400,
            child: Container(
              margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _TemplateDetail(template: _selected!),
            ),
          ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  final Template template;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.tertiary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.description_outlined,
                  size: 18, color: AppColors.tertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${template.data.length} variant(s)',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.onSurfaceMuted)),
                  ],
                ),
              ),
              Text(template.id,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.onSurfaceMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateDetail extends StatelessWidget {
  const _TemplateDetail({required this.template});

  final Template template;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(template.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('ID: ${template.id}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.onSurfaceMuted)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: template.data.isEmpty
              ? Center(
                  child: Text('No language variants',
                      style: TextStyle(color: AppColors.onSurfaceMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: template.data.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final td = template.data[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (td.hasLanguage())
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.tertiary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  td.language.code.isNotEmpty
                                      ? td.language.code
                                      : td.language.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: AppColors.tertiary,
                                          fontWeight: FontWeight.w600),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text('Type: ${td.type}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        color: AppColors.onSurfaceMuted)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            td.detail,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
