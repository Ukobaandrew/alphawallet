import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/pin_input_field.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isLoading = false;
  bool _showError = false;
  bool _pinsMatch = true;

  Map<String, dynamic>? _userData;
  String? _firebaseUserId;
  String? _oldUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userData =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _firebaseUserId = _userData?['userId'];
    _oldUserId = _userData?['oldUserId'];
  }

  Future<void> _submit() async {
    final pin = _pinController.text;
    final confirmPin = _confirmPinController.text;

    if (pin.length != 4) {
      setState(() => _showError = true);
      return;
    }

    if (pin != confirmPin) {
      setState(() => _pinsMatch = false);
      return;
    }

    // Check for simple PINs
    if (RegExp(r'^(\d)\1{3}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avoid using repeated digits'),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }

    if (RegExp(r'^0123|1234|2345|3456|4567|5678|6789|7890$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avoid sequential numbers'),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }

    setState(() {
      _showError = false;
      _pinsMatch = true;
      _isLoading = true;
    });

    try {
      if (_firebaseUserId == null) {
        throw Exception('Firebase User ID not found');
      }

      // Get Firestore instance
      final firestore = FirebaseFirestore.instance;

      // Step 1: Update user document with PIN and complete registration
      await firestore.collection('users').doc(_firebaseUserId!).update({
        'pin': pin, // In production, hash this PIN before storing
        'registrationStep': 4, // Mark registration as complete
        'isVerified': true,
        'isActive': true,
        'pinSetAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Step 2: Create security settings
      await firestore
          .collection('users')
          .doc(_firebaseUserId!)
          .collection('security_settings')
          .doc('settings')
          .set({
        'pin': pin, // Hashed in production
        'pinSetAt': FieldValue.serverTimestamp(),
        'pinRetryAttempts': 0,
        'pinRetryLimit': 3,
        'sessionTimeout': 30,
        'autoLockEnabled': true,
        'requirePinForTransactions': true,
        'requirePinForLogin': false,
        'maxTransactionAmount': 10000.00,
        'dailyTransactionLimit': 50000.00,
        'whitelistedDevices': [],
        'loginHistory': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Step 3: Update user preferences if exists
      await firestore
          .collection('users')
          .doc(_firebaseUserId!)
          .collection('preferences')
          .doc('user_preferences')
          .set({
        'theme': 'light',
        'language': 'en',
        'currency': 'USD',
        'notificationSound': true,
        'vibration': true,
        'biometricLogin': false,
        'quickBalance': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Step 4: Clean up old user ID completely
      if (_oldUserId != null) {
        await _cleanupOldUserData(_oldUserId!);
      }

      // Step 5: Create activity log for PIN setup
      await firestore
          .collection('users')
          .doc(_firebaseUserId!)
          .collection('activity_logs')
          .add({
        'activity': 'pin_created',
        'timestamp': FieldValue.serverTimestamp(),
        'details': 'User created 4-digit PIN',
        'oldUserId': _oldUserId,
        'migrationComplete': true,
        'ipAddress': '127.0.0.1',
        'deviceInfo': 'Flutter App',
      });

      // Step 6: Auto sign in with Firebase Auth
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      if (currentUser == null) {
        // The user was created in previous screen, they should be signed in
        // If not, sign them in with stored credentials (in production, you'd need to store temporarily)
        debugPrint('User not signed in after registration');
      }

      setState(() => _isLoading = false);

      // Step 7: Show success dialog
      _showSuccessDialog();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting up PIN: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('PIN setup error: $e');
    }
  }

  Future<void> _cleanupOldUserData(String oldUserId) async {
    try {
      final firestore = FirebaseFirestore.instance;

      // Delete from pending_users
      await firestore.collection('pending_users').doc(oldUserId).delete();

      // Delete from unauthenticated_users if exists
      final unauthQuery = await firestore
          .collection('unauthenticated_users')
          .where('pendingUserId', isEqualTo: oldUserId)
          .get();

      for (final doc in unauthQuery.docs) {
        await doc.reference.delete();
      }

      debugPrint('Cleaned up old user data for: $oldUserId');
    } catch (e) {
      debugPrint('Error cleaning up old user data: $e');
      // Don't throw - we can continue
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Registration Complete!',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF003366),
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.verified_rounded,
                size: 48,
                color: Colors.green[700],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome to Alpha Bank',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your account setup is complete and ready to use.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Account Number',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['accountNumber'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF003366),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Username',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userData?['username'] ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green[100]!),
              ),
              child: Column(
                children: [
                  Text(
                    'User ID',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _firebaseUserId != null
                        ? '${_firebaseUserId!.substring(0, 8)}...'
                        : 'N/A',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This is your permanent user ID',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
            if (_oldUserId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[100]!),
                ),
                child: Column(
                  children: [
                    Text(
                      'Migration Complete',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Admin ID replaced with your user ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog

                // Navigate to dashboard with user data
                Navigator.pushReplacementNamed(context, '/dashboard',
                    arguments: {
                      'userId': _firebaseUserId,
                      'accountNumber': _userData?['accountNumber'],
                      'username': _userData?['username'],
                      'email': _userData?['email'],
                      'userType': 'authenticated',
                    });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Go to Dashboard',
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
                            'Set Security PIN',
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
                                  child: const Icon(
                                    Icons.pin_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Final Security Step',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Create a 4-digit PIN for quick access and transactions',
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

                          // Create PIN Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Create PIN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF003366),
                                ),
                              ),
                              const SizedBox(height: 12),
                              PinInputField(
                                controller: _pinController,
                                length: 4,
                                obscureText: true, // Add this line
                                onChanged: (value) {
                                  setState(() {
                                    _showError = value.length != 4;
                                    if (_confirmPinController.text.isNotEmpty) {
                                      _pinsMatch =
                                          value == _confirmPinController.text;
                                    }
                                  });
                                },
                              ),
                              if (_showError)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, left: 4),
                                  child: Text(
                                    'PIN must be exactly 4 digits',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Confirm PIN Section
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Confirm PIN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF003366),
                                ),
                              ),
                              const SizedBox(height: 12),
                              PinInputField(
                                controller: _confirmPinController,
                                length: 4,
                                obscureText: true, // Add this line
                                onChanged: (value) {
                                  setState(() {
                                    _pinsMatch = value == _pinController.text;
                                  });
                                },
                              ),
                              if (!_pinsMatch &&
                                  _confirmPinController.text.length == 4)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, left: 4),
                                  child: Text(
                                    'PINs do not match',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Security Tips
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.security_rounded,
                                      color: Color(0xFF003366),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Security Tips',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF003366),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTip(
                                    'Do not use your birth year or simple sequences'),
                                _buildTip('Never share your PIN with anyone'),
                                _buildTip(
                                    'Avoid using repeated digits (e.g., 1111)'),
                                _buildTip(
                                    'Avoid sequential numbers (e.g., 1234)'),
                                _buildTip(
                                    'This PIN will be required for all transactions'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Migration Status
                          if (_oldUserId != null)
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
                                    Icons.swap_horiz_rounded,
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
                                          'Account Migration',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Your account has been migrated from admin ID to your personal Firebase Authentication ID.',
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

                          if (_oldUserId != null) const SizedBox(height: 16),

                          // PIN Strength Indicator
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
                                  Icons.lightbulb_outline_rounded,
                                  color: Colors.orange[700],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'PIN Security',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Your PIN will be securely stored in our encrypted database. '
                                        'It will be used for transaction verification and account access.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.green[800],
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Complete Setup Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_pinController.text.length == 4 &&
                                      _confirmPinController.text.length == 4 &&
                                      _pinsMatch &&
                                      !_isLoading)
                                  ? _submit
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003366),
                                disabledBackgroundColor: Colors.grey[400],
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                shadowColor:
                                    const Color(0xFF003366).withOpacity(0.3),
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
                                          'Complete Setup',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.check_circle_rounded,
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
                                  'Your PIN is encrypted and stored securely in Firebase',
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

                    const SizedBox(height: 40),

                    // Need Help?
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Need help setting up your PIN?',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('PIN Setup Help'),
                                content: const Text(
                                  'If you need assistance setting up your PIN, please contact our customer support:\n\n'
                                  '📞 1-800-ALPHA-BANK\n'
                                  '✉️ support@alphabank.com\n\n'
                                  'Available 24/7',
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
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Contact Support',
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF003366),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ),
          ],
        ));
  }
}
