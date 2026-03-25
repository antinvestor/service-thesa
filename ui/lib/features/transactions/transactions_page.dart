import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/entity_list_page.dart';

class _Transaction {
  const _Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.from,
    required this.to,
    required this.status,
    required this.date,
  });

  final String id;
  final String type;
  final String amount;
  final String from;
  final String to;
  final String status;
  final String date;
}

const _sampleTransactions = [
  _Transaction(id: 'TXN-001', type: 'Purchase', amount: '\$12,400', from: 'Main Wallet', to: 'Blue-Chip Tech', status: 'Completed', date: '2024-04-15 09:23'),
  _Transaction(id: 'TXN-002', type: 'Withdrawal', amount: '\$5,000', from: 'Savings Pool', to: 'Bank Account', status: 'Processing', date: '2024-04-15 08:45'),
  _Transaction(id: 'TXN-003', type: 'Deposit', amount: '\$25,000', from: 'Wire Transfer', to: 'Main Wallet', status: 'Completed', date: '2024-04-14 16:30'),
  _Transaction(id: 'TXN-004', type: 'Transfer', amount: '\$8,200', from: 'Portfolio A', to: 'Portfolio B', status: 'Completed', date: '2024-04-14 14:12'),
  _Transaction(id: 'TXN-005', type: 'Purchase', amount: '\$3,100', from: 'Main Wallet', to: 'ETH Staking', status: 'Failed', date: '2024-04-14 11:00'),
  _Transaction(id: 'TXN-006', type: 'Dividend', amount: '\$452,000', from: 'Green Bond', to: 'Main Wallet', status: 'Completed', date: '2024-04-13 09:00'),
];

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityListPage<_Transaction>(
      title: 'Transactions',
      breadcrumbs: const ['Dashboard', 'Transactions'],
      searchHint: 'Search transactions...',
      items: _sampleTransactions,
      columns: const [
        DataColumn(label: Text('ID')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Amount')),
        DataColumn(label: Text('From')),
        DataColumn(label: Text('To')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Date')),
      ],
      rowBuilder: (item, selected, onSelect) {
        return DataRow(
          selected: selected,
          onSelectChanged: (_) => onSelect(),
          cells: [
            DataCell(Text(item.id, style: const TextStyle(fontWeight: FontWeight.w500))),
            DataCell(Text(item.type)),
            DataCell(Text(item.amount, style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(item.from)),
            DataCell(Text(item.to)),
            DataCell(_TxnStatusBadge(item.status)),
            DataCell(Text(item.date, style: Theme.of(context).textTheme.bodySmall)),
          ],
        );
      },
      detailBuilder: (item) => _TransactionDetail(item: item),
    );
  }
}

class _TxnStatusBadge extends StatelessWidget {
  const _TxnStatusBadge(this.status);
  final String status;

  Color get _color {
    switch (status) {
      case 'Completed': return AppColors.success;
      case 'Processing': return AppColors.warning;
      case 'Failed': return AppColors.error;
      default: return AppColors.onSurfaceMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TransactionDetail extends StatelessWidget {
  const _TransactionDetail({required this.item});
  final _Transaction item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.id, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        _TxnStatusBadge(item.status),
        const SizedBox(height: 24),
        _Row(label: 'Type', value: item.type),
        _Row(label: 'Amount', value: item.amount),
        _Row(label: 'From', value: item.from),
        _Row(label: 'To', value: item.to),
        _Row(label: 'Date', value: item.date),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
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
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
