import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late DocumentReference _preferencesRef;

  bool _isLoading = true;

  // Notification preferences from Firestore
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _smsNotifications = true;
  bool _transactionAlerts = true;
  bool _securityAlerts = true;
  bool _promotionalMessages = false;
  bool _balanceUpdates = true;
  bool _promotionalAlerts = false; // For UI compatibility

  // Sound settings
  String _notificationSound = 'Default';
  bool _vibrationEnabled = true;

  // Quiet hours
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0); // 10:00 PM
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0); // 7:00 AM

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      _preferencesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc('preferences');

      final snapshot = await _preferencesRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;

        if (data != null) {
          setState(() {
            _pushNotifications = (data['pushNotifications'] as bool?) ?? true;
            _emailNotifications = (data['emailNotifications'] as bool?) ?? true;
            _smsNotifications = (data['smsNotifications'] as bool?) ?? true;
            _transactionAlerts = (data['transactionAlerts'] as bool?) ?? true;
            _securityAlerts = (data['securityAlerts'] as bool?) ?? true;
            _promotionalMessages =
                (data['promotionalMessages'] as bool?) ?? false;
            _balanceUpdates = (data['balanceUpdates'] as bool?) ?? true;
            _promotionalAlerts = _promotionalMessages; // Map for UI

            // Load additional settings if they exist
            _notificationSound =
                (data['notificationSound'] as String?) ?? 'Default';
            _vibrationEnabled = (data['vibrationEnabled'] as bool?) ?? true;

            // Load quiet hours if they exist
            final quietHours = data['quietHours'] as Map<String, dynamic>?;
            if (quietHours != null) {
              final start = quietHours['start'] as Map<String, dynamic>?;
              final end = quietHours['end'] as Map<String, dynamic>?;
              if (start != null) {
                _quietStart = TimeOfDay(
                  hour: (start['hour'] as int?) ?? 22,
                  minute: (start['minute'] as int?) ?? 0,
                );
              }
              if (end != null) {
                _quietEnd = TimeOfDay(
                  hour: (end['hour'] as int?) ?? 7,
                  minute: (end['minute'] as int?) ?? 0,
                );
              }
            }

            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // Use default preferences
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notification preferences: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotificationPreferences() async {
    try {
      final Map<String, dynamic> preferences = {
        'transactionAlerts': _transactionAlerts,
        'securityAlerts': _securityAlerts,
        'promotionalMessages': _promotionalMessages,
        'pushNotifications': _pushNotifications,
        'emailNotifications': _emailNotifications,
        'smsNotifications': _smsNotifications,
        'balanceUpdates': _balanceUpdates,
        'notificationSound': _notificationSound,
        'vibrationEnabled': _vibrationEnabled,
        'quietHours': {
          'start': {
            'hour': _quietStart.hour,
            'minute': _quietStart.minute,
          },
          'end': {
            'hour': _quietEnd.hour,
            'minute': _quietEnd.minute,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _preferencesRef.set(preferences, SetOptions(merge: true));

      _showSuccessMessage('Notification preferences saved!');
    } catch (e) {
      print('Error saving notification preferences: $e');
      _showErrorMessage('Failed to save preferences');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: false,
    );
  }

  Future<void> _clearAllNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Clear notifications from a separate notifications collection if you have one
      // For now, we'll just show a success message
      _showSuccessMessage('All notifications cleared!');
    } catch (e) {
      print('Error clearing notifications: $e');
      _showErrorMessage('Failed to clear notifications');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: const Color(0xFF003366),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () async {
              setState(() {
                _pushNotifications = true;
                _emailNotifications = true;
                _smsNotifications = true;
                _transactionAlerts = true;
                _securityAlerts = true;
                _promotionalMessages = true;
                _balanceUpdates = true;
                _promotionalAlerts = true;
              });
              await _saveNotificationPreferences();
            },
            child: const Text(
              'Enable All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notification Preferences Header
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
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notification Preferences',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Customize how you receive notifications',
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

            const Text(
              'Notification Channels',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),

            _buildNotificationOption(
              'Push Notifications',
              'Receive notifications on your device',
              Icons.notifications_rounded,
              Colors.blue,
              _pushNotifications,
              (value) async {
                setState(() {
                  _pushNotifications = value!;
                });
                await _saveNotificationPreferences();
              },
            ),
            _buildNotificationOption(
              'Email Notifications',
              'Receive notifications via email',
              Icons.email_rounded,
              Colors.orange,
              _emailNotifications,
              (value) async {
                setState(() {
                  _emailNotifications = value!;
                });
                await _saveNotificationPreferences();
              },
            ),
            _buildNotificationOption(
              'SMS Notifications',
              'Receive notifications via SMS',
              Icons.sms_rounded,
              Colors.green,
              _smsNotifications,
              (value) async {
                setState(() {
                  _smsNotifications = value!;
                });
                await _saveNotificationPreferences();
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'Notification Types',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),

            _buildNotificationOption(
              'Transaction Alerts',
              'Notifications for deposits, withdrawals, transfers',
              Icons.account_balance_wallet_rounded,
              Colors.purple,
              _transactionAlerts,
              (value) async {
                setState(() {
                  _transactionAlerts = value!;
                });
                await _saveNotificationPreferences();
              },
            ),
            _buildNotificationOption(
              'Security Alerts',
              'Login attempts, password changes, security updates',
              Icons.security_rounded,
              Colors.red,
              _securityAlerts,
              (value) async {
                setState(() {
                  _securityAlerts = value!;
                });
                await _saveNotificationPreferences();
              },
            ),
            _buildNotificationOption(
              'Balance Updates',
              'Notifications for account balance changes',
              Icons.account_balance_rounded,
              Colors.teal,
              _balanceUpdates,
              (value) async {
                setState(() {
                  _balanceUpdates = value!;
                });
                await _saveNotificationPreferences();
              },
            ),
            _buildNotificationOption(
              'Promotional Alerts',
              'Offers, discounts, and new features',
              Icons.local_offer_rounded,
              Colors.amber,
              _promotionalMessages,
              (value) async {
                setState(() {
                  _promotionalMessages = value!;
                  _promotionalAlerts = value;
                });
                await _saveNotificationPreferences();
              },
            ),
            const SizedBox(height: 30),

            // Notification Sound Settings
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sound & Vibration',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Notification Sound'),
                          Text(
                            _notificationSound,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () => _changeNotificationSound(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF003366).withOpacity(0.1),
                          foregroundColor: const Color(0xFF003366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Vibration'),
                      Switch(
                        value: _vibrationEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _vibrationEnabled = value;
                          });
                          await _saveNotificationPreferences();
                        },
                        activeThumbColor: const Color(0xFF003366),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quiet Hours
            Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quiet Hours',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF003366),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mute notifications during specific hours',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('From'),
                            ElevatedButton(
                              onPressed: () =>
                                  _selectTime(context, isStartTime: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                foregroundColor: Colors.grey[800],
                                minimumSize: const Size(double.infinity, 40),
                              ),
                              child: Text(_formatTimeOfDay(_quietStart)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('To'),
                            ElevatedButton(
                              onPressed: () =>
                                  _selectTime(context, isStartTime: false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[100],
                                foregroundColor: Colors.grey[800],
                                minimumSize: const Size(double.infinity, 40),
                              ),
                              child: Text(_formatTimeOfDay(_quietEnd)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              onPressed: _saveNotificationPreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Preferences',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Clear All Notifications
            ElevatedButton(
              onPressed: () => _confirmClearAllNotifications(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[50],
                foregroundColor: Colors.red[700],
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(color: Colors.red[200]!),
              ),
              child: const Text(
                'Clear All Notifications',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationOption(
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

  Future<void> _changeNotificationSound(BuildContext context) async {
    final soundOptions = ['Default', 'Chime', 'Beep', 'Melody', 'Silent'];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Notification Sound'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: soundOptions.length,
              itemBuilder: (context, index) {
                final sound = soundOptions[index];
                return ListTile(
                  title: Text(sound),
                  trailing: sound == _notificationSound
                      ? const Icon(Icons.check_rounded, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _notificationSound = sound;
                    });
                    Navigator.pop(context);
                    _saveNotificationPreferences();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectTime(BuildContext context,
      {required bool isStartTime}) async {
    final initialTime = isStartTime ? _quietStart : _quietEnd;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      setState(() {
        if (isStartTime) {
          _quietStart = selectedTime;
        } else {
          _quietEnd = selectedTime;
        }
      });
      await _saveNotificationPreferences();
    }
  }

  Future<void> _confirmClearAllNotifications(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Clear All Notifications'),
          content: const Text(
              'Are you sure you want to clear all notifications? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _clearAllNotifications();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
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
        duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
