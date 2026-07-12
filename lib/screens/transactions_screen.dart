import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';

// Import the Transaction class from your existing workflow file with an alias
import 'transaction_workflow_screen.dart' as workflow;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key}); // Removed the required parameters

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _selectedFilter = 0; // 0: All, 1: Credit, 2: Debit
  List<AppTransaction> _transactions = [];
  bool _isLoading = true;
  double _totalBalance = 0.0;
  double _monthlyIncome = 0.0;
  double _monthlyExpenses = 0.0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadUserBalance();
  }

  Future<void> _loadUserBalance() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      final balance = (data?['balance'] ?? 0.0);
      setState(() {
        _totalBalance = _safeDouble(balance);
      });
    } catch (e) {
      debugPrint('Error loading balance: $e');
      setState(() {
        _totalBalance = 0.0;
      });
    }
  }

  Future<void> _loadTransactions() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      final List<AppTransaction> loadedTransactions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        try {
          // Determine if this is a transfer transaction or other type
          if (data['transactionType'] != null) {
            // This is a transfer transaction
            final amount = _safeDouble(data['amount']);
            final fee = _safeDouble(data['fee']);

            loadedTransactions.add(AppTransaction(
              id: data['id'] ?? doc.id,
              title: (data['transactionType'] == 'Transfer' ||
                      data['transactionType'] == 'Bank Transfer')
                  ? 'Transfer to ${data['recipientName'] ?? "Unknown"}'
                  : '${data['transactionType']}',
              description: data['description'] ?? 'Transaction',
              amount: -amount - fee,
              date: (data['timestamp'] as Timestamp).toDate(),
              type: TransactionType.debit,
              category: data['transactionType'] ?? 'Transfer',
              icon: _getTransactionIcon(data['transactionType'] ?? 'Transfer'),
              iconColor:
                  _getTransactionColor(data['transactionType'] ?? 'Transfer'),
              bankName: data['bankName'],
              recipientName: data['recipientName'],
              recipientAccount: data['recipientAccount'],
              fee: fee,
              reference: data['reference'],
              status: data['status'] ?? 'Completed',
              transactionType: data['transactionType'],
            ));
          } else {
            // This is other transaction (deposit, withdrawal, etc.)
            final amount = _safeDouble(data['amount']);
            loadedTransactions.add(AppTransaction(
              id: data['id'] ?? doc.id,
              title: data['title'] ?? 'Transaction',
              description: data['description'] ?? '',
              amount: amount,
              date: (data['timestamp'] as Timestamp).toDate(),
              type:
                  amount >= 0 ? TransactionType.credit : TransactionType.debit,
              category: data['category'] ?? 'General',
              icon: _getTransactionIcon(data['category'] ?? 'General'),
              iconColor: _getTransactionColor(data['category'] ?? 'General'),
              bankName: data['bankName'],
              recipientName: data['recipientName'],
              recipientAccount: data['recipientAccount'],
              fee: _safeDouble(data['fee']),
              reference: data['reference'],
              status: data['status'] ?? 'Completed',
              transactionType: data['category'],
            ));
          }
        } catch (e) {
          debugPrint('Error parsing transaction ${doc.id}: $e');
        }
      }

      _calculateMonthlyTotals(loadedTransactions);

      setState(() {
        _transactions = loadedTransactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      setState(() {
        _transactions = [];
        _isLoading = false;
      });
    }
  }

  // Helper function to safely convert any value to double
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

  void _calculateMonthlyTotals(List<AppTransaction> transactions) {
    final now = DateTime.now();
    double income = 0.0;
    double expenses = 0.0;

    for (var transaction in transactions) {
      if (transaction.date.month == now.month &&
          transaction.date.year == now.year) {
        if (transaction.type == TransactionType.credit) {
          income += _safeDouble(transaction.amount);
        } else {
          expenses += _safeDouble(transaction.amount.abs());
        }
      }
    }

    setState(() {
      _monthlyIncome = income;
      _monthlyExpenses = expenses;
    });
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'Bank Transfer':
      case 'Transfer':
        return Icons.account_balance_rounded;
      case 'Mobile Money':
        return Icons.phone_android_rounded;
      case 'Salary':
        return Icons.work_rounded;
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
      case 'Salary':
        return Colors.teal[700]!;
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

  List<AppTransaction> get _filteredTransactions {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));

    switch (_selectedFilter) {
      case 1: // Credits
        return _transactions
            .where((t) => t.type == TransactionType.credit)
            .toList();
      case 2: // Debits
        return _transactions
            .where((t) => t.type == TransactionType.debit)
            .toList();
      case 3: // This Month
        return _transactions
            .where((t) => t.date.month == now.month && t.date.year == now.year)
            .toList();
      case 4: // Last 30 Days
        return _transactions.where((t) => t.date.isAfter(last30Days)).toList();
      default: // All
        return _transactions;
    }
  }

  Future<void> _downloadStatement() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Statement'),
        content: const Text('Select statement period:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _generateAndSharePDF();
            },
            child: const Text('Download PDF'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePDF() async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'ALPHA BANK',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'ACCOUNT STATEMENT',
                    style: const pw.TextStyle(fontSize: 18),
                  ),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Account Holder: ${_auth.currentUser?.displayName ?? 'User'}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Balance:',
                        style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      '\$${_safeDouble(_totalBalance).toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Date',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Description',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Amount',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Balance',
                              style:
                                  pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                    for (var transaction in _filteredTransactions)
                      pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(DateFormat('dd/MM/yyyy')
                                .format(transaction.date)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(transaction.title),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              transaction.type == TransactionType.credit
                                  ? '+\$${_safeDouble(transaction.amount).toStringAsFixed(2)}'
                                  : '-\$${_safeDouble(transaction.amount.abs()).toStringAsFixed(2)}',
                              style: pw.TextStyle(
                                color:
                                    transaction.type == TransactionType.credit
                                        ? PdfColors.green
                                        : PdfColors.red,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                                '\$${_safeDouble(transaction.amount).toStringAsFixed(2)}'),
                          ),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.Text(
                    'Generated by Alpha Bank App',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final pdfPath =
          '${directory.path}/statement_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(pdfPath)],
        text: 'Alpha Bank Account Statement',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate statement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _shareTransactionReceipt(AppTransaction transaction) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'ALPHA BANK',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'TRANSACTION RECEIPT',
                    style: const pw.TextStyle(fontSize: 18),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Transaction ID: ${transaction.id}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(transaction.date)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Time: ${DateFormat('HH:mm').format(transaction.date)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Text(
                  'Description: ${transaction.title}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                if (transaction.recipientName != null)
                  pw.Text(
                    'Recipient: ${transaction.recipientName}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                if (transaction.recipientAccount != null)
                  pw.Text(
                    'Account: ${transaction.recipientAccount}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                if (transaction.bankName != null)
                  pw.Text(
                    'Bank: ${transaction.bankName}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount:', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      '\$${_safeDouble(transaction.amount.abs()).toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                if (transaction.fee > 0)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Fee:', style: const pw.TextStyle(fontSize: 12)),
                      pw.Text(
                        '\$${_safeDouble(transaction.fee).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total:', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      '\$${_safeDouble(transaction.amount.abs() + transaction.fee).toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Status: ${transaction.status}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: transaction.status == 'Completed'
                        ? PdfColors.green
                        : PdfColors.orange,
                  ),
                ),
                pw.Text(
                  'Type: ${transaction.category}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (transaction.reference != null)
                  pw.Text(
                    'Reference: ${transaction.reference}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.Text(
                    'Thank you for banking with us!',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Alpha Bank - Secure Banking',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final pdfPath = '${directory.path}/receipt_${transaction.id}.pdf';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(pdfPath)],
        text: 'Transaction Receipt - ${transaction.id}',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewTransactionReceipt(AppTransaction transaction) {
    // If it's a transfer transaction, use the existing ReceiptScreen
    if (transaction.recipientName != null && transaction.bankName != null) {
      // Create a Transaction object for the existing ReceiptScreen
      // Using the actual Transaction class from the workflow file
      final workflowTransaction = workflow.Transaction(
        id: transaction.id,
        userId: _auth.currentUser!.uid,
        recipientName: transaction.recipientName!,
        recipientAccount: transaction.recipientAccount ?? '',
        bankName: transaction.bankName!,
        amount: _safeDouble(transaction.amount.abs()),
        fee: _safeDouble(transaction.fee),
        description: transaction.description,
        timestamp: transaction.date,
        status: transaction.status,
        transactionType: transaction.transactionType ?? transaction.category,
        reference: transaction.reference,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              workflow.ReceiptScreen(transaction: workflowTransaction),
        ),
      );
    } else {
      // For other transactions, show custom receipt
      _showTransactionReceipt(transaction);
    }
  }

  void _showTransactionReceipt(AppTransaction transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Screenshot(
        controller: _screenshotController,
        child: TransactionReceiptSheet(
          transaction: transaction,
          onShareReceipt: () => _shareTransactionReceipt(transaction),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress bar value safely
    double progressValue = 0.0;
    final total = _monthlyIncome + _monthlyExpenses;
    if (total > 0) {
      progressValue = _monthlyExpenses / total;
      // Clamp between 0 and 1 to avoid invalid values
      progressValue = progressValue.clamp(0.0, 1.0);
    }

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
                            'Transaction History',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.download_rounded,
                                color: Color(0xFF003366)),
                            onPressed: _downloadStatement,
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: Color(0xFF003366)),
                            onPressed: _loadTransactions,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Filter Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All', 0),
                          const SizedBox(width: 8),
                          _buildFilterChip('Credits', 1),
                          const SizedBox(width: 8),
                          _buildFilterChip('Debits', 2),
                          const SizedBox(width: 8),
                          _buildFilterChip('This Month', 3),
                          const SizedBox(width: 8),
                          _buildFilterChip('Last 30 Days', 4),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Summary Card
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
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${_safeDouble(_totalBalance).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF003366),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'This Month',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '+\$${_safeDouble(_monthlyIncome).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.trending_up_rounded,
                                          color: Colors.green, size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '-\$${_safeDouble(_monthlyExpenses).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.trending_down_rounded,
                                          color: Colors.red, size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: progressValue,
                            backgroundColor: Colors.grey[200],
                            color: _safeDouble(_monthlyExpenses) >
                                    _safeDouble(_monthlyIncome)
                                ? Colors.red
                                : Colors.green,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Transactions List
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Transactions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF003366),
                              ),
                            ),
                            Text(
                              '${_filteredTransactions.length} transactions',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isLoading)
                          Container(
                            padding: const EdgeInsets.all(40),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF003366),
                              ),
                            ),
                          )
                        else if (_filteredTransactions.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
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
                                  'No transactions found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try changing your filters',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._filteredTransactions.map((transaction) =>
                              _buildTransactionItem(transaction)),
                      ],
                    ),

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

  Widget _buildFilterChip(String label, int index) {
    bool isSelected = _selectedFilter == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003366) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF003366) : Colors.grey[300]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF003366),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(AppTransaction transaction) {
    final safeAmount = _safeDouble(transaction.amount);
    final safeAmountAbs = _safeDouble(transaction.amount.abs());
    final displayAmount = transaction.type == TransactionType.credit
        ? '+\$${safeAmount.toStringAsFixed(2)}'
        : '-\$${safeAmountAbs.toStringAsFixed(2)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.grey[100]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: transaction.iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              transaction.icon,
              color: transaction.iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: transaction.type == TransactionType.credit
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        transaction.category,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: transaction.type == TransactionType.credit
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(transaction.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
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
                displayAmount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: transaction.type == TransactionType.credit
                      ? Colors.green[700]
                      : Colors.red[700],
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _viewTransactionReceipt(transaction),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Receipt',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('dd/MM/yy').format(date);
    }
  }
}

