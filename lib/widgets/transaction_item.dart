import 'package:flutter/material.dart';
import '../theme/alpha_theme.dart';

class TransactionItem extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionItem({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AlphaTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: transaction['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(transaction['icon'],
                color: transaction['color'], size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['description'],
                  style: AlphaTheme.bodyLarge
                      .copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  transaction['time'],
                  style: AlphaTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            transaction['amount'],
            style: AlphaTheme.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: transaction['color'],
            ),
          ),
        ],
      ),
    );
  }
}
