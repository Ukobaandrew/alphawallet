import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'transaction_workflow_screen.dart' show AmountInputScreen;

class SendMoneyScreen extends StatefulWidget {
  const SendMoneyScreen({super.key});

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accountController = TextEditingController();
  final _bankSearchController = TextEditingController();

  final String _selectedAccount = 'USD Account • \$12,450.00';
  String? _selectedBank;
  String? _selectedBankId;
  bool _isLoading = false;
  bool _isSearchingAccounts = false;
  bool _showBankList = false;
  double _transferFee = 0.0;

  List<Map<String, dynamic>> _allBanks = [];
  List<Map<String, dynamic>> _filteredBanks = [];
  List<Map<String, dynamic>> _recentRecipients = [];
  List<Map<String, dynamic>> _accountSuggestions = [];
  List<Map<String, dynamic>> _suggestedBanks = [];

  // Debouncing variables for account search
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_calculateFee);
    _accountController.addListener(_onAccountNumberChanged);
    _loadAllBanks();
    _loadRecentRecipients();
  }

  Future<void> _loadAllBanks() async {
    try {
      final snapshot = await _firestore
          .collection('banks')
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        _allBanks = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
          };
        }).toList();
        _filteredBanks = _allBanks;
      });
    } catch (e) {
      print('Error loading banks: $e');
    }
  }

  Future<void> _loadRecentRecipients() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('recent_recipients')
          .orderBy('lastTransfer', descending: true)
          .limit(10)
          .get();

      setState(() {
        _recentRecipients = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading recent recipients: $e');
    }
  }

  void _onAccountNumberChanged() {
    // Clear previous debounce timer
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }

    final accountNumber = _accountController.text.trim();

    if (accountNumber.isEmpty) {
      setState(() {
        _accountSuggestions = [];
        _selectedBank = null;
        _selectedBankId = null;
        _recipientController.clear();
        _showBankList = false;
      });
      return;
    }

    // Debounce search to avoid too many queries
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchAccountInDatabase(accountNumber);
    });
  }

  Future<void> _searchAccountInDatabase(String accountNumber) async {
    if (accountNumber.length < 3) return;

    setState(() {
      _isSearchingAccounts = true;
      _accountSuggestions = [];
    });

    try {
      // Search in recent recipients first (fastest)
      final recentMatches = _recentRecipients.where((recipient) {
        final recipientAccount = recipient['account'].toString();
        return recipientAccount.contains(accountNumber) ||
            accountNumber.contains(recipientAccount);
      }).toList();

      if (recentMatches.isNotEmpty) {
        setState(() {
          _accountSuggestions = recentMatches;
        });

        // If exact match found, auto-fill
        final exactMatch = recentMatches.firstWhere(
          (recipient) => recipient['account'].toString() == accountNumber,
          orElse: () => {},
        );

        if (exactMatch.isNotEmpty) {
          _autoFillRecipient(exactMatch);
          return;
        }
      }

      // If not found in recent, search in all users collection
      if (accountNumber.length >= 8) {
        await _searchInAllUsers(accountNumber);
      }

      // Also search for bank by account number pattern
      await _suggestBanksByAccountNumber(accountNumber);
    } catch (e) {
      print('Error searching accounts: $e');
    } finally {
      setState(() {
        _isSearchingAccounts = false;
      });
    }
  }

  Future<void> _searchInAllUsers(String accountNumber) async {
    try {
      // Search in users collection for exact account number match
      final usersSnapshot = await _firestore
          .collection('users')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(5)
          .get();

      if (usersSnapshot.docs.isNotEmpty) {
        final userMatches = usersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'account': accountNumber,
            'name': data['name'] ?? 'User ${doc.id.substring(0, 8)}',
            'bank': data['bank'] ?? 'Alpha Bank',
            'bankId': data['bankId'] ?? 'bank_1',
            'avatar': _generateAvatar(data['name'] ?? 'User'),
            'type': 'user',
            'lastTransfer': FieldValue.serverTimestamp(),
          };
        }).toList();

        setState(() {
          _accountSuggestions = [..._accountSuggestions, ...userMatches];
        });

        // Auto-fill if exact match found
        if (usersSnapshot.docs.length == 1) {
          final userData = usersSnapshot.docs.first.data();
          _autoFillFromUserData(userData, accountNumber);
        }
      }

      // Also search in alpha_users collection
      final alphaUsersSnapshot = await _firestore
          .collection('alpha_users')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(5)
          .get();

      if (alphaUsersSnapshot.docs.isNotEmpty) {
        final alphaMatches = alphaUsersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'account': accountNumber,
            'name': data['name'] ?? 'Alpha User',
            'bank': data['bank'] ?? 'Alpha Bank',
            'bankId': data['bankId'] ?? 'bank_1',
            'avatar': _generateAvatar(data['name'] ?? 'Alpha'),
            'type': 'alpha_user',
            'lastTransfer': FieldValue.serverTimestamp(),
          };
        }).toList();

        setState(() {
          _accountSuggestions = [..._accountSuggestions, ...alphaMatches];
        });

        // Auto-fill if exact match found
        if (alphaUsersSnapshot.docs.length == 1) {
          final alphaData = alphaUsersSnapshot.docs.first.data();
          _autoFillFromAlphaData(alphaData, accountNumber);
        }
      }
    } catch (e) {
      print('Error searching in users: $e');
    }
  }

  Future<void> _suggestBanksByAccountNumber(String accountNumber) async {
    // Check for account number patterns (first 3 digits)
    final prefix =
        accountNumber.length >= 3 ? accountNumber.substring(0, 3) : '';

    // Common patterns for Greek banks
    final bankPatterns = {
      '001': 'Alpha Bank',
      '002': 'Piraeus Bank',
      '003': 'National Bank of Greece',
      '004': 'Eurobank',
      '005': 'Attica Bank',
      '006': 'Optima Bank',
      '007': 'HSBC Bank',
      '008': 'Aegean Baltic Bank',
      '009': 'Citibank Europe PLC',
      '010': 'City Bank',
    };

    final bankName = bankPatterns[prefix];

    if (bankName != null) {
      final matchingBanks = _allBanks.where((bank) {
        return bank['name'] == bankName;
      }).toList();

      if (matchingBanks.isNotEmpty) {
        setState(() {
          _suggestedBanks = matchingBanks;
        });

        // Auto-select bank if only one suggestion
        if (matchingBanks.length == 1 && _selectedBank == null) {
          _selectBank(matchingBanks.first);
        }
      }
    }
  }

  void _autoFillRecipient(Map<String, dynamic> recipient) {
    setState(() {
      _recipientController.text = recipient['name'] ?? '';
      _selectedBank = recipient['bank'];
      _selectedBankId = recipient['bankId'];
      _bankSearchController.text = recipient['bank'] ?? '';
      _suggestedBanks = [];
      _accountSuggestions = [];
    });

    // Show success message
    _showSuccessMessage('Recipient found: ${recipient['name']}');
  }

  void _autoFillFromUserData(
      Map<String, dynamic> userData, String accountNumber) {
    setState(() {
      _recipientController.text = userData['name'] ?? 'User';
      _selectedBank = userData['bank'] ?? 'Alpha Bank';
      _selectedBankId = userData['bankId'] ?? 'bank_1';
      _bankSearchController.text = _selectedBank ?? '';
      _suggestedBanks = [];
      _accountSuggestions = [];
    });

    // Show success message
    _showSuccessMessage('Account verified: ${userData['name']}');
  }

  void _autoFillFromAlphaData(
      Map<String, dynamic> alphaData, String accountNumber) {
    setState(() {
      _recipientController.text = alphaData['name'] ?? 'Alpha User';
      _selectedBank = alphaData['bank'] ?? 'Alpha Bank';
      _selectedBankId = alphaData['bankId'] ?? 'bank_1';
      _bankSearchController.text = _selectedBank ?? '';
      _suggestedBanks = [];
      _accountSuggestions = [];
    });

    // Show success message
    _showSuccessMessage('Alpha account found: ${alphaData['name']}');
  }

  void _filterBanks(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredBanks = _allBanks;
        _showBankList = true;
      });
      return;
    }

    final searchQuery = query.toLowerCase();
    setState(() {
      _filteredBanks = _allBanks.where((bank) {
        final bankName = bank['name'].toString().toLowerCase();
        final bankCode = bank['code'].toString().toLowerCase();
        final country = bank['country'].toString().toLowerCase();

        return bankName.contains(searchQuery) ||
            bankCode.contains(searchQuery) ||
            country.contains(searchQuery);
      }).toList();
      _showBankList = true;
    });
  }

  void _selectBank(Map<String, dynamic> bank) {
    setState(() {
      _selectedBank = bank['name'];
      _selectedBankId = bank['id'];
      _bankSearchController.text = bank['name'];
      _suggestedBanks = [];
      _showBankList = false;
    });
    FocusScope.of(context).unfocus();
  }

  void _selectRecipient(Map<String, dynamic> recipient) {
    _autoFillRecipient(recipient);
  }

  void _selectAccountSuggestion(Map<String, dynamic> suggestion) {
    _autoFillRecipient(suggestion);
  }

  void _clearForm() {
    setState(() {
      _selectedBank = null;
      _selectedBankId = null;
      _bankSearchController.clear();
      _recipientController.clear();
      _accountController.clear();
      _amountController.clear();
      _descriptionController.clear();
      _transferFee = 0.0;
      _suggestedBanks = [];
      _accountSuggestions = [];
      _showBankList = false;
    });

    _filterBanks('');
  }

  void _calculateFee() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _transferFee = _getTransferFee(amount);
    });
  }

  double _getTransferFee(double amount) {
    if (amount <= 0) return 0.0;
    if (amount <= 5000) return 10.0;
    if (amount <= 50000) return 25.0;
    if (amount <= 100000) return 50.0;
    return 100.0;
  }

  double get _totalAmount {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    return amount + _transferFee;
  }

  void _proceedToAmount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBank == null) {
      _showError('Please select a bank');
      return;
    }

    final accountNumber = _accountController.text.replaceAll(' ', '');
    if (accountNumber.length < 8) {
      _showError('Account number must be at least 8 digits');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    if (amount > 1000000) {
      _showError('Maximum transfer limit is \$1,000,000');
      return;
    }

    setState(() => _isLoading = true);

    // Simulate verification
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    // Save recipient to recent recipients
    await _saveRecentRecipient();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmountInputScreen(
          recipientName: _recipientController.text,
          recipientAccount: _accountController.text,
          transactionType: 'Bank Transfer',
          bankName: _selectedBank!,
          initialAmount: amount,
          description: _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : 'Bank Transfer to ${_recipientController.text}',
        ),
      ),
    );
  }

  Future<void> _saveRecentRecipient() async {
    final user = _auth.currentUser;
    if (user == null || _selectedBankId == null) return;

    final recipientsRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('recent_recipients');

    final recipientId = '${_selectedBankId}_${_accountController.text}';
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    // First, try to get the existing document
    final docSnapshot = await recipientsRef.doc(recipientId).get();

    if (docSnapshot.exists) {
      // UPDATE existing document
      await recipientsRef.doc(recipientId).update({
        'name': _recipientController.text,
        'bank': _selectedBank,
        'bankId': _selectedBankId,
        'avatar': _generateAvatar(_recipientController.text),
        'lastTransfer': DateTime.now(), // Use actual DateTime
        'totalTransfers': FieldValue.increment(1),
        'totalAmount': FieldValue.increment(amount),
        'updatedAt': DateTime.now(),
      });
    } else {
      // CREATE new document (first time saving this recipient)
      await recipientsRef.doc(recipientId).set({
        'name': _recipientController.text,
        'account': _accountController.text,
        'bank': _selectedBank,
        'bankId': _selectedBankId,
        'avatar': _generateAvatar(_recipientController.text),
        'lastTransfer': DateTime.now(), // Use actual DateTime
        'totalTransfers': 1, // Start with 1 (not FieldValue)
        'totalAmount': amount, // Start with amount (not FieldValue)
        'isFavorite': false,
        'createdAt': DateTime.now(),
        'updatedAt': DateTime.now(),
      });
    }
  }

  String _generateAvatar(String name) {
    if (name.isEmpty) return '??';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAccountNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Account Number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
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
        const SizedBox(height: 8),
        Stack(
          children: [
            TextFormField(
              controller: _accountController,
              decoration: InputDecoration(
                hintText: 'Enter account number...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon:
                    const Icon(Icons.numbers_rounded, color: Color(0xFF003366)),
                suffixIcon: _isSearchingAccounts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _accountController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _accountController.clear();
                              setState(() {
                                _suggestedBanks = [];
                                _accountSuggestions = [];
                                _selectedBank = null;
                                _selectedBankId = null;
                                _recipientController.clear();
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(Icons.close_rounded, size: 16),
                            ),
                          )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter account number';
                }
                final digitsOnly = value.replaceAll(' ', '');
                if (digitsOnly.length < 8) {
                  return 'Account number must be at least 8 digits';
                }
                if (!RegExp(r'^\d+$').hasMatch(digitsOnly)) {
                  return 'Only numbers are allowed';
                }
                return null;
              },
            ),
            // Account suggestions based on typed number
            if (_accountSuggestions.isNotEmpty)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: _buildAccountSuggestions(),
              ),
            // Bank suggestions based on account number
            if (_suggestedBanks.isNotEmpty && _accountSuggestions.isEmpty)
              Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: _buildBankSuggestions(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountSuggestions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Found ${_accountSuggestions.length} matching account${_accountSuggestions.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _accountSuggestions = [];
                    });
                  },
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
          ..._accountSuggestions
              .map((suggestion) => _buildAccountSuggestionItem(suggestion)),
        ],
      ),
    );
  }

  Widget _buildAccountSuggestionItem(Map<String, dynamic> suggestion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectAccountSuggestion(suggestion),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Container(
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
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    suggestion['avatar'].toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003366),
                      ),
                    ),
                    Text(
                      'Account: ${suggestion['account']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Bank: ${suggestion['bank']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[100]!),
                ),
                child: Text(
                  suggestion['type'] == 'alpha_user' ? 'Alpha' : 'User',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankSuggestions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Suggested Banks',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ..._suggestedBanks.map((bank) => _buildBankSuggestionItem(bank)),
        ],
      ),
    );
  }

  Widget _buildBankSuggestionItem(Map<String, dynamic> bank) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectBank(bank),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(bank['color'].toString().substring(1),
                          radix: 16) +
                      0xFF000000),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getBankIcon(bank['icon'] as String),
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
                      bank['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003366),
                      ),
                    ),
                    Text(
                      'Code: ${bank['code']} • ${bank['country']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBankSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Bank',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _bankSearchController,
            onChanged: _filterBanks,
            onTap: () {
              setState(() {
                _showBankList = true;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search for bank...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: Color(0xFF003366)),
              suffixIcon: _selectedBank != null
                  ? GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedBank = null;
                          _selectedBankId = null;
                          _bankSearchController.clear();
                          _filterBanks('');
                          _showBankList = true;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close_rounded, size: 16),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBankList() {
    if (!_showBankList || _filteredBanks.isEmpty) {
      return Container();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_filteredBanks.length} banks found',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showBankList = false;
                    });
                  },
                  child: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredBanks.length,
              itemBuilder: (context, index) {
                final bank = _filteredBanks[index];
                final isSelected = _selectedBank == bank['name'];

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _selectBank(bank),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF003366).withOpacity(0.08)
                            : Colors.transparent,
                        border: Border(
                          bottom: index < _filteredBanks.length - 1
                              ? BorderSide(color: Colors.grey[100]!)
                              : BorderSide.none,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(int.parse(
                                      bank['color'].toString().substring(1),
                                      radix: 16) +
                                  0xFF000000),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getBankIcon(bank['icon'] as String),
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
                                  bank['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                Text(
                                  'Code: ${bank['code']} • ${bank['country']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF003366),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getBankIcon(String iconName) {
    switch (iconName) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'business':
        return Icons.business_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'euro':
        return Icons.euro_rounded;
      case 'location_city':
        return Icons.location_city_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'security':
        return Icons.security_rounded;
      case 'anchor':
        return Icons.anchor_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  Widget _buildRecentRecipients() {
    if (_recentRecipients.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Recent Recipients',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _recentRecipients.length,
            itemBuilder: (context, index) {
              final recipient = _recentRecipients[index];

              return GestureDetector(
                onTap: () => _selectRecipient(recipient),
                child: Container(
                  width: 120,
                  margin: EdgeInsets.only(
                    right: index < _recentRecipients.length - 1 ? 12 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF003366),
                              Color(0xFF0055AA),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Text(
                            recipient['avatar'].toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          recipient['name'],
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          recipient['account'].toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _showBankList = false;
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFD),
        appBar: AppBar(
          backgroundColor: const Color(0xFF003366),
          title: const Text('Bank Transfer'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              onPressed: _clearForm,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear Form',
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Bank Transfer',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Send money securely to any bank account',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Account Number Field (with auto-detection)
                  _buildAccountNumberField(),
                  const SizedBox(height: 16),

                  // Bank Search Field (appears when no auto-detection)
                  if (_suggestedBanks.isEmpty || _selectedBank == null)
                    Column(
                      children: [
                        _buildBankSearchField(),
                        const SizedBox(height: 8),
                        _buildBankList(),
                      ],
                    ),

                  // Selected Bank Display
                  if (_selectedBank != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
                              color: const Color(0xFF003366),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
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
                                  _selectedBank!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                Text(
                                  'Bank selected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedBank = null;
                                _selectedBankId = null;
                                _bankSearchController.clear();
                                _showBankList = true;
                              });
                            },
                            icon: const Icon(Icons.edit_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),

                  // Recent Recipients
                  _buildRecentRecipients(),
                  const SizedBox(height: 24),

                  // Recipient Details Form
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
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Recipient Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF003366),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _recipientController,
                          decoration: InputDecoration(
                            labelText: 'Recipient Name',
                            labelStyle:
                                const TextStyle(color: Color(0xFF003366)),
                            prefixIcon: const Icon(
                              Icons.person_rounded,
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
                            hintText: 'Enter full name',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter recipient name';
                            }
                            if (value.length < 3) {
                              return 'Name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Description (Optional)',
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            prefixIcon: Icon(
                              Icons.description_rounded,
                              color: Colors.grey[600],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintText: 'e.g., Payment for services',
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amount Input
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
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Transfer Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF003366),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
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
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Enter Amount',
                            labelStyle:
                                const TextStyle(color: Color(0xFF003366)),
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
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter amount';
                            }
                            final amount = double.tryParse(value);
                            if (amount == null) {
                              return 'Please enter a valid amount';
                            }
                            if (amount <= 0) {
                              return 'Amount must be greater than 0';
                            }
                            if (amount > 1000000) {
                              return 'Maximum transfer limit is \$1,000,000';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildQuickAmountButton('100'),
                            _buildQuickAmountButton('500'),
                            _buildQuickAmountButton('1000'),
                            _buildQuickAmountButton('5000'),
                            _buildQuickAmountButton('10000'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Transfer Summary
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
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transfer Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeeRow('Amount',
                            '\$${_amountController.text.isNotEmpty ? double.parse(_amountController.text).toStringAsFixed(2) : '0.00'}'),
                        _buildFeeRow('Transfer Fee',
                            '\$${_transferFee.toStringAsFixed(2)}'),
                        _buildFeeRow(
                            'Selected Bank', _selectedBank ?? 'Not selected',
                            valueColor: _selectedBank != null
                                ? Colors.green[700]
                                : Colors.red),
                        const Divider(height: 24),
                        _buildFeeRow(
                          'Total Amount',
                          '\$${_totalAmount.toStringAsFixed(2)}',
                          isTotal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _proceedToAmount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF003366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor:
                                const Color(0xFF003366).withOpacity(0.3),
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
                                      'Verifying...',
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
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Continue to Payment',
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
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountController.text = amount;
        });
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

  Widget _buildFeeRow(String label, String value,
      {Color? valueColor, bool isTotal = false}) {
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
              color: valueColor ??
                  (isTotal ? const Color(0xFF003366) : Colors.grey[700]),
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _recipientController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _accountController.dispose();
    _bankSearchController.dispose();
    super.dispose();
  }
}
