import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Withdrawal Data Model
class Withdrawal {
  final String id;
  final String method;
  final String accountNumber;
  final String bankName;
  final String bankCode;
  final double amount;
  final double fee;
  final DateTime timestamp;
  final String status;
  final String? reference;
  final String? swiftCode;
  final String? beneficiaryName;

  Withdrawal({
    required this.id,
    required this.method,
    required this.accountNumber,
    required this.bankName,
    required this.bankCode,
    required this.amount,
    required this.fee,
    required this.timestamp,
    required this.status,
    this.reference,
    this.swiftCode,
    this.beneficiaryName,
  });

  double get totalAmount => amount + fee;
}

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({super.key});

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  // User's balance (to be fetched from Firestore)
  double _availableBalance = 0.0;
  bool _isLoading = true;
  bool _processingWithdrawal = false;
  User? _currentUser;
  List<Map<String, dynamic>> _savedAccounts = [];
  List<Map<String, dynamic>> _recentWithdrawals = [];
  String? _primaryAccountNumber;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      await _loadUserBalance();
      await _loadSavedAccounts();
      await _loadRecentWithdrawals();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserBalance() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      final userData = userDoc.data();
      if (userData != null) {
        setState(() {
          _availableBalance = (userData['balance'] ?? 0.0).toDouble();
          _primaryAccountNumber = userData['accountNumber'] ?? 'ALPHA001';
        });
      }
    } catch (e) {
      print('Error loading balance: $e');
      // Fallback to sample balance
      setState(() {
        _availableBalance = 12500.00;
        _primaryAccountNumber = 'ALPHA001';
      });
    }
  }

  Future<void> _loadSavedAccounts() async {
    try {
      final accountsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('bank_accounts')
          .get();

      if (accountsSnapshot.docs.isNotEmpty) {
        _savedAccounts = accountsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'bankName': data['bankName'] ?? 'Unknown Bank',
            'accountNumber': data['accountNumber'] ?? '',
            'accountName':
                data['accountName'] ?? _currentUser?.displayName ?? 'User',
            'type': data['accountType'] ?? 'Checking Account',
            'isDefault': data['isDefault'] ?? false,
            'bankCode': data['bankCode'] ?? '',
            'swiftCode': data['swiftCode'],
            'createdAt': data['createdAt'],
          };
        }).toList();
      } else {
        // Load sample accounts if none exist
        _savedAccounts = [
          {
            'id': 'account_1',
            'bankName': 'Alpha Bank',
            'accountNumber': '1234 5678 9012 3456',
            'accountName': _currentUser?.displayName ?? 'John Doe',
            'type': 'Savings Account',
            'isDefault': true,
            'bankCode': 'ALPHANG001',
            'swiftCode': 'ALPHNGLA',
          },
          {
            'id': 'account_2',
            'bankName': 'City Bank',
            'accountNumber': '9876 5432 1098 7654',
            'accountName': _currentUser?.displayName ?? 'John Doe',
            'type': 'Current Account',
            'isDefault': false,
            'bankCode': 'CITIUS33',
            'swiftCode': 'CITIUS33XXX',
          },
        ];
      }
    } catch (e) {
      print('Error loading accounts: $e');
      _savedAccounts = [];
    }
  }

  Future<void> _loadRecentWithdrawals() async {
    try {
      final transactionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions')
          .where('transactionType', isEqualTo: 'withdrawal')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (transactionsSnapshot.docs.isNotEmpty) {
        _recentWithdrawals = transactionsSnapshot.docs.map((doc) {
          final data = doc.data();
          final timestamp = data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now();
          final withdrawalDetails =
              data['withdrawalDetails'] as Map<String, dynamic>? ?? {};

          return {
            'id': doc.id,
            'method': withdrawalDetails['method'] ?? 'Bank Transfer',
            'amount': (data['amount'] ?? 0.0).toDouble(),
            'fee': (withdrawalDetails['fee'] ?? 0.0).toDouble(),
            'date': _formatDate(timestamp),
            'status': data['status'] ?? 'Pending',
            'account': withdrawalDetails['accountNumber'] ?? '****',
            'bankName': withdrawalDetails['bankName'] ?? 'Bank',
            'reference':
                withdrawalDetails['reference'] ?? data['transactionId'],
          };
        }).toList();
      } else {
        // Sample recent withdrawals
        _recentWithdrawals = [
          {
            'method': 'Bank Transfer',
            'amount': 5000.00,
            'date': 'Today, 10:30 AM',
            'status': 'Completed',
            'account': '***4567',
            'bankName': 'Alpha Bank',
          },
          {
            'method': 'Bank Transfer',
            'amount': 2000.00,
            'date': 'Yesterday, 3:45 PM',
            'status': 'Completed',
            'account': '***3456',
            'bankName': 'City Bank',
          },
          {
            'method': 'Bank Transfer',
            'amount': 1000.00,
            'date': '2 days ago',
            'status': 'Processing',
            'account': '***9012',
            'bankName': 'Alpha Bank',
          },
        ];
      }
    } catch (e) {
      print('Error loading withdrawals: $e');
      _recentWithdrawals = [];
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today, ${_formatTime(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday, ${_formatTime(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserBalance(),
      _loadSavedAccounts(),
      _loadRecentWithdrawals(),
    ]);
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text('Withdraw Funds'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _showHelpDialog,
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Card
                    _buildBalanceCard(),
                    const SizedBox(height: 24),

                    // Withdrawal Methods
                    _buildWithdrawalMethodSection(),
                    const SizedBox(height: 24),

                    // Bank Account Details
                    _buildBankAccountsSection(),
                    const SizedBox(height: 24),

                    // Recent Withdrawals
                    _buildRecentWithdrawalsSection(),
                    const SizedBox(height: 32),

                    // Security Note
                    _buildSecurityNote(),
                    const SizedBox(height: 32),

                    // Withdraw Button
                    _buildWithdrawButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003366),
            Color(0xFF0055AA),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF003366).withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Available Balance',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${_availableBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Min: \$100.00',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  Text(
                    'Max: \$100,000.00',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
                child: const Text(
                  'Fee: \$10.00',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawalMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Method',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bank Transfer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Secure transfer to your bank account',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDetailChip('2-4 hours', Icons.schedule_rounded),
                        const SizedBox(width: 8),
                        _buildDetailChip('Secure', Icons.security_rounded),
                        const SizedBox(width: 8),
                        _buildDetailChip(
                            '\$10.00 fee', Icons.attach_money_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 24,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bank Accounts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select or add a bank account for withdrawal',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        ..._savedAccounts.map((account) {
          final isDefault = account['isDefault'] as bool;
          return GestureDetector(
            onTap: () => _editBankAccount(account),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color:
                      isDefault ? const Color(0xFF003366) : Colors.grey[300]!,
                  width: isDefault ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      color: Color(0xFF003366),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              account['bankName'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF003366),
                              ),
                            ),
                            if (isDefault)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF003366),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Default',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account['accountNumber'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          account['type'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _addNewBankAccount,
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('Add New Bank Account'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: const BorderSide(color: Color(0xFF003366)),
            foregroundColor: const Color(0xFF003366),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentWithdrawalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Withdrawals',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            TextButton(
              onPressed: _viewAllWithdrawals,
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0055AA),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._recentWithdrawals.map((withdrawal) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _getStatusColor(withdrawal['status'] as String)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getStatusIcon(withdrawal['status'] as String),
                    color: _getStatusColor(withdrawal['status'] as String),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        withdrawal['method'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        withdrawal['date'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${withdrawal['bankName']} • ${withdrawal['account']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${(withdrawal['amount'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(withdrawal['status'] as String)
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        withdrawal['status'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color:
                              _getStatusColor(withdrawal['status'] as String),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Information',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• All withdrawals are secured with 256-bit encryption\n'
                  '• Transactions are monitored 24/7 for security\n'
                  '• Processing time: 2-4 business hours\n'
                  '• Minimum withdrawal: \$100.00\n'
                  '• Maximum withdrawal: \$100,000.00 per day',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _savedAccounts.isEmpty ? null : _startWithdrawal,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003366),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: const Color(0xFF003366).withOpacity(0.3),
          disabledBackgroundColor: Colors.grey[400],
        ),
        child: _processingWithdrawal
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Processing...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Start Withdrawal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'processing':
        return Icons.hourglass_top_rounded;
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'failed':
      case 'rejected':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Future<void> _startWithdrawal() async {
    if (_savedAccounts.isEmpty) {
      _showSnackBar('Please add a bank account first');
      return;
    }

    final selectedAccount = _savedAccounts.firstWhere(
      (account) => account['isDefault'] as bool,
      orElse: () => _savedAccounts.first,
    );

    final result = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => WithdrawalAmountScreen(
        minAmount: 100.0,
        maxAmount: 100000.0,
        fee: 10.0,
        availableBalance: _availableBalance,
        bankName: selectedAccount['bankName'] as String,
        accountNumber: selectedAccount['accountNumber'] as String,
      ),
    );

    if (result != null && result > 0) {
      await _processWithdrawal(result, selectedAccount);
    }
  }

  Future<void> _processWithdrawal(
      double amount, Map<String, dynamic> account) async {
    setState(() => _processingWithdrawal = true);

    try {
      // Create withdrawal transaction in Firestore
      final transactionId = 'WD${DateTime.now().millisecondsSinceEpoch}';
      final transactionsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('transactions');

      final userName = _currentUser?.displayName ??
          (_currentUser?.email?.split('@').first ?? 'User');

      final transactionData = {
        'amount': -amount, // Negative amount for withdrawal
        'description': 'Withdrawal to ${account['bankName']}',
        'type': 'withdrawal',
        'timestamp': Timestamp.now(),
        'status': 'processing',
        'from': userName,
        'to': account['bankName'],
        'balanceAfter': _availableBalance - amount - 10.0,
        'category': 'cash',
        'accountNumber': _primaryAccountNumber,
        'transactionId': transactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'securityLevel': 'high',
        'requiresVerification': true,
        'verified': false,
        'transactionType': 'withdrawal',
        'withdrawalDetails': {
          'method': 'bank_transfer',
          'fee': 10.0,
          'total': amount + 10.0,
          'bankName': account['bankName'],
          'accountNumber': account['accountNumber'],
          'accountName': account['accountName'],
          'requiresAdminApproval': true,
          'adminApproved': false,
          'adminNotes': 'Pending admin approval',
          'adminApprovedBy': null,
          'adminApprovedAt': null,
          'swiftCode': account['swiftCode'],
          'bankCode': account['bankCode'],
          'reference': 'REF${DateTime.now().millisecondsSinceEpoch}',
          'userId': _currentUser!.uid,
          'userEmail': _currentUser!.email,
        },
      };

      await transactionsRef.doc(transactionId).set(transactionData);

      // Update user balance immediately (will be adjusted if admin rejects)
      final totalAmount = amount + 10.0;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
        'balance': FieldValue.increment(-totalAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      setState(() {
        _availableBalance -= totalAmount;
        _processingWithdrawal = false;
      });

      // Show success dialog
      _showWithdrawalSuccess(transactionId, amount, account);
    } catch (e) {
      print('Error processing withdrawal: $e');
      setState(() => _processingWithdrawal = false);
      _showSnackBar('Error processing withdrawal. Please try again.');
    }
  }

  void _showWithdrawalSuccess(
      String transactionId, double amount, Map<String, dynamic> account) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 50,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Withdrawal Request Sent!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
              _buildDetailRow('Fee', '\$10.00'),
              _buildDetailRow(
                  'Total', '\$${(amount + 10.0).toStringAsFixed(2)}'),
              _buildDetailRow('Method', 'Bank Transfer'),
              _buildDetailRow('Account',
                  '${account['bankName']} - ${account['accountNumber']}'),
              _buildDetailRow('Transaction ID', transactionId),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Withdrawal is pending admin approval. Funds will be transferred within 2-4 business hours after approval.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _refreshData();
              },
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF003366),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _viewTransactionDetails(transactionId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View Details'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
        ],
      ),
    );
  }

  void _addNewBankAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBankAccountScreen(
          onAccountAdded: _refreshData,
        ),
      ),
    );
  }

  void _editBankAccount(Map<String, dynamic> account) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddBankAccountScreen(
          account: account,
          onAccountAdded: _refreshData,
        ),
      ),
    );
  }

  void _viewAllWithdrawals() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WithdrawalsHistoryScreen(),
      ),
    );
  }

  void _viewTransactionDetails(String transactionId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TransactionDetailScreen(transactionId: transactionId),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Withdrawal Help'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bank Transfer Withdrawals',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '• Processing Time: 2-4 business hours\n'
                  '• Working Hours: 9 AM - 5 PM (Mon-Fri)\n'
                  '• Minimum Amount: \$100.00\n'
                  '• Maximum Daily Limit: \$100,000.00\n'
                  '• Transaction Fee: \$10.00 per withdrawal\n'
                  '• Weekends & Holidays: Next business day\n'
                  '• Verification: Requires admin approval',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Contact support for urgent withdrawals or issues',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF003366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class WithdrawalAmountScreen extends StatefulWidget {
  final double minAmount;
  final double maxAmount;
  final double fee;
  final double availableBalance;
  final String bankName;
  final String accountNumber;

  const WithdrawalAmountScreen({
    super.key,
    required this.minAmount,
    required this.maxAmount,
    required this.fee,
    required this.availableBalance,
    required this.bankName,
    required this.accountNumber,
  });

  @override
  State<WithdrawalAmountScreen> createState() => _WithdrawalAmountScreenState();
}

