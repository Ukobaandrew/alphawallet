import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String _userId;
  bool _isLoading = true;

  // User preferences from Firestore
  bool _biometricEnabled = false;
  bool _fingerprintEnabled = false;
  bool _faceIdEnabled = false;
  bool _notificationEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  bool _pushNotifications = true;

  // Security settings from Firestore
  bool _requirePinForTransactions = true;
  bool _requirePinForLogin = false;
  bool _autoLockEnabled = true;

  // Login history
  List<Map<String, dynamic>> _loginHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _userId = user.uid;

      // Load user document
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _biometricEnabled = userData['biometricEnabled'] ?? false;
          _fingerprintEnabled = userData['fingerprintEnabled'] ?? false;
          _faceIdEnabled = userData['faceIdEnabled'] ?? false;
          _notificationEnabled = userData['notificationEnabled'] ?? true;
        });
      }

      // Load security settings
      final securityDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (securityDoc.exists) {
        final securityData = securityDoc.data() as Map<String, dynamic>;
        setState(() {
          _requirePinForTransactions =
              securityData['requirePinForTransactions'] ?? true;
          _requirePinForLogin = securityData['requirePinForLogin'] ?? false;
          _autoLockEnabled = securityData['autoLockEnabled'] ?? true;

          // Load login history
          _loginHistory = List<Map<String, dynamic>>.from(
              securityData['loginHistory'] ?? []);
        });
      }

      // Load notification preferences
      final notificationsDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .doc('preferences')
          .get();

      if (notificationsDoc.exists) {
        final notificationsData =
            notificationsDoc.data() as Map<String, dynamic>;
        setState(() {
          _emailNotifications = notificationsData['emailNotifications'] ?? true;
          _smsNotifications = notificationsData['smsNotifications'] ?? false;
          _pushNotifications = notificationsData['pushNotifications'] ?? true;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateUserPreference(String field, bool value) async {
    try {
      await _firestore.collection('users').doc(_userId).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user preference: $e');
      _showErrorMessage('Failed to update preference');
    }
  }

  Future<void> _updateSecuritySetting(String field, bool value) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('security_settings')
          .doc('settings')
          .update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating security setting: $e');
      _showErrorMessage('Failed to update security setting');
    }
  }

  Future<void> _updateNotificationPreference(String field, bool value) async {
    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('notifications')
          .doc('preferences')
          .update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating notification preference: $e');
      _showErrorMessage('Failed to update notification preference');
    }
  }

  Future<void> _changePIN(BuildContext context) async {
    String currentPIN = '';
    String newPIN = '';
    String confirmPIN = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Transaction PIN',
            style: TextStyle(
              color: Color(0xFF003366),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => currentPIN = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New PIN (6 digits)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => newPIN = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => confirmPIN = value,
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
                if (newPIN.length != 6) {
                  _showErrorMessage('PIN must be 6 digits');
                  return;
                }

                if (newPIN != confirmPIN) {
                  _showErrorMessage('PINs do not match');
                  return;
                }

                try {
                  // Update PIN in Firestore
                  await _firestore.collection('users').doc(_userId).update({
                    'pin': newPIN,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  Navigator.pop(context);
                  _showSuccessMessage('PIN changed successfully!');
                } catch (e) {
                  _showErrorMessage('Failed to change PIN');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
              child: const Text('Change PIN'),
            ),
          ],
        );
      },
    );
  }

  String _getSecurityStatus() {
    int enabledCount = 0;
    int totalCount = 6;

    if (_biometricEnabled) enabledCount++;
    if (_requirePinForTransactions) enabledCount++;
    if (_autoLockEnabled) enabledCount++;
    if (_emailNotifications) enabledCount++;
    if (_smsNotifications) enabledCount++;
    if (_pushNotifications) enabledCount++;

    final percentage = enabledCount / totalCount;

    if (percentage >= 0.8) return 'Excellent';
    if (percentage >= 0.6) return 'Good';
    if (percentage >= 0.4) return 'Fair';
    return 'Needs Improvement';
  }

  Color _getSecurityStatusColor() {
    final status = _getSecurityStatus();
    switch (status) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.greenAccent;
      case 'Fair':
        return Colors.orange;
      default:
        return Colors.red;
    }
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
        backgroundColor: Colors.red,
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
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Security'),
          backgroundColor: const Color(0xFF003366),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Header
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
              child: const Row(
                children: [
                  Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Security',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Protect your account with advanced security features',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Security Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getSecurityStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _getSecurityStatusColor()),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: _getSecurityStatusColor(),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Status: ${_getSecurityStatus()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                        ),
                        Text(
                          '${_biometricEnabled ? "Biometric" : "Standard"} security enabled',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Security Features',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),

            // Biometric Authentication
            _buildSecurityOption(
              'Biometric Authentication',
              'Use fingerprint or face ID to log in',
              Icons.fingerprint_rounded,
              Colors.blue,
              _biometricEnabled,
              (value) async {
                setState(() {
                  _biometricEnabled = value!;
                });
                await _updateUserPreference('biometricEnabled', value!);
              },
            ),

            // Two-Factor Authentication (using PIN for transactions)
            _buildSecurityOption(
              'Require PIN for Transactions',
              'Require PIN confirmation for all transactions',
              Icons.security_rounded,
              Colors.green,
              _requirePinForTransactions,
              (value) async {
                setState(() {
                  _requirePinForTransactions = value!;
                });
                await _updateSecuritySetting(
                    'requirePinForTransactions', value!);
              },
            ),

            // Auto Lock
            _buildSecurityOption(
              'Auto Lock',
              'Automatically lock app after inactivity',
              Icons.lock_clock_rounded,
              Colors.orange,
              _autoLockEnabled,
              (value) async {
                setState(() {
                  _autoLockEnabled = value!;
                });
                await _updateSecuritySetting('autoLockEnabled', value!);
              },
            ),

            const Text(
              'Notification Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),

            // Email Notifications
            _buildSecurityOption(
              'Email Alerts',
              'Receive security alerts via email',
              Icons.email_rounded,
              Colors.orange,
              _emailNotifications,
              (value) async {
                setState(() {
                  _emailNotifications = value!;
                });
                await _updateNotificationPreference(
                    'emailNotifications', value!);
              },
            ),

            // SMS Notifications
            _buildSecurityOption(
              'SMS Alerts',
              'Receive security alerts via SMS',
              Icons.sms_rounded,
              Colors.purple,
              _smsNotifications,
              (value) async {
                setState(() {
                  _smsNotifications = value!;
                });
                await _updateNotificationPreference('smsNotifications', value!);
              },
            ),

            // Push Notifications
            _buildSecurityOption(
              'Push Notifications',
              'Receive security notifications on your device',
              Icons.notifications_rounded,
              Colors.red,
              _pushNotifications,
              (value) async {
                setState(() {
                  _pushNotifications = value!;
                });
                await _updateNotificationPreference(
                    'pushNotifications', value!);
              },
            ),
            const SizedBox(height: 30),

            // Change PIN Button
            ElevatedButton(
              onPressed: () => _changePIN(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Change Transaction PIN',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // View Login Activity
            OutlinedButton(
              onPressed: () => _viewLoginActivity(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFF003366)),
              ),
              child: const Text(
                'View Login Activity',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF003366),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Security Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue[100]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Security Tips',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildSecurityTip('• Never share your PIN or password'),
                  _buildSecurityTip('• Log out after each session'),
                  _buildSecurityTip('• Use strong, unique passwords'),
                  _buildSecurityTip('• Update your app regularly'),
                  _buildSecurityTip(
                      '• Enable biometric authentication for extra security'),
                  _buildSecurityTip('• Regularly review your login activity'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityOption(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool value,
    Function(bool?) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF003366),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF003366),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTip(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[700],
        ),
      ),
    );
  }

  void _viewLoginActivity(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LoginActivityScreen(
          loginHistory: _loginHistory,
          firestore: _firestore,
          userId: _userId,
        ),
      ),
    );
  }
}

