import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../theme/alpha_theme.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.initialTab});

  final int initialTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _showSecurityOptions = false;
  bool _showPreferences = false;
  bool _showSupport = false;
  bool _showAccountActions = false;
  bool _twoFactorEnabled = false;
  bool _biometricEnabled = false;
  bool _fingerprintEnabled = false;
  bool _faceIdEnabled = false;
  bool _notificationsEnabled = true;
  bool _transactionAlerts = true;
  bool _securityAlerts = true;
  bool _promotionalMessages = false;
  bool _balanceUpdates = true;
  String _appVersion = '1.0.0';
  String? _profileImageUrl;
  File? _imageFile;
  Uint8List? _webImageData;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _usernameController;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  int _transactionCount = 0;
  double _totalSpent = 0.0;
  double _totalReceived = 0.0;
  double _currentBalance = 0.0;
  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _accounts = [];
  final List<Map<String, dynamic>> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _usernameController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeData();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

    await _getAppVersion();
    await _loadUserData();
    await _loadUserStats();
    await _loadSecuritySettings();
    await _loadNotificationPreferences();
    await _loadAccounts();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = _auth.currentUser;
    if (user == null || authProvider.userId == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(authProvider.userId).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userData = data;

        final firstName = data['firstName'] ?? '';
        final lastName = data['lastName'] ?? '';
        final name = data['name'] ?? '$firstName $lastName'.trim();
        final email = data['email'] ?? user.email ?? 'No email';

        if (mounted) {
          setState(() {
            _nameController.text =
                name.isNotEmpty ? name : email.split('@').first;
            _phoneController.text = data['phone'] ?? '';
            _addressController.text = data['address'] ?? '';
            _usernameController.text = data['username'] ?? '';
            _currentBalance = (data['balance'] ?? 0.0).toDouble();
            _twoFactorEnabled = data['twoFactorEnabled'] ?? false;
            _biometricEnabled = data['biometricEnabled'] ?? false;
            _fingerprintEnabled = data['fingerprintEnabled'] ?? false;
            _faceIdEnabled = data['faceIdEnabled'] ?? false;
            _profileImageUrl = data['profileImageUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _getAppVersion() async {
    if (!mounted) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Error getting app version: $e');
    }
  }

  Future<void> _loadUserStats() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = _auth.currentUser;
    if (user == null || authProvider.userId == null) return;

    try {
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(authProvider.userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      double spent = 0.0;
      double received = 0.0;

      for (final doc in transactionsSnapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        if (amount < 0) {
          spent += amount.abs();
        } else {
          received += amount;
        }
      }

      if (mounted) {
        setState(() {
          _transactionCount = transactionsSnapshot.size;
          _totalSpent = spent;
          _totalReceived = received;
        });
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
    }
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId == null) return;

    try {
      final accountsSnapshot = await _firestore
          .collection('users')
          .doc(authProvider.userId)
          .collection('accounts')
          .get();

      if (mounted) {
        setState(() {
          _accounts = accountsSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'Account',
              'accountNumber': data['accountNumber'] ?? '',
              'balance': (data['balance'] ?? 0.0).toDouble(),
              'currencyCode': data['currencyCode'] ?? 'USD',
              'type': data['type'] ?? 'checking',
              'isPrimary': data['isPrimary'] ?? false,
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading accounts: $e');
    }
  }

  Future<void> _loadSecuritySettings() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId == null) return;

    try {
      final securityDoc = await _firestore
          .collection('users')
          .doc(authProvider.userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (securityDoc.exists) {
        final data = securityDoc.data()!;
        if (mounted) {
          setState(() {
            _twoFactorEnabled = data['requirePinForTransactions'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading security settings: $e');
    }
  }

  Future<void> _loadNotificationPreferences() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userId == null) return;

    try {
      final notificationsDoc = await _firestore
          .collection('users')
          .doc(authProvider.userId)
          .collection('notifications')
          .doc('preferences')
          .get();

      if (notificationsDoc.exists) {
        final data = notificationsDoc.data()!;
        if (mounted) {
          setState(() {
            _transactionAlerts = data['transactionAlerts'] ?? true;
            _securityAlerts = data['securityAlerts'] ?? true;
            _promotionalMessages = data['promotionalMessages'] ?? false;
            _balanceUpdates = data['balanceUpdates'] ?? true;
            _notificationsEnabled = data['pushNotifications'] ?? true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  Future<void> _saveProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      // Split name into first and last name if possible
      final nameParts = _nameController.text.trim().split(' ');
      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
      final lastName =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      // Update profile in Firestore
      await _firestore.collection('users').doc(userId).update({
        'name': _nameController.text.trim(),
        'firstName': firstName,
        'lastName': lastName,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'username': _usernameController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update profile image if selected
      if (_imageFile != null || _webImageData != null) {
        await _uploadProfileImage();
      }

      // Update AuthProvider state
      await authProvider.checkAuthStatus();

      if (mounted) {
        _showSnackbar('Profile updated successfully', Colors.green);
        setState(() => _isEditing = false);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      if (mounted) {
        _showSnackbar('Error updating profile', Colors.red);
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    if (mounted) {
      setState(() {
        _isUploadingImage = true;
      });
    }

    try {
      // Upload to Firebase Storage with timeout
      final ref = _storage.ref().child(
          'profile_images/$userId-${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Set timeout for upload
      final uploadTask = kIsWeb
          ? ref.putData(
              _webImageData!, SettableMetadata(contentType: 'image/jpeg'))
          : ref.putFile(_imageFile!);

      // Wait for upload with timeout
      final taskSnapshot = await uploadTask.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Image upload timed out');
        },
      );

      if (taskSnapshot.state != TaskState.success) {
        throw Exception('Upload failed');
      }

      final downloadUrl = await ref.getDownloadURL();

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'profileImageUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
          _imageFile = null;
          _webImageData = null;
          _isUploadingImage = false;
        });
        _showSnackbar('Profile picture updated', Colors.green);
      }
    } on TimeoutException catch (e) {
      debugPrint('Upload timeout: $e');
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        _showSnackbar('Upload timed out. Please try again.', Colors.orange);
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage error: $e');
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        if (e.code == 'storage/retry-limit-exceeded') {
          _showSnackbar(
              'Upload failed. Please check your internet connection and try again.',
              Colors.red);
        } else {
          _showSnackbar('Error uploading image: ${e.message}', Colors.red);
        }
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        _showSnackbar('Error updating profile picture', Colors.red);
      }
    }
  }

  Future<void> _pickImage() async {
    if (_isUploadingImage) return;

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Reduced quality for faster upload
        maxWidth: 400, // Smaller image size
        maxHeight: 400,
      );

      if (pickedFile != null) {
        if (kIsWeb) {
          // For web, read as bytes
          final bytes = await pickedFile.readAsBytes();
          if (mounted) {
            setState(() {
              _webImageData = bytes;
              _profileImageUrl = null; // Clear to show initials immediately
            });
          }
          await _uploadProfileImage();
        } else {
          // For mobile
          if (mounted) {
            setState(() {
              _imageFile = File(pickedFile.path);
              _profileImageUrl = null; // Clear to show initials immediately
            });
          }
          await _uploadProfileImage();
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        _showSnackbar('Error selecting image. Please try again.', Colors.red);
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _updateSecuritySetting(String setting, bool value) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        setting: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          if (setting == 'twoFactorEnabled') {
            _twoFactorEnabled = value;
          } else if (setting == 'biometricEnabled') {
            _biometricEnabled = value;
          } else if (setting == 'fingerprintEnabled') {
            _fingerprintEnabled = value;
          } else if (setting == 'faceIdEnabled') {
            _faceIdEnabled = value;
          }
        });
        _showSnackbar('Security setting updated', Colors.green);
      }
    } catch (e) {
      debugPrint('Error updating security setting: $e');
      if (mounted) {
        _showSnackbar('Error updating setting', Colors.red);
      }
    }
  }

  Future<void> _updateNotificationPreference(String setting, bool value) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc('preferences')
          .update({
        setting: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          if (setting == 'transactionAlerts') {
            _transactionAlerts = value;
          } else if (setting == 'securityAlerts') {
            _securityAlerts = value;
          } else if (setting == 'promotionalMessages') {
            _promotionalMessages = value;
          } else if (setting == 'balanceUpdates') {
            _balanceUpdates = value;
          } else if (setting == 'pushNotifications') {
            _notificationsEnabled = value;
          }
        });
        _showSnackbar('Notification preference updated', Colors.green);
      }
    } catch (e) {
      debugPrint('Error updating notification preference: $e');
      if (mounted) {
        _showSnackbar('Error updating notification preference', Colors.red);
      }
    }
  }

  Future<void> _changePassword() async {
    showDialog(
      context: context,
      builder: (context) => ChangePasswordDialog(
        onPasswordChanged: () {
          if (mounted) {
            _showSnackbar('Password changed successfully', Colors.green);
          }
        },
      ),
    );
  }

  Future<void> _showActiveSessions() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      final sessionsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (sessionsDoc.exists) {
        final data = sessionsDoc.data()!;
        final whitelistedDevices =
            data['whitelistedDevices'] as List<dynamic>? ?? [];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Active Sessions'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: whitelistedDevices.length,
                itemBuilder: (context, index) {
                  final device = whitelistedDevices[index];
                  return ListTile(
                    leading: const Icon(Icons.devices, color: Colors.blue),
                    title: Text(device['deviceName'] ?? 'Unknown Device'),
                    subtitle: Text(
                        'IP: ${device['ipAddress'] ?? 'Unknown'} • Last active: ${device['lastLogin'] != null ? _formatDate(device['lastLogin']) : 'Unknown'}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.red),
                      onPressed: () => _removeDevice(device['deviceId']),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () => _logoutAllSessions(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Logout All Devices'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Unable to load sessions', Colors.orange);
      }
    }
  }

  Future<void> _removeDevice(String? deviceId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null || deviceId == null) return;

    try {
      final securityDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (securityDoc.exists) {
        final data = securityDoc.data()!;
        final whitelistedDevices =
            data['whitelistedDevices'] as List<dynamic>? ?? [];
        final updatedDevices = whitelistedDevices
            .where((device) => device['deviceId'] != deviceId)
            .toList();

        await securityDoc.reference.update({
          'whitelistedDevices': updatedDevices,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showSnackbar('Device removed', Colors.green);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error removing device', Colors.red);
      }
    }
  }

  Future<void> _logoutAllSessions() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_settings')
          .doc('settings')
          .update({
        'whitelistedDevices': [],
        'loginHistory': [],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSnackbar('All devices logged out', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error logging out devices', Colors.red);
      }
    }
  }

  Future<void> _showLoginHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      final securityDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (securityDoc.exists) {
        final data = securityDoc.data()!;
        final loginHistory = data['loginHistory'] as List<dynamic>? ?? [];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Login History'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: loginHistory.length,
                itemBuilder: (context, index) {
                  final history = loginHistory[index];
                  return ListTile(
                    leading: Icon(
                      history['success'] == true
                          ? Icons.check_circle
                          : Icons.error,
                      color: history['success'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                    title: Text(history['device'] ?? 'Unknown Device'),
                    subtitle: Text(
                        '${history['ipAddress'] ?? 'Unknown IP'} • ${_formatDate(history['timestamp'])}'),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Unable to load login history', Colors.orange);
      }
    }
  }

  Future<void> _showHelpAndSupport() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text('24/7 Support Line'),
              subtitle: const Text('+306994303966'),
              onTap: () => _launchPhoneCall('+306994303966'),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email Support'),
              subtitle: const Text('support@alphabankplus.com'),
              onTap: () => _launchEmail('support@alphabankplus.com'),
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Colors.blue),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 9AM-5PM EST'),
              onTap: () => _showSnackbar('Live chat coming soon!', Colors.blue),
            ),
            ListTile(
              leading: const Icon(Icons.help, color: Colors.blue),
              title: const Text('FAQs'),
              subtitle: const Text('Frequently Asked Questions'),
              onTap: () => _launchUrl(
                  'https://sites.google.com/view/alpha-wallet-privacy-policy/faq'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyPolicy() async {
    _launchUrl(
        'https://sites.google.com/view/alpha-wallet-privacy-policy/home');
  }

  Future<void> _showTermsOfService() async {
    _launchUrl(
        'https://sites.google.com/view/alpha-wallet-privacy-policy/terms-and-conditions');
  }

  Future<void> _rateApp() async {
    if (kIsWeb) {
      _showSnackbar('Visit our website to rate us!', Colors.blue);
      return;
    }

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        _launchUrl(
          'https://play.google.com/store/apps/details?id=com.alphabank.app',
        );
      } else if (Platform.isIOS) {
        _launchUrl('https://apps.apple.com/app/alpha-bank/id1234567890');
      }
    }
  }

  Future<void> _exportData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final transactionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      final accountsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('accounts')
          .get();

      // Format data for CSV
      final csvContent = StringBuffer()
        ..writeln('Date,Description,Amount,Type,Status,Category')
        ..writeAll(transactionsSnapshot.docs.map((doc) {
          final data = doc.data();
          final date = data['timestamp'] != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss')
                  .format((data['timestamp'] as Timestamp).toDate())
              : '';
          final description = data['description'] ?? '';
          final amount = data['amount'] ?? 0.0;
          final type = data['type'] ?? '';
          final status = data['status'] ?? '';
          final category = data['category'] ?? '';
          return '"$date","$description","$amount","$type","$status","$category"';
        }), '\n');

      // Share the data
      await Share.share(
        'Alpha Bank Data Export\n\n'
        'Account Summary:\n'
        'Name: ${userDoc.data()?['name']}\n'
        'Email: ${userDoc.data()?['email']}\n'
        'Account Number: ${userDoc.data()?['accountNumber']}\n'
        'Balance: \$${_currentBalance.toStringAsFixed(2)}\n'
        'Total Transactions: ${transactionsSnapshot.size}\n'
        'Total Spent: \$${_totalSpent.toStringAsFixed(2)}\n'
        'Total Received: \$${_totalReceived.toStringAsFixed(2)}\n\n'
        'Accounts:\n'
        '${accountsSnapshot.docs.map((doc) {
          final data = doc.data();
          return '${data['title']}: \$${(data['balance'] ?? 0.0).toStringAsFixed(2)} ${data['currencyCode']}';
        }).join('\n')}\n\n'
        'Transaction History:\n$csvContent\n\n'
        'Exported on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        subject: 'Alpha Bank Data Export',
      );

      if (mounted) {
        _showSnackbar('Data exported successfully', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Error exporting data: $e', Colors.red);
      }
    }
  }

  Future<void> _deleteAccount() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = _auth.currentUser;

    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'All your data including transactions, account details, and personal information will be permanently deleted.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Enter DELETE to confirm',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.toLowerCase() != 'delete') {
                  return 'Please type DELETE to confirm';
                }
                return null;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = _auth.currentUser;

    if (user == null) return;

    // Show final confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content:
            const Text('Are you absolutely sure? This action is irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes, Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      // Delete user from Auth
      await user.delete();

      // Delete user data from Firestore
      final userId = user.uid;
      await _firestore.collection('users').doc(userId).delete();

      // Navigate to login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
        _showSnackbar('Account deleted successfully', Colors.green);
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
      if (mounted) {
        _showSnackbar('Error deleting account', Colors.red);
      }
    }
  }

  Future<void> _showTransactionLimits() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.userId;

    if (userId == null) return;

    try {
      final securityDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (securityDoc.exists) {
        final data = securityDoc.data()!;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Transaction Limits'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLimitRow(
                  'Daily Transaction Limit',
                  '\$${(data['dailyTransactionLimit'] ?? 50000.0).toStringAsFixed(2)}',
                ),
                _buildLimitRow(
                  'Max Transaction Amount',
                  '\$${(data['maxTransactionAmount'] ?? 10000.0).toStringAsFixed(2)}',
                ),
                _buildLimitRow(
                  'PIN Retry Limit',
                  '${data['pinRetryLimit'] ?? 3} attempts',
                ),
                _buildLimitRow(
                  'Session Timeout',
                  '${data['sessionTimeout'] ?? 30} minutes',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnackbar('Unable to load limits', Colors.orange);
      }
    }
  }

  Widget _buildLimitRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AlphaTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        _showSnackbar('Cannot make phone call', Colors.red);
      }
    }
  }

  Future<void> _launchEmail(String email) async {
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        _showSnackbar('Cannot open email client', Colors.red);
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        _showSnackbar('Cannot open URL', Colors.red);
      }
    }
  }

  void _showSnackbar(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AlphaTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AlphaTheme.darkGray,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(Map<String, dynamic> account) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
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
              color: AlphaTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              account['isPrimary'] == true
                  ? Icons.account_balance_wallet
                  : Icons.account_balance,
              color: AlphaTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account['title'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AlphaTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account['accountNumber'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '\$${account['balance'].toStringAsFixed(2)} ${account['currencyCode']}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AlphaTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          if (account['isPrimary'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AlphaTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Primary',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String getInitials() {
    final name = _nameController.text.isNotEmpty
        ? _nameController.text
        : _userData['name'] ?? '';
    if (name.isNotEmpty) {
      final nameParts = name.trim().split(' ');
      if (nameParts.length > 1) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else {
        return name[0].toUpperCase();
      }
    }
    return _userData['email']?.isNotEmpty == true
        ? _userData['email']![0].toUpperCase()
        : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AlphaTheme.headingSmall.copyWith(color: AlphaTheme.white),
        ),
        backgroundColor: AlphaTheme.primaryBlue,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: AlphaTheme.white),
              onPressed: _saveProfile,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit, color: AlphaTheme.white),
              onPressed: () {
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _initializeData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Header with Stats
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AlphaTheme.primaryBlue,
                                  image: _profileImageUrl != null &&
                                          _profileImageUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image:
                                              NetworkImage(_profileImageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _isUploadingImage
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AlphaTheme.white),
                                        ),
                                      )
                                    : _profileImageUrl == null ||
                                            _profileImageUrl!.isEmpty
                                        ? Center(
                                            child: Text(
                                              getInitials(),
                                              style: const TextStyle(
                                                fontSize: 32,
                                                fontWeight: FontWeight.bold,
                                                color: AlphaTheme.white,
                                              ),
                                            ),
                                          )
                                        : null,
                              ),
                              if (!_isUploadingImage)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AlphaTheme.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                      color: AlphaTheme.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isEditing
                                  ? TextField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Full Name',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.all(12),
                                      ),
                                    )
                                  : Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text
                                          : _userData['name'] ?? 'User',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: AlphaTheme.primaryBlue,
                                      ),
                                    ),
                              const SizedBox(height: 4),
                              Text(
                                _userData['email'] ??
                                    authProvider.userEmail ??
                                    '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AlphaTheme.darkGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (_userData['accountNumber'] != null)
                                Text(
                                  'Account: ${_userData['accountNumber']}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Balance and Quick Stats
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AlphaTheme.primaryBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Current Balance',
                            style: TextStyle(
                              fontSize: 14,
                              color: AlphaTheme.darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '\$${_currentBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AlphaTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Account Statistics
                    const Text(
                      'Account Statistics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AlphaTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Transactions',
                            _transactionCount.toString(),
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Spent',
                            '\$${_totalSpent.toStringAsFixed(2)}',
                            Icons.arrow_downward,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Total Received',
                            '\$${_totalReceived.toStringAsFixed(2)}',
                            Icons.arrow_upward,
                            Colors.green,
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // My Accounts Section
            if (_accounts.isNotEmpty) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AlphaTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._accounts.map(_buildAccountCard),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Contact Information
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contact Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AlphaTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Username
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AlphaTheme.darkGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person,
                                color: AlphaTheme.primaryBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _isEditing
                                  ? TextField(
                                      controller: _usernameController,
                                      decoration: InputDecoration(
                                        hintText: 'Enter username',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.all(12),
                                      ),
                                    )
                                  : Text(
                                      _usernameController.text.isNotEmpty
                                          ? _usernameController.text
                                          : 'Not set',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AlphaTheme.primaryBlue,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Phone Number
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phone Number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AlphaTheme.darkGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone,
                                color: AlphaTheme.primaryBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _isEditing
                                  ? TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: 'Enter phone number',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.all(12),
                                      ),
                                    )
                                  : Text(
                                      _phoneController.text.isNotEmpty
                                          ? _phoneController.text
                                          : 'Not set',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AlphaTheme.primaryBlue,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Address
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Address',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AlphaTheme.darkGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on,
                                color: AlphaTheme.primaryBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _isEditing
                                  ? TextField(
                                      controller: _addressController,
                                      maxLines: 2,
                                      decoration: InputDecoration(
                                        hintText: 'Enter address',
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.all(12),
                                      ),
                                    )
                                  : Text(
                                      _addressController.text.isNotEmpty
                                          ? _addressController.text
                                          : 'Not set',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AlphaTheme.primaryBlue,
                                      ),
                                      maxLines: 2,
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Email (read-only)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AlphaTheme.darkGray,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.email,
                                color: AlphaTheme.primaryBlue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _userData['email'] ??
                                    authProvider.userEmail ??
                                    'N/A',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AlphaTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    if (_userData['isVerified'] != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            _userData['isVerified'] == true
                                ? Icons.verified
                                : Icons.pending,
                            color: _userData['isVerified'] == true
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _userData['isVerified'] == true
                                ? 'Verified Account'
                                : 'Account Pending Verification',
                            style: TextStyle(
                              fontSize: 14,
                              color: _userData['isVerified'] == true
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Security Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                          () => _showSecurityOptions = !_showSecurityOptions),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Security Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AlphaTheme.primaryBlue,
                            ),
                          ),
                          Icon(
                            _showSecurityOptions
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                    if (_showSecurityOptions) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.security,
                              color: AlphaTheme.primaryBlue, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Two-Factor Authentication',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Add an extra layer of security',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _twoFactorEnabled,
                            onChanged: (value) => _updateSecuritySetting(
                                'twoFactorEnabled', value),
                            activeThumbColor: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!kIsWeb &&
                          (Platform.isAndroid || Platform.isIOS)) ...[
                        Row(
                          children: [
                            const Icon(Icons.fingerprint,
                                color: AlphaTheme.primaryBlue, size: 24),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Biometric Login',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Use fingerprint or face ID',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AlphaTheme.darkGray,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _biometricEnabled,
                              onChanged: (value) => _updateSecuritySetting(
                                  'biometricEnabled', value),
                              activeThumbColor: AlphaTheme.primaryBlue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      ListTile(
                        leading: const Icon(Icons.lock,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Change Password'),
                        subtitle: const Text('Update your login password'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _changePassword,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.devices,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Active Sessions'),
                        subtitle: const Text('Manage logged-in devices'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showActiveSessions,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.history,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Login History'),
                        subtitle: const Text('View recent login activity'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showLoginHistory,
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        leading: const Icon(Icons.tune,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Transaction Limits'),
                        subtitle: const Text('View and manage spending limits'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showTransactionLimits,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Preferences Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showPreferences = !_showPreferences),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Preferences',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Icon(
                            _showPreferences
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                    if (_showPreferences) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.notifications,
                              color: AlphaTheme.primaryBlue, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Push Notifications',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Receive app notifications',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _notificationsEnabled,
                            onChanged: (value) => _updateNotificationPreference(
                                'pushNotifications', value),
                            activeThumbColor: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.receipt,
                              color: AlphaTheme.primaryBlue, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Transaction Alerts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Get alerts for transactions',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _transactionAlerts,
                            onChanged: (value) => _updateNotificationPreference(
                                'transactionAlerts', value),
                            activeThumbColor: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.security,
                              color: AlphaTheme.primaryBlue, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security Alerts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Security and login alerts',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _securityAlerts,
                            onChanged: (value) => _updateNotificationPreference(
                                'securityAlerts', value),
                            activeThumbColor: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet,
                              color: AlphaTheme.primaryBlue, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Balance Updates',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Daily balance updates',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _balanceUpdates,
                            onChanged: (value) => _updateNotificationPreference(
                                'balanceUpdates', value),
                            activeThumbColor: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.local_offer,
                              color: AlphaTheme.primaryBlue, size: 24),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Promotional Messages',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Marketing and offers',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AlphaTheme.darkGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _promotionalMessages,
                            onChanged: (value) => _updateNotificationPreference(
                                'promotionalMessages', value),
                            activeThumbColor: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Support Section
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _showSupport = !_showSupport),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Support',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AlphaTheme.primaryBlue,
                            ),
                          ),
                          Icon(
                            _showSupport
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                    if (_showSupport) ...[
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.help_outline,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Help & Support'),
                        subtitle: const Text('Get help with your account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showHelpAndSupport,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.privacy_tip_outlined,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Privacy Policy'),
                        subtitle: const Text('Read our privacy policy'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showPrivacyPolicy,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.description_outlined,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Terms of Service'),
                        subtitle: const Text('Read our terms and conditions'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showTermsOfService,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.star_outline,
                            color: AlphaTheme.primaryBlue),
                        title: const Text('Rate the App'),
                        subtitle: const Text('Rate us on the app store'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _rateApp,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Account Actions
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(
                          () => _showAccountActions = !_showAccountActions),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Account Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AlphaTheme.primaryBlue,
                            ),
                          ),
                          Icon(
                            _showAccountActions
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: AlphaTheme.primaryBlue,
                          ),
                        ],
                      ),
                    ),
                    if (_showAccountActions) ...[
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.download, color: Colors.blue),
                        title: const Text('Export Data'),
                        subtitle: const Text('Download your account data'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _exportData,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.delete_outline,
                            color: AlphaTheme.errorRed),
                        title: const Text('Delete Account'),
                        subtitle: const Text('Permanently delete your account'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _deleteAccount,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button
            ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AlphaTheme.errorRed,
                foregroundColor: AlphaTheme.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 40),

            // App Version
            Center(
              child: Text(
                'Alpha Bank v$_appVersion',
                style: TextStyle(
                  fontSize: 14,
                  color: AlphaTheme.darkGray.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'N/A';
      }
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: AlphaTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordDialog extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const ChangePasswordDialog({
    super.key,
    required this.onPasswordChanged,
  });

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final success = await authProvider.changePassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );

    if (success) {
      widget.onPasswordChanged();
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authProvider.errorMessage ?? 'Failed to change password'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrent,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureCurrent ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter current password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter new password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm password';
                  }
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _changePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Change Password'),
        ),
      ],
    );
  }
}
