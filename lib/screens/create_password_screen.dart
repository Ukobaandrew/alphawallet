import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/password_strength_indicator.dart';

class CreatePasswordScreen extends StatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  State<CreatePasswordScreen> createState() => _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isUsernameAvailable = false;
  bool _isCheckingUsername = false;

  // User data from previous screen
  Map<String, dynamic>? _userData;
  String? _adminUserId; // The admin-created user ID
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_checkUsernameAvailability);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userData =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _adminUserId = _userData?['userId'];
  }

  Future<void> _checkUsernameAvailability() async {
    if (_usernameController.text.isEmpty) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    // Check minimum length
    if (_usernameController.text.length < 3) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    // Check for valid characters
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(_usernameController.text)) {
      setState(() {
        _isUsernameAvailable = false;
        _isCheckingUsername = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
    });

    try {
      // Check Firestore for existing username
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.toLowerCase())
          .limit(1)
          .get();

      final isAvailable = usersQuery.docs.isEmpty;

      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable =
            isAvailable && _usernameController.text.length >= 3;
      });
    } catch (e) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = false;
      });
      debugPrint('Error checking username: $e');
    }
  }

  String _validateUsername(String username) {
    if (username.isEmpty) {
      return 'Username is required';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 20) {
      return 'Username must be less than 20 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    if (username.startsWith('_') || username.endsWith('_')) {
      return 'Username cannot start or end with underscore';
    }
    if (username.contains('__')) {
      return 'Username cannot contain consecutive underscores';
    }
    return '';
  }

  String _validatePassword(String password) {
    if (password.length < 8) return 'Password must be at least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Include at least one lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Include at least one special character';
    }
    return '';
  }

  Future<void> _submit() async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final usernameError = _validateUsername(username);
    if (usernameError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(usernameError),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (!_isUsernameAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username is not available or invalid'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final passwordError = _validatePassword(password);
    if (passwordError.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordError),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_adminUserId == null || _userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User data not found. Please restart registration.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final email = _userData?['email'];
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not found. Please contact admin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Create Firebase Auth user
      UserCredential authCredential;

      try {
        authCredential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Email already registered in Firebase Auth
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'This email is already registered. Please login instead.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
          setState(() => _isLoading = false);
          return;
        } else {
          rethrow;
        }
      }

      final firebaseUserId = authCredential.user!.uid;
      debugPrint('✅ Created Firebase Auth user: $firebaseUserId');

      // Force token refresh to ensure new token is used immediately
      await authCredential.user?.getIdToken(true);
      debugPrint('🔄 Token refreshed');

      // Step 2: Get admin-created user data
      Map<String, dynamic> adminUserData;
      try {
        final adminUserDoc =
            await _firestore.collection('users').doc(_adminUserId!).get();
        if (!adminUserDoc.exists)
          throw Exception('Admin-created user not found');
        adminUserData = adminUserDoc.data() as Map<String, dynamic>;
        debugPrint('✅ Read admin user doc');
      } catch (e) {
        debugPrint('❌ Failed to read admin user doc: $e');
        rethrow;
      }

      // Step 3: Create NEW user document with Firebase Auth UID as document ID
      final newUserData = {
        ...adminUserData, // Copy all data from admin-created document
        'id': firebaseUserId, // Replace ID with Firebase UID
        'uid': firebaseUserId, // Store Firebase UID in data
        'username': username.toLowerCase().trim(),
        'password': password, // In production, hash this!
        'email': email.trim(),
        'registrationStep': 3, // Ready for PIN setup
        'isVerified': true,
        'isActive': true,
        'createdAt': adminUserData['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'credentialsCreatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Remove old ID if it exists in data
      newUserData.remove('_id');
      newUserData.remove('adminId');

      try {
        await _firestore
            .collection('users')
            .doc(firebaseUserId)
            .set(newUserData);
        debugPrint('✅ Created new user doc: $firebaseUserId');
      } catch (e) {
        debugPrint('❌ Failed to create new user doc: $e');
        rethrow;
      }

      // Step 4: Copy all subcollections from admin-created doc to new doc
      try {
        await _copySubcollections(_adminUserId!, firebaseUserId);
        debugPrint('✅ Copied subcollections');
      } catch (e) {
        debugPrint('❌ Failed to copy subcollections: $e');
        rethrow;
      }

      // Step 5: Update pending_users collection
      try {
        final pendingUserDoc = await _firestore
            .collection('pending_users')
            .doc(_adminUserId!)
            .get();

        if (pendingUserDoc.exists) {
          // Create new pending user document with new UID
          await _firestore.collection('pending_users').doc(firebaseUserId).set({
            ...pendingUserDoc.data() as Map<String, dynamic>,
            'id': firebaseUserId,
            'uid': firebaseUserId,
            'registrationStatus': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('✅ Created new pending user doc');

          // Delete old pending user document
          await _firestore
              .collection('pending_users')
              .doc(_adminUserId!)
              .delete();
          debugPrint('✅ Deleted old pending user doc');
        } else {
          debugPrint('ℹ️ No pending user doc found for $_adminUserId');
        }
      } catch (e) {
        debugPrint('❌ Failed during pending_users operation: $e');
        rethrow;
      }

      // Step 6: Delete admin-created user document
      try {
        await _firestore.collection('users').doc(_adminUserId!).delete();
        debugPrint('✅ Deleted admin-created user doc: $_adminUserId');
      } catch (e) {
        debugPrint('❌ Failed to delete admin-created user doc: $e');
        rethrow;
      }

      // Step 7: Create user preferences
      try {
        await _firestore
            .collection('users')
            .doc(firebaseUserId)
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
        });
        debugPrint('✅ Created user preferences');
      } catch (e) {
        debugPrint('❌ Failed to create preferences: $e');
        rethrow;
      }

      // Step 8: Create activity log
      try {
        await _firestore
            .collection('users')
            .doc(firebaseUserId)
            .collection('activity_logs')
            .add({
          'activity': 'credentials_created',
          'timestamp': FieldValue.serverTimestamp(),
          'details':
              'User created online banking credentials and migrated from admin ID',
          'oldUserId': _adminUserId,
          'newUserId': firebaseUserId,
          'ipAddress': '127.0.0.1',
          'deviceInfo': 'Flutter App',
        });
        debugPrint('✅ Created activity log');
      } catch (e) {
        debugPrint('❌ Failed to create activity log: $e');
        rethrow;
      }

      // Step 9: Send email verification
      try {
        await authCredential.user?.sendEmailVerification();
        debugPrint('✅ Email verification sent');
      } catch (e) {
        debugPrint('⚠️ Failed to send email verification: $e');
        // Don't rethrow – not critical for flow
      }

      setState(() => _isLoading = false);

      // Step 10: Navigate to create PIN screen
      Navigator.pushNamed(
        context,
        '/create-pin',
        arguments: {
          'userId': firebaseUserId, // Pass the Firebase Auth UID
          'username': username,
          'accountNumber': _userData?['accountNumber'],
          'accountHolderName': _userData?['accountHolderName'],
          'email': email,
          'oldUserId': _adminUserId, // For tracking
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);

      String errorMessage = 'Error creating account: $e';
      debugPrint('🔥 Registration error: $e');

      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'weak-password':
            errorMessage =
                'Password is too weak. Please choose a stronger password.';
            break;
          case 'invalid-email':
            errorMessage = 'Invalid email address format.';
            break;
          case 'operation-not-allowed':
            errorMessage =
                'Email/password accounts are not enabled. Please contact support.';
            break;
          default:
            errorMessage = 'Authentication error: ${e.message}';
        }
      } else if (e is FirebaseException) {
        debugPrint('FirebaseException code: ${e.code}, message: ${e.message}');
        errorMessage = 'Database error: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _copySubcollections(
      String sourceUserId, String targetUserId) async {
    try {
      // Define known subcollections that might exist
      final knownSubcollections = [
        'preferences',
        'security_settings',
        'activity_logs',
        'accounts',
        'transactions',
        'notifications',
      ];

      for (final collectionName in knownSubcollections) {
        try {
          // Try to get documents from each known subcollection
          final snapshot = await _firestore
              .collection('users')
              .doc(sourceUserId)
              .collection(collectionName)
              .get();

          debugPrint(
              '📖 Reading $collectionName from $sourceUserId: ${snapshot.docs.length} docs');

          if (snapshot.docs.isNotEmpty) {
            for (final doc in snapshot.docs) {
              try {
                await _firestore
                    .collection('users')
                    .doc(targetUserId)
                    .collection(collectionName)
                    .doc(doc.id)
                    .set(doc.data());
                debugPrint('✅ Copied $collectionName/${doc.id}');
              } catch (e) {
                debugPrint('❌ Failed to copy $collectionName/${doc.id}: $e');
                rethrow; // stop on first error
              }
            }
          }
        } catch (e) {
          // Subcollection might not exist, continue with next
          debugPrint('⚠️ No $collectionName subcollection or error: $e');
        }
      }

      debugPrint(
          '✅ Finished copying subcollections from $sourceUserId to $targetUserId');
    } catch (e) {
      debugPrint('❌ Error copying subcollections: $e');
      rethrow; // important: propagate so outer catch sees it
    }
  }

  @override
  void dispose() {
    _usernameController.removeListener(_checkUsernameAvailability);
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                            'Create Credentials',
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
                                    Icons.person_add_alt_1_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Create Your Credentials',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Choose a username and secure password',
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

                          // Account Info Display
                          if (_userData != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue[100]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    color: Colors.blue[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Account: ${_userData?['accountNumber'] ?? 'N/A'}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF003366),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Name: ${_userData?['accountHolderName'] ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (_adminUserId != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Temp ID: ${_adminUserId!.substring(0, 8)}...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Username Field
                          _buildFormField(
                            label: 'Username',
                            controller: _usernameController,
                            prefixIcon: Icons.person_outline_rounded,
                            isFirst: true,
                            suffixWidget: _buildUsernameStatus(),
                            hintText: 'john_doe_2023',
                            maxLength: 20,
                            validator: (value) {
                              final error = _validateUsername(value ?? '');
                              return error.isNotEmpty ? error : null;
                            },
                            onChanged: (value) => setState(() {}),
                          ),

                          const SizedBox(height: 16),

                          // Username Requirements
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Username Requirements:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildUsernameRequirement(
                                  '3-20 characters',
                                  _usernameController.text.length >= 3 &&
                                      _usernameController.text.length <= 20,
                                ),
                                _buildUsernameRequirement(
                                  'Letters, numbers, and underscores only',
                                  _usernameController.text.isEmpty ||
                                      RegExp(r'^[a-zA-Z0-9_]+$')
                                          .hasMatch(_usernameController.text),
                                ),
                                _buildUsernameRequirement(
                                  'No consecutive underscores',
                                  !_usernameController.text.contains('__'),
                                ),
                                _buildUsernameRequirement(
                                  'Cannot start or end with underscore',
                                  !_usernameController.text.startsWith('_') &&
                                      !_usernameController.text.endsWith('_'),
                                ),
                                _buildUsernameRequirement(
                                  'Available',
                                  _isUsernameAvailable &&
                                      _usernameController.text.length >= 3,
                                  isAvailable: _isUsernameAvailable,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Password Field
                          _buildFormField(
                            label: 'Create Password',
                            controller: _passwordController,
                            prefixIcon: Icons.lock_outline_rounded,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            onToggleVisibility: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            onChanged: (value) => setState(() {}),
                          ),

                          const SizedBox(height: 16),

                          // Password Strength Indicator
                          PasswordStrengthIndicator(
                              password: _passwordController.text),
                          const SizedBox(height: 8),

                          // Password Requirements
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
                                const Text(
                                  'Password Requirements:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildPasswordRequirement(
                                    'At least 8 characters',
                                    _passwordController.text.length >= 8),
                                _buildPasswordRequirement(
                                    'One uppercase letter',
                                    RegExp(r'[A-Z]')
                                        .hasMatch(_passwordController.text)),
                                _buildPasswordRequirement(
                                    'One lowercase letter',
                                    RegExp(r'[a-z]')
                                        .hasMatch(_passwordController.text)),
                                _buildPasswordRequirement(
                                    'One number',
                                    RegExp(r'[0-9]')
                                        .hasMatch(_passwordController.text)),
                                _buildPasswordRequirement(
                                    'One special character (!@#\$%^&*)',
                                    RegExp(r'[!@#\$%^&*(),.?":{}|<>]')
                                        .hasMatch(_passwordController.text)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Confirm Password Field
                          _buildFormField(
                            label: 'Confirm Password',
                            controller: _confirmPasswordController,
                            prefixIcon: Icons.lock_reset_rounded,
                            isPassword: true,
                            obscureText: _obscureConfirmPassword,
                            onToggleVisibility: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                            isLast: true,
                          ),

                          const SizedBox(height: 32),

                          // Security Tips
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.orange[100]!,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                        'Security Tips',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '• Use a unique username that\'s easy to remember\n'
                                        '• Don\'t reuse passwords from other accounts\n'
                                        '• Consider using a password manager\n'
                                        '• Your username will be visible to recipients',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange[800],
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

                          // Migration Notice
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
                                  Icons.swap_horiz_rounded,
                                  color: Colors.green[700],
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
                                          color: Colors.green[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Your account will be migrated to use Firebase Authentication. '
                                        'The temporary admin ID will be replaced with your permanent user ID.',
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

                          // Continue Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (_isUsernameAvailable &&
                                      _passwordController.text.isNotEmpty &&
                                      _confirmPasswordController
                                          .text.isNotEmpty &&
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
                                          'Continue to Set PIN',
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
                                  'All credentials are encrypted and stored securely in Firebase',
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

                    // Demo Usernames Hint
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Username Tips:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try usernames like: john_doe, sarah_j, mike_2023, etc.\n'
                            'Avoid special characters except underscore.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.9),
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
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    bool isFirst = false,
    bool isLast = false,
    String? hintText,
    int? maxLength,
    Widget? suffixWidget,
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
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                  obscureText: isPassword && obscureText,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    prefixIcon: Icon(
                      prefixIcon,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                    hintText: hintText,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    border: InputBorder.none,
                    errorBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    counterText: maxLength != null
                        ? '${controller.text.length}/$maxLength'
                        : null,
                    counterStyle: TextStyle(
                      fontSize: 12,
                      color: controller.text.length == maxLength
                          ? Colors.green[700]
                          : Colors.grey[500],
                    ),
                  ),
                  validator: validator,
                  onChanged: onChanged,
                  maxLength: maxLength,
                ),
              ),
              if (isPassword && onToggleVisibility != null)
                IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: onToggleVisibility,
                ),
              if (suffixWidget != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffixWidget,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsernameStatus() {
    if (_usernameController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isCheckingUsername) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
        ),
      );
    }

    if (_isUsernameAvailable && _usernameController.text.length >= 3) {
      return Icon(
        Icons.check_circle_rounded,
        color: Colors.green[700],
        size: 20,
      );
    }

    return Icon(
      Icons.cancel_rounded,
      color: Colors.red[700],
      size: 20,
    );
  }

  Widget _buildUsernameRequirement(String text, bool isMet,
      {bool isAvailable = false}) {
    Color iconColor;
    Color textColor;

    if (isAvailable) {
      // For "Available" requirement, show special logic
      iconColor = _isUsernameAvailable ? Colors.green[700]! : Colors.red[700]!;
      textColor = _isUsernameAvailable ? Colors.green[700]! : Colors.red[700]!;
    } else {
      iconColor = isMet ? Colors.green[700]! : Colors.grey[400]!;
      textColor = isMet ? Colors.green[700]! : Colors.grey[600]!;
    }

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: iconColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              isMet ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isMet ? Colors.green[700] : Colors.grey[400],
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  color: isMet ? Colors.green[700] : Colors.grey[600],
                  fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ));
  }
}
