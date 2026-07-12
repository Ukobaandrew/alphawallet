import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_workflow_screen.dart' as workflow;

class InternationalTransferScreen extends StatefulWidget {
  const InternationalTransferScreen({super.key});

  @override
  State<InternationalTransferScreen> createState() =>
      _InternationalTransferScreenState();
}

class _InternationalTransferScreenState
    extends State<InternationalTransferScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _recipientNameController =
      TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _swiftController = TextEditingController();
  final TextEditingController _bankNameController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _countries = [];
  List<Map<String, dynamic>> _filteredCountries = [];
  Map<String, dynamic>? _selectedCountry;
  Map<String, dynamic>? _selectedBank;
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _filteredBanks = [];

  String? _selectedTransferType = 'SWIFT';
  String? _selectedTransferSpeed = 'Standard';
  bool _isLoading = false;
  bool _isLoadingCountries = false;
  bool _isLoadingBanks = false;
  double _exchangeRate = 0.0;
  double _transferFee = 0.0;
  double _totalCost = 0.0;
  double _convertedAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeCountries();
    _amountController.addListener(_calculateCosts);
  }

  Future<void> _initializeCountries() async {
    setState(() => _isLoadingCountries = true);

    try {
      final countriesSnapshot = await _firestore
          .collection('countries')
          .where('popular', isEqualTo: true)
          .get();

      final allCountries = await _firestore.collection('countries').get();

      // Convert to list of maps
      _countries = allCountries.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'code': data['code'] ?? '',
          'currency': data['currency'] ?? 'USD',
          'flag': data['flag'] ?? '🇺🇸',
          'exchangeRate': (data['exchangeRate'] ?? 1.0).toDouble(),
          'transferFee': (data['baseTransferFee'] ?? 25.0).toDouble(),
          'color': _hexToColor(data['color'] ?? '#1976D2'),
          'popular': data['popular'] ?? false,
          'swiftCode': data['defaultSwiftCode'] ?? '',
          'defaultBank': data['defaultBank'] ?? '',
          'maxTransferLimit': (data['maxTransferLimit'] ?? 50000.0).toDouble(),
          'minTransferAmount': (data['minTransferAmount'] ?? 10.0).toDouble(),
          'processingTime': data['processingTime'] ?? '1-2 business days',
          'requiresSwift': data['requiresSwift'] ?? true,
          'requiresIban': data['requiresIban'] ?? true,
          'timezone': data['timezone'] ?? 'UTC',
        };
      }).toList();

      _filteredCountries = _countries;

      // Load banks for popular countries
      await _loadBanksForPopularCountries();
    } catch (e) {
      print('Error loading countries: $e');
      // Fallback to static data if Firebase fails
      _loadStaticData();
    } finally {
      setState(() => _isLoadingCountries = false);
    }
  }

  Future<void> _loadBanksForPopularCountries() async {
    setState(() => _isLoadingBanks = true);

    try {
      final banksSnapshot = await _firestore.collection('banks').get();

      _banks = banksSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'code': data['code'] ?? '',
          'swiftCode': data['swiftCode'] ?? '',
          'icon': data['icon'] ?? 'account_balance',
          'color': _hexToColor(data['color'] ?? '#003366'),
          'country': data['country'] ?? '',
          'countryCode': data['countryCode'] ?? '',
          'transferFee': (data['transferFee'] ?? 5.0).toDouble(),
          'processingTime': data['processingTime'] ?? '1-2 hours',
          'dailyLimit': (data['dailyLimit'] ?? 50000.0).toDouble(),
          'supportedCurrencies': data['supportedCurrencies'] ?? ['USD'],
          'requiresAccountNumber': data['requiresAccountNumber'] ?? true,
          'requiresIBAN': data['requiresIBAN'] ?? true,
          'requiresSWIFT': data['requiresSWIFT'] ?? false,
        };
      }).toList();

      _filteredBanks = _banks;
    } catch (e) {
      print('Error loading banks: $e');
    } finally {
      setState(() => _isLoadingBanks = false);
    }
  }

  void _loadStaticData() {
    // Fallback static data
    _countries = [
      {
        'name': 'United States',
        'code': 'US',
        'currency': 'USD',
        'flag': '🇺🇸',
        'exchangeRate': 1.0,
        'transferFee': 25.0,
        'color': Colors.blue[700],
        'popular': true,
        'swiftCode': 'CHASUS33',
        'defaultBank': 'Chase Bank',
        'maxTransferLimit': 100000.0,
        'minTransferAmount': 10.0,
        'processingTime': '1-2 business days',
        'requiresSwift': true,
        'requiresIban': false,
      },
      {
        'name': 'United Kingdom',
        'code': 'UK',
        'currency': 'GBP',
        'flag': '🇬🇧',
        'exchangeRate': 0.79,
        'transferFee': 20.0,
        'color': Colors.red[700],
        'popular': true,
        'swiftCode': 'BARCGB22',
        'defaultBank': 'Barclays',
        'maxTransferLimit': 100000.0,
        'minTransferAmount': 10.0,
        'processingTime': '1-2 business days',
        'requiresSwift': true,
        'requiresIban': true,
      },
    ];
    _filteredCountries = _countries;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  void _filterCountries(String query) {
    setState(() {
      _filteredCountries = _countries.where((country) {
        final name = country['name'].toString().toLowerCase();
        final currency = country['currency'].toString().toLowerCase();
        final code = country['code'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();
        return name.contains(searchQuery) ||
            currency.contains(searchQuery) ||
            code.contains(searchQuery);
      }).toList();
    });
  }

  void _filterBanks(String query) {
    if (_selectedCountry == null) return;

    setState(() {
      _filteredBanks = _banks.where((bank) {
        final name = bank['name'].toString().toLowerCase();
        final countryCode = bank['countryCode'].toString().toLowerCase();
        final searchQuery = query.toLowerCase();

        return countryCode ==
                _selectedCountry!['code'].toString().toLowerCase() &&
            name.contains(searchQuery);
      }).toList();
    });
  }

  void _selectCountry(Map<String, dynamic> country) {
    setState(() {
      _selectedCountry = country;
      _selectedBank = null; // Reset selected bank when country changes
      _exchangeRate = country['exchangeRate'];
      _transferFee = country['transferFee'];
      _searchController.text = country['name'];

      // Auto-fill with default values
      _bankNameController.text = country['defaultBank'];
      _swiftController.text = country['swiftCode'];

      // Filter banks for selected country
      _filterBanks('');
    });
  }

  void _selectBank(Map<String, dynamic> bank) {
    setState(() {
      _selectedBank = bank;
      _bankNameController.text = bank['name'];
      _swiftController.text = bank['swiftCode'];
      // Update transfer fee based on bank
      _transferFee = bank['transferFee'];
      _calculateCosts();
    });
  }

  void _calculateCosts() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (_selectedCountry != null && amount > 0) {
      setState(() {
        _transferFee = _calculateTransferFee(amount);
        _convertedAmount = amount * _exchangeRate;
        _totalCost = amount + _transferFee;
      });
    }
  }

  double _calculateTransferFee(double amount) {
    double baseFee = _selectedBank?['transferFee'] ??
        _selectedCountry?['transferFee'] ??
        25.0;

    if (_selectedTransferSpeed == 'Express') {
      return baseFee * 2.0;
    } else if (_selectedTransferSpeed == 'Priority') {
      return baseFee * 1.5;
    }
    return baseFee;
  }

  String _getTransferTime() {
    if (_selectedTransferSpeed == 'Express') {
      return '1-2 hours';
    } else if (_selectedTransferSpeed == 'Priority') {
      return 'Same day';
    } else if (_selectedBank != null) {
      return _selectedBank!['processingTime'] ?? '1-3 business days';
    }
    return _selectedCountry?['processingTime'] ?? '1-3 business days';
  }

  double _getMaxLimit() {
    if (_selectedBank != null) {
      final bankLimit = _selectedBank!['dailyLimit'] ?? 50000.0;
      final countryLimit = _selectedCountry?['maxTransferLimit'] ?? 50000.0;
      return bankLimit < countryLimit ? bankLimit : countryLimit;
    }
    return _selectedCountry?['maxTransferLimit'] ?? 50000.0;
  }

  void _showCountryDetails(BuildContext context, Map<String, dynamic> country) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      country['name'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003366),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (country['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        country['flag'],
                        style: const TextStyle(fontSize: 30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Currency: ${country['currency']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Exchange Rate: 1 USD = ${country['exchangeRate']} ${country['currency']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Standard Fee: \$${country['transferFee']}',
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
              const SizedBox(height: 20),
              _buildDetailItem('Maximum Transfer',
                  '\$${country['maxTransferLimit'].toStringAsFixed(0)}'),
              _buildDetailItem('Minimum Transfer',
                  '\$${country['minTransferAmount'].toStringAsFixed(0)}'),
              _buildDetailItem('Processing Time', country['processingTime']),
              _buildDetailItem('Default SWIFT', country['swiftCode']),
              _buildDetailItem('Default Bank', country['defaultBank']),
              _buildDetailItem(
                  'Requires SWIFT', country['requiresSwift'] ? 'Yes' : 'No'),
              _buildDetailItem(
                  'Requires IBAN', country['requiresIban'] ? 'Yes' : 'No'),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _selectCountry(country);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003366),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Select This Country',
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
        );
      },
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankSelection() {
    if (_selectedCountry == null || _isLoadingBanks) {
      return Container();
    }

    final countryBanks = _banks
        .where((bank) =>
            bank['countryCode'].toString().toLowerCase() ==
            _selectedCountry!['code'].toString().toLowerCase())
        .toList();

    if (countryBanks.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Select Bank',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: countryBanks.map((bank) {
              final isSelected = _selectedBank?['id'] == bank['id'];
              return GestureDetector(
                onTap: () => _selectBank(bank),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF003366)
                        : (bank['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF003366)
                          : (bank['color'] as Color).withOpacity(0.3),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        bank['name'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fee: \$${bank['transferFee']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _proceedToTransfer() async {
    if (_selectedCountry == null) {
      _showError('Please select a destination country');
      return;
    }

    if (_recipientNameController.text.isEmpty) {
      _showError('Please enter recipient name');
      return;
    }

    if (_accountController.text.isEmpty || _accountController.text.length < 8) {
      _showError('Please enter a valid account number');
      return;
    }

    if (_selectedCountry!['requiresSwift'] &&
        (_swiftController.text.isEmpty || _swiftController.text.length < 8)) {
      _showError(
          'Please enter a valid SWIFT/BIC code for ${_selectedCountry!['name']}');
      return;
    }

    if (_selectedCountry!['requiresIban'] &&
        !_accountController.text.startsWith(RegExp(r'[A-Z]{2}'))) {
      _showError('Please enter a valid IBAN for ${_selectedCountry!['name']}');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    final maxLimit = _getMaxLimit();
    if (amount > maxLimit) {
      _showError(
          'Maximum transfer limit to ${_selectedCountry!['name']} is \$${maxLimit.toStringAsFixed(0)}');
      return;
    }

    final minAmount = _selectedCountry!['minTransferAmount'] ?? 10.0;
    if (amount < minAmount) {
      _showError(
          'Minimum transfer amount to ${_selectedCountry!['name']} is \$${minAmount.toStringAsFixed(0)}');
      return;
    }

    // Show confirmation dialog
    await _showConfirmationDialog(context);
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm International Transfer'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please review your transfer details:'),
                const SizedBox(height: 16),
                _buildConfirmationItem('To Country', _selectedCountry!['name']),
                _buildConfirmationItem(
                    'Currency', _selectedCountry!['currency']),
                if (_selectedBank != null)
                  _buildConfirmationItem('Bank', _selectedBank!['name']),
                _buildConfirmationItem(
                    'Recipient', _recipientNameController.text),
                _buildConfirmationItem('Account', _accountController.text),
                if (_swiftController.text.isNotEmpty)
                  _buildConfirmationItem('SWIFT Code', _swiftController.text),
                _buildConfirmationItem(
                    'Transfer Type', _selectedTransferSpeed!),
                _buildConfirmationItem('Transfer Time', _getTransferTime()),
                const Divider(),
                _buildConfirmationItem(
                    'Amount', '\$${amount.toStringAsFixed(2)}'),
                _buildConfirmationItem('Exchange Rate',
                    '1 USD = $_exchangeRate ${_selectedCountry!['currency']}'),
                _buildConfirmationItem('Converted Amount',
                    '${_convertedAmount.toStringAsFixed(2)} ${_selectedCountry!['currency']}'),
                _buildConfirmationItem(
                    'Transfer Fee', '\$${_transferFee.toStringAsFixed(2)}'),
                _buildConfirmationItem(
                    'Total Cost', '\$${_totalCost.toStringAsFixed(2)}',
                    isTotal: true),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber[100]!),
                  ),
                  child: const Text(
                    'Transfers may be subject to additional fees by intermediary banks',
                    style: TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processTransfer();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
              child: const Text('Confirm Transfer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfirmationItem(String label, String value,
      {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTotal ? 18 : 14,
                color: isTotal ? const Color(0xFF003366) : Colors.grey[800],
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _processTransfer() async {
    setState(() => _isLoading = true);

    // Simulate API call for international transfer
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isLoading = false);

    // Navigate to AmountInputScreen for completion
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => workflow.AmountInputScreen(
          recipientName: _recipientNameController.text,
          recipientAccount: _accountController.text,
          transactionType: 'International Transfer',
          bankName: _selectedBank != null
              ? '${_selectedBank!['name']} - ${_selectedCountry!['name']}'
              : '${_selectedCountry!['name']}',
          initialAmount: double.parse(_amountController.text),
          description:
              'International transfer to ${_selectedCountry!['name']}. '
              'Exchange rate: $_exchangeRate. '
              'Converted amount: ${_convertedAmount.toStringAsFixed(2)} ${_selectedCountry!['currency']}. '
              'Transfer fee: \$${_transferFee.toStringAsFixed(2)}',
          // Remove the transferDetails parameter if AmountInputScreen doesn't support it
          // transferDetails: {
          //   'country': _selectedCountry!['name'],
          //   'currency': _selectedCountry!['currency'],
          //   'exchangeRate': _exchangeRate,
          //   'convertedAmount': _convertedAmount,
          //   'transferFee': _transferFee,
          //   'swiftCode': _swiftController.text,
          //   'transferSpeed': _selectedTransferSpeed,
          // },
        ),
      ),
    );
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

  Widget _buildSelectedCountryCard() {
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _selectedCountry!['color'].withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                _selectedCountry!['flag'],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCountry!['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_selectedCountry!['currency']} • 1 USD = ${_selectedCountry!['exchangeRate']} ${_selectedCountry!['currency']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              _selectedCountry = null;
              _selectedBank = null;
              _bankNameController.clear();
              _swiftController.clear();
            }),
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularCountryCard(Map<String, dynamic> country) {
    return GestureDetector(
      onTap: () => _showCountryDetails(context, country),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
            Text(
              country['flag'],
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 8),
            Text(
              country['name'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              country['currency'],
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

  Widget _buildCountrySearch() {
    return Container(
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
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search country or currency...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: _isLoadingCountries
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded, color: Color(0xFF003366)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onChanged: _filterCountries,
        enabled: !_isLoadingCountries,
      ),
    );
  }

  Widget _buildCostSummary() {
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cost Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Amount to send'),
              Text(
                '\$${_amountController.text.isEmpty ? '0.00' : _amountController.text}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exchange rate (1 USD = ${_selectedCountry!['currency']})'),
              Text(
                _exchangeRate.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Converted to ${_selectedCountry!['currency']}'),
              Text(
                _convertedAmount.toStringAsFixed(2),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Transfer fee'),
              Text(
                '\$${_transferFee.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total cost',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              Text(
                '\$${_totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF003366),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('International Transfer Help'),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Required Information:'),
                SizedBox(height: 8),
                Text('• Recipient\'s full name'),
                Text('• Account number or IBAN'),
                Text('• SWIFT/BIC code'),
                Text('• Bank name and address'),
                SizedBox(height: 16),
                Text('Transfer Times:'),
                SizedBox(height: 8),
                Text('• Standard: 1-3 business days'),
                Text('• Priority: Same day'),
                Text('• Express: 1-2 hours'),
                SizedBox(height: 16),
                Text('Fees:'),
                SizedBox(height: 8),
                Text('• Transfer fees vary by country and bank'),
                Text('• Additional intermediary bank fees may apply'),
                Text('• Exchange rates are locked at transfer time'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text('International Transfer'),
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
      body: _isLoadingCountries
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.language_rounded,
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
                                  'Send Money Worldwide',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fast, secure international transfers',
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

                    // Country Search
                    _buildCountrySearch(),
                    const SizedBox(height: 16),

                    // Selected Country Preview
                    if (_selectedCountry != null) _buildSelectedCountryCard(),
                    const SizedBox(height: 16),

                    // Bank Selection (if country selected)
                    _buildBankSelection(),
                    const SizedBox(height: 16),

                    // Popular Countries
                    const Text(
                      'Popular Destinations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF003366),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 128,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _countries
                            .where((c) => c['popular'] == true)
                            .map((country) {
                          return _buildPopularCountryCard(country);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Transfer Details Form
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
                            'Transfer Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _recipientNameController,
                            decoration: InputDecoration(
                              labelText: 'Recipient Full Name',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF003366)),
                              prefixIcon: const Icon(Icons.person_rounded,
                                  color: Color(0xFF003366)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _accountController,
                            decoration: InputDecoration(
                              labelText:
                                  _selectedCountry?['requiresIban'] == true
                                      ? 'IBAN Number'
                                      : 'Account Number',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF003366)),
                              prefixIcon: const Icon(Icons.numbers_rounded,
                                  color: Color(0xFF003366)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedCountry?['requiresSwift'] == true)
                            Column(
                              children: [
                                TextFormField(
                                  controller: _swiftController,
                                  decoration: InputDecoration(
                                    labelText: 'SWIFT / BIC Code',
                                    labelStyle: const TextStyle(
                                        color: Color(0xFF003366)),
                                    prefixIcon: const Icon(
                                        Icons.qr_code_rounded,
                                        color: Color(0xFF003366)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          TextFormField(
                            controller: _bankNameController,
                            decoration: InputDecoration(
                              labelText: 'Bank Name',
                              labelStyle:
                                  const TextStyle(color: Color(0xFF003366)),
                              prefixIcon: const Icon(
                                  Icons.account_balance_rounded,
                                  color: Color(0xFF003366)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _branchController,
                            decoration: InputDecoration(
                              labelText: 'Branch Name (Optional)',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(Icons.business_rounded,
                                  color: Colors.grey[600]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Transfer Options
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
                            'Transfer Options',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text('Transfer Type'),
                          Wrap(
                            spacing: 8,
                            children:
                                ['SWIFT', 'SEPA', 'Local Transfer'].map((type) {
                              return ChoiceChip(
                                label: Text(type),
                                selected: _selectedTransferType == type,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTransferType =
                                        selected ? type : null;
                                  });
                                },
                                selectedColor: const Color(0xFF003366),
                                labelStyle: TextStyle(
                                  color: _selectedTransferType == type
                                      ? Colors.white
                                      : const Color(0xFF003366),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text('Transfer Speed'),
                          Wrap(
                            spacing: 8,
                            children: ['Standard', 'Priority', 'Express']
                                .map((speed) {
                              return ChoiceChip(
                                label: Text(speed),
                                selected: _selectedTransferSpeed == speed,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedTransferSpeed =
                                        selected ? speed : null;
                                    _calculateCosts();
                                  });
                                },
                                selectedColor: const Color(0xFF003366),
                                labelStyle: TextStyle(
                                  color: _selectedTransferSpeed == speed
                                      ? Colors.white
                                      : const Color(0xFF003366),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                'Estimated arrival: ${_getTransferTime()}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
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
                          const Text(
                            'Transfer Amount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF003366),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              labelText: 'Amount in USD',
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
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              hintText: '0.00',
                              suffixText: _selectedCountry != null
                                  ? '≈ ${_convertedAmount.toStringAsFixed(2)} ${_selectedCountry!['currency']}'
                                  : null,
                              suffixStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children:
                                ['100', '500', '1000', '5000'].map((amount) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _amountController.text = amount;
                                    _calculateCosts();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF003366)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF003366)
                                          .withOpacity(0.2),
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
                            }).toList(),
                          ),
                          if (_selectedCountry != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Limits: \$${_selectedCountry!['minTransferAmount'].toStringAsFixed(0)} - \$${_getMaxLimit().toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cost Summary
                    if (_selectedCountry != null &&
                        _amountController.text.isNotEmpty)
                      _buildCostSummary(),
                    const SizedBox(height: 24),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _proceedToTransfer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Continue to Transfer',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
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
                    const SizedBox(height: 32),

                    // Information Card
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
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              const Text(
                                'Important Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF003366),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Exchange rates fluctuate and are locked at time of transfer\n'
                            '• Additional fees may be charged by intermediary banks\n'
                            '• Recipient may receive amount in local currency\n'
                            '• Transfers are subject to local regulations\n'
                            '• SWIFT/BIC code required for most international transfers\n'
                            '• IBAN required for European countries',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
