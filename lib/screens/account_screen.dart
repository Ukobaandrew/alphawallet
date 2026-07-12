import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _isBalanceVisible = true;
  String _sortBy = 'Default';
  List<Map<String, dynamic>> _accounts = [];
  bool _isLoading = true;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NumberFormat _currencyFormat =
      NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Load main account from user document
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final userData = userDoc.data()!;

        final mainAccount = {
          'id': 'primary',
          'title': 'Alpha Bank Account',
          'accountNumber': userData['accountNumber']?.toString() ?? 'ALPHA001',
          'balance': (userData['balance'] ?? userData['accountBalance'] ?? 0.0)
              .toDouble(),
          'currencyCode': 'USD',
          'available':
              (userData['balance'] ?? userData['accountBalance'] ?? 0.0)
                  .toDouble(),
          'gradientColors': [
            const Color(0xFF003366),
            const Color(0xFF0055AA),
          ],
          'isPrimary': true,
          'icon': Icons.attach_money_rounded,
          'status': 'Active',
          'openedDate': _formatDate(userData['createdAt']),
          'interestRate': '1.5%',
          'lastTransaction': 'Recently',
          'type': 'checking',
        };

        // Load additional accounts from accounts subcollection
        final accountsSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .get();

        final additionalAccounts = accountsSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Account',
            'accountNumber':
                data['accountNumber'] ?? 'ACC${doc.id.substring(0, 8)}',
            'balance': (data['balance'] ?? 0.0).toDouble(),
            'currencyCode': data['currencyCode'] ?? 'USD',
            'available':
                (data['available'] ?? data['balance'] ?? 0.0).toDouble(),
            'gradientColors':
                _getAccountGradient(data['currencyCode'] ?? 'USD'),
            'isPrimary': data['isPrimary'] ?? false,
            'icon': _getCurrencyIcon(data['currencyCode'] ?? 'USD'),
            'status': data['status'] ?? 'Active',
            'openedDate': _formatDate(data['openedDate']),
            'interestRate': data['interestRate'] ?? '1.2%',
            'lastTransaction': data['lastTransaction'] ?? 'No transactions',
            'type': data['type'] ?? 'checking',
          };
        }).toList();

        setState(() {
          _accounts = [mainAccount, ...additionalAccounts];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading accounts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Color> _getAccountGradient(String currencyCode) {
    switch (currencyCode) {
      case 'GBP':
        return [Colors.green[800]!, Colors.green[600]!];
      case 'EUR':
        return [Colors.blueGrey[800]!, Colors.blueGrey[600]!];
      case 'NGN':
        return [Colors.green[700]!, Colors.green[500]!];
      default:
        return [const Color(0xFF003366), const Color(0xFF0055AA)];
    }
  }

  IconData _getCurrencyIcon(String currencyCode) {
    switch (currencyCode) {
      case 'GBP':
        return Icons.currency_pound_rounded;
      case 'EUR':
        return Icons.euro_rounded;
      case 'NGN':
        return Icons.currency_exchange_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      if (timestamp is Timestamp) {
        return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }
    return 'Recently';
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _isBalanceVisible = !_isBalanceVisible;
    });
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sort Accounts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 20),
              _buildSortOption('Default', Icons.sort_by_alpha_rounded),
              _buildSortOption(
                  'Balance: High to Low', Icons.arrow_downward_rounded),
              _buildSortOption(
                  'Balance: Low to High', Icons.arrow_upward_rounded),
              _buildSortOption('Account Name: A-Z', Icons.text_format_rounded),
              _buildSortOption('Currency', Icons.currency_exchange_rounded),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String option, IconData icon) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = option;
          _sortAccounts(option);
        });
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _sortBy == option
                ? const Color(0xFF003366)
                : Colors.grey.withOpacity(0.1),
            width: _sortBy == option ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF003366),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
              ),
            ),
            if (_sortBy == option)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF003366),
              ),
          ],
        ),
      ),
    );
  }

  void _sortAccounts(String option) {
    final accountsCopy = List<Map<String, dynamic>>.from(_accounts);

    switch (option) {
      case 'Balance: High to Low':
        accountsCopy.sort((a, b) => b['balance'].compareTo(a['balance']));
        break;
      case 'Balance: Low to High':
        accountsCopy.sort((a, b) => a['balance'].compareTo(b['balance']));
        break;
      case 'Account Name: A-Z':
        accountsCopy.sort((a, b) => a['title'].compareTo(b['title']));
        break;
      case 'Currency':
        accountsCopy
            .sort((a, b) => a['currencyCode'].compareTo(b['currencyCode']));
        break;
      default:
        // Primary account first, then others
        accountsCopy.sort((a, b) {
          if (a['isPrimary'] && !b['isPrimary']) return -1;
          if (!a['isPrimary'] && b['isPrimary']) return 1;
          return 0;
        });
    }

    setState(() {
      _accounts = accountsCopy;
    });
  }

  String _formatCurrency(double amount, String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'GBP':
        return '£${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'NGN':
        return '₦${NumberFormat('#,##0').format(amount)}';
      default:
        return '\$${amount.toStringAsFixed(2)}';
    }
  }

  double get _totalBalance {
    return _accounts.fold(0.0, (sum, account) => sum + account['balance']);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFD),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF003366),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF003366),
            expandedHeight: 120,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
              title: Text(
                'My Accounts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF003366),
                      Color(0xFF0055AA),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                onPressed: () {
                  _showOpenAccountModal(context);
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  // Total Balance Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
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
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF003366).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Balance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                            IconButton(
                              onPressed: _toggleBalanceVisibility,
                              icon: Icon(
                                _isBalanceVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              _isBalanceVisible
                                  ? '\$${_totalBalance.toStringAsFixed(2)}'
                                  : '••••••••',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_accounts.length} Account${_accounts.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _accounts
                                .map((account) => Padding(
                                      padding: const EdgeInsets.only(right: 20),
                                      child: _buildBalanceDetail(
                                        account['currencyCode'],
                                        _isBalanceVisible
                                            ? _formatCurrency(
                                                account['balance'],
                                                account['currencyCode'],
                                              )
                                            : '••••••',
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Accounts Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'All Accounts',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF003366),
                            letterSpacing: -0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showSortOptions(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF003366).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 16,
                                  color: Color(0xFF003366),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Sort',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Account Cards
          if (_accounts.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(32),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Accounts Found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your accounts will appear here',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _showOpenAccountModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                      child: const Text('Open Your First Account'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final account = _accounts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: _buildModernAccountCard(
                        account: account,
                        isBalanceVisible: _isBalanceVisible,
                      ),
                    );
                  },
                  childCount: _accounts.length,
                ),
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {
            _showOpenAccountModal(context);
          },
          backgroundColor: const Color(0xFF003366),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 8,
          icon: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Color(0xFF003366),
              size: 16,
            ),
          ),
          label: const Text(
            'Open Account',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBalanceDetail(String currency, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currency,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildModernAccountCard({
    required Map<String, dynamic> account,
    required bool isBalanceVisible,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Card Header with Gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: account['gradientColors'] as List<Color>,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              account['icon'] as IconData,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account['title'] as String,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                account['currencyCode'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (account['isPrimary'] as bool)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Number
                  Text(
                    account['accountNumber'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 1.2,
                      fontFamily: 'Courier',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Balance
                  Text(
                    isBalanceVisible
                        ? _formatCurrency(
                            account['balance'] as double,
                            account['currencyCode'] as String,
                          )
                        : '••••••••',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Card Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Account Details
                  Row(
                    children: [
                      Expanded(
                        child: _buildAccountDetail(
                          'Available',
                          isBalanceVisible
                              ? _formatCurrency(
                                  account['available'] as double,
                                  account['currencyCode'] as String,
                                )
                              : '••••••',
                          Icons.account_balance_wallet_rounded,
                          Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _buildAccountDetail(
                          'Status',
                          account['status'] as String,
                          Icons.check_circle_rounded,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildAccountActionButton(
                          'View Details',
                          Icons.remove_red_eye_rounded,
                          () {
                            _showAccountDetails(context, account);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildAccountActionButton(
                          'Transactions',
                          Icons.history_rounded,
                          () {
                            _viewTransactions(context, account);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountDetail(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed, {
    bool primary = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            primary ? const Color(0xFF003366) : Colors.grey.withOpacity(0.1),
        foregroundColor: primary ? Colors.white : const Color(0xFF003366),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: primary ? 4 : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primary ? Colors.white : const Color(0xFF003366),
            ),
          ),
        ],
      ),
    );
  }

  void _showOpenAccountModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Open New Account',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose account type to open',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              _buildAccountTypeOption(
                'US Dollar Account',
                'Open USD account',
                Icons.attach_money_rounded,
                Colors.blue,
                () {
                  Navigator.pop(context);
                  _showAccountOpeningDialog(context, 'US Dollar', 'USD');
                },
              ),
              _buildAccountTypeOption(
                'Pound Sterling Account',
                'Open GBP account',
                Icons.currency_pound_rounded,
                Colors.green,
                () {
                  Navigator.pop(context);
                  _showAccountOpeningDialog(context, 'Pound Sterling', 'GBP');
                },
              ),
              _buildAccountTypeOption(
                'Euro Account',
                'Open EUR account',
                Icons.euro_rounded,
                Colors.blueGrey,
                () {
                  Navigator.pop(context);
                  _showAccountOpeningDialog(context, 'Euro', 'EUR');
                },
              ),
              _buildAccountTypeOption(
                'Naira Account',
                'Open NGN account',
                Icons.currency_exchange_rounded,
                Colors.green[700]!,
                () {
                  Navigator.pop(context);
                  _showAccountOpeningDialog(context, 'Naira', 'NGN');
                },
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
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
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountTypeOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountOpeningDialog(
      BuildContext context, String currency, String code) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Open $currency Account',
            style: const TextStyle(
              color: Color(0xFF003366),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are opening a new $currency ($code) account.'),
              const SizedBox(height: 16),
              const Text('• No opening fees'),
              const SizedBox(height: 8),
              const Text('• Instant activation'),
              const SizedBox(height: 8),
              const Text('• Digital statements'),
              const SizedBox(height: 8),
              const Text('• 24/7 customer support'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showAccountOpeningConfirmation(context, currency, code);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Open Account'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAccountOpeningConfirmation(
      BuildContext context, String currency, String code) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newAccountNumber = _generateAccountNumber(code);
    final newAccount = {
      'title': '$currency Account',
      'accountNumber': newAccountNumber,
      'balance': 0.0,
      'currencyCode': code,
      'available': 0.0,
      'isPrimary': false,
      'status': 'Active',
      'openedDate': FieldValue.serverTimestamp(),
      'interestRate': '1.2%',
      'lastTransaction': 'No transactions yet',
      'type': 'checking',
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .add(newAccount);

      // Refresh accounts list
      await _loadAccounts();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Column(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 60,
                ),
                SizedBox(height: 10),
                Text(
                  'Account Opened!',
                  style: TextStyle(
                    color: Color(0xFF003366),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your new $currency account has been created successfully.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Account Number:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        newAccountNumber,
                        style: const TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessMessage(
                      context, '$currency account opened successfully!');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('Error opening account: $e');
      _showErrorMessage(context, 'Failed to open account. Please try again.');
    }
  }

  String _generateAccountNumber(String currencyCode) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = (timestamp % 100000).toString().padLeft(5, '0');

    switch (currencyCode) {
      case 'USD':
        return 'USD-$randomPart${DateTime.now().millisecondsSinceEpoch.toString().substring(9, 12)}';
      case 'GBP':
        return 'GBP-$randomPart${DateTime.now().millisecondsSinceEpoch.toString().substring(9, 12)}';
      case 'EUR':
        return 'EUR-$randomPart${DateTime.now().millisecondsSinceEpoch.toString().substring(9, 12)}';
      case 'NGN':
        return 'NGN-$randomPart${DateTime.now().millisecondsSinceEpoch.toString().substring(9, 12)}';
      default:
        return 'ACC-$randomPart${DateTime.now().millisecondsSinceEpoch.toString().substring(9, 12)}';
    }
  }

  void _showAccountDetails(BuildContext context, Map<String, dynamic> account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: account['gradientColors'] as List<Color>,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    account['icon'] as IconData,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  account['title'] as String,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF003366),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  account['accountNumber'] as String,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontFamily: 'Courier',
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildDetailRow(
                  'Account Balance',
                  _formatCurrency(account['balance'] as double,
                      account['currencyCode'] as String)),
              _buildDetailRow(
                  'Available Balance',
                  _formatCurrency(account['available'] as double,
                      account['currencyCode'] as String)),
              _buildDetailRow('Currency', account['currencyCode'] as String),
              _buildDetailRow('Status', account['status'] as String),
              _buildDetailRow('Opened Date', account['openedDate'] as String),
              _buildDetailRow(
                  'Interest Rate', account['interestRate'] as String),
              _buildDetailRow(
                  'Last Transaction', account['lastTransaction'] as String),
              const SizedBox(height: 30),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF003366),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _viewTransactions(BuildContext context, Map<String, dynamic> account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            children: [
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '${account['title']} Transactions',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                account['accountNumber'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('users')
                      .doc(_auth.currentUser!.uid)
                      .collection('transactions')
                      .where('accountNumber',
                          isEqualTo: account['accountNumber'])
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No transactions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF003366),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Transactions will appear here',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final transactions = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final transaction =
                            transactions[index].data() as Map<String, dynamic>;
                        final amount =
                            (transaction['amount'] ?? 0.0).toDouble();
                        final description =
                            transaction['description'] ?? 'Transaction';
                        final timestamp =
                            transaction['timestamp'] as Timestamp?;
                        final type = transaction['type'] ?? 'other';

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: amount >= 0
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              amount >= 0
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: amount >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            description,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            timestamp != null
                                ? DateFormat('MMM dd, yyyy • HH:mm')
                                    .format(timestamp.toDate())
                                : 'Recently',
                          ),
                          trailing: Text(
                            _formatCurrency(amount, account['currencyCode']),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: amount >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF003366),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        elevation: 4,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
