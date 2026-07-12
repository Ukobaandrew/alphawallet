import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'deposit_screen.dart';
import 'international_transfer_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';
import 'cards_screen.dart';
import 'investment_screen.dart';
import 'account_screen.dart';
import 'transfer_screen.dart';
import 'more_screen.dart';
import 'stats_screen.dart';
import 'exchange_screen.dart';
import 'alpha_users_screen.dart';
import 'withdraw_screen.dart';
import 'send_money_screen.dart';
import 'messages_screen.dart';
import 'help_support_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:intl/intl.dart';

// Design constants for OPay-like styling
const Color kPrimaryColor = Color(0xFF003366);
const Color kPrimaryLightColor = Color(0xFF004080);
const Color kPrimaryDarkColor = Color(0xFF002244);
const Color kAccentColor = Color(0xFF00D1C1);
const Color kBackgroundColor = Color(0xFFF5F7FA);
const Color kCardColor = Colors.white;
const Color kTextPrimaryColor = Color(0xFF1A2B3C);
const Color kTextSecondaryColor = Color(0xFF6B7B8C);
const Color kSuccessColor = Color(0xFF4CAF50);
const Color kWarningColor = Color(0xFFFF9800);
const Color kErrorColor = Color(0xFFF44336);

const double kDefaultPadding = 16.0;
const double kCardRadius = 24.0;
const double kSmallRadius = 12.0;
const double kButtonRadius = 16.0;

const TextStyle kAppBarTitleStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: Colors.white,
  letterSpacing: -0.3,
);

const TextStyle kCardTitleStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w700,
  color: kTextPrimaryColor,
  letterSpacing: -0.3,
);

const TextStyle kBodyTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kTextSecondaryColor,
  height: 1.4,
);

const TextStyle kAmountStyle = TextStyle(
  fontSize: 28,
  fontWeight: FontWeight.w800,
  color: Colors.white,
  letterSpacing: -0.5,
);

// Firestore collections
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Global success message function
void showSuccessMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      backgroundColor: kSuccessColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSmallRadius),
      ),
      elevation: 6,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(kDefaultPadding),
    ),
  );
}

class AlphaDashboard extends StatefulWidget {
  const AlphaDashboard({super.key});

  @override
  State<AlphaDashboard> createState() => _AlphaDashboardState();
}