class LoginActivityScreen extends StatefulWidget {
  final List<Map<String, dynamic>> loginHistory;
  final FirebaseFirestore firestore;
  final String userId;

  const LoginActivityScreen({
    super.key,
    required this.loginHistory,
    required this.firestore,
    required this.userId,
  });

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _loginHistory = [];

  @override
  void initState() {
    super.initState();
    _loadLoginHistory();
  }

  Future<void> _loadLoginHistory() async {
    try {
      // Try to get login history from security settings
      final securityDoc = await widget.firestore
          .collection('users')
          .doc(widget.userId)
          .collection('security_settings')
          .doc('settings')
          .get();

      if (securityDoc.exists) {
        final data = securityDoc.data() as Map<String, dynamic>;
        final history =
            List<Map<String, dynamic>>.from(data['loginHistory'] ?? []);

        setState(() {
          _loginHistory = history;
          _isLoading = false;
        });
      } else {
        // If no login history, show sample data
        _loadSampleLoginHistory();
      }
    } catch (e) {
      print('Error loading login history: $e');
      _loadSampleLoginHistory();
    }
  }

  void _loadSampleLoginHistory() {
    setState(() {
      _loginHistory = [
        {
          'device': 'iPhone 13 Pro',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
          'location': 'New York, USA',
          'ip': '192.168.1.100',
          'status': 'success',
        },
        {
          'device': 'MacBook Pro',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)),
          'location': 'San Francisco, USA',
          'ip': '192.168.1.101',
          'status': 'success',
        },
        {
          'device': 'Android Phone',
          'timestamp': DateTime.now().subtract(const Duration(days: 3)),
          'location': 'London, UK',
          'ip': '192.168.1.102',
          'status': 'success',
        },
        {
          'device': 'Windows PC',
          'timestamp': DateTime.now().subtract(const Duration(days: 7)),
          'location': 'Tokyo, Japan',
          'ip': '192.168.1.103',
          'status': 'success',
        },
      ];
      _isLoading = false;
    });
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat('MMM dd, yyyy • HH:mm').format(dateTime);
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago • ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday • ${DateFormat('HH:mm').format(dateTime)}';
    } else if (difference.inHours > 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Activity'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF003366)),
              ),
            )
          : _loginHistory.isEmpty
              ? Center(
                  child: Text(
                    'No login activity found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _loginHistory.length,
                  itemBuilder: (context, index) {
                    final item = _loginHistory[index];
                    final device =
                        item['device'] as String? ?? 'Unknown Device';
                    final timestamp = item['timestamp'] is Timestamp
                        ? (item['timestamp'] as Timestamp).toDate()
                        : (item['timestamp'] is DateTime
                            ? item['timestamp'] as DateTime
                            : DateTime.now());
                    final location =
                        item['location'] as String? ?? 'Unknown Location';
                    final ip = item['ip'] as String? ?? 'N/A';
                    final status = item['status'] as String? ?? 'unknown';

                    return _buildLoginActivityItem(
                      device,
                      timestamp,
                      location,
                      ip,
                      status,
                      index == 0, // Mark first as current if needed
                    );
                  },
                ),
    );
  }

  Widget _buildLoginActivityItem(
    String device,
    DateTime timestamp,
    String location,
    String ip,
    String status,
    bool isCurrent,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            device.contains('iPhone') || device.contains('Android')
                ? Icons.phone_iphone_rounded
                : device.contains('Mac')
                    ? Icons.laptop_mac_rounded
                    : Icons.computer_rounded,
            color: const Color(0xFF003366),
            size: 28,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      device,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003366),
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  location,
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.router_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'IP: $ip',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == 'success'
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: status == 'success'
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
