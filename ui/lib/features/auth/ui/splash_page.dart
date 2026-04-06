import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Full-screen splash shown while auth state is being determined.
///
/// Displayed during:
/// - Initial app load (checking stored tokens)
/// - OAuth callback processing (exchanging auth code for tokens)
/// - Token refresh in progress
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.diamond_outlined,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Antinvestor',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
