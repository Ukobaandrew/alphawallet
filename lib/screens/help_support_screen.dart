import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'live_chat_screen.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<Map<String, dynamic>> _supportData;
  List<Map<String, dynamic>> _userTickets = [];
  bool _isLoadingTickets = false;
  final TextEditingController _ticketController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'account';
  final _formKey = GlobalKey<FormState>();

  // Professional Alpha Bank Greece contact information
  final Map<String, String> _alphaBankContacts = {
    'emergencyPhone': '+30 210 326 0000',
    'internationalEmergency': '+30 699 430 3966',
    'supportPhone': '+30 210 326 0000',
    'supportEmail': 'support@alphabankplus.com',
    'headquartersAddress': '40 Stadiou Street, 102 52 Athens, Greece',
    'swiftCode': 'CRBAGRAA',
    'ibanFormat': 'GRXX XXXX XXXX XXXX XXXX XXXX XXX',
    'officeHours': 'Mon-Fri: 08:00-18:00, Sat: 09:00-14:00 (EET/EEST)',
    'corporateWebsite': 'https://www.alpha.gr',
    'customerServiceEmail': 'customerservice@alphabankplus.com',
    'fax': '+30 210 326 0100',
    'regulatoryAuthority': 'Hellenic Bank Association',
  };

  // Professional color scheme
  final Color _primaryColor = const Color(0xFF003366); // Navy Blue
  final Color _secondaryColor = const Color(0xFFD4AF37); // Gold
  final Color _accentColor = const Color(0xFF2E8B57); // Sea Green
  final Color _emergencyColor = const Color(0xFFC41E3A); // Deep Red
  final Color _backgroundColor = const Color(0xFFF8F9FA); // Light Gray
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF333333);

  @override
  void initState() {
    super.initState();
    _supportData = _loadSupportData();
    _loadUserTickets();
  }

  Future<Map<String, dynamic>> _loadSupportData() async {
    try {
      final contactsDoc =
          await _firestore.collection('support').doc('contacts').get();
      final faqsDoc = await _firestore.collection('support').doc('faqs').get();

      return {
        'contacts': {
          ...contactsDoc.data() ?? {},
          // Merge with Alpha Bank defaults
          'emergencyPhone': contactsDoc.data()?['emergencyPhone'] ??
              _alphaBankContacts['emergencyPhone']!,
          'internationalEmergency':
              contactsDoc.data()?['internationalEmergency'] ??
                  _alphaBankContacts['internationalEmergency']!,
          'supportPhone': contactsDoc.data()?['supportPhone'] ??
              _alphaBankContacts['supportPhone']!,
          'supportEmail': contactsDoc.data()?['supportEmail'] ??
              _alphaBankContacts['supportEmail']!,
          'headquartersAddress': contactsDoc.data()?['headquartersAddress'] ??
              _alphaBankContacts['headquartersAddress']!,
          'swiftCode': contactsDoc.data()?['swiftCode'] ??
              _alphaBankContacts['swiftCode']!,
          'ibanFormat': contactsDoc.data()?['ibanFormat'] ??
              _alphaBankContacts['ibanFormat']!,
          'officeHours': contactsDoc.data()?['officeHours'] ??
              _alphaBankContacts['officeHours']!,
          'corporateWebsite': contactsDoc.data()?['corporateWebsite'] ??
              _alphaBankContacts['corporateWebsite']!,
          'customerServiceEmail': contactsDoc.data()?['customerServiceEmail'] ??
              _alphaBankContacts['customerServiceEmail']!,
          'fax': contactsDoc.data()?['fax'] ?? _alphaBankContacts['fax']!,
          'regulatoryAuthority': contactsDoc.data()?['regulatoryAuthority'] ??
              _alphaBankContacts['regulatoryAuthority']!,
        },
        'faqs': faqsDoc.data() ?? {},
      };
    } catch (e) {
      print('Error loading support data: $e');
      return {
        'contacts': _alphaBankContacts,
        'faqs': {},
      };
    }
  }

  Future<void> _loadUserTickets() async {
    setState(() {
      _isLoadingTickets = true;
    });

    try {
      final userId = await _getCurrentUserId();

      final ticketsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('support_tickets')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      setState(() {
        _userTickets = ticketsSnapshot.docs.map((doc) => doc.data()).toList();
      });
    } catch (e) {
      print('Error loading tickets: $e');
    } finally {
      setState(() {
        _isLoadingTickets = false;
      });
    }
  }

  Future<String> _getCurrentUserId() async {
    // TODO: Implement based on your authentication system
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final uri =
        Uri.parse('tel:${phoneNumber.replaceAll(RegExp(r'[^\d+]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Unable to initiate phone call');
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email?subject=Alpha Bank Support Inquiry');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Unable to open email client');
    }
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Unable to open website');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showFAQDialog(Map<String, dynamic> faqData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Frequently Asked Questions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if ((faqData['categories'] as List?)?.isNotEmpty ?? false)
                ...(faqData['categories'] as List).map((category) {
                  return ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      category['title'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    leading: Icon(
                      _getIcon(category['icon']),
                      color: _secondaryColor,
                    ),
                    children: [
                      ...(category['questions'] as List).map((question) {
                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 40),
                          title: Text(
                            question['question'],
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              question['answer'],
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            _showQuestionDetail(question);
                          },
                        );
                      }),
                    ],
                  );
                }),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuestionDetail(Map<String, dynamic> question) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question['question'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                question['answer'],
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      _shareQuestion(question);
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _secondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareQuestion(Map<String, dynamic> question) {
    _showSnackBar('Question shared successfully');
  }

  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'account_circle':
        return Icons.account_balance;
      case 'payment':
        return Icons.payment;
      case 'security':
        return Icons.security;
      case 'international':
        return Icons.language;
      case 'transactions':
        return Icons.swap_horiz;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _submitSupportTicket() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final userId = await _getCurrentUserId();

      final ticketData = {
        'subject': _ticketController.text,
        'description': _descriptionController.text,
        'category': _selectedCategory,
        'status': 'open',
        'priority': 'medium',
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'ticketId': 'TICKET-${DateTime.now().millisecondsSinceEpoch}',
        'reference': 'REF-${DateTime.now().millisecondsSinceEpoch}',
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('support_tickets')
          .add(ticketData);

      _formKey.currentState!.reset();
      await _loadUserTickets();

      _showSnackBar(
          'Support ticket submitted. Reference: ${ticketData['reference']}');
    } catch (e) {
      _showSnackBar('Error submitting ticket. Please try again.');
    }
  }

  Widget _buildContactCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    bool isEmergency = false,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isEmergency
              ? _emergencyColor.withOpacity(0.2)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isEmergency ? _emergencyColor.withOpacity(0.05) : _cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isEmergency
                      ? _emergencyColor.withOpacity(0.1)
                      : _primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isEmergency
                      ? _emergencyColor
                      : (iconColor ?? _primaryColor),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isEmergency ? _emergencyColor : _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: isEmergency ? _emergencyColor : Colors.grey.shade400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTickets() {
    if (_isLoadingTickets) {
      return Center(
        child: CircularProgressIndicator(
          color: _primaryColor,
        ),
      );
    }

    if (_userTickets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Support Tickets',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your submitted support tickets will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Recent Support Tickets',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
        ),
        Column(
          children: _userTickets.map((ticket) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(ticket['status']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      _getStatusIcon(ticket['status']),
                      color: _getStatusColor(ticket['status']),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ticket['subject'] ?? 'No Subject',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ticket['ticketId'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ticket['status'])
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getStatusColor(ticket['status'])
                                .withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          (ticket['status'] ?? 'unknown').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(ticket['status']),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(ticket['createdAt']),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'open':
        return Icons.hourglass_empty;
      case 'in_progress':
        return Icons.update;
      case 'resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'open':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return _accentColor;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return DateFormat('MMM dd, yyyy').format(date);
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  void _openLiveChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LiveChatScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Help & Support',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _supportData = _loadSupportData();
                _loadUserTickets();
              });
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _supportData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load support data',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _supportData = _loadSupportData();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Try Again',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }

          final contacts = snapshot.data?['contacts'] ?? _alphaBankContacts;
          final faqs = snapshot.data?['faqs'] ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bank Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.account_balance,
                          size: 32,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Alpha Bank ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer Support Center',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Divider(color: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Text(
                        'Greece • Established 1879',
                        style: TextStyle(
                          fontSize: 12,
                          color: _secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Emergency Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _emergencyColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _emergencyColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _emergencyColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.warning_amber,
                              size: 20,
                              color: _emergencyColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '24/7 Emergency Support',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _emergencyColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'For immediate assistance with:',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            label: const Text('Lost/Stolen Cards'),
                            backgroundColor: _emergencyColor.withOpacity(0.1),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _emergencyColor,
                            ),
                            side: BorderSide.none,
                          ),
                          Chip(
                            label: const Text('Suspected Fraud'),
                            backgroundColor: _emergencyColor.withOpacity(0.1),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _emergencyColor,
                            ),
                            side: BorderSide.none,
                          ),
                          Chip(
                            label: const Text('Account Security'),
                            backgroundColor: _emergencyColor.withOpacity(0.1),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              color: _emergencyColor,
                            ),
                            side: BorderSide.none,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Local Emergency',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contacts['emergencyPhone'] ??
                                    '+30 210 326 0000',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _emergencyColor,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'International',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contacts['internationalEmergency'] ??
                                    '+30 699 430 3966',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _emergencyColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Contact Options
                Text(
                  'Contact Channels',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 12),

                _buildContactCard(
                  title: 'Phone Support',
                  subtitle: contacts['supportPhone'] ?? '+30 210 326 0000',
                  icon: Icons.phone,
                  onTap: () =>
                      _launchPhone(contacts['supportPhone'] ?? '+302103260000'),
                ),

                const SizedBox(height: 8),

                _buildContactCard(
                  title: 'Email Support',
                  subtitle:
                      contacts['supportEmail'] ?? 'support@alphabankplus.com',
                  icon: Icons.email,
                  onTap: () => _launchEmail(
                      contacts['supportEmail'] ?? 'support@alphabankplus.com'),
                  iconColor: _accentColor,
                ),

                const SizedBox(height: 8),

                _buildContactCard(
                  title: 'Secure Live Chat',
                  subtitle: 'Available 24/7 with banking specialist',
                  icon: Icons.chat,
                  onTap: _openLiveChat,
                ),

                const SizedBox(height: 24),

                // FAQ Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Find answers to common banking questions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _showFAQDialog(faqs),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, size: 18),
                            SizedBox(width: 8),
                            Text('Browse Knowledge Base'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Support Ticket
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Submit Support Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ticketController,
                          decoration: InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: Icon(Icons.subject,
                                color: Colors.grey.shade500),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a subject';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            prefixIcon: Icon(Icons.category,
                                color: Colors.grey.shade500),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'account',
                              child: Text('Account Management'),
                            ),
                            DropdownMenuItem(
                              value: 'transactions',
                              child: Text('Transactions'),
                            ),
                            DropdownMenuItem(
                              value: 'cards',
                              child: Text('Cards & Payments'),
                            ),
                            DropdownMenuItem(
                              value: 'security',
                              child: Text('Security'),
                            ),
                            DropdownMenuItem(
                              value: 'international',
                              child: Text('International Banking'),
                            ),
                            DropdownMenuItem(
                              value: 'other',
                              child: Text('Other Inquiries'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value ?? 'account';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: InputDecoration(
                            labelText: 'Detailed Description',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 4,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please describe your issue';
                            }
                            if (value.length < 20) {
                              return 'Please provide more details (minimum 20 characters)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitSupportTicket,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _secondaryColor,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Submit Request',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Recent Tickets
                _buildRecentTickets(),

                const SizedBox(height: 24),

                // Bank Information
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alpha Bank Greece',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              contacts['headquartersAddress'] ??
                                  '40 Stadiou Street, 102 52 Athens, Greece',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              contacts['officeHours'] ??
                                  'Mon-Fri: 08:00-18:00, Sat: 09:00-14:00 (EET/EEST)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.language,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              contacts['corporateWebsite'] ??
                                  'https://www.alpha.gr',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.security,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              contacts['regulatoryAuthority'] ??
                                  'Hellenic Bank Association',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // International Note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _primaryColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: _primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All times are in Eastern European Time (EET/EEST). '
                          'For international calls: dial your country exit code +30 (Greece) + the number.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _ticketController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
