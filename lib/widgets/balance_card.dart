import 'package:flutter/material.dart';
import '../theme/alpha_theme.dart';

class BalanceCard extends StatelessWidget {
  final double balance;

  const BalanceCard({super.key, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AlphaTheme.gradientCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: AlphaTheme.bodyLarge.copyWith(
              color: AlphaTheme.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₦${balance.toStringAsFixed(2)}',
            style: AlphaTheme.headingLarge.copyWith(
              color: AlphaTheme.white,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildBalanceInfo(
                  'Income', '₦25,000', AlphaTheme.white.withOpacity(0.8)),
              const SizedBox(width: 20),
              _buildBalanceInfo(
                  'Expenses', '₦7,500', AlphaTheme.white.withOpacity(0.8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInfo(String title, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AlphaTheme.bodySmall.copyWith(color: color)),
        const SizedBox(height: 4),
        Text(value,
            style: AlphaTheme.bodyMedium.copyWith(
              color: AlphaTheme.white,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
