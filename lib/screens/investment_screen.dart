import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key});

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _userId;
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Overview, 1: Invest, 2: Portfolio

  List<InvestmentPlan> _plans = [];
  List<PortfolioItem> _portfolio = [];
  Map<String, dynamic> _userData = {};
  double _availableBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _userId = user.uid;

      // Load user document
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
        _availableBalance = (_userData['balance'] ?? 0.0).toDouble();
      }

      // Load investment plans and portfolio
      await _loadInvestmentPlans();
      await _loadPortfolio();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInvestmentPlans() async {
    try {
      final plansSnapshot =
          await _firestore.collection('investment_plans').get();

      if (plansSnapshot.docs.isNotEmpty) {
        _plans = plansSnapshot.docs.map((doc) {
          final data = doc.data();
          return InvestmentPlan(
            id: doc.id,
            name: data['name'] ?? 'Unnamed Plan',
            description: data['description'] ?? 'No description',
            minAmount: (data['minAmount'] ?? 0.0).toDouble(),
            maxAmount: (data['maxAmount'] ?? 1000000.0).toDouble(),
            expectedReturn: (data['expectedReturn'] ?? 0.0).toDouble(),
            duration: data['duration'] ?? 365,
            riskLevel: _parseRiskLevel(data['riskLevel'] ?? 'low'),
            icon: _getIconData(data['icon'] ?? 'savings'),
            iconColor: _parseColor(data['iconColor'] ?? '#003366'),
            commission: (data['commission'] ?? 0.0).toDouble(),
            earlyWithdrawalPenalty:
                (data['earlyWithdrawalPenalty'] ?? 0.0).toDouble(),
            isActive: data['isActive'] ?? true,
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();
      } else {
        // Create sample plans if none exist
        await _createSamplePlans();
        await _loadInvestmentPlans();
      }
    } catch (e) {
      print('Error loading investment plans: $e');
      // Fallback to local plans
      _loadLocalPlans();
    }
  }

  Future<void> _createSamplePlans() async {
    try {
      final samplePlans = [
        {
          'name': 'Alpha Saver',
          'description': 'Low risk, steady returns with guaranteed principal',
          'minAmount': 100.0,
          'maxAmount': 10000.0,
          'expectedReturn': 10.5,
          'duration': 365,
          'riskLevel': 'low',
          'icon': 'savings',
          'iconColor': '#2196F3',
          'commission': 0.5,
          'earlyWithdrawalPenalty': 2.0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Growth Plus',
          'description': 'Medium risk with higher returns for growth investors',
          'minAmount': 500.0,
          'maxAmount': 50000.0,
          'expectedReturn': 18.2,
          'duration': 730,
          'riskLevel': 'medium',
          'icon': 'trending_up',
          'iconColor': '#4CAF50',
          'commission': 1.0,
          'earlyWithdrawalPenalty': 5.0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Premium Yield',
          'description': 'High risk, maximum returns for experienced investors',
          'minAmount': 2500.0,
          'maxAmount': 100000.0,
          'expectedReturn': 25.8,
          'duration': 1095,
          'riskLevel': 'high',
          'icon': 'rocket',
          'iconColor': '#9C27B0',
          'commission': 1.5,
          'earlyWithdrawalPenalty': 10.0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Fixed Deposit',
          'description': 'Guaranteed fixed returns with FDIC insurance',
          'minAmount': 250.0,
          'maxAmount': 25000.0,
          'expectedReturn': 12.0,
          'duration': 180,
          'riskLevel': 'low',
          'icon': 'account_balance',
          'iconColor': '#FF9800',
          'commission': 0.0,
          'earlyWithdrawalPenalty': 0.0,
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      ];

      for (final plan in samplePlans) {
        await _firestore.collection('investment_plans').add(plan);
      }
    } catch (e) {
      print('Error creating sample plans: $e');
    }
  }

  void _loadLocalPlans() {
    setState(() {
      _plans = [
        InvestmentPlan(
          id: '1',
          name: 'Alpha Saver',
          description: 'Low risk, steady returns',
          minAmount: 100.00,
          maxAmount: 10000.00,
          expectedReturn: 10.5,
          duration: 365,
          riskLevel: RiskLevel.low,
          icon: Icons.savings_rounded,
          iconColor: Colors.blue[700]!,
          commission: 0.5,
          earlyWithdrawalPenalty: 2.0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        InvestmentPlan(
          id: '2',
          name: 'Growth Plus',
          description: 'Medium risk, higher returns',
          minAmount: 500.00,
          maxAmount: 50000.00,
          expectedReturn: 18.2,
          duration: 730,
          riskLevel: RiskLevel.medium,
          icon: Icons.trending_up_rounded,
          iconColor: Colors.green[700]!,
          commission: 1.0,
          earlyWithdrawalPenalty: 5.0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        InvestmentPlan(
          id: '3',
          name: 'Premium Yield',
          description: 'High risk, maximum returns',
          minAmount: 2500.00,
          maxAmount: 100000.00,
          expectedReturn: 25.8,
          duration: 1095,
          riskLevel: RiskLevel.high,
          icon: Icons.rocket_launch_rounded,
          iconColor: Colors.purple[700]!,
          commission: 1.5,
          earlyWithdrawalPenalty: 10.0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        InvestmentPlan(
          id: '4',
          name: 'Fixed Deposit',
          description: 'Guaranteed returns',
          minAmount: 250.00,
          maxAmount: 25000.00,
          expectedReturn: 12.0,
          duration: 180,
          riskLevel: RiskLevel.low,
          icon: Icons.account_balance_rounded,
          iconColor: Colors.orange[700]!,
          commission: 0.0,
          earlyWithdrawalPenalty: 0.0,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      ];
    });
  }

  Future<void> _loadPortfolio() async {
    try {
      final portfolioSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('investments')
          .orderBy('investedAt', descending: true)
          .get();

      _portfolio = portfolioSnapshot.docs.map((doc) {
        final data = doc.data();
        final investedAt = (data['investedAt'] as Timestamp).toDate();
        final maturityDate =
            investedAt.add(Duration(days: data['duration'] ?? 365));

        // Calculate current value based on time elapsed and expected return
        final daysElapsed = DateTime.now().difference(investedAt).inDays;
        final totalDays = data['duration'] ?? 365;
        final progress = daysElapsed / totalDays;
        final expectedReturn = data['expectedReturn'] ?? 0.0;

        final investedAmount = (data['amount'] ?? 0.0).toDouble();
        final commission = (data['commission'] ?? 0.0).toDouble();
        final netAmount = investedAmount * (1 - commission / 100);

        // Calculate returns (simple interest for now)
        final returns =
            netAmount * expectedReturn / 100 * (progress > 1 ? 1 : progress);
        final currentValue = netAmount + returns;
        final returnPercentage = (returns / netAmount) * 100;

        return PortfolioItem(
          id: doc.id,
          planName: data['planName'] ?? 'Unknown Plan',
          planId: data['planId'] ?? '',
          investedAmount: investedAmount,
          netAmount: netAmount,
          currentValue: currentValue,
          returns: returns,
          returnPercentage: returnPercentage,
          startDate: investedAt,
          maturityDate: maturityDate,
          status: _parsePortfolioStatus(data['status'] ?? 'active'),
          expectedReturn: expectedReturn,
          transactionId: data['transactionId'] ?? '',
          withdrawableAmount: data['withdrawableAmount'] ?? 0.0,
          lastUpdated:
              (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Error loading portfolio: $e');
    }
  }

  Future<void> _investInPlan(InvestmentPlan plan) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => InvestmentBottomSheet(
        plan: plan,
        availableBalance: _availableBalance,
        userId: _userId,
        firestore: _firestore,
        onInvestmentComplete: _handleInvestmentComplete,
      ),
    );

    if (result == true) {
      await _loadUserData(); // Refresh data
      setState(() {
        _selectedTab = 2; // Switch to portfolio tab
      });
    }
  }

  Future<void> _handleInvestmentComplete() async {
    await _loadUserData();
    _showSuccessMessage('Investment successful!');
  }

  Future<void> _withdrawEarnings() async {
    final totalWithdrawable =
        _portfolio.fold(0.0, (sum, item) => sum + item.withdrawableAmount);

    if (totalWithdrawable <= 0) {
      _showErrorMessage('No earnings available for withdrawal');
      return;
    }

    final result = await showDialog(
      context: context,
      builder: (context) => WithdrawEarningsDialog(
        portfolio: _portfolio,
        userId: _userId,
        firestore: _firestore,
      ),
    );

    if (result == true) {
      await _loadUserData();
      _showSuccessMessage('Withdrawal successful!');
    }
  }

  Future<void> _viewInvestmentHistory() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvestmentHistoryScreen(
          userId: _userId,
          firestore: _firestore,
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
        ),
      );
    }

    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF003366).withOpacity(0.05),
                    const Color(0xFF004080).withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Header
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20),
                              color: const Color(0xFF003366),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Investments',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.history_rounded,
                                color: Color(0xFF003366)),
                            onPressed: _viewInvestmentHistory,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _buildTabButton('Overview', 0)),
                          Expanded(child: _buildTabButton('Invest', 1)),
                          Expanded(child: _buildTabButton('Portfolio', 2)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Content based on selected tab
                    if (_selectedTab == 0) _buildOverviewTab(),
                    if (_selectedTab == 1) _buildInvestTab(),
                    if (_selectedTab == 2) _buildPortfolioTab(),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2)),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF003366) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final totalInvestment =
        _portfolio.fold(0.0, (sum, item) => sum + item.investedAmount);
    final totalReturns =
        _portfolio.fold(0.0, (sum, item) => sum + item.returns);
    final totalValue =
        _portfolio.fold(0.0, (sum, item) => sum + item.currentValue);
    final growthPercentage =
        totalInvestment > 0 ? (totalReturns / totalInvestment) * 100 : 0;

    return Column(
      children: [
        // Investment Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF003366),
                Color(0xFF004080),
                Color(0xFF0055AA),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003366).withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Investment Summary',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '\$${totalValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total Portfolio Value',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryStat('Total Invested',
                      '\$${totalInvestment.toStringAsFixed(2)}', Colors.white),
                  _buildSummaryStat(
                      'Total Returns',
                      '+\$${totalReturns.toStringAsFixed(2)}',
                      Colors.green[200]!),
                  _buildSummaryStat(
                      'Growth',
                      '${growthPercentage.toStringAsFixed(1)}%',
                      Colors.green[200]!),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Quick Stats
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 16),
              _buildStatRow('Available Balance',
                  '\$${_availableBalance.toStringAsFixed(2)}'),
              _buildStatRow('Active Investments', '${_portfolio.length} plans'),
              _buildStatRow('Average Return',
                  '${_calculateAverageReturn().toStringAsFixed(1)}% p.a.'),
              _buildStatRow('Best Performing', _getBestPerformingPlan()),
              _buildStatRow('Next Payout', _getNextPayoutDate()),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Recommended Plans
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recommended Plans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003366),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedTab = 1),
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
            ..._plans
                .where((plan) => plan.isActive)
                .take(2)
                .map((plan) => _buildPlanCard(plan)),
          ],
        ),

        const SizedBox(height: 20),

        // Investment Tips
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue[100]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Investment Tip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Diversify your investments across different plans to minimize risk and maximize returns.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
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

  double _calculateAverageReturn() {
    if (_portfolio.isEmpty) return 0.0;
    final total =
        _portfolio.fold(0.0, (sum, item) => sum + item.returnPercentage);
    return total / _portfolio.length;
  }

  String _getBestPerformingPlan() {
    if (_portfolio.isEmpty) return 'None';
    final best = _portfolio
        .reduce((a, b) => a.returnPercentage > b.returnPercentage ? a : b);
    return '${best.planName} (${best.returnPercentage.toStringAsFixed(1)}%)';
  }

  String _getNextPayoutDate() {
    if (_portfolio.isEmpty) return 'No active investments';

    final now = DateTime.now();
    final upcoming = _portfolio
        .where((item) => item.maturityDate.isAfter(now))
        .map((item) => item.maturityDate)
        .toList();

    if (upcoming.isEmpty) return 'No upcoming payouts';

    final nextPayout = upcoming.reduce((a, b) => a.isBefore(b) ? a : b);
    final daysLeft = nextPayout.difference(now).inDays;
    return '$daysLeft days';
  }

  Widget _buildPlanCard(InvestmentPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: plan.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(plan.icon, color: plan.iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getRiskColor(plan.riskLevel).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        plan.riskLevel.toString().split('.').last,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getRiskColor(plan.riskLevel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.circle, size: 4, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(
                      'Min: \$${plan.minAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${plan.expectedReturn}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.green[700],
                ),
              ),
              Text(
                'p.a.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: () => _investInPlan(plan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Invest',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(RiskLevel riskLevel) {
    switch (riskLevel) {
      case RiskLevel.low:
        return Colors.green[700]!;
      case RiskLevel.medium:
        return Colors.orange[700]!;
      case RiskLevel.high:
        return Colors.red[700]!;
    }
  }

  Widget _buildInvestTab() {
    final activePlans = _plans.where((plan) => plan.isActive).toList();

    return Column(
      children: [
        // Available Balance
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Balance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '\$${_availableBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _availableBalance < 100
                    ? () => _showErrorMessage('Minimum investment is \$100')
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Add Funds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Investment Plans Grid
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Investment Plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from our range of investment options (${activePlans.length} available)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            ...activePlans.map((plan) => _buildPlanCard(plan)),
          ],
        ),

        const SizedBox(height: 20),

        // Why Invest Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Why Invest with Alpha?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 16),
              _buildFeatureRow('Guaranteed Returns', Icons.verified_rounded),
              _buildFeatureRow('Flexible Tenure', Icons.calendar_today_rounded),
              _buildFeatureRow('24/7 Monitoring', Icons.monitor_heart_rounded),
              _buildFeatureRow(
                  'Easy Withdrawal', Icons.money_off_csred_rounded),
              _buildFeatureRow(
                  'Professional Management', Icons.manage_accounts_rounded),
              _buildFeatureRow('Transparent Fees', Icons.receipt_long_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF003366), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    final activeInvestments = _portfolio
        .where((item) => item.status == PortfolioStatus.active)
        .toList();
    final maturedInvestments = _portfolio
        .where((item) => item.status == PortfolioStatus.matured)
        .toList();

    return Column(
      children: [
        // Portfolio Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 15,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Portfolio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPortfolioStat(
                      'Active', '${activeInvestments.length} plans'),
                  _buildPortfolioStat('Total Value',
                      '\$${_portfolio.fold(0.0, (sum, item) => sum + item.currentValue).toStringAsFixed(2)}'),
                  _buildPortfolioStat('Total Returns',
                      '+\$${_portfolio.fold(0.0, (sum, item) => sum + item.returns).toStringAsFixed(2)}'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Active Investments
        if (activeInvestments.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Active Investments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  Text(
                    '${activeInvestments.length} items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...activeInvestments.map((item) => _buildPortfolioItem(item)),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Matured Investments
        if (maturedInvestments.isNotEmpty) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Matured Investments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  Text(
                    '${maturedInvestments.length} items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...maturedInvestments.map((item) => _buildPortfolioItem(item)),
            ],
          ),
          const SizedBox(height: 20),
        ],

        // Withdraw Earnings Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _withdrawEarnings,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            child: const Text(
              'Withdraw Earnings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Portfolio Insights
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue[100]!, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.insights_rounded, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Portfolio Insights',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getPortfolioInsight(),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: label.contains('Returns')
                ? Colors.green[700]
                : const Color(0xFF003366),
          ),
        ),
      ],
    );
  }

  String _getPortfolioInsight() {
    if (_portfolio.isEmpty) {
      return 'Start investing to grow your wealth. Consider our Alpha Saver plan for beginners.';
    }

    final avgReturn = _calculateAverageReturn();
    if (avgReturn < 5) {
      return 'Consider diversifying into higher-yield plans to improve your returns.';
    } else if (avgReturn >= 15) {
      return 'Great returns! Your portfolio is performing well. Consider reinvesting your earnings.';
    } else {
      return 'Your portfolio is growing steadily. Keep up the good investment strategy!';
    }
  }

  Widget _buildPortfolioItem(PortfolioItem item) {
    final daysToMaturity = item.maturityDate.difference(DateTime.now()).inDays;
    final progress = _calculateProgress(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.planName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: item.status == PortfolioStatus.active
                      ? Colors.green[50]
                      : item.status == PortfolioStatus.matured
                          ? Colors.blue[50]
                          : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  item.status == PortfolioStatus.active
                      ? 'Active'
                      : item.status == PortfolioStatus.matured
                          ? 'Matured'
                          : 'Withdrawn',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.status == PortfolioStatus.active
                        ? Colors.green[700]
                        : item.status == PortfolioStatus.matured
                            ? Colors.blue[700]
                            : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPortfolioDetail(
                  'Invested', '\$${item.investedAmount.toStringAsFixed(2)}'),
              _buildPortfolioDetail(
                  'Current', '\$${item.currentValue.toStringAsFixed(2)}'),
              _buildPortfolioDetail(
                  'Returns', '+${item.returnPercentage.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            color: progress >= 1 ? Colors.blue[500] : Colors.green[500],
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Started: ${_formatDate(item.startDate)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                daysToMaturity > 0 ? '$daysToMaturity days left' : 'Matured',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          if (item.status == PortfolioStatus.matured)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _withdrawInvestment(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Withdraw \$${item.currentValue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _withdrawInvestment(PortfolioItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Investment'),
        content: Text(
            'Withdraw \$${item.currentValue.toStringAsFixed(2)} from ${item.planName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
            ),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Update investment status
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('investments')
            .doc(item.id)
            .update({
          'status': 'withdrawn',
          'withdrawnAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });

        // Add transaction record
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('transactions')
            .add({
          'amount': item.currentValue,
          'description': 'Investment withdrawal - ${item.planName}',
          'type': 'deposit',
          'transactionType': 'investment_withdrawal',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'completed',
          'from': 'Alpha Bank Investments',
          'to': _userData['name'] ?? 'User',
          'category': 'investment',
          'accountNumber': _userData['accountNumber'] ?? 'N/A',
          'transactionId': 'INVW${DateTime.now().millisecondsSinceEpoch}',
          'createdAt': FieldValue.serverTimestamp(),
          'investmentId': item.id,
        });

        // Update user balance
        await _firestore.collection('users').doc(_userId).update({
          'balance': FieldValue.increment(item.currentValue),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _loadUserData();
        _showSuccessMessage('Investment withdrawn successfully!');
      } catch (e) {
        _showErrorMessage('Failed to withdraw investment: $e');
      }
    }
  }

  Widget _buildPortfolioDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: label == 'Returns'
                ? Colors.green[700]
                : const Color(0xFF003366),
          ),
        ),
      ],
    );
  }

  double _calculateProgress(PortfolioItem item) {
    final totalDuration = item.maturityDate.difference(item.startDate).inDays;
    final elapsedDuration = DateTime.now().difference(item.startDate).inDays;
    final progress = elapsedDuration / totalDuration;
    return progress > 1 ? 1 : progress;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// Helper functions for parsing
RiskLevel _parseRiskLevel(String risk) {
  switch (risk.toLowerCase()) {
    case 'medium':
      return RiskLevel.medium;
    case 'high':
      return RiskLevel.high;
    default:
      return RiskLevel.low;
  }
}

IconData _getIconData(String iconName) {
  switch (iconName) {
    case 'trending_up':
      return Icons.trending_up_rounded;
    case 'rocket':
      return Icons.rocket_launch_rounded;
    case 'account_balance':
      return Icons.account_balance_rounded;
    default:
      return Icons.savings_rounded;
  }
}

Color _parseColor(String colorHex) {
  try {
    return Color(int.parse(colorHex.replaceFirst('#', '0xff')));
  } catch (e) {
    return const Color(0xFF003366);
  }
}

PortfolioStatus _parsePortfolioStatus(String status) {
  switch (status.toLowerCase()) {
    case 'matured':
      return PortfolioStatus.matured;
    case 'withdrawn':
      return PortfolioStatus.withdrawn;
    default:
      return PortfolioStatus.active;
  }
}

enum RiskLevel { low, medium, high }

enum PortfolioStatus { active, matured, withdrawn }

class InvestmentPlan {
  final String id;
  final String name;
  final String description;
  final double minAmount;
  final double maxAmount;
  final double expectedReturn;
  final int duration; // in days
  final RiskLevel riskLevel;
  final IconData icon;
  final Color iconColor;
  final double commission;
  final double earlyWithdrawalPenalty;
  final bool isActive;
  final DateTime createdAt;

  InvestmentPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.minAmount,
    required this.maxAmount,
    required this.expectedReturn,
    required this.duration,
    required this.riskLevel,
    required this.icon,
    required this.iconColor,
    required this.commission,
    required this.earlyWithdrawalPenalty,
    required this.isActive,
    required this.createdAt,
  });
}

class PortfolioItem {
  final String id;
  final String planName;
  final String planId;
  final double investedAmount;
  final double netAmount;
  final double currentValue;
  final double returns;
  final double returnPercentage;
  final DateTime startDate;
  final DateTime maturityDate;
  final PortfolioStatus status;
  final double expectedReturn;
  final String transactionId;
  final double withdrawableAmount;
  final DateTime lastUpdated;

  PortfolioItem({
    required this.id,
    required this.planName,
    required this.planId,
    required this.investedAmount,
    required this.netAmount,
    required this.currentValue,
    required this.returns,
    required this.returnPercentage,
    required this.startDate,
    required this.maturityDate,
    required this.status,
    required this.expectedReturn,
    required this.transactionId,
    required this.withdrawableAmount,
    required this.lastUpdated,
  });
}

class InvestmentBottomSheet extends StatefulWidget {
  final InvestmentPlan plan;
  final double availableBalance;
  final String userId;
  final FirebaseFirestore firestore;
  final VoidCallback onInvestmentComplete;

  const InvestmentBottomSheet({
    super.key,
    required this.plan,
    required this.availableBalance,
    required this.userId,
    required this.firestore,
    required this.onInvestmentComplete,
  });

  @override
  State<InvestmentBottomSheet> createState() => _InvestmentBottomSheetState();
}

class _InvestmentBottomSheetState extends State<InvestmentBottomSheet> {
  double _amount = 0.0;
  bool _agreeToTerms = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _amount = widget.plan.minAmount;
  }

  Future<void> _processInvestment() async {
    if (!_agreeToTerms) {
      _showError('Please agree to the terms and conditions');
      return;
    }

    if (_amount < widget.plan.minAmount) {
      _showError(
          'Minimum investment is \$${widget.plan.minAmount.toStringAsFixed(2)}');
      return;
    }

    if (_amount > widget.plan.maxAmount) {
      _showError(
          'Maximum investment is \$${widget.plan.maxAmount.toStringAsFixed(2)}');
      return;
    }

    if (_amount > widget.availableBalance) {
      _showError('Insufficient balance');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final transactionId = 'INV${DateTime.now().millisecondsSinceEpoch}';

      // Create investment record
      await widget.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('investments')
          .add({
        'planId': widget.plan.id,
        'planName': widget.plan.name,
        'amount': _amount,
        'commission': widget.plan.commission,
        'netAmount': _amount * (1 - widget.plan.commission / 100),
        'expectedReturn': widget.plan.expectedReturn,
        'duration': widget.plan.duration,
        'riskLevel': widget.plan.riskLevel.toString().split('.').last,
        'investedAt': FieldValue.serverTimestamp(),
        'maturityDate': Timestamp.fromDate(
            DateTime.now().add(Duration(days: widget.plan.duration))),
        'status': 'active',
        'transactionId': transactionId,
        'withdrawableAmount': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Create transaction record
      await widget.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('transactions')
          .add({
        'amount': -_amount,
        'description': 'Investment in ${widget.plan.name}',
        'type': 'investment',
        'transactionType': 'investment',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'from': 'User',
        'to': 'Alpha Bank Investments',
        'category': 'investment',
        'accountNumber': 'N/A', // Will be fetched from user data
        'transactionId': transactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'investmentDetails': {
          'plan': widget.plan.name,
          'expectedReturn': widget.plan.expectedReturn,
          'duration': widget.plan.duration,
          'commission': widget.plan.commission,
        },
      });

      // Update user balance
      await widget.firestore.collection('users').doc(widget.userId).update({
        'balance': FieldValue.increment(-_amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, true);
      widget.onInvestmentComplete();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to process investment: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expectedReturns = _amount *
        (widget.plan.expectedReturn / 100) *
        (widget.plan.duration / 365);
    final commissionAmount = _amount * (widget.plan.commission / 100);
    final netInvestment = _amount - commissionAmount;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Invest in ${widget.plan.name}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Min: \$${widget.plan.minAmount.toStringAsFixed(0)} • Max: \$${widget.plan.maxAmount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Investment Amount Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Investment Amount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    keyboardType: TextInputType.number,
                    initialValue: _amount.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      prefixText: '\$ ',
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      final parsed =
                          double.tryParse(value) ?? widget.plan.minAmount;
                      setState(() {
                        _amount = parsed;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickAmountButton('Min', widget.plan.minAmount),
                      _buildQuickAmountButton('\$100', 100),
                      _buildQuickAmountButton('\$500', 500),
                      _buildQuickAmountButton('Max', widget.plan.maxAmount),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Investment Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                children: [
                  _buildInvestmentDetail(
                      'Investment Amount', '\$${_amount.toStringAsFixed(2)}'),
                  _buildInvestmentDetail(
                      'Commission (${widget.plan.commission}%)',
                      '-\$${commissionAmount.toStringAsFixed(2)}'),
                  _buildInvestmentDetail('Net Investment',
                      '\$${netInvestment.toStringAsFixed(2)}'),
                  const Divider(height: 20),
                  _buildInvestmentDetail('Expected Returns',
                      '\$${expectedReturns.toStringAsFixed(2)}'),
                  _buildInvestmentDetail('Total Value at Maturity',
                      '\$${(netInvestment + expectedReturns).toStringAsFixed(2)}'),
                  _buildInvestmentDetail(
                      'Annual Return Rate', '${widget.plan.expectedReturn}%'),
                  _buildInvestmentDetail(
                      'Investment Period', '${widget.plan.duration} days'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Terms and Conditions
            Row(
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  onChanged: (value) =>
                      setState(() => _agreeToTerms = value ?? false),
                  activeColor: const Color(0xFF003366),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                    child: Text(
                      'I agree to the terms and conditions of this investment plan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Invest Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processInvestment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Confirm Investment',
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
      ),
    );
  }

  Widget _buildQuickAmountButton(String label, double amount) {
    return TextButton(
      onPressed: () => setState(() => _amount = amount),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _amount == amount ? const Color(0xFF003366) : Colors.grey[600],
          fontWeight: _amount == amount ? FontWeight.w700 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildInvestmentDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class WithdrawEarningsDialog extends StatefulWidget {
  final List<PortfolioItem> portfolio;
  final String userId;
  final FirebaseFirestore firestore;

  const WithdrawEarningsDialog({
    super.key,
    required this.portfolio,
    required this.userId,
    required this.firestore,
  });

  @override
  State<WithdrawEarningsDialog> createState() => _WithdrawEarningsDialogState();
}

class _WithdrawEarningsDialogState extends State<WithdrawEarningsDialog> {
  double _withdrawAmount = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _withdrawAmount = _calculateTotalEarnings();
  }

  double _calculateTotalEarnings() {
    return widget.portfolio.fold(0.0, (sum, item) => sum + item.returns);
  }

  Future<void> _processWithdrawal() async {
    if (_withdrawAmount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (_withdrawAmount > _calculateTotalEarnings()) {
      _showError('Cannot withdraw more than available earnings');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final transactionId = 'WDE${DateTime.now().millisecondsSinceEpoch}';

      // Create transaction record
      await widget.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('transactions')
          .add({
        'amount': _withdrawAmount,
        'description': 'Investment earnings withdrawal',
        'type': 'deposit',
        'transactionType': 'earnings_withdrawal',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
        'from': 'Alpha Bank Investments',
        'to': 'User',
        'category': 'investment',
        'accountNumber': 'N/A',
        'transactionId': transactionId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user balance
      await widget.firestore.collection('users').doc(widget.userId).update({
        'balance': FieldValue.increment(_withdrawAmount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update portfolio items (reduce earnings)
      for (final item in widget.portfolio) {
        if (item.returns > 0) {
          final toWithdraw = min(_withdrawAmount, item.returns);
          await widget.firestore
              .collection('users')
              .doc(widget.userId)
              .collection('investments')
              .doc(item.id)
              .update({
            'returns': FieldValue.increment(-toWithdraw),
            'currentValue': FieldValue.increment(-toWithdraw),
            'withdrawableAmount': FieldValue.increment(-toWithdraw),
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          _withdrawAmount -= toWithdraw;
          if (_withdrawAmount <= 0) break;
        }
      }

      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showError('Failed to process withdrawal: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalEarnings = _calculateTotalEarnings();

    return AlertDialog(
      title: const Text('Withdraw Earnings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'Total available earnings: \$${totalEarnings.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          TextFormField(
            keyboardType: TextInputType.number,
            initialValue: totalEarnings.toStringAsFixed(2),
            decoration: const InputDecoration(
              labelText: 'Amount to withdraw',
              prefixText: '\$ ',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _withdrawAmount = double.tryParse(value) ?? 0.0;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _processWithdrawal,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Withdraw'),
        ),
      ],
    );
  }
}

class InvestmentHistoryScreen extends StatelessWidget {
  final String userId;
  final FirebaseFirestore firestore;

  const InvestmentHistoryScreen({
    super.key,
    required this.userId,
    required this.firestore,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Investment History'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestore
            .collection('users')
            .doc(userId)
            .collection('transactions')
            .where('category', isEqualTo: 'investment')
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
                  Icon(Icons.history_rounded,
                      size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No investment history',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          final transactions = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction =
                  transactions[index].data() as Map<String, dynamic>;
              final amount = (transaction['amount'] ?? 0.0).toDouble();
              final description = transaction['description'] ?? 'Investment';
              final timestamp =
                  (transaction['timestamp'] as Timestamp).toDate();
              final type = transaction['transactionType'] ?? 'investment';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: type.contains('withdrawal')
                            ? Colors.green[50]
                            : Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        type.contains('withdrawal')
                            ? Icons.download_rounded
                            : Icons.upload_rounded,
                        color: type.contains('withdrawal')
                            ? Colors.green[700]
                            : Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            description,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${amount.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: amount > 0 ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
