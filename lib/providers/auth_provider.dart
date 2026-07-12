import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? fullName;
  final String? phone;
  final String? accountNumber;
  final bool isVerified;
  final int failedLoginAttempts;
  final bool accountLocked;
  final DateTime? accountLockedUntil;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.fullName,
    this.phone,
    this.accountNumber,
    this.isVerified = false,
    this.failedLoginAttempts = 0,
    this.accountLocked = false,
    this.accountLockedUntil,
    this.lastLogin,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      uid: doc.id, // Use document ID as UID (Firebase Auth UID)
      email: data['email'] as String? ?? '',
      username: data['username'] as String? ?? '',
      fullName: data['fullName'] as String? ?? data['name'] as String?,
      phone: data['phone'] as String?,
      accountNumber: data['accountNumber'] as String?,
      isVerified: data['isVerified'] as bool? ?? false,
      failedLoginAttempts: data['failedLoginAttempts'] as int? ?? 0,
      accountLocked: data['accountLocked'] as bool? ?? false,
      accountLockedUntil: data['accountLockedUntil']?.toDate(),
      lastLogin: data['lastLogin']?.toDate(),
      createdAt: data['createdAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'fullName': fullName,
      'phone': phone,
      'accountNumber': accountNumber,
      'isVerified': isVerified,
      'failedLoginAttempts': failedLoginAttempts,
      'accountLocked': accountLocked,
      'accountLockedUntil': accountLockedUntil,
      'lastLogin': lastLogin,
      'createdAt': createdAt,
    };
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? fullName,
    String? phone,
    String? accountNumber,
    bool? isVerified,
    int? failedLoginAttempts,
    bool? accountLocked,
    DateTime? accountLockedUntil,
    DateTime? lastLogin,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      accountNumber: accountNumber ?? this.accountNumber,
      isVerified: isVerified ?? this.isVerified,
      failedLoginAttempts: failedLoginAttempts ?? this.failedLoginAttempts,
      accountLocked: accountLocked ?? this.accountLocked,
      accountLockedUntil: accountLockedUntil ?? this.accountLockedUntil,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Keys for SharedPreferences
  static const String _rememberMeKey = 'remember_me';
  static const String _userEmailKey = 'user_email';

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  bool _rememberMe = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  String? get userId => _currentUser?.uid;
  String? get userEmail => _currentUser?.email;
  String? get username => _currentUser?.username;
  String? get userName => _currentUser?.fullName ?? _currentUser?.username;
  String? get userPhone => _currentUser?.phone;
  String? get accountNumber => _currentUser?.accountNumber;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  bool get rememberMe => _rememberMe;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadRememberMePreference();
    await checkAuthStatus();
  }

  Future<void> _loadRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _rememberMe = prefs.getBool(_rememberMeKey) ?? false;

      if (_rememberMe) {
        final savedEmail = prefs.getString(_userEmailKey);
        if (savedEmail != null) {
          // Try to load user data from Firestore by email
          final usersQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: savedEmail)
              .limit(1)
              .get();

          if (usersQuery.docs.isNotEmpty) {
            final userDoc = usersQuery.docs.first;
            _currentUser = UserModel.fromFirestore(userDoc);
            _isAuthenticated = true;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      _rememberMe = false;
    }
  }

  Future<void> _saveRememberMePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_rememberMeKey, _rememberMe);

      if (_rememberMe && _currentUser?.email != null) {
        await prefs.setString(_userEmailKey, _currentUser!.email);
      } else if (!_rememberMe) {
        await prefs.remove(_userEmailKey);
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }

  // -------------------------
  // Username/Password Sign In
  // -------------------------
  Future<bool> signInWithUsername(String username, String password,
      {bool rememberMe = false}) async {
    try {
      debugPrint('Starting sign in for username: $username');
      _isLoading = true;
      _errorMessage = null;
      _rememberMe = rememberMe;
      notifyListeners();

      // Step 1: Find user by username in Firestore
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase().trim())
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        _errorMessage = 'Invalid username or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userDoc = usersQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Get email from user data
      final email = userData['email'] as String?;
      if (email == null || email.isEmpty) {
        _errorMessage = 'Account error: No email associated';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if user has Firebase Auth UID (means they completed registration)
      final uid = userData['uid'] as String?;
      if (uid == null) {
        _errorMessage =
            'Account not fully registered. Please complete registration.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check account locked status
      final isAccountLocked = userData['accountLocked'] as bool? ?? false;
      final lockedUntilValue = userData['accountLockedUntil'];
      DateTime? lockedUntil;
      if (lockedUntilValue is Timestamp) {
        lockedUntil = lockedUntilValue.toDate();
      }

      if (isAccountLocked && lockedUntil != null) {
        if (DateTime.now().isBefore(lockedUntil)) {
          _errorMessage = 'Account is locked. Please try again later.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Check if user is verified
      final isVerified = userData['isVerified'] as bool? ?? false;
      if (!isVerified) {
        _errorMessage = 'Account not verified. Please complete verification.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if user is active
      final isActive = userData['isActive'] as bool? ?? true;
      if (!isActive) {
        _errorMessage = 'Account is deactivated. Please contact support.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Step 2: Sign in with Firebase Auth using the email
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 3: Reset failed login attempts on successful login
      await userDoc.reference.update({
        'failedLoginAttempts': 0,
        'accountLocked': false,
        'accountLockedUntil': null,
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Step 4: Update local state
      _currentUser = UserModel.fromFirestore(userDoc);
      _isAuthenticated = true;

      // Save remember me preference
      await _saveRememberMePreference();

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      // Update failed login attempts for wrong password
      if (e.code == 'wrong-password') {
        await _updateFailedAttempts(username);
      }

      _errorMessage = _getFirebaseErrorMessage(e);
      notifyListeners();
      return false;
    } catch (e, stackTrace) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      debugPrint('Unexpected SignIn Error: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }

  Future<void> _updateFailedAttempts(String username) async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase().trim())
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        final userDoc = usersQuery.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>? ?? {};
        final currentAttempts = userData['failedLoginAttempts'] as int? ?? 0;
        final failedAttempts = currentAttempts + 1;

        final updates = {
          'failedLoginAttempts': failedAttempts,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Lock account after 5 failed attempts for 30 minutes
        if (failedAttempts >= 5) {
          updates['accountLocked'] = true;
          updates['accountLockedUntil'] = Timestamp.fromDate(
              DateTime.now().add(const Duration(minutes: 30)));
        }

        await userDoc.reference.update(updates);
      }
    } catch (e) {
      debugPrint('Error updating failed attempts: $e');
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this username';
      case 'wrong-password':
        return 'Incorrect password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-email':
        return 'Invalid email format';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'invalid-credential':
        return 'Invalid login credentials';
      default:
        return 'Login failed. Please try again';
    }
  }

  // -------------------------
  // Email/Password Sign In (for direct email login)
  // -------------------------
  Future<bool> signInWithEmail(String email, String password,
      {bool rememberMe = false}) async {
    try {
      debugPrint('Starting sign in for email: $email');
      _isLoading = true;
      _errorMessage = null;
      _rememberMe = rememberMe;
      notifyListeners();

      // Step 1: Find user by email in Firestore
      final usersQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        _errorMessage = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userDoc = usersQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      // Check if user has Firebase Auth UID
      final uid = userData['uid'] as String?;
      if (uid == null) {
        _errorMessage =
            'Account not fully registered. Please complete registration.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check account status
      final isAccountLocked = userData['accountLocked'] as bool? ?? false;
      final lockedUntilValue = userData['accountLockedUntil'];
      DateTime? lockedUntil;
      if (lockedUntilValue is Timestamp) {
        lockedUntil = lockedUntilValue.toDate();
      }

      if (isAccountLocked && lockedUntil != null) {
        if (DateTime.now().isBefore(lockedUntil)) {
          _errorMessage = 'Account is locked. Please try again later.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
      }

      // Step 2: Sign in with Firebase Auth
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Step 3: Reset failed login attempts
      await userDoc.reference.update({
        'failedLoginAttempts': 0,
        'accountLocked': false,
        'accountLockedUntil': null,
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // Step 4: Update local state
      _currentUser = UserModel.fromFirestore(userDoc);
      _isAuthenticated = true;

      // Save remember me preference
      await _saveRememberMePreference();

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getFirebaseErrorMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred';
      notifyListeners();
      debugPrint('Email SignIn Error: $e');
      return false;
    }
  }

  // -------------------------
  // Check Username Availability
  // -------------------------
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase().trim())
          .limit(1)
          .get();

      return query.docs.isEmpty; // true if available, false if taken
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  // -------------------------
  // Update Profile
  // -------------------------
  Future<bool> updateProfile({
    String? username,
    String? fullName,
    String? phone,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final userRef = _firestore.collection('users').doc(user.uid);
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (username != null && username.isNotEmpty) {
        if (!_isValidUsername(username)) {
          _errorMessage = 'Invalid username format';
          _isLoading = false;
          notifyListeners();
          return false;
        }

        // Check if new username is available
        final available = await checkUsernameAvailability(username);
        if (!available) {
          _errorMessage = 'Username already taken';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        updateData['username'] = username.toLowerCase().trim();
      }

      if (fullName != null && fullName.isNotEmpty) {
        updateData['fullName'] = fullName;
      }

      if (phone != null && phone.isNotEmpty) {
        updateData['phone'] = phone;
      }

      await userRef.update(updateData);

      // Update local user model
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          username: username?.toLowerCase().trim() ?? _currentUser!.username,
          fullName: fullName ?? _currentUser!.fullName,
          phone: phone ?? _currentUser!.phone,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update profile: ${e.message}';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to update profile';
      notifyListeners();
      debugPrint('Update Profile Error: $e');
      return false;
    }
  }

  // -------------------------
  // Change Password
  // -------------------------
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_isValidPassword(newPassword)) {
        _errorMessage =
            'Password must be at least 8 characters with letters and numbers';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'wrong-password':
          _errorMessage = 'Current password is incorrect';
          break;
        case 'weak-password':
          _errorMessage = 'New password is too weak';
          break;
        default:
          _errorMessage = 'Failed to change password';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to change password';
      notifyListeners();
      debugPrint('Change Password Error: $e');
      return false;
    }
  }

  // -------------------------
  // Reset Password
  // -------------------------
  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // First check if email exists in our database
      final usersQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        _errorMessage = 'No account found with this email';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      await _auth.sendPasswordResetEmail(email: email);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to send reset email: ${e.message}';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to reset password';
      notifyListeners();
      debugPrint('Reset Password Error: $e');
      return false;
    }
  }

  // -------------------------
  // Phone OTP Sign-In
  // -------------------------
  Future<void> signInWithPhone(
    String phone, {
    required Function(String verificationId) codeSent,
    required Function(FirebaseAuthException e) verificationFailed,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          await _handlePhoneLoginSuccess(userCredential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _isLoading = false;
          _errorMessage = _getPhoneAuthErrorMessage(e.code);
          notifyListeners();
          verificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _isLoading = false;
          notifyListeners();
          codeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to initiate phone login';
      notifyListeners();
      debugPrint('Phone sign in error: $e');
    }
  }

  Future<bool> verifyOtp(String verificationId, String smsCode) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      await _handlePhoneLoginSuccess(userCredential);

      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      _errorMessage = _getOtpErrorMessage(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to verify OTP';
      notifyListeners();
      debugPrint('OTP verification error: $e');
      return false;
    }
  }

  Future<void> _handlePhoneLoginSuccess(UserCredential credential) async {
    final user = credential.user;
    if (user == null) {
      throw Exception('User not found after phone login');
    }

    // Check if user exists in Firestore
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      // Existing user - update last login
      await userDoc.reference.update({
        'lastLogin': FieldValue.serverTimestamp(),
        'phone': user.phoneNumber,
      });

      // Load user data from Firestore
      _currentUser = UserModel.fromFirestore(userDoc);
    } else {
      // New user - create account
      final username = _generateUsernameFromPhone(user.phoneNumber);
      final accountNumber = _generateAccountNumber();
      final now = DateTime.now();

      final newUserData = {
        'uid': user.uid,
        'phone': user.phoneNumber,
        'email': '', // Phone-only users might not have email
        'username': username,
        'fullName': 'Phone User',
        'accountNumber': accountNumber,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'lastLogin': Timestamp.fromDate(now),
        'isVerified': true,
        'failedLoginAttempts': 0,
        'accountLocked': false,
        'accountLockedUntil': null,
      };

      await _firestore.collection('users').doc(user.uid).set(newUserData);

      _currentUser = UserModel(
        uid: user.uid,
        email: '',
        username: username,
        fullName: 'Phone User',
        phone: user.phoneNumber,
        accountNumber: accountNumber,
        isVerified: true,
        lastLogin: now,
        createdAt: now,
      );
    }

    _isAuthenticated = true;
    _isLoading = false;
    notifyListeners();
  }

  String _generateUsernameFromPhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return 'user_${DateTime.now().millisecondsSinceEpoch}';
    }
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final last6Digits =
        digits.length > 6 ? digits.substring(digits.length - 6) : digits;
    return 'phone_$last6Digits';
  }

  String _getPhoneAuthErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Failed to send OTP. Please try again';
    }
  }

  String _getOtpErrorMessage(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please try again';
      case 'session-expired':
        return 'OTP session expired. Please request a new OTP';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'code-expired':
        return 'OTP has expired. Please request a new one';
      default:
        return 'OTP verification failed. Please try again';
    }
  }

  // -------------------------
  // Sign Out
  // -------------------------
  Future<bool> signOut() async {
    try {
      await _auth.signOut();
      _clearAuthData();
      return true;
    } catch (e) {
      debugPrint('Sign out error: $e');
      return false;
    }
  }

  // -------------------------
  // Clear Auth Data
  // -------------------------
  void _clearAuthData() {
    _currentUser = null;
    _isAuthenticated = false;
    _errorMessage = null;

    if (!_rememberMe) {
      _rememberMe = false;
      _saveRememberMePreference();
    }

    notifyListeners();
  }

  // -------------------------
  // Check Authentication Status
  // -------------------------
  Future<bool> checkAuthStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Fetch user data from Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          _currentUser = UserModel.fromFirestore(userDoc);
          _isAuthenticated = true;
          notifyListeners();
          return true;
        }
      }

      // If we have remember me but no Firebase user, clear data
      if (!_rememberMe) {
        _clearAuthData();
      }

      return false;
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      return false;
    }
  }

  // -------------------------
  // Email Verification
  // -------------------------
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<bool> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      return false;
    }
  }

  Future<bool> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
      await checkAuthStatus();
      return true;
    } catch (e) {
      debugPrint('Error reloading user: $e');
      return false;
    }
  }

  // -------------------------
  // Delete Account
  // -------------------------
  Future<bool> deleteAccount(String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        _errorMessage = 'User not authenticated';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Delete from Firestore first
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete from Firebase Auth
      await user.delete();

      _clearAuthData();
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;

      switch (e.code) {
        case 'wrong-password':
          _errorMessage = 'Password is incorrect';
          break;
        case 'requires-recent-login':
          _errorMessage = 'Please log in again to delete your account';
          break;
        default:
          _errorMessage = 'Failed to delete account: ${e.message}';
      }

      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to delete account';
      notifyListeners();
      debugPrint('Delete Account Error: $e');
      return false;
    }
  }

  // -------------------------
  // Validation Methods
  // -------------------------
  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  bool _isValidUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Za-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  String _generateAccountNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final last10Digits = timestamp.length > 10
        ? timestamp.substring(timestamp.length - 10)
        : timestamp.padLeft(10, '0');
    return 'ACC$last10Digits';
  }

  // -------------------------
  // Stream for Auth State Changes
  // -------------------------
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
