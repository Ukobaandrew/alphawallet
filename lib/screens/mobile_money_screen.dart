import 'package:flutter/material.dart';

class MobileMoneyScreen extends StatelessWidget {
  const MobileMoneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Money Transfer'),
        backgroundColor: const Color(0xFF003366),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Provider',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF003366),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Send money to mobile wallets instantly',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            _buildProviderCard(
              'MTN Mobile Money',
              'Send to MTN numbers',
              Icons.phone_android,
              Colors.yellow[700]!,
              () {
                _showMTNTransferDialog(context);
              },
            ),
            const SizedBox(height: 16),
            _buildProviderCard(
              'Airtel Money',
              'Send to Airtel numbers',
              Icons.phone_iphone,
              Colors.red[700]!,
              () {
                _showAirtelTransferDialog(context);
              },
            ),
            const SizedBox(height: 16),
            _buildProviderCard(
              'Vodafone Cash',
              'Send to Vodafone numbers',
              Icons.phone,
              Colors.purple[700]!,
              () {
                _showVodafoneTransferDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF003366),
            ),
          ),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  void _showMTNTransferDialog(BuildContext context) {
    _showMobileMoneyDialog(context, 'MTN Mobile Money', '+233');
  }

  void _showAirtelTransferDialog(BuildContext context) {
    _showMobileMoneyDialog(context, 'Airtel Money', '+233');
  }

  void _showVodafoneTransferDialog(BuildContext context) {
    _showMobileMoneyDialog(context, 'Vodafone Cash', '+233');
  }

  void _showMobileMoneyDialog(
      BuildContext context, String provider, String countryCode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Transfer to $provider'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: countryCode,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showSuccessMessage(context, '$provider transfer initiated');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003366),
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