class _WithdrawalAmountScreenState extends State<WithdrawalAmountScreen> {
  final TextEditingController _amountController = TextEditingController();
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateTotal);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _totalAmount = amount + widget.fee;
    });
  }

  void _confirmWithdrawal() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (amount < widget.minAmount) {
      _showError('Minimum withdrawal is \$${widget.minAmount}');
      return;
    }

    if (amount > widget.maxAmount) {
      _showError('Maximum withdrawal is \$${widget.maxAmount}');
      return;
    }

    if (_totalAmount > widget.availableBalance) {
      _showError('Insufficient balance');
      return;
    }

    Navigator.pop(context, amount);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter Withdrawal Amount',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.bankName} • ${widget.accountNumber}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003366),
                ),
                hintText: '0.00',
                hintStyle: const TextStyle(
                  fontSize: 24,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _buildQuickAmountButton('100'),
                _buildQuickAmountButton('500'),
                _buildQuickAmountButton('1000'),
                _buildQuickAmountButton('5000'),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildAmountRow('Amount',
                      '\$${_amountController.text.isEmpty ? '0.00' : _amountController.text}'),
                  _buildAmountRow('Fee', '\$${widget.fee.toStringAsFixed(2)}'),
                  const Divider(height: 16),
                  _buildAmountRow(
                    'Total',
                    '\$${_totalAmount.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                  const SizedBox(height: 8),
                  _buildAmountRow(
                    'Available Balance',
                    '\$${widget.availableBalance.toStringAsFixed(2)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF003366),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _confirmWithdrawal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Withdraw',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ));
  }

  Widget _buildQuickAmountButton(String amount) {
    return GestureDetector(
      onTap: () {
        _amountController.text = amount;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF003366).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF003366).withOpacity(0.2),
          ),
        ),
        child: Text(
          '\$$amount',
          style: const TextStyle(
            color: Color(0xFF003366),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              color: Colors.grey[600],
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? const Color(0xFF003366) : Colors.grey[700],
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Additional supporting screens

class AddBankAccountScreen extends StatefulWidget {
  final Map<String, dynamic>? account;
  final VoidCallback? onAccountAdded;

  const AddBankAccountScreen({
    super.key,
    this.account,
    this.onAccountAdded,
  });

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _swiftCodeController = TextEditingController();
  final TextEditingController _bankCodeController = TextEditingController();
  String _accountType = 'Checking Account';
  bool _isDefault = false;
  bool _isLoading = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;

    if (widget.account != null) {
      _bankNameController.text = widget.account!['bankName'] as String;
      _accountNumberController.text =
          widget.account!['accountNumber'] as String;
      _accountNameController.text = widget.account!['accountName'] as String;
      _swiftCodeController.text = widget.account!['swiftCode'] as String? ?? '';
      _bankCodeController.text = widget.account!['bankCode'] as String? ?? '';
      _accountType = widget.account!['type'] as String;
      _isDefault = widget.account!['isDefault'] as bool;
    } else {
      _accountNameController.text = _currentUser?.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _swiftCodeController.dispose();
    _bankCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveBankAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final accountData = {
        'bankName': _bankNameController.text,
        'accountNumber': _accountNumberController.text,
        'accountName': _accountNameController.text,
        'accountType': _accountType,
        'isDefault': _isDefault,
        'swiftCode': _swiftCodeController.text.isNotEmpty
            ? _swiftCodeController.text
            : null,
        'bankCode': _bankCodeController.text.isNotEmpty
            ? _bankCodeController.text
            : null,
        'userId': _currentUser!.uid,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };

      if (widget.account != null) {
        // Update existing account
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('bank_accounts')
            .doc(widget.account!['id'])
            .update(accountData);
      } else {
        // Add new account
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .collection('bank_accounts')
            .add(accountData);
      }

      if (widget.onAccountAdded != null) {
        widget.onAccountAdded!();
      }

      Navigator.pop(context);
    } catch (e) {
      print('Error saving bank account: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving bank account'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.account != null ? 'Edit Bank Account' : 'Add Bank Account',
        ),
        backgroundColor: const Color(0xFF003366),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bank Account Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your bank account information for withdrawals',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),

              // Bank Name
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank Name',
                  prefixIcon: Icon(Icons.account_balance_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter bank name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Account Number
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Account Name
              TextFormField(
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Account Type
              DropdownButtonFormField<String>(
                initialValue: _accountType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items:
                    ['Checking Account', 'Savings Account', 'Current Account']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                onChanged: (value) {
                  setState(() => _accountType = value!);
                },
              ),
              const SizedBox(height: 16),

              // SWIFT Code (Optional)
              TextFormField(
                controller: _swiftCodeController,
                decoration: const InputDecoration(
                  labelText: 'SWIFT/BIC Code (Optional)',
                  prefixIcon: Icon(Icons.code_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Bank Code (Optional)
              TextFormField(
                controller: _bankCodeController,
                decoration: const InputDecoration(
                  labelText: 'Bank Code (Optional)',
                  prefixIcon: Icon(Icons.confirmation_number_rounded),
                ),
              ),
              const SizedBox(height: 16),

              // Default Account
              SwitchListTile.adaptive(
                title: const Text('Set as default account'),
                subtitle: const Text('Use this account for all withdrawals'),
                value: _isDefault,
                onChanged: (value) {
                  setState(() => _isDefault = value);
                },
                activeColor: const Color(0xFF003366),
              ),
              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBankAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.account != null
                              ? 'Update Account'
                              : 'Add Account',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class WithdrawalsHistoryScreen extends StatelessWidget {
  const WithdrawalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal History'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('transactions')
            .where('transactionType', isEqualTo: 'withdrawal')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading withdrawals'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data?.docs ?? [];

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Withdrawals Yet',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFF003366),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your withdrawal history will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final doc = transactions[index];
              final data = doc.data() as Map<String, dynamic>;
              final withdrawalDetails =
                  data['withdrawalDetails'] as Map<String, dynamic>? ?? {};
              final timestamp = data['timestamp'] != null
                  ? (data['timestamp'] as Timestamp).toDate()
                  : DateTime.now();
              final amount = (data['amount'] as num).toDouble().abs();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        _getStatusColor(data['status'] as String? ?? 'Pending')
                            .withOpacity(0.1),
                    child: Icon(
                      _getStatusIcon(data['status'] as String? ?? 'Pending'),
                      color: _getStatusColor(
                          data['status'] as String? ?? 'Pending'),
                    ),
                  ),
                  title: Text(
                    '\$${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        withdrawalDetails['bankName'] as String? ?? 'Bank',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  trailing: Chip(
                    label: Text(
                      data['status'] as String? ?? 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(
                            data['status'] as String? ?? 'Pending'),
                      ),
                    ),
                    backgroundColor:
                        _getStatusColor(data['status'] as String? ?? 'Pending')
                            .withOpacity(0.1),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TransactionDetailScreen(transactionId: doc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'processing':
        return Icons.hourglass_top_rounded;
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'failed':
      case 'rejected':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

class TransactionDetailScreen extends StatelessWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('transactions')
            .doc(transactionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Error loading transaction details'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('Transaction not found'));
          }

          final withdrawalDetails =
              data['withdrawalDetails'] as Map<String, dynamic>? ?? {};
          final timestamp = data['timestamp'] != null
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now();
          final amount = (data['amount'] as num).toDouble().abs();
          final fee = (withdrawalDetails['fee'] as num?)?.toDouble() ?? 0.0;
          final total = amount + fee;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        _getStatusColor(data['status'] as String? ?? 'Pending')
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(
                          data['status'] as String? ?? 'Pending'),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(data['status'] as String? ?? 'Pending'),
                        color: _getStatusColor(
                            data['status'] as String? ?? 'Pending'),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['status'] as String? ?? 'Pending',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(
                                    data['status'] as String? ?? 'Pending'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getStatusDescription(
                                  data['status'] as String? ?? 'Pending'),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Transaction Type
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['transactionType'] as String? ?? 'Transaction',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF003366),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Amount Details
                const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
                _buildDetailRow('Fee', '\$${fee.toStringAsFixed(2)}'),
                _buildDetailRow('Total', '\$${total.toStringAsFixed(2)}'),
                _buildDetailRow(
                    'Description', data['description'] as String? ?? ''),
                const Divider(height: 24),

                // Bank Details (if withdrawal)
                if (data['transactionType'] == 'withdrawal') ...[
                  const Text(
                    'Bank Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Bank Name',
                      withdrawalDetails['bankName'] as String? ?? ''),
                  _buildDetailRow('Account Number',
                      withdrawalDetails['accountNumber'] as String? ?? ''),
                  _buildDetailRow('Account Name',
                      withdrawalDetails['accountName'] as String? ?? ''),
                  if (withdrawalDetails['swiftCode'] != null)
                    _buildDetailRow(
                        'SWIFT Code', withdrawalDetails['swiftCode'] as String),
                  if (withdrawalDetails['bankCode'] != null)
                    _buildDetailRow(
                        'Bank Code', withdrawalDetails['bankCode'] as String),
                  const Divider(height: 24),
                ],

                // Transaction Info
                const Text(
                  'Transaction Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Transaction ID',
                    data['transactionId'] as String? ?? transactionId),
                if (withdrawalDetails['reference'] != null)
                  _buildDetailRow(
                      'Reference', withdrawalDetails['reference'] as String),
                _buildDetailRow('Date',
                    '${timestamp.day}/${timestamp.month}/${timestamp.year}'),
                _buildDetailRow('Time',
                    '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}'),
                _buildDetailRow(
                    'Account', data['accountNumber'] as String? ?? ''),
                if (data['balanceAfter'] != null)
                  _buildDetailRow('Balance After',
                      '\$${(data['balanceAfter'] as num).toStringAsFixed(2)}'),
                const SizedBox(height: 32),

                // Admin Approval Info (if applicable)
                if (withdrawalDetails['requiresAdminApproval'] == true) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[100]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admin Approval Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Approval Required', 'Yes'),
                        _buildDetailRow(
                            'Approved',
                            (withdrawalDetails['adminApproved'] == true)
                                ? 'Yes'
                                : 'No'),
                        if (withdrawalDetails['adminApprovedBy'] != null)
                          _buildDetailRow('Approved By', 'Admin'),
                        if (withdrawalDetails['adminNotes'] != null)
                          _buildDetailRow('Admin Notes',
                              withdrawalDetails['adminNotes'] as String),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Help Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Need Help?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'If you have any questions about this transaction, please contact our support team.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          // Implement contact support
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Contact Support'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'processing':
        return Icons.hourglass_top_rounded;
      case 'pending':
        return Icons.pending_actions_rounded;
      case 'failed':
      case 'rejected':
        return Icons.error_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'Transaction completed successfully';
      case 'processing':
        return 'Transaction is being processed';
      case 'pending':
        return 'Transaction is pending verification';
      case 'failed':
        return 'Transaction failed. Please contact support';
      case 'rejected':
        return 'Transaction was rejected by admin';
      default:
        return 'Status unknown';
    }
  }
}
