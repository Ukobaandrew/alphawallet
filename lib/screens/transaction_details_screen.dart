import 'package:flutter/material.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen(
      {super.key,
      required String transactionId,
      required Map<String, dynamic> transactionData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: const Color(0xFF003366),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Download statement
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildTransactionItem(
            'John Doe',
            '-\$2,500.00',
            'Today, 10:30 AM',
            Icons.account_balance,
            Colors.blue[700]!,
            'Completed',
          ),
          _buildTransactionItem(
            'Amazon.com',
            '-\$189.99',
            'Yesterday, 3:45 PM',
            Icons.shopping_bag,
            Colors.orange[700]!,
            'Completed',
          ),
          _buildTransactionItem(
            'Salary Credit',
            '+\$5,000.00',
            '2 days ago',
            Icons.work,
            Colors.green[700]!,
            'Completed',
          ),
          _buildTransactionItem(
            'Netflix',
            '-\$15.99',
            '3 days ago',
            Icons.tv,
            Colors.red[700]!,
            'Completed',
          ),
          _buildTransactionItem(
            'Mike Johnson',
            '-\$1,200.00',
            '1 week ago',
            Icons.person,
            Colors.purple[700]!,
            'Completed',
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String name,
    String amount,
    String time,
    IconData icon,
    Color color,
    String status,
  ) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(time),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status == 'Completed'
                    ? Colors.green[100]
                    : Colors.yellow[100],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'Completed'
                      ? Colors.green[800]
                      : Colors.yellow[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        trailing: Text(
          amount,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: amount.startsWith('+') ? Colors.green[700] : Colors.red[700],
          ),
        ),
        onTap: () {
          // Show transaction details
        },
      ),
    );
  }
}
