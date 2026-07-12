import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'profile_screen.dart';
import 'security_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import 'statements_screen.dart';
import 'app_settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: const Color(0xFF003366),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Profile Header
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
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Provider.of<AuthProvider>(context).userName ??
                                'Customer',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Provider.of<AuthProvider>(context).userEmail ??
                                'customer@alpha.com',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Premium Member • Joined 2023',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const ProfileScreen(initialTab: 0)),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Account & Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 16),

              // Settings Options Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildMoreOptionCard(
                    icon: Icons.person_rounded,
                    title: 'Profile',
                    subtitle: 'Personal info',
                    color: Colors.blue[700]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ProfileScreen(initialTab: 0)),
                      );
                    },
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.security_rounded,
                    title: 'Security',
                    subtitle: '2FA, PIN, Biometric',
                    color: Colors.green[700]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SecurityScreen()),
                      );
                    },
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.notifications_rounded,
                    title: 'Notifications',
                    subtitle: 'Alerts & preferences',
                    color: Colors.orange[700]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const NotificationsScreen()),
                      );
                    },
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.help_rounded,
                    title: 'Help & Support',
                    subtitle: 'FAQs, contact us',
                    color: Colors.purple[700]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const HelpSupportScreen()),
                      );
                    },
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.document_scanner_rounded,
                    title: 'Statements',
                    subtitle: 'Account statements',
                    color: Colors.teal[700]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const StatementsScreen()),
                      );
                    },
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.settings_rounded,
                    title: 'App Settings',
                    subtitle: 'Theme, language',
                    color: Colors.red[700]!,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AppSettingsScreen()),
                      );
                    },
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.share_rounded,
                    title: 'Refer a Friend',
                    subtitle: 'Earn rewards',
                    color: Colors.amber[700]!,
                    onTap: () => _shareApp(context),
                  ),
                  _buildMoreOptionCard(
                    icon: Icons.star_rounded,
                    title: 'Rate Us',
                    subtitle: 'Rate on App Store',
                    color: Colors.pink[700]!,
                    onTap: () => _rateApp(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Additional Options
              const Text(
                'Additional Options',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF003366),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildAdditionalOption(
                      'Privacy Policy',
                      Icons.privacy_tip_rounded,
                      () => _showPrivacyPolicy(context),
                    ),
                    _buildAdditionalOption(
                      'Terms of Service',
                      Icons.description_rounded,
                      () => _showTermsOfService(context),
                    ),
                    _buildAdditionalOption(
                      'About Alpha Bank',
                      Icons.info_rounded,
                      () => _showAbout(context),
                    ),
                    _buildAdditionalOption(
                      'Contact Us',
                      Icons.phone_rounded,
                      () => _contactUs(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showLogoutConfirmation(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: Colors.red[200]!,
                      width: 1.5,
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Version Info
              Center(
                child: Text(
                  'Alpha Bank v1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoreOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF003366),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdditionalOption(
      String title, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF003366),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _shareApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.share_rounded,
                color: Color(0xFF003366),
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'Share Alpha Bank',
                style: TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Text(
            'Share Alpha Bank with your friends and earn \$10 for each successful referral!',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage(context, 'Share link copied to clipboard!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Share Now'),
            ),
          ],
        );
      },
    );
  }

  void _rateApp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.star_rounded,
                color: Color(0xFF003366),
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'Rate Our App',
                style: TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How would you rate your experience with Alpha Bank?',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                  Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                  Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                  Icon(Icons.star_rounded, color: Colors.amber, size: 32),
                  Icon(Icons.star_outline_rounded,
                      color: Colors.amber, size: 32),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage(context, 'Thank you for your rating!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Submit Rating'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Privacy Policy',
            style: TextStyle(
              color: Color(0xFF003366),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Last updated: January 2024',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Alpha Bank is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our banking services.',
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Key Points:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                _buildPolicyPoint(
                    '• We collect only necessary information for banking services'),
                _buildPolicyPoint(
                    '• Your data is encrypted and securely stored'),
                _buildPolicyPoint(
                    '• We never share your information with third parties without consent'),
                _buildPolicyPoint(
                    '• You have control over your data preferences'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF003366)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPolicyPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[700],
        ),
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Terms of Service',
            style: TextStyle(
              color: Color(0xFF003366),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please read these terms carefully before using Alpha Bank services.',
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 16),
                _buildTOSPoint('1. Account Terms',
                    'You must be at least 18 years old to use our services.'),
                _buildTOSPoint('2. Service Usage',
                    'Use our services only for lawful purposes.'),
                _buildTOSPoint('3. Security',
                    'Keep your login credentials secure and confidential.'),
                _buildTOSPoint('4. Fees',
                    'We may charge fees for certain services as disclosed.'),
                _buildTOSPoint('5. Liability',
                    'We are not liable for unauthorized transactions if security measures are breached.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Agree',
                style: TextStyle(
                    color: Color(0xFF003366), fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTOSPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
            description,
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.account_balance_rounded,
                color: Color(0xFF003366),
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'About Alpha Bank',
                style: TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Alpha Bank is a leading digital banking platform providing secure, innovative, and convenient banking solutions.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Founded: 2020\nCustomers: 1M+\nCountries: 5\nRating: 4.8/5',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFF003366)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _contactUs(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.phone_rounded,
                color: Color(0xFF003366),
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'Contact Us',
                style: TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('24/7 Customer Support'),
              SizedBox(height: 12),
              Text('📞 1-800-ALPHA-BANK'),
              Text('✉️ support@alphabank.com'),
              Text('🏢 123 Alpha Street, Financial District'),
              SizedBox(height: 12),
              Text(
                'Available 24/7 for all your banking needs.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage(context, 'Opening call screen...');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Call Now'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Column(
            children: [
              Icon(
                Icons.logout_rounded,
                color: Color(0xFF003366),
                size: 50,
              ),
              SizedBox(height: 10),
              Text(
                'Log Out',
                style: TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to log out? You will need to log in again to access your account.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                authProvider.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Log Out'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
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
}
