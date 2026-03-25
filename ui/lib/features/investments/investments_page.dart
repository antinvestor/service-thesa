import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/entity_list_page.dart';

class _Investment {
  const _Investment({
    required this.name,
    required this.type,
    required this.value,
    required this.change,
    required this.status,
    required this.date,
  });

  final String name;
  final String type;
  final String value;
  final String change;
  final String status;
  final String date;
}

const _sampleInvestments = [
  _Investment(name: 'Blue-Chip Tech Fund', type: 'Equity', value: '\$2,450,000', change: '+12.4%', status: 'Active', date: '2024-01-15'),
  _Investment(name: 'Downtown Office Complex', type: 'Real Estate', value: '\$8,200,000', change: '+5.2%', status: 'Active', date: '2023-08-22'),
  _Investment(name: 'Ethereum Staking Pool', type: 'Crypto', value: '\$890,000', change: '-8.2%', status: 'Under Review', date: '2024-03-01'),
  _Investment(name: 'Green Energy Bond', type: 'Bond', value: '\$1,200,000', change: '+3.1%', status: 'Active', date: '2023-11-10'),
  _Investment(name: 'Emerging Markets ETF', type: 'Equity', value: '\$3,100,000', change: '+18.7%', status: 'Active', date: '2024-02-28'),
  _Investment(name: 'Residential REIT', type: 'Real Estate', value: '\$5,500,000', change: '+7.8%', status: 'Pending', date: '2024-04-12'),
  _Investment(name: 'Bitcoin Reserve', type: 'Crypto', value: '\$2,100,000', change: '+22.1%', status: 'Active', date: '2023-06-05'),
];

class InvestmentsPage extends StatelessWidget {
  const InvestmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityListPage<_Investment>(
      title: 'Investments',
      breadcrumbs: const ['Dashboard', 'Investments'],
      searchHint: 'Search investments...',
      addLabel: 'New Investment',
      onAdd: () {},
      items: _sampleInvestments,
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Value')),
        DataColumn(label: Text('Change')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Actions')),
      ],
      rowBuilder: (item, selected, onSelect) {
        final isNegative = item.change.startsWith('-');
        return DataRow(
          selected: selected,
          onSelectChanged: (_) => onSelect(),
          cells: [
            DataCell(Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(_TypeChip(item.type)),
            DataCell(Text(item.value)),
            DataCell(Text(
              item.change,
              style: TextStyle(
                color: isNegative ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            )),
            DataCell(_StatusBadge(item.status)),
            DataCell(Text(item.date)),
            DataCell(PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'view', child: Text('View Details')),
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            )),
          ],
        );
      },
      detailBuilder: (item) => _InvestmentDetail(item: item),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip(this.type);
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final String status;

  Color get _color {
    switch (status) {
      case 'Active':
        return AppColors.success;
      case 'Under Review':
        return AppColors.warning;
      case 'Pending':
        return AppColors.info;
      default:
        return AppColors.onSurfaceMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _InvestmentDetail extends StatelessWidget {
  const _InvestmentDetail({required this.item});
  final _Investment item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        _TypeChip(item.type),
        const SizedBox(height: 24),
        _DetailRow(label: 'Value', value: item.value),
        _DetailRow(label: 'Change', value: item.change),
        _DetailRow(label: 'Status', value: item.status),
        _DetailRow(label: 'Date', value: item.date),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Edit Investment'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            child: const Text('View Full Report'),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
