import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _passcodeController = TextEditingController();

  bool _isLoading = false;
  bool _acceptTerms = false;
  bool _showPasscodeField = false;
  bool _accountVerified = false;
  String? _accountHolderName;
  String? _userId;
  String? _email;

  // Firebase instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _accountNumberController.addListener(_checkAccountNumber);
  }

  Future<void> _checkAccountNumber() async {
    final accountNumber = _accountNumberController.text;

    if (accountNumber.length == 10) {
      try {
        // Check if account exists in Firestore
        final usersQuery = await _firestore
            .collection('users')
            .where('accountNumber', isEqualTo: accountNumber)
            .limit(1)
            .get();

        if (usersQuery.docs.isNotEmpty) {
          final userDoc = usersQuery.docs.first;
          final userData = userDoc.data();

          setState(() {
            _accountHolderName = userData['name'];
            _userId = userDoc.id;
            _email = userData['email'];
          });

          // Show the name in a dialog or snackbar
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAccountHolderName(userData);
          });
        } else {
          setState(() {
            _accountHolderName = null;
            _userId = null;
            _email = null;
          });

          // Show error if account not found
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showAccountNotFoundError();
          });
        }
      } catch (e) {
        _showError('Error checking account: $e');
      }
    } else {
      setState(() {
        _accountHolderName = null;
        _userId = null;
        _email = null;
      });
    }
  }

  void _showAccountHolderName(Map<String, dynamic> userData) {
    if (_accountHolderName == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF003366)),
            SizedBox(width: 10),
            Text('Account Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Account holder details:'),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _accountHolderName!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Account: ${_accountNumberController.text}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_email != null)
                    Text(
                      'Email: $_email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'If this is your account, please continue with verification.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _verifyAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003366),
            ),
            child: const Text('YES, CONTINUE'),
          ),
        ],
      ),
    );
  }

  void _showAccountNotFoundError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('Account number not found. Please check and try again.'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _verifyAccount() async {
    if (_accountNumberController.text.length == 10 && _userId != null) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Check if user already has credentials
        final userDoc =
            await _firestore.collection('users').doc(_userId!).get();
        final userData = userDoc.data();

        // Check if user already has Firebase Auth credentials (username field)
        if (userData != null &&
            userData['username'] != null &&
            userData['uid'] != null) {
          _showError(
              'This account already has online banking credentials. Please login instead.');
          setState(() => _isLoading = false);
          return;
        }

        // Check secure code/passcode
        if (userData?['secureCode'] != null) {
          // Secure code exists (created by admin)
          setState(() {
            _isLoading = false;
            _showPasscodeField = true;
            _accountVerified = true;
          });

          // Show info about secure code
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showSecureCodeInfoDialog(userData!['secureCode']);
          });
        } else {
          // This shouldn't happen if admin created properly
          _showError('No secure code found. Please contact admin.');
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showError('Error verifying account: $e');
      }
    }
  }

  void _showSecureCodeInfoDialog(String secureCode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Secure Code Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You need a 6-digit secure code to register.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your secure code should have been provided by your bank administrator.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Need Help?'),
                    content: const Text(
                      'Contact your bank administrator or customer support to get your secure code.\n\nEmail: support@alphabank.com\nPhone: 1-800-ALPHA-BANK',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Don\'t have a secure code?'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() &&
        _acceptTerms &&
        _accountVerified &&
        _userId != null) {
      setState(() => _isLoading = true);

      try {
        // Verify secure code/passcode
        final userDoc =
            await _firestore.collection('users').doc(_userId!).get();
        final userData = userDoc.data();

        final secureCode = userData?['secureCode'];

        if (secureCode != null && _passcodeController.text != secureCode) {
          _showError('Incorrect secure code. Please try again.');
          setState(() => _isLoading = false);
          return;
        }

        // Update registration step
        await _firestore.collection('users').doc(_userId!).update({
          'registrationStep': 2, // Ready for username/password
          'secureCodeVerified': true,
          'secureCodeVerifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoading = false);

        // Navigate to create password screen
        Navigator.pushNamed(
          context,
          '/create-password',
          arguments: {
            'userId': _userId,
            'accountNumber': _accountNumberController.text,
            'accountHolderName': _accountHolderName,
            'email': _email,
            'phone': userData?['phone'],
            'secureCode': secureCode,
          },
        );
      } catch (e) {
        setState(() => _isLoading = false);
        _showError('Error during verification: $e');
      }
    }
  }

  @override
  void dispose() {
    _accountNumberController.removeListener(_checkAccountNumber);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    const Color(0xFF003366).withOpacity(0.9),
                    const Color(0xFF004080).withOpacity(0.85),
                    const Color(0xFF0055AA).withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Back Button and Title
                    SizedBox(
                      height: 60,
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20),
                              color: Colors.white,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Account Verification',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // White Form Container
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 32,
                        vertical: isSmallScreen ? 28 : 36,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            spreadRadius: 5,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Center(
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF003366),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Icon(
                                      _accountVerified
                                          ? Icons.verified_rounded
                                          : Icons.account_balance_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _accountVerified
                                        ? 'Account Verified ✓'
                                        : 'Verify Your Account',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF003366),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _accountVerified
                                        ? 'Enter your secure code to continue'
                                        : 'Enter your 10-digit account number',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[700],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Account Number Field (10 digits)
                            _buildFormField(
                              label: 'Account Number (10 digits)',
                              controller: _accountNumberController,
                              prefixIcon: Icons.credit_card_rounded,
                              maxLength: 10,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your account number';
                                }
                                if (value.length != 10) {
                                  return 'Account number must be exactly 10 digits';
                                }
                                return null;
                              },
                              isFirst: true,
                              isLast: !_showPasscodeField,
                              enabled: !_accountVerified,
                              counterText:
                                  '${_accountNumberController.text.length}/10',
                              suffixText:
                                  _accountNumberController.text.length == 10 &&
                                          _accountHolderName != null
                                      ? '✓ Found'
                                      : null,
                              suffixColor: Colors.green,
                            ),

                            // Account Holder Name Display (when found)
                            if (_accountHolderName != null && !_accountVerified)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.blue[100]!),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_rounded,
                                      color: Colors.blue[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Account Holder',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _accountHolderName!,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF003366),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Verify Account Button (shows only if passcode field is not visible)
                            if (!_showPasscodeField && !_accountVerified)
                              Column(
                                children: [
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _accountNumberController
                                                      .text.length ==
                                                  10 &&
                                              _accountHolderName != null
                                          ? _verifyAccount
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF003366),
                                        disabledBackgroundColor:
                                            Colors.grey[400],
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        elevation: 4,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Verify Account',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),

                            // Secure Code Field (shows after account verification - 6 digits)
                            if (_showPasscodeField)
                              Column(
                                children: [
                                  const SizedBox(height: 24),
                                  _buildFormField(
                                    label: 'Secure Code (6 digits)',
                                    controller: _passcodeController,
                                    prefixIcon: Icons.security_rounded,
                                    maxLength: 6,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your secure code';
                                      }
                                      if (value.length != 6) {
                                        return 'Secure code must be exactly 6 digits';
                                      }
                                      return null;
                                    },
                                    isFirst: true,
                                    isLast: true,
                                    counterText:
                                        '${_passcodeController.text.length}/6',
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Need Help?'),
                                            content: const Text(
                                              'If you need help with your secure code, please contact customer support at:\n\n'
                                              '📞 1-800-ALPHA-BANK\n'
                                              '✉️ support@alphabank.com\n\n'
                                              'You can also request your bank administrator to resend the secure code.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Need Help?',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF003366),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.blue[100]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline_rounded,
                                          color: Colors.blue[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Account Holder:',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _accountHolderName ?? 'N/A',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF003366),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Account: ${_accountNumberController.text}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green[100]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.security_rounded,
                                          color: Colors.green[700],
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Your secure code is provided by your bank administrator during account setup.',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.green[800],
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 28),

                            // Terms and Conditions
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acceptTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptTerms = value ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFF003366),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Terms & Conditions',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF003366),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'I agree to Alpha Bank\'s Terms of Service and Privacy Policy for online banking.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () {
                                            // Show terms and conditions
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Terms & Conditions'),
                                                content: SingleChildScrollView(
                                                  child: Text(
                                                    _getTermsAndConditions(),
                                                    style: const TextStyle(
                                                        fontSize: 14),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('CLOSE'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: const Text(
                                            'View full terms and conditions',
                                            style: TextStyle(
                                              fontSize: 13,
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

                            const SizedBox(height: 32),

                            // Submit Button (only shows when secure code field is visible)
                            if (_showPasscodeField)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _acceptTerms &&
                                          _passcodeController.text.length == 6
                                      ? _submit
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF003366),
                                    disabledBackgroundColor: Colors.grey[400],
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 18),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                    shadowColor: const Color(0xFF003366)
                                        .withOpacity(0.3),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Continue to Create Credentials',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 20,
                                              color: Colors.white,
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                            const SizedBox(height: 20),

                            // Security Notice
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.security_rounded,
                                    color: Colors.green[700],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'All data is encrypted and stored securely in Firebase',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Already have online banking?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have online banking?',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Firebase Connection Status
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.cloud_done_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Connected to Firebase Database',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData prefixIcon,
    required String? Function(String?) validator,
    required int maxLength,
    TextInputType keyboardType = TextInputType.text,
    bool isFirst = false,
    bool isLast = false,
    bool isPassword = false,
    bool enabled = true,
    String? counterText,
    String? suffixText,
    Color? suffixColor,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF003366),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(12) : Radius.zero,
              topRight: isFirst ? const Radius.circular(12) : Radius.zero,
              bottomLeft: isLast ? const Radius.circular(12) : Radius.zero,
              bottomRight: isLast ? const Radius.circular(12) : Radius.zero,
            ),
            border: Border.all(color: Colors.grey[300]!),
            color: enabled ? Colors.white : Colors.grey[100],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  maxLength: maxLength,
                  style: TextStyle(
                    fontSize: 16,
                    color: enabled ? Colors.grey[800] : Colors.grey[500],
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      prefixIcon,
                      color: enabled ? Colors.grey[600] : Colors.grey[400],
                      size: 22,
                    ),
                    border: InputBorder.none,
                    errorBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    enabled: enabled,
                    counterText: counterText,
                    counterStyle: TextStyle(
                      fontSize: 12,
                      color: controller.text.length == maxLength
                          ? Colors.green[700]
                          : Colors.grey[500],
                    ),
                  ),
                  validator: validator,
                ),
              ),
              if (isPassword)
                IconButton(
                  icon: Icon(
                    Icons.visibility_off,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    // Password visibility toggle
                  },
                ),
              if (suffixText != null && suffixText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text(
                    suffixText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: suffixColor ?? Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _getTermsAndConditions() {
    return '''
ALPHA BANK TERMS OF SERVICE AND PRIVACY POLICY

1. AGREEMENT TO TERMS
By registering for Alpha Bank Online Banking, you agree to be bound by these Terms of Service and our Privacy Policy.

2. ACCOUNT REGISTRATION
You must provide accurate, complete, and current information during registration. You are responsible for maintaining the confidentiality of your account credentials.

3. SECURITY
You agree to:
- Keep your secure code and PIN confidential
- Not share your credentials with anyone
- Log out after each session
- Report any unauthorized access immediately

4. PRIVACY POLICY
We collect and use your personal information to:
- Provide banking services
- Verify your identity
- Comply with legal obligations
- Improve our services

5. ELECTRONIC COMMUNICATIONS
You consent to receive electronic communications from us, including notices, disclosures, and statements.

6. LIMITATION OF LIABILITY
Alpha Bank is not liable for:
- Unauthorized transactions if you fail to secure your credentials
- Delays or failures due to circumstances beyond our control
- Third-party service interruptions

7. CHANGES TO TERMS
We may modify these terms at any time. Continued use of our services constitutes acceptance of modified terms.

8. CONTACT INFORMATION
For questions, contact customer support at 1-800-ALPHA-BANK or support@alphabank.com.

By agreeing to these terms, you acknowledge that you have read, understood, and agree to be bound by all provisions.
''';
  }
}
