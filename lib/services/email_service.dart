// lib/services/email_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class EmailService {
  // Replace these with YOUR EmailJS IDs (get from emailjs.com)
  static const String _serviceId = 'service_53bbayn'; // YOUR Service ID
  static const String _templateId = 'template_9js0njh'; // YOUR Template ID
  static const String _publicKey = 's8s7j6yrFVKUaraPc'; // YOUR Public Key

  // Send transaction email directly from Flutter (FREE)
  static Future<bool> sendTransactionEmail({
    required String userEmail,
    required String userName,
    required double amount,
    required String type,
    required String description,
    required String transactionId,
  }) async {
    try {
      debugPrint('📧 Sending email to: $userEmail');

      final response = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost', // Required for web, ignore for mobile
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': userEmail,
            'user_name': userName,
            'amount': amount.abs(),
            'formatted_amount': '\$${amount.abs().toStringAsFixed(2)}',
            'transaction_type': type,
            'is_credit': amount > 0,
            'description': description,
            'transaction_id': transactionId,
            'date': DateTime.now().toLocal().toString(),
            'year': DateTime.now().year,
          }
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Email sent successfully!');
        return true;
      } else {
        debugPrint('❌ Email failed: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Email error: $e');
      return false;
    }
  }
}
