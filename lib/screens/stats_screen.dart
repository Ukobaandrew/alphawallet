import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _userId;
  bool _isLoading = true;

  // Time period filters
  String _selectedPeriod = 'mornth';
  String _selectedYear = DateTime.now().year.toString();
  String _selectedAccount = 'all';

  // Statistics data
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _netSavings = 0;
  double _largestTransaction = 0;
  int _totalTransactions = 0;
  String _mostFrequentCategory = 'N/A';

  // Charts data
  List<Map<String, dynamic>> _monthlyData = [];
  List<Map<String, dynamic>> _categoryData = [];
  List<Map<String, dynamic>> _accountData = [];
  List<Map<String, dynamic>> _recentTransactions = [];

  // Time periods
  final List<String> _periods = ['week', 'month', 'quarter', 'year', 'custom'];
  final List<String> _years = ['2024', '2023', '2022'];

  // User accounts
  List<Map<String, dynamic>> _accounts = [];

  // Tab controller
  late TabController _tabController;
  final List<String> _tabs = ['Overview', 'Categories', 'Trends', 'Details'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _userId = user.uid;

      // Load user accounts
      await _loadAccounts();

      // Load statistics
      await _loadStatistics();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final accountsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('accounts')
          .get();

      _accounts = accountsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error loading accounts: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Calculate date range based on selected period
      final now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'quarter':
          final quarter = ((now.month - 1) / 3).floor();
          startDate = DateTime(now.year, quarter * 3 + 1, 1);
          break;
        case 'year':
          startDate = DateTime(int.parse(_selectedYear), 1, 1);
          break;
        default:
          startDate = now.subtract(const Duration(days: 30));
      }

      // Fetch transactions for the period
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(now))
          .orderBy('timestamp', descending: true)
          .get();

      // Process transactions
      final transactions = transactionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      // Filter by account if needed
      List<Map<String, dynamic>> filteredTransactions = transactions;
      if (_selectedAccount != 'all') {
        filteredTransactions = transactions.where((t) {
          return t['accountNumber'] == _selectedAccount;
        }).toList();
      }

      // Calculate statistics
      _calculateStatistics(filteredTransactions);

      // Prepare chart data
      _prepareChartData(filteredTransactions);

      // Get recent transactions
      _recentTransactions = filteredTransactions.take(5).toList();
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  void _calculateStatistics(List<Map<String, dynamic>> transactions) {
    double totalIncome = 0;
    double totalExpenses = 0;
    double largestTransaction = 0;
    final Map<String, int> categoryCount = {};
    String mostFrequentCategory = 'N/A';
    int maxCount = 0;

    for (final transaction in transactions) {
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
      final category = transaction['category'] as String? ?? 'uncategorized';

      // Update category count
      categoryCount[category] = (categoryCount[category] ?? 0) + 1;
      if (categoryCount[category]! > maxCount) {
        maxCount = categoryCount[category]!;
        mostFrequentCategory = category;
      }

      // Update totals
      if (amount > 0) {
        totalIncome += amount;
      } else {
        totalExpenses += amount.abs();
      }

      // Update largest transaction
      if (amount.abs() > largestTransaction) {
        largestTransaction = amount.abs();
      }
    }

    setState(() {
      _totalIncome = totalIncome;
      _totalExpenses = totalExpenses;
      _netSavings = totalIncome - totalExpenses;
      _largestTransaction = largestTransaction;
      _totalTransactions = transactions.length;
      _mostFrequentCategory = mostFrequentCategory;
    });
  }

  void _prepareChartData(List<Map<String, dynamic>> transactions) {
    // Monthly data for line chart
    final Map<String, Map<String, double>> monthlyMap = {};

    for (final transaction in transactions) {
      final timestamp = (transaction['timestamp'] as Timestamp).toDate();
      final monthKey = DateFormat('MMM yyyy').format(timestamp);
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;

      if (!monthlyMap.containsKey(monthKey)) {
        monthlyMap[monthKey] = {'income': 0, 'expenses': 0};
      }

      if (amount > 0) {
        monthlyMap[monthKey]!['income'] =
            monthlyMap[monthKey]!['income']! + amount;
      } else {
        monthlyMap[monthKey]!['expenses'] =
            monthlyMap[monthKey]!['expenses']! + amount.abs();
      }
    }

    _monthlyData = monthlyMap.entries.map((entry) {
      return {
        'month': entry.key,
        'income': entry.value['income']!,
        'expenses': entry.value['expenses']!,
      };
    }).toList();

    // Category data for pie chart
    final Map<String, double> categoryMap = {};

    for (final transaction in transactions) {
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
      final category = transaction['category'] as String? ?? 'uncategorized';

      if (amount < 0) {
        // Only expenses for pie chart
        categoryMap[category] = (categoryMap[category] ?? 0) + amount.abs();
      }
    }

    _categoryData = categoryMap.entries.map((entry) {
      return {
        'category': entry.key,
        'amount': entry.value,
        'color': _getCategoryColor(entry.key),
      };
    }).toList();

    // Account data for bar chart
    final Map<String, double> accountMap = {};

    for (final transaction in transactions) {
      final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
      final accountNumber =
          transaction['accountNumber'] as String? ?? 'Unknown';

      // Find account name
      final account = _accounts.firstWhere(
        (acc) => acc['accountNumber'] == accountNumber,
        orElse: () => {'title': accountNumber},
      );

      final accountName = account['title'] as String? ?? accountNumber;

      if (amount < 0) {
        // Expenses by account
        accountMap[accountName] = (accountMap[accountName] ?? 0) + amount.abs();
      }
    }

    _accountData = accountMap.entries.map((entry) {
      return {
        'account': entry.key,
        'amount': entry.value,
      };
    }).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'shopping':
        return Colors.purple;
      case 'food':
        return Colors.orange;
      case 'transportation':
        return Colors.blue;
      case 'entertainment':
        return Colors.pink;
      case 'bills':
        return Colors.green;
      case 'health':
        return Colors.red;
      case 'education':
        return Colors.teal;
      case 'transfer':
        return Colors.cyan;
      case 'deposit':
        return Colors.lightGreen;
      case 'withdrawal':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount);
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    if (_categoryData.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.pie_chart_rounded,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No expense data',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: SfCircularChart(
        title: const ChartTitle(text: 'Expenses by Category'),
        legend: const Legend(
          isVisible: true,
          overflowMode: LegendItemOverflowMode.wrap,
        ),
        series: <CircularSeries>[
          DoughnutSeries<Map<String, dynamic>, String>(
            dataSource: _categoryData,
            xValueMapper: (data, _) => data['category'],
            yValueMapper: (data, _) => data['amount'],
            pointColorMapper: (data, _) => data['color'],
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelPosition: ChartDataLabelPosition.inside,
              textStyle: TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyLineChart() {
    if (_monthlyData.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No data available',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: SfCartesianChart(
        title: const ChartTitle(text: 'Income vs Expenses Trend'),
        primaryXAxis: const CategoryAxis(
          labelRotation: -45,
        ),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.currency(symbol: '\$'),
        ),
        legend: const Legend(isVisible: true),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          LineSeries<Map<String, dynamic>, String>(
            name: 'Income',
            dataSource: _monthlyData,
            xValueMapper: (data, _) => data['month'],
            yValueMapper: (data, _) => data['income'],
            markerSettings: const MarkerSettings(isVisible: true),
            color: Colors.green,
          ),
          LineSeries<Map<String, dynamic>, String>(
            name: 'Expenses',
            dataSource: _monthlyData,
            xValueMapper: (data, _) => data['month'],
            yValueMapper: (data, _) => data['expenses'],
            markerSettings: const MarkerSettings(isVisible: true),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBarChart() {
    if (_accountData.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bar_chart_rounded,
                size: 60,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No account data',
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: SfCartesianChart(
        title: const ChartTitle(text: 'Expenses by Account'),
        primaryXAxis: const CategoryAxis(),
        primaryYAxis: NumericAxis(
          numberFormat: NumberFormat.currency(symbol: '\$'),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries>[
          ColumnSeries<Map<String, dynamic>, String>(
            dataSource: _accountData,
            xValueMapper: (data, _) => data['account'],
            yValueMapper: (data, _) => data['amount'],
            color: const Color(0xFF003366),
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              labelAlignment: ChartDataLabelAlignment.top,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (_recentTransactions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No recent transactions',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
          ),
          ..._recentTransactions.map((transaction) {
            final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
            final description =
                transaction['description'] as String? ?? 'No description';
            final timestamp = (transaction['timestamp'] as Timestamp).toDate();
            final category =
                transaction['category'] as String? ?? 'uncategorized';
            final isPositive = amount > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getCategoryColor(category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPositive
                          ? Icons.download_rounded
                          : Icons.upload_rounded,
                      color: _getCategoryColor(category),
                      size: 20,
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
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              DateFormat('MMM dd, HH:mm').format(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getCategoryColor(category)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getCategoryColor(category),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatCurrency(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(
              onPressed: () {
                // Navigate to transactions screen
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF003366),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('View All Transactions'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF003366),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Filters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ..._periods.map((period) {
            final isSelected = _selectedPeriod == period;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  period.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF003366),
                    fontSize: 12,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedPeriod = period;
                  });
                  _loadStatistics();
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF003366),
                side: BorderSide(
                  color:
                      isSelected ? const Color(0xFF003366) : Colors.grey[300]!,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAccountFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _selectedAccount,
        isExpanded: true,
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem<String>(
            value: 'all',
            child: Text('All Accounts'),
          ),
          ..._accounts.map<DropdownMenuItem<String>>((account) {
            return DropdownMenuItem<String>(
              value: account['accountNumber'],
              child: Text(
                '${account['title']} (${account['accountNumber']})',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (String? value) {
          setState(() {
            _selectedAccount = value!;
          });
          _loadStatistics();
        },
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: _selectedYear,
        isExpanded: true,
        underline: const SizedBox(),
        items: _years.map<DropdownMenuItem<String>>((year) {
          return DropdownMenuItem<String>(
            value: year,
            child: Text(year),
          );
        }).toList(),
        onChanged: (String? value) {
          setState(() {
            _selectedYear = value!;
          });
          _loadStatistics();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Statistics'),
          backgroundColor: const Color(0xFF003366),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        backgroundColor: const Color(0xFF003366),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Overview Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filters
                _buildFilterChips(),
                const SizedBox(height: 16),

                // Account Filter
                _buildAccountFilter(),
                const SizedBox(height: 16),

                // Year Selector (for year view)
                if (_selectedPeriod == 'year') ...[
                  _buildYearSelector(),
                  const SizedBox(height: 16),
                ],

                // Stats Summary
                const Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 16),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  children: [
                    _buildStatCard(
                      'Total Income',
                      _formatCurrency(_totalIncome),
                      Icons.trending_up_rounded,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Total Expenses',
                      _formatCurrency(_totalExpenses),
                      Icons.trending_down_rounded,
                      Colors.red,
                    ),
                    _buildStatCard(
                      'Net Savings',
                      _formatCurrency(_netSavings),
                      _netSavings >= 0
                          ? Icons.savings_rounded
                          : Icons.warning_rounded,
                      _netSavings >= 0 ? Colors.teal : Colors.amber,
                    ),
                    _buildStatCard(
                      'Transactions',
                      _totalTransactions.toString(),
                      Icons.receipt_long_rounded,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Largest Transaction',
                      _formatCurrency(_largestTransaction),
                      Icons.attach_money_rounded,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      'Top Category',
                      _mostFrequentCategory,
                      Icons.category_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Monthly Trend Chart
                _buildMonthlyLineChart(),
                const SizedBox(height: 24),

                // Recent Transactions
                _buildRecentTransactions(),
              ],
            ),
          ),

          // Categories Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterChips(),
                const SizedBox(height: 16),
                _buildAccountFilter(),
                const SizedBox(height: 16),
                _buildCategoryPieChart(),
                const SizedBox(height: 24),

                // Category Details
                if (_categoryData.isNotEmpty) ...[
                  const Text(
                    'Category Breakdown',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._categoryData.map((category) {
                    final percentage =
                        (category['amount']! / _totalExpenses) * 100;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: category['color'],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    category['category'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _formatCurrency(category['amount']!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[200],
                            color: category['color'],
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // Trends Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterChips(),
                const SizedBox(height: 16),
                _buildAccountFilter(),
                const SizedBox(height: 16),
                _buildMonthlyLineChart(),
                const SizedBox(height: 24),
                _buildAccountBarChart(),
              ],
            ),
          ),

          // Details Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterChips(),
                const SizedBox(height: 16),
                _buildAccountFilter(),
                const SizedBox(height: 16),

                // Detailed Statistics
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Financial Health',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _buildDetailRow('Savings Rate',
                          '${((_netSavings / _totalIncome) * 100).toStringAsFixed(1)}%'),
                      _buildDetailRow('Expense to Income Ratio',
                          '${((_totalExpenses / _totalIncome) * 100).toStringAsFixed(1)}%'),
                      _buildDetailRow(
                          'Average Transaction',
                          _formatCurrency((_totalIncome + _totalExpenses) /
                              _totalTransactions)),
                      _buildDetailRow('Transaction Frequency',
                          '${(_totalTransactions / 30).toStringAsFixed(1)} per day'),
                      _buildDetailRow('Most Active Day',
                          'Monday'), // This would require more calculation
                      _buildDetailRow('Peak Spending Time',
                          'Evening'), // This would require more calculation
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Export Options
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Export as PDF
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Export as PDF Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Export as CSV
                        },
                        icon: const Icon(Icons.table_chart_rounded),
                        label: const Text('Export as CSV Data'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF003366),
                          side: const BorderSide(color: Color(0xFF003366)),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
        ],
      ),
    );
  }
}
