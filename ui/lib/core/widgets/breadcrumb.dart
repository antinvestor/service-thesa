import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class Breadcrumb extends StatelessWidget {
  const Breadcrumb({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '/',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.onSurfaceMuted),
              ),
            ),
          Text(
            items[i],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: i == items.length - 1
                      ? AppColors.onSurface
                      : AppColors.onSurfaceMuted,
                  fontWeight: i == items.length - 1 ? FontWeight.w500 : FontWeight.w400,
                ),
          ),
        ],
      ],
    );
  }
}