class _AlphaDashboardState extends State<AlphaDashboard> {
  int _selectedIndex = 0;
  late Stream<DocumentSnapshot> _userDataStream;
  late Stream<QuerySnapshot> _transactionsStream;
  late Stream<QuerySnapshot> _notificationsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userDataStream =
          _firestore.collection('users').doc(user.uid).snapshots();
      _transactionsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots();
      _notificationsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots();
    }
  }

  Future<void> _refreshData() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: kPrimaryColor,
        backgroundColor: Colors.white,
        displacement: 40,
        edgeOffset: 20,
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: kPrimaryColor,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: kDefaultPadding),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileScreen(initialTab: 0),
              ),
            );
          },
          child: StreamBuilder<DocumentSnapshot>(
            stream: _userDataStream,
            builder: (context, snapshot) {
              final userData = snapshot.data?.data() as Map<String, dynamic>?;
              final name = userData?['name'] ??
                  FirebaseAuth.instance.currentUser?.displayName ??
                  '';
              return Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : FirebaseAuth.instance.currentUser?.email?[0]
                                .toUpperCase() ??
                            'A',
                    style: const TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      title: StreamBuilder<DocumentSnapshot>(
        stream: _userDataStream,
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final userName = userData?['name'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              FirebaseAuth.instance.currentUser?.email?.split('@').first ??
              'Customer';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        _buildNotificationButton(),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(kSmallRadius),
            ),
            child:
                const Icon(Icons.help_outline, color: Colors.white, size: 22),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
          ),
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(kSmallRadius),
            ),
            child: const Icon(Icons.qr_code_scanner,
                color: Colors.white, size: 22),
          ),
          onPressed: _scanQRCode,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildNotificationButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data?.docs.length ?? 0;
        return Stack(
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(kSmallRadius),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MessagesScreen()),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: kErrorColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kPrimaryColor, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    unreadCount > 9 ? '9+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: kPrimaryColor,
      unselectedItemColor: kTextSecondaryColor,
      currentIndex: _selectedIndex,
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      unselectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
      ),
      elevation: 8,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined, size: 24),
          activeIcon: Icon(Icons.home_filled, size: 24),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_outlined, size: 24),
          activeIcon: Icon(Icons.account_balance, size: 24),
          label: 'Accounts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.compare_arrows_outlined, size: 24),
          activeIcon: Icon(Icons.compare_arrows, size: 24),
          label: 'Transfer',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.credit_card_outlined, size: 24),
          activeIcon: Icon(Icons.credit_card, size: 24),
          label: 'Cards',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz_outlined, size: 24),
          activeIcon: Icon(Icons.more_horiz, size: 24),
          label: 'More',
        ),
      ],
    );
  }

  static final List<Widget> _widgetOptions = <Widget>[
    const HomeTab(),
    const AccountScreen(),
    const TransferScreen(),
    const CardsScreen(),
    const MoreScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _scanQRCode() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kCardRadius)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(kDefaultPadding),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 180,
                height: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: kPrimaryColor.withOpacity(0.1), width: 2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 80,
                      color: kPrimaryColor,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Scan QR Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Point your camera at a QR code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimaryColor,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'To pay or receive money instantly',
                style: TextStyle(
                  fontSize: 14,
                  color: kTextSecondaryColor,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showSuccessMessage(context, 'QR Code scanner activated');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kButtonRadius),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Activate Camera',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  bool _balanceVisible = true;
  late Stream<DocumentSnapshot> _userDataStream;
  late Stream<QuerySnapshot> _transactionsStream;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    final user = this.user;
    if (user != null) {
      _userDataStream =
          _firestore.collection('users').doc(user.uid).snapshots();
      _transactionsStream = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .snapshots();
    }
  }

  void _toggleBalanceVisibility() {
    setState(() {
      _balanceVisible = !_balanceVisible;
    });
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recently';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM dd').format(date);
      }
    } catch (e) {
      return 'Recently';
    }
  }

  String _formatBalance(double balance) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2)
        .format(balance);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _userDataStream,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: kPrimaryColor,
              strokeWidth: 3,
            ),
          );
        }

        if (userSnapshot.hasError || !userSnapshot.hasData) {
          return _buildErrorWidget();
        }

        final userData =
            userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        final balance = _safeDouble(userData['balance']);
        final accountNumber = userData['accountNumber']?.toString() ?? 'N/A';

        return StreamBuilder<QuerySnapshot>(
          stream: _transactionsStream,
          builder: (context, transactionSnapshot) {
            final transactions = transactionSnapshot.data?.docs ?? [];
            final recentTransactions = transactions.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final amount = _safeDouble(data['amount']);

              String title = data['description'] ?? 'Transaction';
              String type = data['transactionType'] ?? data['type'] ?? 'Other';
              IconData icon = Icons.receipt_rounded;
              Color color = kTextSecondaryColor;

              if (type.contains('Transfer')) {
                icon = Icons.account_balance_rounded;
                color = Colors.blue[700]!;
              } else if (type.contains('Deposit') || type == 'deposit') {
                icon = Icons.account_balance_wallet_rounded;
                color = kSuccessColor;
              } else if (type.contains('Withdrawal') || type == 'withdrawal') {
                icon = Icons.currency_exchange_rounded;
                color = kErrorColor;
              }

              return {
                'title': title,
                'amount': amount,
                'time': _formatTimestamp(data['timestamp']),
                'icon': icon,
                'color': color,
                'type': type,
              };
            }).toList();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: kDefaultPadding),
                  // Balance Card
                  _buildBalanceCard(balance, accountNumber),

                  // Quick Actions Grid
                  _buildQuickActionsGrid(),

                  // Quick Payment
                  _buildQuickPaymentSection(),

                  // Recent Transactions
                  _buildRecentTransactionsSection(recentTransactions),

                  // Promotional Banner
                  _buildPromotionalBanner(),

                  // Security Status
                  _buildSecurityStatus(),

                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceCard(double balance, String accountNumber) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            kPrimaryColor,
            kPrimaryLightColor,
            kPrimaryDarkColor,
          ],
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _balanceVisible ? _formatBalance(balance) : '••••••••',
                    style: kAmountStyle,
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _balanceVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 24,
                ),
                onPressed: _toggleBalanceVisibility,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Number',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            accountNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.copy_outlined,
                          color: Colors.white.withOpacity(0.8),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Alpha Bank • \$50,000 daily limit',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _addMoney,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: const Text(
                  'Add Money',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kButtonRadius),
                    side: BorderSide(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Container(
      margin: const EdgeInsets.all(kDefaultPadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: kCardTitleStyle,
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8, // 👈 ADD THIS
            children: [
              _buildQuickAction(
                icon: Icons.compare_arrows_rounded,
                label: 'Transfer',
                color: kPrimaryColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TransferScreen()),
                ),
              ),
              _buildQuickAction(
                icon: Icons.bar_chart_rounded,
                label: 'Stats',
                color: Colors.teal[700]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                ),
              ),
              _buildQuickAction(
                icon: Icons.credit_card_rounded,
                label: 'Cards',
                color: Colors.red[700]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CardsScreen()),
                ),
              ),
              _buildQuickAction(
                icon: Icons.currency_exchange_rounded,
                label: 'Exchange',
                color: kWarningColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ExchangeScreen()),
                ),
              ),
              _buildQuickAction(
                icon: Icons.trending_up_rounded,
                label: 'Invest',
                color: Colors.teal[700]!,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const InvestmentScreen()),
                ),
              ),
              _buildQuickAction(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                color: kTextSecondaryColor,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MoreScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPaymentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Payment',
            style: kCardTitleStyle,
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPaymentAction(
                  'To Bank',
                  Icons.account_balance_rounded,
                  kPrimaryColor,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SendMoneyScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                _buildPaymentAction(
                  'To Alpha',
                  Icons.person_rounded,
                  Colors.blue[700]!,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AlphaUsersScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                _buildPaymentAction(
                  'To Others',
                  Icons.language_rounded,
                  const Color.fromARGB(255, 126, 24, 170),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const InternationalTransferScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                _buildPaymentAction(
                  'Withdraw',
                  Icons.currency_exchange_rounded,
                  kSuccessColor,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WithdrawScreen()),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionsSection(
      List<Map<String, dynamic>> transactions) {
    return Container(
      margin: const EdgeInsets.all(kDefaultPadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: kCardTitleStyle,
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const TransactionsScreen()),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: kPrimaryColor,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (transactions.isNotEmpty)
            ...transactions.map((transaction) => _buildTransactionItem(
                  transaction['title'] as String,
                  _safeDouble(transaction['amount']),
                  transaction['time'] as String,
                  transaction['icon'] as IconData,
                  transaction['color'] as Color,
                  transaction['type'] as String,
                )),
          if (transactions.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.grey[300],
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transactions yet',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your transactions will appear here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const TransactionsScreen()),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: kPrimaryColor,
              side: BorderSide(color: kPrimaryColor.withOpacity(0.2)),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kButtonRadius),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionalBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kDefaultPadding),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            kPrimaryColor,
            kPrimaryLightColor,
          ],
        ),
        borderRadius: BorderRadius.circular(kCardRadius),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(kSmallRadius),
            ),
            child: const Icon(
              Icons.star_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Premium Banking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Upgrade your account for exclusive benefits',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showPremiumOptions,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStatus() {
    return Container(
      margin: const EdgeInsets.all(kDefaultPadding),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kCardRadius),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 0,
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
              color: kSuccessColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(kSmallRadius),
            ),
            child: const Icon(
              Icons.security_rounded,
              color: kSuccessColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Protection',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimaryColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your account is protected with 2FA',
                  style: TextStyle(
                    fontSize: 13,
                    color: kTextSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showSecurityDetails,
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: kTextSecondaryColor,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(kDefaultPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: kErrorColor,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kTextPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your internet connection',
              style: TextStyle(
                fontSize: 14,
                color: kTextSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  final user = this.user;
                  if (user != null) {
                    _userDataStream = _firestore
                        .collection('users')
                        .doc(user.uid)
                        .snapshots();
                    _transactionsStream = _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('transactions')
                        .orderBy('timestamp', descending: true)
                        .limit(5)
                        .snapshots();
                  }
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kButtonRadius),
                ),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentAction(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextPrimaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    String title,
    double amount,
    String date,
    IconData icon,
    Color color,
    String type,
  ) {
    final safeAmount = _safeDouble(amount);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 13,
                        color: kTextSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            safeAmount >= 0
                ? '+\$${safeAmount.toStringAsFixed(2)}'
                : '-\$${(-safeAmount).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: safeAmount >= 0 ? kSuccessColor : kErrorColor,
            ),
          ),
        ],
      ),
    );
  }

  void _addMoney() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DepositScreen()),
    );
  }

  void _scanQRCode() {
    showSuccessMessage(context, 'Opening QR scanner...');
  }

  void _showPremiumOptions() {
    showSuccessMessage(context, 'Showing premium options...');
  }

  void _showSecurityDetails() {
    showSuccessMessage(context, 'Showing security details...');
  }
}
