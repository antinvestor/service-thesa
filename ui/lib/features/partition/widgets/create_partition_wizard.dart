import 'package:antinvestor_api_tenancy/antinvestor_api_tenancy.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Result from the partition creation wizard.
class CreatePartitionWizardResult {
  const CreatePartitionWizardResult({
    required this.tenantId,
    required this.name,
    this.parentId,
    this.description = '',
    this.domain,
    this.allowAutoAccess = true,
    this.defaultRole = '',
    this.supportEmail = '',
    this.supportPhone = '',
  });

  final String tenantId;
  final String name;
  final String? parentId;
  final String description;
  final String? domain;
  final bool allowAutoAccess;
  final String defaultRole;
  final String supportEmail;
  final String supportPhone;

  /// Build a protobuf [Struct] from the metadata fields.
  Struct? toPropertiesStruct() {
    final fields = <String, Value>{};

    fields['allow_auto_access'] =
        Value(boolValue: allowAutoAccess);

    if (defaultRole.isNotEmpty) {
      fields['default_role'] = Value(stringValue: defaultRole);
    }

    final contactFields = <String, Value>{};
    if (supportEmail.isNotEmpty) {
      contactFields['email'] = Value(stringValue: supportEmail);
    }
    if (supportPhone.isNotEmpty) {
      contactFields['msisdn'] = Value(stringValue: supportPhone);
    }
    if (contactFields.isNotEmpty) {
      fields['support_contacts'] = Value(
        structValue: Struct(fields: contactFields),
      );
    }

    if (fields.isEmpty) return null;
    return Struct(fields: fields);
  }
}

/// Shows a multi-step wizard dialog for creating a partition.
///
/// When [tenantId] is provided, the tenant step is skipped (creating within
/// a known tenant). When [existingPartitions] is provided, a searchable
/// parent selector is shown.
Future<CreatePartitionWizardResult?> showCreatePartitionWizard({
  required BuildContext context,
  String? tenantId,
  List<TenantObject>? tenants,
  List<PartitionObject> existingPartitions = const [],
}) {
  return showDialog<CreatePartitionWizardResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CreatePartitionWizard(
      fixedTenantId: tenantId,
      tenants: tenants ?? [],
      existingPartitions: existingPartitions,
    ),
  );
}

class _CreatePartitionWizard extends StatefulWidget {
  const _CreatePartitionWizard({
    required this.fixedTenantId,
    required this.tenants,
    required this.existingPartitions,
  });

  final String? fixedTenantId;
  final List<TenantObject> tenants;
  final List<PartitionObject> existingPartitions;

  @override
  State<_CreatePartitionWizard> createState() => _CreatePartitionWizardState();
}

