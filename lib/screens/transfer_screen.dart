import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'alpha_users_screen.dart';
import 'mobile_money_screen.dart';
import 'international_transfer_screen.dart';
import 'add_contact_screen.dart';
import 'send_money_screen.dart' as send_money;
import 'transaction_workflow_screen.dart' as workflow;
import 'transactions_screen.dart'; // Import the TransactionsScreen

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  List<RecentTransaction> _recentTransactions = [];
  bool _isLoading = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
  }

  Future<void> _loadRecentTransactions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(5) // Limit to 5 recent transactions
          .get();

      final List<RecentTransaction> loadedTransactions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        try {
          final amount = _safeDouble(data['amount']);
          final fee = _safeDouble(data['fee']);
          final totalAmount = amount + fee;

          // Determine transaction type and display text
          String displayText;
          IconData icon;
          Color color;

          if (data['transactionType'] != null) {
            // This is a transfer transaction
            final type = data['transactionType'] as String;
            final recipientName = data['recipientName'] ?? 'Unknown';

            displayText = type == 'Transfer' || type == 'Bank Transfer'
                ? 'Transfer to $recipientName'
                : '$type to $recipientName';

            icon = _getTransactionIcon(type);
            color = _getTransactionColor(type);
          } else {
            // Other transaction types
            displayText = data['title'] ?? 'Transaction';
            final category = data['category'] ?? 'General';
            icon = _getTransactionIcon(category);
            color = _getTransactionColor(category);
          }

          loadedTransactions.add(RecentTransaction(
            id: data['id'] ?? doc.id,
            name: displayText,
            amount: totalAmount,
            time: (data['timestamp'] as Timestamp).toDate(),
            status: data['status'] ?? 'Completed',
            icon: icon,
            color: color,
            isCredit: amount >= 0,
            recipientName: data['recipientName'],
            bankName: data['bankName'],
            transactionType: data['transactionType'],
          ));
        } catch (e) {
          debugPrint('Error parsing transaction ${doc.id}: $e');
        }
      }

      setState(() {
        _recentTransactions = loadedTransactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading recent transactions: $e');
      setState(() {
        _recentTransactions = [];
        _isLoading = false;
      });
    }
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value.isNaN ? 0.0 : value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    if (value is num) {
      final result = value.toDouble();
      return result.isNaN ? 0.0 : result;
    }
    return 0.0;
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'Bank Transfer':
      case 'Transfer':
        return Icons.account_balance_rounded;
      case 'Mobile Money':
        return Icons.phone_iphone_rounded;
      case 'Alpha Users':
        return Icons.people_rounded;
      case 'International':
        return Icons.language_rounded;
      case 'Deposit':
        return Icons.account_balance_wallet_rounded;
      case 'Withdrawal':
        return Icons.credit_card_rounded;
      case 'Payment':
        return Icons.payment_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Bills':
        return Icons.receipt_rounded;
      case 'Food':
        return Icons.restaurant_rounded;
      case 'Entertainment':
        return Icons.movie_rounded;
      case 'Transport':
        return Icons.directions_car_rounded;
      case 'Healthcare':
        return Icons.local_hospital_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color _getTransactionColor(String type) {
    switch (type) {
      case 'Bank Transfer':
      case 'Transfer':
        return Colors.blue[700]!;
      case 'Mobile Money':
        return Colors.green[700]!;
      case 'Alpha Users':
        return Colors.teal[700]!;
      case 'International':
        return Colors.purple[700]!;
      case 'Deposit':
        return Colors.indigo[700]!;
      case 'Withdrawal':
        return Colors.red[700]!;
      case 'Payment':
        return Colors.orange[700]!;
      case 'Shopping':
        return Colors.pink[700]!;
      case 'Bills':
        return Colors.purple[700]!;
      case 'Food':
        return Colors.amber[700]!;
      case 'Entertainment':
        return Colors.deepPurple[700]!;
      case 'Transport':
        return Colors.cyan[700]!;
      case 'Healthcare':
        return Colors.redAccent[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar with Gradient
            SliverAppBar(
              backgroundColor: const Color(0xFF003366),
              expandedHeight: 100,
              floating: true,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                title: Text(
                  'Transfer Money',
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF003366),
                        const Color(0xFF003366).withOpacity(0.95),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.only(bottom: 100), // Space for FAB
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Modern Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded,
                                color: Colors.grey[500], size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText:
                                      'Search contacts, banks, or phone...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                ),
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF003366),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _scanQRCode(context),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF003366),
                                      Color(0xFF0055AA),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF003366)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Transfer Section
                      _buildSectionHeader(
                        title: 'Quick Transfer',
                        action: 'Add New',
                        onAction: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddContactScreen(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Modern Contacts Carousel
                      SizedBox(
                        height: 130,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            const SizedBox(width: 4),
                            ..._buildContactItems(context),
                            _buildAddContactCard(context),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Transfer Services Section
                      _buildSectionHeader(
                        title: 'Transfer Services',
                        action: 'View All',
                        onAction: () {},
                      ),
                      const SizedBox(height: 16),

                      // Horizontal Scrollable Transfer Options
                      SizedBox(
                        height: 160, // Fixed height for horizontal scroll
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          children: [
                            const SizedBox(width: 4),
                            _buildModernServiceCard(
                              icon: Icons.account_balance_rounded,
                              title: 'Bank Transfer',
                              subtitle: 'Complete workflow',
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF003366),
                                  Color(0xFF0055AA),
                                ],
                              ),
                              onTap: () => _startBankTransfer(context),
                              cardWidth: 160, // Fixed width for cards
                            ),
                            const SizedBox(width: 12),
                            _buildModernServiceCard(
                              icon: Icons.people_rounded,
                              title: 'Alpha Users',
                              subtitle: 'Send instantly',
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue[700]!,
                                  Colors.blue[500]!,
                                ],
                              ),
                              onTap: () => _startAlphaTransfer(context),
                              cardWidth: 160,
                            ),
                            const SizedBox(width: 12),
                            _buildModernServiceCard(
                              icon: Icons.language_rounded,
                              title: 'International',
                              subtitle: 'Send abroad',
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.purple[700]!,
                                  Colors.purple[500]!,
                                ],
                              ),
                              onTap: () => _startInternationalTransfer(context),
                              cardWidth: 160,
                            ),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Recent Transactions Section
                      _buildSectionHeader(
                        title: 'Recent Transfers',
                        action: 'View All',
                        onAction: () => _navigateToTransactionsScreen(context),
                      ),
                      const SizedBox(height: 16),

                      // Modern Transaction Cards - Now from Firestore
                      if (_isLoading)
                        Container(
                          padding: const EdgeInsets.all(40),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF003366),
                            ),
                          ),
                        )
                      else if (_recentTransactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No recent transactions',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Make your first transfer to see it here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._buildModernTransactionCards(context),
                      const SizedBox(height: 24),

                      // Security Features Card
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF003366).withOpacity(0.95),
                              const Color(0xFF0055AA).withOpacity(0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF003366).withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () => _showSecurityInfo(context),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text(
                                          'Bank-Level Security',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '256-bit encryption & real-time monitoring',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                Colors.white.withOpacity(0.9),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showTransferOptions(context),
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
              Icons.send_rounded,
              color: Color(0xFF003366),
              size: 16,
            ),
          ),
          label: const Text(
            'New Transfer',
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

  // Modern Section Header
  Widget _buildSectionHeader({
    required String title,
    required String action,
    required VoidCallback onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF003366),
            letterSpacing: -0.5,
          ),
        ),
        GestureDetector(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF003366).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              action,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Modern Contact Items - UPDATED to use new workflow
  List<Widget> _buildContactItems(BuildContext context) {
    final contacts = [
      {
        'name': 'John Doe',
        'initials': 'JD',
        'phone': '+1234567890',
        'isFavorite': true,
        'color': Colors.blue[700]!,
        'type': 'Bank Transfer',
        'bank': 'Alpha Bank',
      },
      {
        'name': 'Sarah Smith',
        'initials': 'SS',
        'phone': '+1987654321',
        'isFavorite': false,
        'color': Colors.purple[700]!,
        'type': 'Mobile Money',
        'bank': 'MTN Mobile',
      },
      {
        'name': 'Mike Johnson',
        'initials': 'MJ',
        'phone': '+1122334455',
        'isFavorite': true,
        'color': Colors.green[700]!,
        'type': 'Alpha Users',
        'bank': 'Alpha Bank',
      },
      {
        'name': 'Emma Wilson',
        'initials': 'EW',
        'phone': '+1555666777',
        'isFavorite': false,
        'color': Colors.orange[700]!,
        'type': 'Bank Transfer',
        'bank': 'City Bank',
      },
    ];

    return contacts.map((contact) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: GestureDetector(
          onTap: () => _startQuickTransfer(
            context,
            contact['name']! as String,
            contact['phone']! as String,
            contact['type']! as String,
            contact['bank']! as String,
          ),
          child: SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              contact['color']! as Color,
                              (contact['color']! as Color).withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            contact['initials']! as String,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (contact['isFavorite']! as bool)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    contact['name']! as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact['type']! as String,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003366).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Send Now',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003366),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // Modern Add Contact Card
  Widget _buildAddContactCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddContactScreen(),
            ),
          );
        },
        child: SizedBox(
          width: 100,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF003366).withOpacity(0.2),
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Color(0xFF003366),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Beneficiary',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Modern Service Card - UPDATED for horizontal scrolling
  Widget _buildModernServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
    double cardWidth = 160,
  }) {
    return SizedBox(
      width: cardWidth,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.colors.first.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003366),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Container(
                      height: 28,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            gradient.colors.first.withOpacity(0.1),
                            gradient.colors.first.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: gradient.colors.first.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Transfer Now',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: gradient.colors.first,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Modern Transaction Cards - Now using data from Firestore
  List<Widget> _buildModernTransactionCards(BuildContext context) {
    return _recentTransactions.map((transaction) {
      final displayAmount = transaction.isCredit
          ? '+\$${_safeDouble(transaction.amount).toStringAsFixed(2)}'
          : '-\$${_safeDouble(transaction.amount.abs()).toStringAsFixed(2)}';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => _showTransactionDetails(context, transaction),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: transaction.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  transaction.icon,
                  color: transaction.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      transaction.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003366),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRelativeTime(transaction.time),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayAmount,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: transaction.isCredit
                          ? Colors.green[700]
                          : const Color(0xFFE53935),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: transaction.status == 'Completed'
                          ? Colors.green[50]
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      transaction.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: transaction.status == 'Completed'
                            ? Colors.green[700]
                            : Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${difference.inDays ~/ 7}w ago';
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }

  // Navigation to TransactionsScreen - FIXED VERSION
  void _navigateToTransactionsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TransactionsScreen(),
      ),
    );
  }

  // NEW METHODS FOR TRANSACTION WORKFLOW

  void _startBankTransfer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const send_money.SendMoneyScreen(),
      ),
    );
  }

  void _startAlphaTransfer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AlphaUsersScreen(),
      ),
    );
  }

  void _startMobileMoneyTransfer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MobileMoneyScreen(),
      ),
    );
  }

  void _startInternationalTransfer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InternationalTransferScreen(),
      ),
    );
  }

  void _startQuickTransfer(
    BuildContext context,
    String name,
    String phone,
    String type,
    String bankName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => workflow.AmountInputScreen(
          recipientName: name,
          recipientAccount: phone,
          transactionType: type,
          bankName: bankName,
        ),
      ),
    );
  }

  // Navigation Functions (existing)
  void _scanQRCode(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
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
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'QR Code Scanner',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Place QR code within frame to scan',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Start transaction with QR code data
                  _startQuickTransfer(
                    context,
                    'QR Code User',
                    '+1234567890',
                    'QR Transfer',
                    'QR Bank',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  elevation: 4,
                ),
                child: const Text(
                  'Simulate Scan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showTransactionDetails(
      BuildContext context, RecentTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        final displayAmount = transaction.isCredit
            ? '+\$${_safeDouble(transaction.amount).toStringAsFixed(2)}'
            : '-\$${_safeDouble(transaction.amount.abs()).toStringAsFixed(2)}';

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaction Details',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: transaction.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        transaction.icon,
                        color: transaction.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003366),
                            ),
                          ),
                          Text(
                            _formatRelativeTime(transaction.time),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      displayAmount,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: transaction.isCredit
                            ? Colors.green[700]
                            : const Color(0xFFE53935),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildDetailItem('Transaction ID', transaction.id),
              _buildDetailItem('Status', transaction.status),
              if (transaction.recipientName != null)
                _buildDetailItem('Recipient', transaction.recipientName!),
              if (transaction.bankName != null)
                _buildDetailItem('Bank', transaction.bankName!),
              _buildDetailItem(
                  'Date', DateFormat('dd/MM/yyyy').format(transaction.time)),
              _buildDetailItem(
                  'Time', DateFormat('HH:mm').format(transaction.time)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Start new transfer to same recipient
                    if (transaction.recipientName != null) {
                      _startQuickTransfer(
                        context,
                        transaction.recipientName!,
                        'N/A',
                        transaction.transactionType ?? 'Transfer',
                        transaction.bankName ?? 'Bank',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Repeat Transfer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
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

  void _showSecurityInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Security Features',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSecurityFeature(
                icon: Icons.verified_user_rounded,
                title: '256-bit Encryption',
                subtitle: 'Bank-level security for all transactions',
              ),
              _buildSecurityFeature(
                icon: Icons.fingerprint_rounded,
                title: 'Biometric Authentication',
                subtitle: 'Secure login with fingerprint or face ID',
              ),
              _buildSecurityFeature(
                icon: Icons.shield_rounded,
                title: 'Real-time Monitoring',
                subtitle: '24/7 fraud detection and prevention',
              ),
              _buildSecurityFeature(
                icon: Icons.enhanced_encryption_rounded,
                title: 'PCI DSS Compliant',
                subtitle: 'Meets highest security standards',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecurityFeature({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF003366).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF003366),
              size: 24,
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
                const SizedBox(height: 4),
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
        ],
      ),
    );
  }

  void _showTransferOptions(BuildContext context) {
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
                'New Transfer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Choose transfer type',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              _buildTransferOption(
                icon: Icons.account_balance_rounded,
                title: 'Bank Transfer',
                subtitle: 'Send to any bank account',
                onTap: () {
                  Navigator.pop(context);
                  _startBankTransfer(context);
                },
              ),
              _buildTransferOption(
                icon: Icons.people_rounded,
                title: 'Alpha Users',
                subtitle: 'Send to Alpha Bank customers',
                onTap: () {
                  Navigator.pop(context);
                  _startAlphaTransfer(context);
                },
              ),
              _buildTransferOption(
                icon: Icons.phone_iphone_rounded,
                title: 'Mobile Money',
                subtitle: 'Send to mobile wallets',
                onTap: () {
                  Navigator.pop(context);
                  _startMobileMoneyTransfer(context);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransferOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
                color: const Color(0xFF003366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF003366),
                size: 24,
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
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
}

// Recent Transaction Model for TransferScreen
class RecentTransaction {
  final String id;
  final String name;
  final double amount;
  final DateTime time;
  final String status;
  final IconData icon;
  final Color color;
  final bool isCredit;
  final String? recipientName;
  final String? bankName;
  final String? transactionType;

  RecentTransaction({
    required this.id,
    required this.name,
    required this.amount,
    required this.time,
    required this.status,
    required this.icon,
    required this.color,
    required this.isCredit,
    this.recipientName,
    this.bankName,
    this.transactionType,
  });
}
