import 'package:flutter/material.dart'; // ADD THIS IMPORT

class WalletProvider with ChangeNotifier {
  double _balance = 1250000.0;
  bool _isLoading = false;

  double get balance => _balance;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> get recentTransactions {
    return [
      {
        'type': 'deposit',
        'amount': '+₦50,000',
        'description': 'Bank Transfer',
        'time': '2 hours ago',
        'icon': Icons.add, // FIXED: Now Icons is imported
        'color': Colors.green,
      },
      {
        'type': 'withdrawal',
        'amount': '-₦15,000',
        'description': 'ATM Withdrawal',
        'time': '1 day ago',
        'icon': Icons.remove, // FIXED: Now Icons is imported
        'color': Colors.red,
      },
      {
        'type': 'transfer',
        'amount': '-₦25,000',
        'description': 'Sent to John',
        'time': '2 days ago',
        'icon': Icons.arrow_upward, // FIXED: Now Icons is imported
        'color': Colors.orange,
      },
      {
        'type': 'deposit',
        'amount': '+₦75,000',
        'description': 'Salary',
        'time': '3 days ago',
        'icon': Icons.add, // FIXED: Now Icons is imported
        'color': Colors.green,
      },
    ];
  }

  Future<void> deposit(double amount) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    _balance += amount;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> withdraw(double amount) async {
    if (amount > _balance) return false;

    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    _balance -= amount;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> transfer(double amount, String recipient) async {
    if (amount > _balance) return false;

    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    _balance -= amount;
    _isLoading = false;
    notifyListeners();
    return true;
  }
}
