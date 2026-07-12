import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  String _selectedMethod = 'bank_transfer';
  String? _selectedCardType = 'Visa';
  bool _isLoading = false;
  double _processingFee = 0.0;
  User? _currentUser;
  DocumentReference? _userRef;
  double _userBalance = 0.0;
  String? _primaryAccountNumber;

  // Firebase Data
  Map<String, dynamic>? _depositSettings;
  List<Map<String, dynamic>> _depositMethods = [];
  Map<String, dynamic>? _selectedMethodDetails;
  Map<String, dynamic>? _depositFees;
  Map<String, dynamic>? _depositLimits;
  List<Map<String, dynamic>> _quickAmounts = [];

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _userRef =
          FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      _loadUserBalance();
      _loadDepositData();
    }
    _amountController.addListener(_calculateFee);
  }

  Future<void> _loadUserBalance() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          final balanceValue = userData?['balance'];
          _userBalance = balanceValue is int
              ? balanceValue.toDouble()
              : (balanceValue as num? ?? 0.0).toDouble();
          _primaryAccountNumber = userData?['accountNumber'] ?? 'ACCOUNT001';
        });
      }
    } catch (e) {
      print('Error loading user balance: $e');
    }
  }

  Future<void> _loadDepositData() async {
    print('🔄 Starting to load deposit data...');
    final startTime = DateTime.now();

    try {
      // Load deposit settings
      final settingsStart = DateTime.now();
      final settingsDoc = await FirebaseFirestore.instance
          .collection('deposit_settings')
          .doc('global')
          .get();
      final settingsEnd = DateTime.now();
      print(
          '   ⚙️ Settings loaded in ${settingsEnd.difference(settingsStart).inMilliseconds}ms');

      if (settingsDoc.exists) {
        setState(() {
          _depositSettings = settingsDoc.data();
          _depositLimits = _depositSettings?['limits'];
          _generateQuickAmounts();
        });
      }

      // Load deposit methods
      final methodsStart = DateTime.now();
      print('   💳 Starting to load deposit methods...');
      final methodsQuery = await FirebaseFirestore.instance
          .collection('deposit_methods')
          .where('isActive', isEqualTo: true)
          .orderBy('priority')
          .get();
      final methodsEnd = DateTime.now();
      print(
          '   ✅ Deposit methods loaded in ${methodsEnd.difference(methodsStart).inMilliseconds}ms');
      print('   📊 Found ${methodsQuery.docs.length} active methods');

      if (methodsQuery.docs.isNotEmpty) {
        setState(() {
          _depositMethods = methodsQuery.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data(),
                  })
              .toList();

          _selectedMethodDetails = _depositMethods.firstWhere(
            (method) => method['type'] == _selectedMethod,
            orElse: () => _depositMethods.isNotEmpty ? _depositMethods[0] : {},
          );
        });
      }

      // Load deposit fees
      final feesStart = DateTime.now();
      final feesQuery = await FirebaseFirestore.instance
          .collection('deposit_fees')
          .where('isActive', isEqualTo: true)
          .get();
      final feesEnd = DateTime.now();
      print(
          '   💰 Fees loaded in ${feesEnd.difference(feesStart).inMilliseconds}ms');

      if (feesQuery.docs.isNotEmpty) {
        final feesMap = <String, dynamic>{};
        for (final doc in feesQuery.docs) {
          feesMap[doc.data()['method'] as String] = doc.data();
        }
        setState(() {
          _depositFees = feesMap;
        });
      }

      final totalTime = DateTime.now().difference(startTime);
      print('🎉 All deposit data loaded in ${totalTime.inMilliseconds}ms');
    } catch (e) {
      print('❌ Error loading deposit data: $e');
      final totalTime = DateTime.now().difference(startTime);
      print('⏱️ Failed after ${totalTime.inMilliseconds}ms');
    }
  }

  void _generateQuickAmounts() {
    final minAmountValue = _depositLimits?['minDepositAmount'];
    final minAmount = minAmountValue is int
        ? minAmountValue.toDouble()
        : (minAmountValue as num? ?? 10.0).toDouble();

    final maxAmountValue = _depositLimits?['maxDepositAmount'];
    final maxAmount = maxAmountValue is int
        ? maxAmountValue.toDouble()
        : (maxAmountValue as num? ?? 10000.0).toDouble();

    _quickAmounts = [
      {'amount': minAmount, 'label': 'Min'},
      {'amount': 100.0},
      {'amount': 500.0},
      {'amount': 1000.0},
      {'amount': 5000.0},
      {'amount': 10000.0},
      {'amount': maxAmount, 'label': 'Max'},
    ].where((item) {
      final amountValue = item['amount'];
      final amount = amountValue is int
          ? amountValue.toDouble()
          : (amountValue as num).toDouble();
      return amount <= maxAmount;
    }).toList();
  }

  void _calculateFee() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (amount <= 0 || _depositFees == null) {
      setState(() => _processingFee = 0.0);
      return;
    }

    final feeInfo = _depositFees![_selectedMethod];
    if (feeInfo == null) {
      setState(() => _processingFee = 0.0);
      return;
    }

    if (feeInfo['feeType'] == 'fixed') {
      final feeValue = feeInfo['feeValue'];
      setState(() {
        _processingFee = feeValue is int
            ? feeValue.toDouble()
            : (feeValue as num? ?? 0.0).toDouble();
      });
    } else if (feeInfo['feeType'] == 'percentage') {
      final feeValue = feeInfo['feeValue'];
      final percentage = (feeValue is int
              ? feeValue.toDouble()
              : (feeValue as num? ?? 0.0).toDouble()) /
          100;
      final calculatedFee = amount * percentage;

      final minFeeValue = feeInfo['minFee'];
      final minFee = minFeeValue is int
          ? minFeeValue.toDouble()
          : (minFeeValue as num? ?? 0.0).toDouble();

      final maxFeeValue = feeInfo['maxFee'];
      final maxFee = maxFeeValue is int
          ? maxFeeValue.toDouble()
          : (maxFeeValue as num? ?? double.infinity).toDouble();

      setState(() {
        _processingFee = calculatedFee.clamp(minFee, maxFee).toDouble();
      });
    }
  }

  double get _totalAmount {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return amount + _processingFee;
  }

  Future<void> _processDeposit() async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final minAmountValue = _depositLimits?['minDepositAmount'];
    final minAmount = minAmountValue is int
        ? minAmountValue.toDouble()
        : (minAmountValue as num? ?? 10.0).toDouble();

    final maxAmountValue = _depositLimits?['maxDepositAmount'];
    final maxAmount = maxAmountValue is int
        ? maxAmountValue.toDouble()
        : (maxAmountValue as num? ?? 10000.0).toDouble();

    final requiresAdminApprovalAboveValue =
        _depositLimits?['requiresAdminApprovalAbove'];
    final requiresAdminApprovalAbove = requiresAdminApprovalAboveValue is int
        ? requiresAdminApprovalAboveValue.toDouble()
        : (requiresAdminApprovalAboveValue as num? ?? 5000.0).toDouble();

    // Validation
    if (amount < minAmount) {
      _showError('Minimum deposit amount is \$${minAmount.toStringAsFixed(2)}');
      return;
    }

    if (amount > maxAmount) {
      _showError('Maximum deposit amount is \$${maxAmount.toStringAsFixed(2)}');
      return;
    }

    // Validate based on payment method
    if (_selectedMethod == 'card') {
      if (_cardNumberController.text.replaceAll(' ', '').length != 16) {
        _showError('Please enter a valid 16-digit card number');
        return;
      }
      if (_expiryController.text.length != 5 ||
          !_expiryController.text.contains('/')) {
        _showError('Please enter expiry in MM/YY format');
        return;
      }
      if (_cvvController.text.length < 3) {
        _showError('Please enter a valid CVV');
        return;
      }
    }

    if (_userRef == null) {
      _showError('User not authenticated. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get user data
      final userDoc = await _userRef!.get();
      final userData = userDoc.data() as Map<String, dynamic>?;

      // Create deposit transaction
      final transactionId = 'DEP${DateTime.now().millisecondsSinceEpoch}';
      final transactionsRef = _userRef!.collection('transactions');

      final userName =
          userData?['name'] ?? userData?['email']?.split('@').first ?? 'User';

      final requiresAdminApproval = amount > requiresAdminApprovalAbove ||
          (_selectedMethodDetails?['requiresAdminApproval'] ?? true);

      final transactionData = {
        'amount': amount,
        'description': _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : 'Deposit via ${_selectedMethodDetails?['name'] ?? _selectedMethod}',
        'type': 'deposit',
        'timestamp': Timestamp.now(),
        'status': 'pending',
        'from': _selectedMethod == 'bank_transfer'
            ? (_selectedMethodDetails?['bankDetails']?['bankName'] ??
                'Bank Transfer')
            : _selectedCardType ?? 'Card',
        'to': userName,
        'balanceAfter': _userBalance + amount,
        'category': 'deposit',
        'accountNumber': _primaryAccountNumber,
        'transactionId': transactionId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'userId': _currentUser!.uid,
        'userEmail': _currentUser!.email,
        'userName': userName,
        'currency': _depositSettings?['general']?['defaultCurrency'] ?? 'USD',
        'securityLevel': 'high',
        'requiresVerification': true,
        'verified': false,
        'transactionType': 'deposit',
        'depositDetails': {
          'method': _selectedMethod,
          'methodName': _selectedMethodDetails?['name'],
          'fee': _processingFee,
          'total': _totalAmount,
          'requiresAdminApproval': requiresAdminApproval,
          'adminApproved': false,
          'adminNotes': requiresAdminApproval
              ? 'Pending admin approval'
              : 'Auto-approved',
          'adminApprovedBy': null,
          'adminApprovedAt': null,
          'referenceNumber':
              'REF${DateTime.now().millisecondsSinceEpoch ~/ 1000}',
          'currency': _depositSettings?['general']?['defaultCurrency'] ?? 'USD',
          'processingTime':
              _selectedMethodDetails?['processingTime'] ?? '1-24 hours',
          'userId': _currentUser!.uid,
          'userEmail': _currentUser!.email,
          'userName': userName,
          ..._selectedMethod == 'card'
              ? {
                  'lastFour': _cardNumberController.text
                      .substring(_cardNumberController.text.length - 4),
                  'cardType': _selectedCardType,
                  'methodDetails': {
                    'lastFour': _cardNumberController.text
                        .substring(_cardNumberController.text.length - 4),
                    'cardType': _selectedCardType,
                    'expiry': _expiryController.text,
                  }
                }
              : _selectedMethod == 'bank_transfer'
                  ? {
                      'bankName': _selectedMethodDetails?['bankDetails']
                          ?['bankName'],
                      'accountName': _selectedMethodDetails?['bankDetails']
                          ?['accountName'],
                      'accountNumber': _selectedMethodDetails?['bankDetails']
                          ?['accountNumber'],
                      'methodDetails': {
                        'bankName': _selectedMethodDetails?['bankDetails']
                            ?['bankName'],
                        'accountName': _selectedMethodDetails?['bankDetails']
                            ?['accountName'],
                        'accountNumber': _selectedMethodDetails?['bankDetails']
                            ?['accountNumber'],
                      }
                    }
                  : {},
        },
      };

      await transactionsRef.doc(transactionId).set(transactionData);

      // Auto-approve if under limit
      final autoApproveLimitValue =
          _depositSettings?['general']?['autoApproveLimit'];
      final autoApproveLimit = autoApproveLimitValue is int
          ? autoApproveLimitValue.toDouble()
          : (autoApproveLimitValue as num? ?? 1000.0).toDouble();

      if (amount <= autoApproveLimit && !requiresAdminApproval) {
        await _autoApproveDeposit(transactionId, transactionData);
      }

      setState(() => _isLoading = false);

      // Show pending dialog
      _showPendingDialog(amount, transactionId);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to process deposit: $e');
    }
  }

  Future<void> _autoApproveDeposit(
      String transactionId, Map<String, dynamic> transactionData) async {
    try {
      final transactionRef =
          _userRef!.collection('transactions').doc(transactionId);

      await transactionRef.update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
        'depositDetails.adminApproved': true,
        'depositDetails.adminApprovedBy': 'system',
        'depositDetails.adminApprovedAt': FieldValue.serverTimestamp(),
        'depositDetails.adminNotes': 'Auto-approved (under limit)',
      });

      // Update user balance
      final amountValue = transactionData['amount'];
      final amount = amountValue is int
          ? amountValue.toDouble()
          : (amountValue as num).toDouble();
      final newBalance = _userBalance + amount;
      await _userRef!.update({
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': _currentUser!.uid,
        'title': 'Deposit Approved',
        'message':
            'Your deposit of \$${amount.toStringAsFixed(2)} has been approved and credited to your account.',
        'type': 'deposit_approved',
        'data': {'transactionId': transactionId},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error auto-approving deposit: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showPendingDialog(double amount, String transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.access_time_rounded,
                  color: Colors.orange[700], size: 30),
              const SizedBox(width: 10),
              const Text(
                'Deposit Pending',
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
              Text(
                'Your deposit of \$${amount.toStringAsFixed(2)} has been submitted.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.orange[700], size: 18),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedMethodDetails?['requiresAdminApproval'] == true
                          ? 'Your deposit will be processed once an administrator reviews and approves it. '
                              'You will receive a notification when the status changes.'
                          : 'Your deposit is being processed. You will receive a notification when completed.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            color: Colors.grey[600], size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Transaction ID: $transactionId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TransactionStatusScreen(transactionId: transactionId),
                  ),
                );
              },
              child: const Text('View Status'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAmountSection() {
    final minAmountValue = _depositLimits?['minDepositAmount'];
    final minAmount = minAmountValue is int
        ? minAmountValue.toDouble()
        : (minAmountValue as num? ?? 10.0).toDouble();

    final maxAmountValue = _depositLimits?['maxDepositAmount'];
    final maxAmount = maxAmountValue is int
        ? maxAmountValue.toDouble()
        : (maxAmountValue as num? ?? 10000.0).toDouble();

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Deposit Amount',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF003366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Enter Amount',
              labelStyle: const TextStyle(color: Color(0xFF003366)),
              prefixText: '\$ ',
              prefixStyle: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF003366),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              hintText: '0.00',
              suffixIcon: _amountController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => _amountController.clear(),
                    )
                  : null,
              helperText:
                  'Min: \$${minAmount.toStringAsFixed(2)} | Max: \$${maxAmount.toStringAsFixed(2)}',
              helperStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 12),
          if (_quickAmounts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickAmounts.map((amountData) {
                // Convert to double safely
                final amountValue = amountData['amount'];
                final amount = amountValue is int
                    ? amountValue.toDouble()
                    : (amountValue as num).toDouble();
                final label = amountData['label'] as String?;
                return _buildQuickAmountButton(amount, label);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickAmountButton(double amount, String? label) {
    return GestureDetector(
      onTap: () {
        _amountController.text = amount.toStringAsFixed(2);
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
          label ?? '\$${amount.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Color(0xFF003366),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 12),
          if (_depositMethods.isEmpty)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            ..._depositMethods.map((method) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildPaymentMethodCard(method),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedMethod == method['type'];
    final icon = _getIconData(method['icon'] as String?);
    final color = _getColorFromHex(method['color'] as String? ?? '#1976D2');

    return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedMethod = method['type'];
              _selectedMethodDetails = method;
              _calculateFee();
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        method['name'] as String? ?? 'Unknown Method',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        method['description'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Processing: ${method['processingTime'] ?? '1-24 hours'}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: method['type'] as String,
                  groupValue: _selectedMethod,
                  onChanged: (newValue) {
                    setState(() {
                      _selectedMethod = newValue!;
                      _selectedMethodDetails = method;
                      _calculateFee();
                    });
                  },
                  activeColor: color,
                ),
              ],
            ),
          ),
        ));
  }

  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      default:
        return Icons.payment_rounded;
    }
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor';
    }
    return Color(int.parse(hexColor, radix: 16));
  }

  Widget _buildBankTransferForm() {
    final bankDetails =
        _selectedMethodDetails?['bankDetails'] as Map<String, dynamic>?;

    if (bankDetails == null) {
      return Container();
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bank Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 12),
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
                  'Bank Account Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 8),
                if (bankDetails['accountName'] != null)
                  Text(
                    'Account Name: ${bankDetails['accountName']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 141, 140, 140),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (bankDetails['accountNumber'] != null)
                  Text(
                    'Account Number: ${bankDetails['accountNumber']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 141, 140, 140),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (bankDetails['bankName'] != null)
                  Text(
                    'Bank: ${bankDetails['bankName']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 141, 140, 140),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                if (bankDetails['swiftCode'] != null)
                  Text(
                    'SWIFT: ${bankDetails['swiftCode']}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color.fromARGB(255, 141, 140, 140),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                if (bankDetails['additionalInstructions'] != null)
                  Text(
                    bankDetails['additionalInstructions'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
                    ),
                  ),
                Text(
                  'Transfer to this account and the funds will be credited after admin approval.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardForm() {
    final supportedCardTypes =
        _selectedMethodDetails?['supportedCardTypes'] as List<dynamic>? ??
            ['Visa', 'Mastercard'];

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Card Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 12),

          // Card Type Selection
          if (supportedCardTypes.length > 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Card Type',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: supportedCardTypes.map<Widget>((type) {
                    final typeString = type.toString();
                    return ChoiceChip(
                      label: Text(typeString),
                      selected: _selectedCardType == typeString,
                      onSelected: (selected) {
                        setState(() {
                          _selectedCardType = typeString;
                        });
                      },
                      selectedColor: const Color(0xFF003366).withOpacity(0.2),
                      backgroundColor: Colors.grey[100],
                      labelStyle: TextStyle(
                        color: _selectedCardType == typeString
                            ? const Color(0xFF003366)
                            : Colors.grey[700],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),

          TextField(
            controller: _cardNumberController,
            decoration: InputDecoration(
              labelText: 'Card Number',
              labelStyle: const TextStyle(color: Color(0xFF003366)),
              prefixIcon: const Icon(Icons.credit_card_rounded,
                  color: Color(0xFF003366)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF003366),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              hintText: '1234 5678 9012 3456',
            ),
            keyboardType: TextInputType.number,
            maxLength: 19,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  decoration: InputDecoration(
                    labelText: 'MM/YY',
                    labelStyle: const TextStyle(color: Color(0xFF003366)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF003366),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    hintText: 'MM/YY',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  decoration: InputDecoration(
                    labelText: 'CVV',
                    labelStyle: const TextStyle(color: Color(0xFF003366)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF003366),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    hintText: '123',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    final requiresAdminApprovalAboveValue =
        _depositLimits?['requiresAdminApprovalAbove'];
    final requiresAdminApprovalAbove = requiresAdminApprovalAboveValue is int
        ? requiresAdminApprovalAboveValue.toDouble()
        : (requiresAdminApprovalAboveValue as num? ?? 5000.0).toDouble();

    final requiresAdminApproval = amount > requiresAdminApprovalAbove ||
        (_selectedMethodDetails?['requiresAdminApproval'] ?? true);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deposit Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Deposit Amount', '\$${amount.toStringAsFixed(2)}'),
          _buildSummaryRow(
              'Processing Fee', '\$${_processingFee.toStringAsFixed(2)}'),
          _buildSummaryRow(
              'Payment Method', _selectedMethodDetails?['name'] ?? ''),
          _buildSummaryRow('Processing Time',
              _selectedMethodDetails?['processingTime'] ?? ''),
          const Divider(height: 24),
          _buildSummaryRow(
            'Total Amount',
            '\$${_totalAmount.toStringAsFixed(2)}',
            isTotal: true,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  requiresAdminApproval ? Colors.orange[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: requiresAdminApproval
                    ? Colors.orange[100]!
                    : Colors.green[100]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  requiresAdminApproval
                      ? Icons.access_time_rounded
                      : Icons.check_circle_rounded,
                  color: requiresAdminApproval
                      ? Colors.orange[700]
                      : Colors.green[700],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    requiresAdminApproval
                        ? 'This deposit requires admin approval. Funds will be available after review.'
                        : 'This deposit will be processed automatically.',
                    style: TextStyle(
                      fontSize: 12,
                      color: requiresAdminApproval
                          ? Colors.orange[800]
                          : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTotal ? 16 : 14,
                color: Colors.grey[600],
                fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                color: isTotal ? const Color(0xFF003366) : Colors.grey[700],
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text(
          'Deposit Money',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Funds to Your Wallet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Current Balance: \$${_userBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Amount Section
              _buildAmountSection(),
              const SizedBox(height: 24),

              // Payment Method Section
              _buildPaymentMethodSection(),
              const SizedBox(height: 24),

              // Payment Method Specific Form
              if (_selectedMethod == 'bank_transfer') ...[
                _buildBankTransferForm(),
                const SizedBox(height: 24),
              ] else if (_selectedMethod == 'card') ...[
                _buildCardForm(),
                const SizedBox(height: 24),
              ],

              // Description (Optional)
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
                child: TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: Icon(Icons.description_rounded,
                        color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    hintText: 'e.g., Savings deposit',
                  ),
                  maxLines: 2,
                ),
              ),
              const SizedBox(height: 24),

              // Summary Section
              _buildSummarySection(),
              const SizedBox(height: 32),

              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading || _depositMethods.isEmpty
                          ? null
                          : _processDeposit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF003366).withOpacity(0.3),
                      ),
                      child: _isLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance_wallet_rounded,
                                    size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Submit Deposit Request',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
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
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final minAmountValue = _depositLimits?['minDepositAmount'];
    final minAmount = minAmountValue is int
        ? minAmountValue.toDouble()
        : (minAmountValue as num? ?? 10.0).toDouble();

    final maxAmountValue = _depositLimits?['maxDepositAmount'];
    final maxAmount = maxAmountValue is int
        ? maxAmountValue.toDouble()
        : (maxAmountValue as num? ?? 10000.0).toDouble();

    final dailyLimitValue = _depositLimits?['dailyDepositLimit'];
    final dailyLimit = dailyLimitValue is int
        ? dailyLimitValue.toDouble()
        : (dailyLimitValue as num? ?? 50000.0).toDouble();

    final monthlyLimitValue = _depositLimits?['monthlyDepositLimit'];
    final monthlyLimit = monthlyLimitValue is int
        ? monthlyLimitValue.toDouble()
        : (monthlyLimitValue as num? ?? 200000.0).toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deposit Help'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Important Information',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Minimum deposit: \$${minAmount.toStringAsFixed(2)}\n'
                  '• Maximum deposit: \$${maxAmount.toStringAsFixed(2)}\n'
                  '• Daily limit: \$${dailyLimit.toStringAsFixed(2)}\n'
                  '• Monthly limit: \$${monthlyLimit.toStringAsFixed(2)}\n'
                  '• All deposits are processed securely\n'
                  '• You will receive notifications for all transactions\n'
                  '• Contact support for urgent requests',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                if (_depositMethods.isNotEmpty) ...[
                  Text(
                    'Available Methods:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._depositMethods.map((method) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            _getIconData(method['icon'] as String?),
                            color: _getColorFromHex(
                                method['color'] as String? ?? '#1976D2'),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${method['name']} - ${method['processingTime']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
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
                          'Keep your transaction details for reference',
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

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

// Transaction Status Screen
class TransactionStatusScreen extends StatelessWidget {
  final String transactionId;

  const TransactionStatusScreen({super.key, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF003366),
          title: const Text('Transaction Status'),
        ),
        body: const Center(child: Text('User not authenticated')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text(
          'Transaction Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('transactions')
            .doc(transactionId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Error loading transaction status'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transaction = snapshot.data?.data() as Map<String, dynamic>?;

          if (transaction == null) {
            return const Center(child: Text('Transaction not found'));
          }

          return _buildStatusContent(transaction, context);
        },
      ),
    );
  }

  Widget _buildStatusContent(
      Map<String, dynamic> transaction, BuildContext context) {
    final status = transaction['status'] as String? ?? 'pending';

    final amountValue = transaction['amount'];
    final amount = amountValue is int
        ? amountValue.toDouble()
        : (amountValue as num? ?? 0.0).toDouble();

    final depositDetails =
        transaction['depositDetails'] as Map<String, dynamic>? ?? {};

    final feeValue = depositDetails['fee'];
    final fee = feeValue is int
        ? feeValue.toDouble()
        : (feeValue as num? ?? 0.0).toDouble();

    final totalValue = depositDetails['total'];
    final total = totalValue is int
        ? totalValue.toDouble()
        : (totalValue as num? ?? 0.0).toDouble();

    final method = depositDetails['method'] as String? ?? 'bank_transfer';
    final createdAt = transaction['createdAt'] as Timestamp?;
    final updatedAt = transaction['updatedAt'] as Timestamp?;
    final adminNotes = depositDetails['adminNotes'] as String?;
    final processedAt = depositDetails['processedAt'] as Timestamp?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getStatusColor(status).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                // Transaction Type Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003366).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    transaction['transactionType'] as String? ?? 'Transaction',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF003366),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _getStatusTitle(status),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _getStatusColor(status),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusMessage(status),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                if (adminNotes != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.message_rounded,
                            color: Colors.blue[700], size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Admin Note: $adminNotes',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[800],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Transaction Details
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaction Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Transaction ID',
                    transaction['transactionId'] as String? ?? ''),
                _buildDetailRow('Amount', '\$${amount.toStringAsFixed(2)}'),
                _buildDetailRow(
                    'Processing Fee', '\$${fee.toStringAsFixed(2)}'),
                _buildDetailRow('Total', '\$${total.toStringAsFixed(2)}'),
                _buildDetailRow('Payment Method',
                    method == 'bank_transfer' ? 'Bank Transfer' : 'Card'),
                if (depositDetails['bankName'] != null)
                  _buildDetailRow('Bank', depositDetails['bankName'] as String),
                if (createdAt != null)
                  _buildDetailRow('Request Date',
                      '${createdAt.toDate().day}/${createdAt.toDate().month}/${createdAt.toDate().year} ${createdAt.toDate().hour}:${createdAt.toDate().minute}'),
                if (updatedAt != null && status != 'pending')
                  _buildDetailRow('Processed Date',
                      '${updatedAt.toDate().day}/${updatedAt.toDate().month}/${updatedAt.toDate().year} ${updatedAt.toDate().hour}:${updatedAt.toDate().minute}'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Timeline
          Container(
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaction Timeline',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTimelineStep(
                  'Request Submitted',
                  true,
                  createdAt != null ? createdAt.toDate() : DateTime.now(),
                  Icons.check_circle_rounded,
                  Colors.green,
                ),
                _buildTimelineStep(
                  'Admin Review',
                  status != 'pending',
                  status != 'pending' && updatedAt != null
                      ? updatedAt.toDate()
                      : null,
                  status == 'pending'
                      ? Icons.access_time_rounded
                      : status == 'completed'
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                  status == 'pending'
                      ? Colors.orange
                      : status == 'completed'
                          ? Colors.green
                          : Colors.red,
                ),
                _buildTimelineStep(
                  status == 'completed' ? 'Funds Credited' : 'Completion',
                  status == 'completed',
                  processedAt?.toDate(),
                  status == 'completed'
                      ? Icons.check_circle_rounded
                      : Icons.pending_rounded,
                  status == 'completed' ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Admin Approval Status
          if (depositDetails['requiresAdminApproval'] == true) ...[
            Container(
              padding: const EdgeInsets.all(20),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Approval Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Approval Required', 'Yes'),
                  _buildDetailRow('Approved',
                      (depositDetails['adminApproved'] == true) ? 'Yes' : 'No'),
                  if (depositDetails['adminApprovedBy'] != null)
                    _buildDetailRow('Approved By', 'Admin'),
                  if (depositDetails['adminApprovedAt'] != null)
                    _buildDetailRow(
                        'Approved At',
                        '${(depositDetails['adminApprovedAt'] as Timestamp).toDate().day}/'
                            '${(depositDetails['adminApprovedAt'] as Timestamp).toDate().month}/'
                            '${(depositDetails['adminApprovedAt'] as Timestamp).toDate().year}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Action Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Back to Dashboard',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep(String title, bool completed, DateTime? date,
      IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: completed ? Colors.black : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (date != null)
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'failed':
      case 'rejected':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      default: // pending
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'failed':
      case 'rejected':
        return Icons.cancel_rounded;
      case 'processing':
        return Icons.hourglass_bottom_rounded;
      default: // pending
        return Icons.access_time_rounded;
    }
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'completed':
        return 'Transaction Completed';
      case 'failed':
        return 'Transaction Failed';
      case 'rejected':
        return 'Transaction Rejected';
      case 'processing':
        return 'Processing';
      default: // pending
        return 'Pending Approval';
    }
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'completed':
        return 'Your deposit has been approved and credited to your account.';
      case 'failed':
        return 'The transaction could not be processed. Please try again.';
      case 'rejected':
        return 'Your transaction request was rejected. Contact support for more information.';
      case 'processing':
        return 'Your transaction is being processed by our team.';
      default: // pending
        return 'Your transaction request is awaiting admin approval. You will be notified once processed.';
    }
  }
}
