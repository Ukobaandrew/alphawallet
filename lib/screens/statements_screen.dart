import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StatementsScreen extends StatefulWidget {
  const StatementsScreen({super.key});

  @override
  State<StatementsScreen> createState() => _StatementsScreenState();
}

class _StatementsScreenState extends State<StatementsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _userId;
  bool _isLoading = true;

  List<Map<String, dynamic>> _accounts = [];
  List<Map<String, dynamic>> _statements = [];
  Map<String, dynamic> _userData = {};

  DateTimeRange? _selectedDateRange;
  String _selectedAccount = 'all';

  final List<Map<String, dynamic>> _availableMonths = [];

  @override
  void initState() {
    super.initState();
    _initDateRange();
    _loadUserData();
  }

  void _initDateRange() {
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month - 3, 1),
      end: now,
    );
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
      }

      // Load user accounts
      await _loadAccounts();

      // Load statements
      await _loadStatements();

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

      // Sort accounts: primary first
      _accounts.sort((a, b) {
        if (a['isPrimary'] == true) return -1;
        if (b['isPrimary'] == true) return 1;
        return 0;
      });
    } catch (e) {
      print('Error loading accounts: $e');
    }
  }

  Future<void> _loadStatements() async {
    try {
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      // Group transactions by month and account
      final Map<String, Map<String, List<Map<String, dynamic>>>>
          groupedTransactions = {};

      for (final doc in transactionsSnapshot.docs) {
        final transaction = doc.data();
        final timestamp = (transaction['timestamp'] as Timestamp).toDate();
        final monthKey = DateFormat('yyyy-MM').format(timestamp);
        final accountNumber =
            transaction['accountNumber'] as String? ?? 'default';

        if (!groupedTransactions.containsKey(monthKey)) {
          groupedTransactions[monthKey] = {};
        }

        if (!groupedTransactions[monthKey]!.containsKey(accountNumber)) {
          groupedTransactions[monthKey]![accountNumber] = [];
        }

        groupedTransactions[monthKey]![accountNumber]!.add({
          'id': doc.id,
          ...transaction,
        });
      }

      // Generate statements from grouped transactions
      _statements = [];
      _availableMonths.clear();

      groupedTransactions.forEach((monthKey, accounts) {
        accounts.forEach((accountNumber, transactions) {
          final account = _accounts.firstWhere(
            (acc) => acc['accountNumber'] == accountNumber,
            orElse: () => {'title': 'Unknown Account', 'currencyCode': 'USD'},
          );

          final month =
              DateFormat('MMMM yyyy').format(DateTime.parse('$monthKey-01'));
          final year = DateTime.parse('$monthKey-01').year;
          final monthNum = DateTime.parse('$monthKey-01').month;

          // Calculate totals
          double income = 0;
          double expenses = 0;

          for (final transaction in transactions) {
            final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
            if (amount > 0) {
              income += amount;
            } else {
              expenses += amount.abs();
            }
          }

          final statement = {
            'month': month,
            'monthKey': monthKey,
            'monthNum': monthNum,
            'year': year,
            'account': account['title'] ?? 'Unknown Account',
            'accountNumber': accountNumber,
            'currency': account['currencyCode'] ?? 'USD',
            'transactions': transactions.length,
            'income': _formatCurrency(income, account['currencyCode'] ?? 'USD'),
            'expenses':
                _formatCurrency(expenses, account['currencyCode'] ?? 'USD'),
            'netBalance': _formatCurrency(
                income - expenses, account['currencyCode'] ?? 'USD'),
            'transactionsData': transactions,
            'accountData': account,
          };

          _statements.add(statement);
        });

        // Add month to available months list
        final monthDateTime = DateTime.parse('$monthKey-01');
        _availableMonths.add({
          'month': DateFormat('MMMM yyyy').format(monthDateTime),
          'monthKey': monthKey,
        });
      });

      // Sort statements by date (newest first)
      _statements.sort((a, b) {
        final aDate = DateTime(a['year'], a['monthNum']);
        final bDate = DateTime(b['year'], b['monthNum']);
        return bDate.compareTo(aDate);
      });
    } catch (e) {
      print('Error loading statements: $e');
    }
  }

  String _formatCurrency(double amount, String currency) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      case 'NGN':
        return '₦';
      default:
        return '\$';
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      await _loadStatements();
    }
  }

  List<Map<String, dynamic>> _getFilteredStatements() {
    List<Map<String, dynamic>> filtered = _statements;

    // Filter by selected date range
    if (_selectedDateRange != null) {
      filtered = filtered.where((statement) {
        final statementDate =
            DateTime(statement['year'], statement['monthNum']);
        return statementDate.isAfter(
                _selectedDateRange!.start.subtract(const Duration(days: 1))) &&
            statementDate
                .isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Filter by selected account
    if (_selectedAccount != 'all') {
      filtered = filtered.where((statement) {
        return statement['accountNumber'] == _selectedAccount;
      }).toList();
    }

    return filtered;
  }

  Future<void> _downloadStatement(Map<String, dynamic> statement) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
        ),
      );

      // Generate PDF
      final pdf = await _generateStatementPDF(statement);

      // Save PDF to file
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
          '${dir.path}/Statement_${statement['monthKey']}_${statement['accountNumber']}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      Navigator.pop(context);

      // Show success message
      _showSuccessMessage('Statement downloaded successfully');

      // Open PDF viewer
    } catch (e) {
      Navigator.pop(context);
      _showErrorMessage('Failed to download statement: $e');
    }
  }

  Future<pw.Document> _generateStatementPDF(
      Map<String, dynamic> statement) async {
    final pdf = pw.Document();

    final transactions =
        statement['transactionsData'] as List<Map<String, dynamic>>;
    final account = statement['accountData'] as Map<String, dynamic>;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Alpha Bank',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue,
                        ),
                      ),
                      pw.Text(
                        'Account Statement',
                        style: const pw.TextStyle(
                          fontSize: 18,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        statement['month'],
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Account Information
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue, width: 1),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Account Information',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Account Holder:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(_userData['name'] ?? 'N/A'),
                            pw.SizedBox(height: 5),
                            pw.Text('Account Number:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(statement['accountNumber']),
                          ],
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Account Type:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(account['type']?.toString().toUpperCase() ??
                                'CHECKING'),
                            pw.SizedBox(height: 5),
                            pw.Text('Currency:',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(statement['currency']),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Total Transactions',
                          style: const pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey)),
                      pw.Text(statement['transactions'].toString(),
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Total Income',
                          style: const pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey)),
                      pw.Text(statement['income'],
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Total Expenses',
                          style: const pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey)),
                      pw.Text(statement['expenses'],
                          style: pw.TextStyle(
                              fontSize: 18,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Net Balance',
                          style: const pw.TextStyle(
                              fontSize: 12, color: PdfColors.grey)),
                      pw.Text(statement['netBalance'],
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Transactions Table
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
              headers: ['Date', 'Description', 'Type', 'Amount', 'Balance'],
              data: transactions.map((transaction) {
                final timestamp =
                    (transaction['timestamp'] as Timestamp).toDate();
                final amount = (transaction['amount'] as num?)?.toDouble() ?? 0;
                final balance =
                    (transaction['balanceAfter'] as num?)?.toDouble() ?? 0;

                return [
                  DateFormat('dd/MM/yyyy').format(timestamp),
                  transaction['description']?.toString().substring(
                          0,
                          min(30,
                              transaction['description'].toString().length)) ??
                      'N/A',
                  transaction['type']?.toString().toUpperCase() ?? 'N/A',
                  _formatCurrency(amount, statement['currency']),
                  _formatCurrency(balance, statement['currency']),
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Important Information',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '• This is an electronic statement. For any discrepancies, please contact customer support within 30 days.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '• For assistance, call +234 1 700 0000 or email support@alphabank.com',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '• This statement has been generated by Alpha Bank Systems.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  Future<void> _downloadAllStatements() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Download All Statements'),
          content: const Text(
              'This will download all available statements for the selected filters. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                final filteredStatements = _getFilteredStatements();

                if (filteredStatements.isEmpty) {
                  _showErrorMessage('No statements available for download');
                  return;
                }

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
                    ),
                  ),
                );

                try {
                  for (final statement in filteredStatements) {
                    await _downloadStatement(statement);
                    await Future.delayed(const Duration(
                        seconds: 1)); // Delay to avoid overwhelming
                  }

                  Navigator.pop(context); // Close loading dialog
                  _showSuccessMessage('All statements downloaded successfully');
                } catch (e) {
                  Navigator.pop(context); // Close loading dialog
                  _showErrorMessage('Failed to download all statements: $e');
                }
              },
              child: const Text('Download All'),
            ),
          ],
        );
      },
    );
  }

  void _viewStatement(Map<String, dynamic> statement) {
    final transactions =
        statement['transactionsData'] as List<Map<String, dynamic>>;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('${statement['month']} Statement'),
            backgroundColor: const Color(0xFF003366),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statement Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Alpha Bank Statement',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        statement['month'],
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Divider(height: 30),
                      _buildStatementRow('Account', statement['account']),
                      _buildStatementRow(
                          'Account Number', statement['accountNumber']),
                      _buildStatementRow('Total Transactions',
                          statement['transactions'].toString()),
                      _buildStatementRow('Total Income', statement['income']),
                      _buildStatementRow(
                          'Total Expenses', statement['expenses']),
                      _buildStatementRow(
                          'Net Balance', statement['netBalance']),
                      _buildStatementRow(
                          'Statement Period', statement['month']),
                      _buildStatementRow('Currency', statement['currency']),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Transactions List
                const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 12),

                ...transactions.map((transaction) {
                  final timestamp =
                      (transaction['timestamp'] as Timestamp).toDate();
                  final amount =
                      (transaction['amount'] as num?)?.toDouble() ?? 0;
                  final description =
                      transaction['description'] as String? ?? 'No description';
                  final type = transaction['type'] as String? ?? 'Unknown';

                  return _buildTransactionRow(
                    DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                    description,
                    type,
                    amount,
                    statement['currency'],
                  );
                }),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _downloadStatement(statement),
            backgroundColor: const Color(0xFF003366),
            child: const Icon(Icons.download_rounded),
          ),
        ),
      ),
    );
  }

  Widget _buildStatementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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

  Widget _buildTransactionRow(String date, String description, String type,
      double amount, String currency) {
    final isPositive = amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTransactionColor(type),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getTransactionIcon(type),
              color: Colors.white,
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
                    color: Color(0xFF003366),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      date,
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
                        color: _getTransactionColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getTransactionColor(type),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(amount, currency),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTransactionColor(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return Colors.green;
      case 'withdrawal':
        return Colors.red;
      case 'transfer':
        return Colors.blue;
      case 'shopping':
        return Colors.purple;
      case 'exchange':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTransactionIcon(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return Icons.download_rounded;
      case 'withdrawal':
        return Icons.upload_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'shopping':
        return Icons.shopping_cart_rounded;
      case 'exchange':
        return Icons.currency_exchange_rounded;
      default:
        return Icons.receipt_rounded;
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Account Statements'),
          backgroundColor: const Color(0xFF003366),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
        ),
      );
    }

    final filteredStatements = _getFilteredStatements();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Statements'),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: filteredStatements.isNotEmpty
                ? () => _downloadAllStatements()
                : null,
            tooltip: 'Download All',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Controls
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.filter_alt_rounded, color: Color(0xFF003366)),
                      SizedBox(width: 8),
                      Text(
                        'Filter Statements',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Account Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Account',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedAccount,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem<String>(
                              value: 'all',
                              child: Text(
                                'All Accounts',
                                style: TextStyle(
                                  color: Color(0xFF003366),
                                ),
                              ),
                            ),
                            ..._accounts
                                .map<DropdownMenuItem<String>>((account) {
                              return DropdownMenuItem<String>(
                                value: account['accountNumber'],
                                child: Text(
                                  '${account['title']} (${account['accountNumber']})',
                                  style: const TextStyle(
                                    color: Color(0xFF003366),
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedAccount = newValue!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Range Selection
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Date Range',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _selectDateRange(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDateRange != null
                                    ? '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}'
                                    : 'Select Date Range',
                                style: const TextStyle(
                                  color: Color(0xFF003366),
                                ),
                              ),
                              const Icon(Icons.calendar_month_rounded,
                                  color: Color(0xFF003366)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Apply Filter Button
                  ElevatedButton(
                    onPressed: () {
                      _loadStatements();
                      _showSuccessMessage('Filters applied successfully');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Apply Filters',
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
            const SizedBox(height: 24),

            // Statements Header
            Container(
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
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Statements',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${filteredStatements.length} statement${filteredStatements.length != 1 ? 's' : ''} available',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Available Statements (${filteredStatements.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),

            // Statements List
            if (filteredStatements.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No statements found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your filters',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredStatements.length,
                itemBuilder: (context, index) {
                  final statement = filteredStatements[index];
                  return _buildStatementCard(statement);
                },
              ),
            const SizedBox(height: 20),

            // Statement Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statement Information',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                      '• Statements are generated from your transaction history'),
                  Text('• Available for download in PDF format'),
                  Text('• Includes detailed transaction information'),
                  Text('• Bank charges and fees are included where applicable'),
                  Text('• For custom statements, contact customer support'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatementCard(Map<String, dynamic> statement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                statement['month'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statement['account'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatementDetail(
                  'Transactions', statement['transactions'].toString()),
              _buildStatementDetail('Income', statement['income']),
              _buildStatementDetail('Expenses', statement['expenses']),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatementDetail('Net Balance', statement['netBalance']),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _viewStatement(statement),
                  icon: const Icon(Icons.visibility_rounded, size: 18),
                  label: const Text('View'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF003366)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadStatement(statement),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatementDetail(String label, String value) {
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
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
      ],
    );
  }
}

int min(int a, int b) => a < b ? a : b;