class _CreatePartitionWizardState extends State<_CreatePartitionWizard> {
  int _currentStep = 0;
  final _formKeys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];

  // Step 1: Basic
  String? _selectedTenantId;
  final _nameController = TextEditingController();
  String? _selectedParentId;
  final _parentSearchController = TextEditingController();

  // Step 2: Details
  final _descriptionController = TextEditingController();
  final _domainController = TextEditingController();

  // Step 3: Properties
  bool _allowAutoAccess = true;
  final _defaultRoleController = TextEditingController();
  final _supportEmailController = TextEditingController();
  final _supportPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTenantId = widget.fixedTenantId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentSearchController.dispose();
    _descriptionController.dispose();
    _domainController.dispose();
    _defaultRoleController.dispose();
    _supportEmailController.dispose();
    _supportPhoneController.dispose();
    super.dispose();
  }

  bool get _hasTenantStep => widget.fixedTenantId == null;

  int get _totalSteps => 3;

  String get _stepTitle => switch (_currentStep) {
        0 => 'Basic Information',
        1 => 'Details',
        2 => 'Properties & Metadata',
        _ => '',
      };

  void _next() {
    if (_formKeys[_currentStep].currentState?.validate() ?? false) {
      if (_currentStep < _totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        _submit();
      }
    }
  }

  void _back() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _submit() {
    final result = CreatePartitionWizardResult(
      tenantId: _selectedTenantId!,
      name: _nameController.text.trim(),
      parentId: _selectedParentId,
      description: _descriptionController.text.trim(),
      domain: _domainController.text.trim().isNotEmpty
          ? _domainController.text.trim()
          : null,
      allowAutoAccess: _allowAutoAccess,
      defaultRole: _defaultRoleController.text.trim(),
      supportEmail: _supportEmailController.text.trim(),
      supportPhone: _supportPhoneController.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Partition'),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < _totalSteps; i++) ...[
                if (i > 0) Expanded(
                  child: Container(
                    height: 2,
                    color: i <= _currentStep
                        ? AppColors.tertiary
                        : AppColors.border,
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= _currentStep
                        ? AppColors.tertiary
                        : AppColors.border,
                  ),
                  child: Center(
                    child: i < _currentStep
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${i + 1}',
                            style: TextStyle(
                              color: i <= _currentStep
                                  ? Colors.white
                                  : AppColors.onSurfaceMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(_stepTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _buildStep(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: _back,
            child: const Text('Back'),
          ),
        ElevatedButton(
          onPressed: _next,
          child: Text(_currentStep < _totalSteps - 1 ? 'Next' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildStep() {
    return switch (_currentStep) {
      0 => _buildBasicStep(),
      1 => _buildDetailsStep(),
      2 => _buildPropertiesStep(),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildBasicStep() {
    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tenant selector (only if not fixed)
            if (_hasTenantStep) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedTenantId,
                decoration: const InputDecoration(
                  labelText: 'Tenant *',
                  hintText: 'Select a tenant...',
                ),
                items: widget.tenants
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.name),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTenantId = v),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Tenant is required' : null,
              ),
              const SizedBox(height: 16),
            ],

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Partition Name *',
                hintText: 'e.g. Production, Staging, Team Alpha',
                helperText: '3-100 characters',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                if (v.trim().length < 3) return 'At least 3 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Parent partition (searchable)
            if (widget.existingPartitions.isNotEmpty) ...[
              Autocomplete<PartitionObject>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return widget.existingPartitions;
                  }
                  final query = textEditingValue.text.toLowerCase();
                  return widget.existingPartitions
                      .where((p) => p.name.toLowerCase().contains(query));
                },
                displayStringForOption: (p) => p.name,
                onSelected: (p) =>
                    setState(() => _selectedParentId = p.id),
                fieldViewBuilder:
                    (context, textController, focusNode, onFieldSubmitted) {
                  // Keep reference for clear button
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_parentSearchController != textController &&
                        mounted) {
                      // Copy text controller reference
                    }
                  });
                  return TextFormField(
                    controller: textController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Parent Partition (optional)',
                      hintText: 'Type to search partitions...',
                      suffixIcon: textController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                textController.clear();
                                setState(() => _selectedParentId = null);
                              },
                            )
                          : const Icon(Icons.search, size: 18),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (_selectedParentId != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    children: [
                      Icon(Icons.subdirectory_arrow_right,
                          size: 14, color: AppColors.tertiary),
                      const SizedBox(width: 4),
                      Text('Will be a child of this partition',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.tertiary)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description *',
                hintText: 'Describe the purpose of this partition...',
                alignLabelWithHint: true,
                helperText: '10-500 characters',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Description is required';
                if (v.trim().length < 10) return 'At least 10 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _domainController,
              decoration: const InputDecoration(
                labelText: 'Custom Domain (optional)',
                hintText: 'e.g. app.example.com',
                helperText: 'Must be unique across all partitions',
                prefixIcon: Icon(Icons.language, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesStep() {
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto access toggle
            SwitchListTile(
              title: const Text('Allow Auto Access'),
              subtitle: const Text(
                'Automatically grant access to users during login',
                style: TextStyle(fontSize: 12),
              ),
              value: _allowAutoAccess,
              onChanged: (v) => setState(() => _allowAutoAccess = v),
              contentPadding: EdgeInsets.zero,
            ),
            const Divider(),
            const SizedBox(height: 8),

            // Default role
            TextFormField(
              controller: _defaultRoleController,
              decoration: const InputDecoration(
                labelText: 'Default Role (optional)',
                hintText: 'e.g. user, member, viewer',
                helperText: 'Role auto-assigned to new users',
                prefixIcon: Icon(Icons.badge_outlined, size: 20),
              ),
            ),
            const SizedBox(height: 16),

            // Support contacts
            Text('Support Contacts',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _supportEmailController,
              decoration: const InputDecoration(
                labelText: 'Support Email (optional)',
                hintText: 'e.g. support@example.com',
                prefixIcon: Icon(Icons.email_outlined, size: 20),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _supportPhoneController,
              decoration: const InputDecoration(
                labelText: 'Support Phone (optional)',
                hintText: 'e.g. +256757546244',
                prefixIcon: Icon(Icons.phone_outlined, size: 20),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }
}