// Updated enum and class names to avoid conflicts
enum TransactionType { credit, debit }

class AppTransaction {
  final String id;
  final String title;
  final String description;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String category;
  final IconData icon;
  final Color iconColor;
  final String? bankName;
  final String? recipientName;
  final String? recipientAccount;
  final double fee;
  final String? reference;
  final String status;
  final String? transactionType;

  AppTransaction({
    required this.id,
    required this.title,
    required this.description,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    required this.icon,
    required this.iconColor,
    this.bankName,
    this.recipientName,
    this.recipientAccount,
    this.fee = 0.0,
    this.reference,
    this.status = 'Completed',
    this.transactionType,
  });
}

class TransactionReceiptSheet extends StatelessWidget {
  final AppTransaction transaction;
  final VoidCallback onShareReceipt;

  const TransactionReceiptSheet({
    super.key,
    required this.transaction,
    required this.onShareReceipt,
  });

  // Helper function to safely convert any value to double
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

  @override
  Widget build(BuildContext context) {
    final safeAmount = _safeDouble(transaction.amount);
    final safeAmountAbs = _safeDouble(transaction.amount.abs());
    final safeFee = _safeDouble(transaction.fee);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: transaction.iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    transaction.icon,
                    color: transaction.iconColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        transaction.category,
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
            const SizedBox(height: 24),
            Text(
              transaction.type == TransactionType.credit
                  ? '+\$${safeAmount.toStringAsFixed(2)}'
                  : '-\$${safeAmountAbs.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: transaction.type == TransactionType.credit
                    ? Colors.green[700]
                    : Colors.red[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              transaction.type == TransactionType.credit ? 'Credit' : 'Debit',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            _buildDetailRow('Description', transaction.description),
            _buildDetailRow('Transaction ID', transaction.id),
            _buildDetailRow(
                'Date', DateFormat('dd/MM/yyyy').format(transaction.date)),
            _buildDetailRow(
                'Time', DateFormat('HH:mm:ss').format(transaction.date)),
            _buildDetailRow('Status', transaction.status),
            if (transaction.recipientName != null)
              _buildDetailRow('Recipient', transaction.recipientName!),
            if (transaction.recipientAccount != null)
              _buildDetailRow('Account', transaction.recipientAccount!),
            if (transaction.bankName != null)
              _buildDetailRow('Bank', transaction.bankName!),
            if (safeFee > 0)
              _buildDetailRow('Fee', '\$${safeFee.toStringAsFixed(2)}'),
            if (transaction.reference != null)
              _buildDetailRow('Reference', transaction.reference!),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onShareReceipt,
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Receipt'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
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
          ],
        ),
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
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper function to save different transaction types
Future<void> saveTransactionToFirestore({
  required String userId,
  required String title,
  required String description,
  required double amount,
  required String category,
  String? bankName,
  String? recipientName,
  String? recipientAccount,
  double fee = 0.0,
  String status = 'Completed',
  String? transactionType,
}) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';

    await firestore
        .collection('users')
        .doc(userId)
        .collection('transactions')
        .doc(transactionId)
        .set({
      'id': transactionId,
      'title': title,
      'description': description,
      'amount': amount,
      'category': category,
      'transactionType': transactionType ?? category,
      'timestamp': DateTime.now(),
      'bankName': bankName,
      'recipientName': recipientName,
      'recipientAccount': recipientAccount,
      'fee': fee,
      'status': status,
      'reference': 'REF${DateTime.now().millisecondsSinceEpoch}',
    });

    // Update user balance
    await firestore.collection('users').doc(userId).update({
      'balance': FieldValue.increment(amount),
    });
  } catch (e) {
    debugPrint('Error saving transaction: $e');
    rethrow;
  }
}
