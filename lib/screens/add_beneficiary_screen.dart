import 'package:flutter/material.dart';

class AddBeneficiaryScreen extends StatefulWidget {
  const AddBeneficiaryScreen({super.key});

  @override
  State<AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<AddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _routingController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedBank = 'Alpha Bank';
  String _selectedAccountType = 'Checking';
  String _selectedPaymentMethod = 'Bank Transfer';
  String _selectedCountry = 'United States';

  final List<String> _banks = [
    'Alpha Bank',
    'OPay Bank',
    'First Bank',
    'Zenith Bank',
    'GTBank',
    'Access Bank',
    'UBA',
    'Fidelity Bank',
    'Stanbic IBTC',
    'Ecobank'
  ];

  final List<String> _accountTypes = [
    'Checking',
    'Savings',
    'Current',
    'Fixed Deposit'
  ];

  final List<String> _paymentMethods = [
    'Bank Transfer',
    'Alpha Users',
    'International'
  ];

  final List<String> _countries = [
    'United States',
    'United Kingdom',
    'Canada',
    'Nigeria',
    'Ghana',
    'Kenya',
    'South Africa',
    'Germany',
    'France',
    'Australia'
  ];

  @override
  void initState() {
    super.initState();
    // Load any initial data if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        title: const Text(
          'Add New Beneficiary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF003366),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _saveBeneficiary,
            tooltip: 'Save Beneficiary',
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header Card
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
                      color: const Color(0xFF003366).withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Bank Beneficiary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Save recipients for faster transfers',
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

              // Form Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Payment Method Selection
                        _buildDropdownField(
                          label: 'Payment Method',
                          value: _selectedPaymentMethod,
                          items: _paymentMethods,
                          icon: Icons.payment_rounded,
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentMethod = value!;
                              // Update bank list based on payment method
                              if (_selectedPaymentMethod == 'Alpha Users') {
                                _selectedBank = 'Alpha Users Network';
                              } else if (_selectedPaymentMethod ==
                                  'International') {
                                _selectedBank = 'Western Union';
                              } else {
                                _selectedBank = 'Alpha Bank';
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Beneficiary Name
                        _buildFormField(
                          label: 'Beneficiary Full Name',
                          hint: 'Enter full name as per bank account',
                          icon: Icons.person_rounded,
                          controller: _nameController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter beneficiary name';
                            }
                            if (value.length < 3) {
                              return 'Name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Country Selection
                        _buildDropdownField(
                          label: 'Country',
                          value: _selectedCountry,
                          items: _countries,
                          icon: Icons.flag_rounded,
                          onChanged: (value) {
                            setState(() {
                              _selectedCountry = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Bank Selection
                        _buildDropdownField(
                          label: 'Bank/Provider',
                          value: _selectedBank,
                          items: _getBankListForPaymentMethod(),
                          icon: Icons.account_balance_rounded,
                          onChanged: (value) {
                            setState(() {
                              _selectedBank = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Account Number
                        _buildFormField(
                          label: 'Account Number',
                          hint: 'Enter bank account number',
                          icon: Icons.credit_card_rounded,
                          controller: _accountController,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter account number';
                            }
                            if (_selectedPaymentMethod == 'Bank Transfer' &&
                                value.length < 10) {
                              return 'Account number must be at least 10 digits';
                            }
                            if (_selectedPaymentMethod == 'Alpha Users' &&
                                value.length < 8) {
                              return 'Alpha user ID must be at least 8 digits';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Account Type Selection
                        _buildDropdownField(
                          label: 'Account Type',
                          value: _selectedAccountType,
                          items: _accountTypes,
                          icon: Icons.account_balance_wallet_rounded,
                          onChanged: (value) {
                            setState(() {
                              _selectedAccountType = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        // Email (Optional)
                        _buildFormField(
                          label: 'Email Address (Optional)',
                          hint: 'Enter beneficiary email',
                          icon: Icons.email_rounded,
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          optional: true,
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                !value.contains('@')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Mobile Number (Optional)
                        _buildFormField(
                          label: 'Mobile Number (Optional)',
                          hint: 'Enter beneficiary mobile number',
                          icon: Icons.phone_rounded,
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          optional: true,
                          validator: (value) {
                            if (value != null &&
                                value.isNotEmpty &&
                                value.length < 10) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Routing Number (Optional)
                        if (_selectedCountry == 'United States')
                          _buildFormField(
                            label: 'Routing Number (Optional)',
                            hint: 'Enter bank routing number',
                            icon: Icons.numbers_rounded,
                            controller: _routingController,
                            keyboardType: TextInputType.number,
                            optional: true,
                          ),
                        const SizedBox(height: 30),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _saveBeneficiary,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save Beneficiary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: const BorderSide(color: Color(0xFF003366)),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF003366),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Security Note
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      color: Color(0xFF003366),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'We use bank-level encryption to protect beneficiary details. Information is stored securely and never shared.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _getBankListForPaymentMethod() {
    switch (_selectedPaymentMethod) {
      case 'Bank Transfer':
        return _banks;
      case 'Alpha Users':
        return ['Alpha Users Network'];
      case 'International':
        return ['Western Union', 'MoneyGram', 'WorldRemit', 'PayPal'];
      default:
        return _banks;
    }
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool optional = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF003366),
              ),
            ),
            if (optional)
              Text(
                ' (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF003366), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(icon, color: const Color(0xFF003366)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF003366),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.3),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down_rounded,
                  color: Color(0xFF003366)),
              iconSize: 24,
              elevation: 16,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF003366),
              ),
              onChanged: onChanged,
              items: items.map<DropdownMenuItem<String>>((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(icon, color: const Color(0xFF003366), size: 20),
                        const SizedBox(width: 12),
                        Text(item),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void _saveBeneficiary() {
    if (_formKey.currentState!.validate()) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
        ),
      );

      // Prepare beneficiary data matching TransactionWorkflowScreen format
      final beneficiaryData = {
        'name': _nameController.text,
        'bank': _selectedBank,
        'account':
            '***${_accountController.text.substring(_accountController.text.length - 4)}',
        'accountNumber': _accountController.text, // Full account number
        'paymentMethod': _selectedPaymentMethod,
        'country': _selectedCountry,
        'accountType': _selectedAccountType,
        'email': _emailController.text,
        'mobile': _mobileController.text,
        'routing': _routingController.text,
        'isFavorite': false,
      };

      // Simulate API call
      Future.delayed(const Duration(seconds: 1), () {
        Navigator.pop(context); // Remove loading

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Beneficiary Added Successfully!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_nameController.text} has been saved to your beneficiaries',
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

        // Return the beneficiary data to previous screen
        Navigator.pop(context, beneficiaryData);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _routingController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}
