import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Settings',
            breadcrumbs: ['Dashboard', 'Settings'],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Profile',
            children: [
              _SettingsTextField(label: 'Organization Name', value: 'Antinvestor'),
              _SettingsTextField(label: 'Admin Email', value: 'admin@antinvestor.com'),
              _SettingsTextField(label: 'Contact Phone', value: '+1 (555) 000-0000'),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Preferences',
            children: [
              _SettingsToggle(label: 'Email Notifications', subtitle: 'Receive email alerts for critical events', value: true),
              _SettingsToggle(label: 'Two-Factor Authentication', subtitle: 'Require 2FA for all admin logins', value: true),
              _SettingsToggle(label: 'Dark Mode', subtitle: 'Use dark theme across the dashboard', value: false),
              _SettingsToggle(label: 'Auto-refresh Data', subtitle: 'Automatically refresh dashboard data every 30 seconds', value: true),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'API Configuration',
            children: [
              _SettingsTextField(label: 'API Base URL', value: 'https://api.antinvestor.com/v1'),
              _SettingsTextField(label: 'Webhook URL', value: 'https://hooks.antinvestor.com/events'),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton(onPressed: () {}, child: const Text('Save Changes')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: () {}, child: const Text('Reset')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: value,
            decoration: const InputDecoration(),
          ),
        ],
      ),
    );
  }
}

class _SettingsToggle extends StatefulWidget {
  const _SettingsToggle({
    required this.label,
    required this.subtitle,
    required this.value,
  });
  final String label;
  final String subtitle;
  final bool value;

  @override
  State<_SettingsToggle> createState() => _SettingsToggleState();
}

class _SettingsToggleState extends State<_SettingsToggle> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: _value,
            onChanged: (v) => setState(() => _value = v),
            activeThumbColor: AppColors.tertiary,
            activeTrackColor: AppColors.tertiary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
