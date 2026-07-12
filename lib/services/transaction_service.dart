// lib/services/transaction_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'email_service.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Complete transaction with BOTH in-app notification and email
  Future<Map<String, dynamic>> completeTransaction({
    required double amount,
    required String type,
    required String description,
    String? recipientName,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Please login first');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Create transaction ID
      final transactionId = DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Save transaction to Firestore (FREE)
      final transactionData = {
        'id': transactionId,
        'userId': user.uid,
        'amount': amount,
        'type': type,
        'description': description,
        'recipientName': recipientName,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'emailSent': false, // Will update after sending
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('transactions')
          .doc(transactionId)
          .set(transactionData);

      // 2. Update user balance
      await _updateBalance(user.uid, amount);

      // 3. Create in-app notification
      await _createNotification(
        userId: user.uid,
        transactionId: transactionId,
        amount: amount,
        type: type,
        description: description,
      );

      // 4. Send email if user has email
      bool emailSent = false;
      final userEmail = userData['email'] ?? user.email;

      if (userEmail != null) {
        emailSent = await EmailService.sendTransactionEmail(
          userEmail: userEmail,
          userName: userData['name'] ?? user.displayName ?? 'Customer',
          amount: amount,
          type: type,
          description: description,
          transactionId: transactionId,
        );

        // Update email status
        if (emailSent) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('transactions')
              .doc(transactionId)
              .update({'emailSent': true});
        }
      }

      // Return success data
      return {
        'success': true,
        'transactionId': transactionId,
        'amount': amount,
        'type': type,
        'emailSent': emailSent,
        'message': emailSent
            ? 'Transaction completed and email sent!'
            : 'Transaction completed!',
      };
    } catch (e) {
      debugPrint('Transaction error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Transaction failed. Please try again.',
      };
    }
  }

  Future<void> _updateBalance(String userId, double amount) async {
    final userRef = _firestore.collection('users').doc(userId);

    await userRef.update({
      'balance': FieldValue.increment(amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _createNotification({
    required String userId,
    required String transactionId,
    required double amount,
    required String type,
    required String description,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'id': 'notif_$transactionId',
      'title': 'Transaction Completed',
      'body': description,
      'type': 'transaction',
      'amount': amount,
      'transactionType': type,
      'transactionId': transactionId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'icon': amount > 0 ? '📈' : '📉',
    });
  }
}
