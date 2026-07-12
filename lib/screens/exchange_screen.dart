import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ExchangeScreen extends StatefulWidget {
  const ExchangeScreen({super.key});

  @override
  State<ExchangeScreen> createState() => _ExchangeScreenState();
}

class _ExchangeScreenState extends State<ExchangeScreen> {
  // Exchange rates from Firestore
  Map<String, double> exchangeRates = {};
  bool _isLoading = true;

  // List of currencies
  final List<String> currencies = [
    'USD',
    'GBP',
    'EUR',
    'NGN',
    'CAD',
    'AUD',
    'JPY',
    'CNY',
  ];

  String fromCurrency = 'USD';
  String toCurrency = 'GBP';
  double amount = 100.0;
  double convertedAmount = 79.0;

  TextEditingController amountController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    amountController.text = amount.toStringAsFixed(2);
    _loadExchangeRates();
  }

  Future<void> _loadExchangeRates() async {
    try {
      final ratesDoc =
          await _firestore.collection('exchange_rates').doc('latest').get();

      if (ratesDoc.exists) {
        final data = ratesDoc.data()!;
        setState(() {
          exchangeRates = Map<String, double>.from(data);
          _isLoading = false;
          _calculateConversion();
        });
      } else {
        // Use default rates if none exist
        await _setDefaultExchangeRates();
      }
    } catch (e) {
      debugPrint('Error loading exchange rates: $e');
      await _setDefaultExchangeRates();
    }
  }

  Future<void> _setDefaultExchangeRates() async {
    setState(() {
      exchangeRates = {
        'USD': 1.0,
        'GBP': 0.79,
        'EUR': 0.92,
        'NGN': 1500.0,
        'CAD': 1.35,
        'AUD': 1.52,
        'JPY': 148.0,
        'CNY': 7.15,
      };
      _isLoading = false;
      _calculateConversion();
    });

    // Save default rates to Firestore
    try {
      await _firestore.collection('exchange_rates').doc('latest').set({
        'USD': 1.0,
        'GBP': 0.79,
        'EUR': 0.92,
        'NGN': 1500.0,
        'CAD': 1.35,
        'AUD': 1.52,
        'JPY': 148.0,
        'CNY': 7.15,
        'lastUpdated': FieldValue.serverTimestamp(),
        'baseCurrency': 'USD',
      });
    } catch (e) {
      debugPrint('Error saving exchange rates: $e');
    }
  }

  void _calculateConversion() {
    if (amountController.text.isEmpty || exchangeRates.isEmpty) return;

    setState(() {
      amount = double.tryParse(amountController.text) ?? 0.0;
      if (fromCurrency == toCurrency) {
        convertedAmount = amount;
      } else {
        // Convert to USD first, then to target currency
        double amountInUSD = amount / exchangeRates[fromCurrency]!;
        convertedAmount = amountInUSD * exchangeRates[toCurrency]!;
      }
    });
  }

  void _swapCurrencies() {
    setState(() {
      String temp = fromCurrency;
      fromCurrency = toCurrency;
      toCurrency = temp;
      _calculateConversion();
    });
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return '€';
      case 'NGN':
        return '₦';
      case 'CAD':
        return '\$';
      case 'AUD':
        return '\$';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      default:
        return '\$';
    }
  }

  String _getCurrencyName(String currency) {
    switch (currency) {
      case 'USD':
        return 'US Dollar';
      case 'GBP':
        return 'British Pound';
      case 'EUR':
        return 'Euro';
      case 'NGN':
        return 'Nigerian Naira';
      case 'CAD':
        return 'Canadian Dollar';
      case 'AUD':
        return 'Australian Dollar';
      case 'JPY':
        return 'Japanese Yen';
      case 'CNY':
        return 'Chinese Yuan';
      default:
        return 'US Dollar';
    }
  }

  Future<void> _processExchange() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorMessage('Please log in to process exchange');
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Get user's account for the source currency
      final userAccounts = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .where('currencyCode', isEqualTo: fromCurrency)
          .limit(1)
          .get();

      if (userAccounts.docs.isEmpty) {
        _showErrorMessage('No account found for $fromCurrency');
        return;
      }

      final sourceAccount = userAccounts.docs.first;
      final sourceBalance = (sourceAccount.data()['balance'] ?? 0.0).toDouble();

      if (sourceBalance < amount) {
        _showErrorMessage('Insufficient balance in $fromCurrency account');
        return;
      }

      // Show confirmation dialog
      _showExchangeConfirmation(sourceAccount);
    } catch (e) {
      debugPrint('Error processing exchange: $e');
      _showErrorMessage('Failed to process exchange');
    }
  }

  void _showExchangeConfirmation(DocumentSnapshot sourceAccount) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.currency_exchange_rounded,
                color: Color(0xFF003366),
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'Confirm Exchange',
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
              _buildConfirmationDetail('From:',
                  '${_getCurrencySymbol(fromCurrency)}${amount.toStringAsFixed(2)} $fromCurrency'),
              _buildConfirmationDetail('To:',
                  '${_getCurrencySymbol(toCurrency)}${convertedAmount.toStringAsFixed(2)} $toCurrency'),
              _buildConfirmationDetail('Exchange Rate:',
                  '1 $fromCurrency = ${(exchangeRates[toCurrency]! / exchangeRates[fromCurrency]!).toStringAsFixed(4)} $toCurrency'),
              _buildConfirmationDetail('Fee:', 'No fees'),
              const SizedBox(height: 20),
              const Text(
                'Are you sure you want to proceed with this exchange?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
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
                _executeExchange(sourceAccount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm Exchange'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
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

  Future<void> _executeExchange(DocumentSnapshot sourceAccount) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get or create target account
      final targetAccounts = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .where('currencyCode', isEqualTo: toCurrency)
          .limit(1)
          .get();

      DocumentReference targetAccountRef;

      if (targetAccounts.docs.isEmpty) {
        // Create new account for target currency
        final newAccount = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .add({
          'title': '$toCurrency Account',
          'accountNumber':
              '$toCurrency-${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 13)}',
          'balance': convertedAmount,
          'available': convertedAmount,
          'currencyCode': toCurrency,
          'isPrimary': false,
          'status': 'Active',
          'type': 'checking',
          'interestRate': '0.0%',
          'openedDate': FieldValue.serverTimestamp(),
          'lastTransaction': 'Currency Exchange',
          'createdAt': FieldValue.serverTimestamp(),
        });
        targetAccountRef = newAccount;
      } else {
        targetAccountRef = targetAccounts.docs.first.reference;
      }

      // Update source account balance
      await sourceAccount.reference.update({
        'balance': FieldValue.increment(-amount),
        'available': FieldValue.increment(-amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update target account balance
      await targetAccountRef.update({
        'balance': FieldValue.increment(convertedAmount),
        'available': FieldValue.increment(convertedAmount),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastTransaction': 'Exchange from $fromCurrency',
      });

      // Record the transaction
      await _recordExchangeTransaction();

      // Show success message
      _showExchangeSuccess();
    } catch (e) {
      debugPrint('Error executing exchange: $e');
      _showErrorMessage('Failed to complete exchange');
    }
  }

  Future<void> _recordExchangeTransaction() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final transactionId = 'EXC-${DateTime.now().millisecondsSinceEpoch}';

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .add({
      'amount': -amount,
      'description': 'Currency Exchange to $toCurrency',
      'type': 'exchange',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed',
      'from': fromCurrency,
      'to': toCurrency,
      'convertedAmount': convertedAmount,
      'exchangeRate': exchangeRates[toCurrency]! / exchangeRates[fromCurrency]!,
      'category': 'exchange',
      'accountNumber': '$fromCurrency Account',
      'transactionId': transactionId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also record the incoming transaction in target currency
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('transactions')
        .add({
      'amount': convertedAmount,
      'description': 'Currency Exchange from $fromCurrency',
      'type': 'deposit',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'completed',
      'from': 'Currency Exchange',
      'to': user.displayName ?? user.email,
      'category': 'exchange',
      'accountNumber': '$toCurrency Account',
      'transactionId': '$transactionId-IN',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  void _showExchangeSuccess() {
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
                'Exchange Successful!',
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
                'You have successfully exchanged ${_getCurrencySymbol(fromCurrency)}${amount.toStringAsFixed(2)} $fromCurrency to ${_getCurrencySymbol(toCurrency)}${convertedAmount.toStringAsFixed(2)} $toCurrency',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Transaction ID: EX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage('Currency exchange completed!');

                // Refresh the screen
                _calculateConversion();
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Currency Exchange'),
          backgroundColor: const Color(0xFF003366),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF003366),
          ),
        ),
      );
    }

    double exchangeRate =
        exchangeRates[toCurrency]! / exchangeRates[fromCurrency]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Currency Exchange'),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exchange Card
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
              child: Column(
                children: [
                  // Exchange Rate Display
                  Text(
                    '1 $fromCurrency = ${exchangeRate.toStringAsFixed(4)} $toCurrency',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<DocumentSnapshot>(
                    stream: _firestore
                        .collection('exchange_rates')
                        .doc('latest')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final lastUpdated = snapshot.data?.data()?['lastUpdated'];
                      String updateText = 'Market Rate • ';

                      if (lastUpdated is Timestamp) {
                        final now = DateTime.now();
                        final updated = lastUpdated.toDate();
                        final difference = now.difference(updated);

                        if (difference.inMinutes < 60) {
                          updateText += '${difference.inMinutes} min ago';
                        } else if (difference.inHours < 24) {
                          updateText += '${difference.inHours} hours ago';
                        } else {
                          updateText +=
                              DateFormat('MMM dd, yyyy').format(updated);
                        }
                      } else {
                        updateText += 'Live rates';
                      }

                      return Text(
                        updateText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // From Currency Card
            _buildCurrencyCard(
              'From',
              fromCurrency,
              true,
              amount,
              (value) {
                setState(() {
                  fromCurrency = value;
                });
                _calculateConversion();
              },
            ),
            const SizedBox(height: 20),

            // Swap Button
            Center(
              child: GestureDetector(
                onTap: _swapCurrencies,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.swap_vert_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // To Currency Card
            _buildCurrencyCard(
              'To',
              toCurrency,
              false,
              convertedAmount,
              (value) {
                setState(() {
                  toCurrency = value;
                });
                _calculateConversion();
              },
            ),
            const SizedBox(height: 30),

            // Exchange Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
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
                  _buildExchangeDetail('Exchange Rate',
                      '1 $fromCurrency = ${exchangeRate.toStringAsFixed(4)} $toCurrency'),
                  _buildExchangeDetail('Fee', 'No fees'),
                  _buildExchangeDetail('Processing Time', 'Instant'),
                  _buildExchangeDetail('Total to Receive',
                      '${_getCurrencySymbol(toCurrency)}${convertedAmount.toStringAsFixed(2)} $toCurrency'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Convert Button
            ElevatedButton(
              onPressed: _processExchange,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                'Convert Currency',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Popular Conversions
            const Text(
              'Popular Conversions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPopularConversion('USD', 'EUR'),
                  const SizedBox(width: 12),
                  _buildPopularConversion('GBP', 'USD'),
                  const SizedBox(width: 12),
                  _buildPopularConversion('EUR', 'GBP'),
                  const SizedBox(width: 12),
                  _buildPopularConversion('USD', 'NGN'),
                  const SizedBox(width: 12),
                  _buildPopularConversion('GBP', 'EUR'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Rate Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFF003366),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Exchange rates are updated in real-time. Please note that rates may fluctuate and the final amount may vary.',
                      style: TextStyle(
                        color: Color(0xFF003366),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(
    String label,
    String currency,
    bool isFrom,
    double amount,
    ValueChanged<String> onCurrencyChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: isFrom
                    ? TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: _getCurrencySymbol(currency),
                          prefixStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003366),
                          ),
                          border: InputBorder.none,
                          hintText: '0.00',
                          hintStyle: const TextStyle(
                            fontSize: 28,
                            color: Colors.grey,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                        ),
                        onChanged: (value) {
                          _calculateConversion();
                        },
                      )
                    : Text(
                        '${_getCurrencySymbol(currency)}${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF003366),
                        ),
                      ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF003366),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButton<String>(
                  value: currency,
                  icon: const Icon(Icons.arrow_drop_down_rounded,
                      color: Colors.white),
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF003366),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      onCurrencyChanged(newValue);
                    }
                  },
                  items:
                      currencies.map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Text(value),
                          const SizedBox(width: 8),
                          Text(
                            _getCurrencyName(value),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _getCurrencyName(currency),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
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

  Widget _buildPopularConversion(String from, String to) {
    if (exchangeRates.isEmpty) return const SizedBox();

    double rate = exchangeRates[to]! / exchangeRates[from]!;
    return GestureDetector(
      onTap: () {
        setState(() {
          fromCurrency = from;
          toCurrency = to;
          _calculateConversion();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(
              '$from → $to',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '1 $from = ${rate.toStringAsFixed(3)} $to',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
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

  void _showErrorMessage(String message) {
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

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }
}

extension on Object? {
  operator [](String other) {}
}
