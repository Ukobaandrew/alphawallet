import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/auth_provider.dart';

// Notification Data Model
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String
      type; // 'transaction', 'deposit', 'withdrawal', 'transfer', 'system'
  final Map<String, dynamic>?
      data; // Additional data like transactionId, amount, etc.
  final DateTime timestamp;
  final bool isRead;
  final String priority; // 'high', 'medium', 'low'

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    this.data,
    required this.timestamp,
    this.isRead = false,
    this.priority = 'medium',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      'data': data,
      'timestamp': timestamp,
      'isRead': isRead,
      'priority': priority,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      type: map['type'] ?? 'system',
      data: map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      priority: map['priority'] ?? 'medium',
    );
  }
}

// Transaction Data Model
class Transaction {
  final String id;
  final String userId;
  final String recipientName;
  final String recipientAccount;
  final String bankName;
  final double amount;
  final double fee;
  final String description;
  final DateTime timestamp;
  final String status;
  final String transactionType;
  final String? reference;
  final String? recipientUserId;
  final String currency;
  final String? senderName;
  final String? senderAccount;
  final String? transactionCategory;

  Transaction({
    required this.id,
    required this.userId,
    required this.recipientName,
    required this.recipientAccount,
    required this.bankName,
    required this.amount,
    required this.fee,
    required this.description,
    required this.timestamp,
    required this.status,
    required this.transactionType,
    this.reference,
    this.recipientUserId,
    this.currency = 'USD',
    this.senderName,
    this.senderAccount,
    this.transactionCategory = 'transfer',
  });

  double get totalAmount => amount + fee;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'recipientName': recipientName,
      'recipientAccount': recipientAccount,
      'bankName': bankName,
      'amount': amount,
      'fee': fee,
      'description': description,
      'timestamp': timestamp,
      'status': status,
      'transactionType': transactionType,
      'reference': reference,
      'recipientUserId': recipientUserId,
      'currency': currency,
      'senderName': senderName,
      'senderAccount': senderAccount,
      'transactionCategory': transactionCategory,
    };
  }

  Map<String, dynamic> toEmailData(String userEmail) {
    return {
      'user_email': userEmail,
      'transaction_id': id,
      'amount': totalAmount.toStringAsFixed(2),
      'recipient_name': recipientName,
      'transaction_type': transactionType,
      'fee': fee.toStringAsFixed(2),
      'description': description,
      'date': timestamp.toIso8601String(),
      'status': status,
      'bank_name': bankName,
      'recipient_account': recipientAccount,
      'reference': reference ?? 'N/A',
      'currency': currency,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      recipientName: map['recipientName'] ?? '',
      recipientAccount: map['recipientAccount'] ?? '',
      bankName: map['bankName'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      fee: (map['fee'] ?? 0.0).toDouble(),
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] ?? 'Pending',
      transactionType: map['transactionType'] ?? '',
      reference: map['reference'],
      recipientUserId: map['recipientUserId'],
      currency: map['currency'] ?? 'USD',
      senderName: map['senderName'],
      senderAccount: map['senderAccount'],
      transactionCategory: map['transactionCategory'] ?? 'transfer',
    );
  }
}

// Notification Service
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createNotification(AppNotification notification) async {
    try {
      await _firestore
          .collection('users')
          .doc(notification.userId)
          .collection('notifications')
          .doc(notification.id)
          .set(notification.toMap());

      debugPrint('📱 Notification created for user: ${notification.userId}');
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
    }
  }

  Future<void> createSenderTransactionNotification({
    required String userId,
    required Transaction transaction,
    required double newBalance,
  }) async {
    final notification = AppNotification(
      id: '${transaction.id}_sender_notif',
      userId: userId,
      title: 'Transfer Successful',
      message:
          'You transferred \$${transaction.amount.toStringAsFixed(2)} to ${transaction.recipientName}',
      type: 'transaction',
      data: {
        'transactionId': transaction.id,
        'amount': transaction.amount,
        'fee': transaction.fee,
        'total': transaction.totalAmount,
        'recipientName': transaction.recipientName,
        'recipientAccount': transaction.recipientAccount,
        'transactionType': transaction.transactionType,
        'status': transaction.status,
        'newBalance': newBalance,
        'timestamp': transaction.timestamp.toIso8601String(),
        'reference': transaction.reference,
      },
      timestamp: DateTime.now(),
      isRead: false,
      priority: 'high',
    );

    await createNotification(notification);
  }

  Future<void> createRecipientTransactionNotification({
    required String userId,
    required Transaction transaction,
    required double newBalance,
  }) async {
    final notification = AppNotification(
      id: '${transaction.id}_recipient_notif',
      userId: userId,
      title: 'Money Received',
      message:
          'You received \$${transaction.amount.toStringAsFixed(2)} from ${transaction.senderName ?? "Sender"}',
      type: 'transaction',
      data: {
        'transactionId': transaction.id,
        'amount': transaction.amount,
        'senderName': transaction.senderName,
        'senderAccount': transaction.senderAccount,
        'transactionType': 'Incoming Transfer',
        'status': transaction.status,
        'newBalance': newBalance,
        'timestamp': transaction.timestamp.toIso8601String(),
        'reference': transaction.reference,
      },
      timestamp: DateTime.now(),
      isRead: false,
      priority: 'high',
    );

    await createNotification(notification);
  }

  Future<void> createDepositNotification({
    required String userId,
    required double amount,
    required String method,
    required String status,
    required double newBalance,
    String transactionId = '',
  }) async {
    final notification = AppNotification(
      id: 'deposit_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: status == 'completed' ? 'Deposit Successful' : 'Deposit Pending',
      message: status == 'completed'
          ? 'Your deposit of \$${amount.toStringAsFixed(2)} via $method has been completed'
          : 'Your deposit of \$${amount.toStringAsFixed(2)} is pending approval',
      type: 'deposit',
      data: {
        'transactionId': transactionId,
        'amount': amount,
        'method': method,
        'status': status,
        'newBalance': newBalance,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      isRead: false,
      priority: status == 'completed' ? 'high' : 'medium',
    );

    await createNotification(notification);
  }

  Future<void> createWithdrawalNotification({
    required String userId,
    required double amount,
    required String method,
    required String status,
    required double newBalance,
    String transactionId = '',
  }) async {
    final notification = AppNotification(
      id: 'withdrawal_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: status == 'completed'
          ? 'Withdrawal Successful'
          : 'Withdrawal Processing',
      message: status == 'completed'
          ? 'Your withdrawal of \$${amount.toStringAsFixed(2)} via $method has been completed'
          : 'Your withdrawal of \$${amount.toStringAsFixed(2)} is being processed',
      type: 'withdrawal',
      data: {
        'transactionId': transactionId,
        'amount': amount,
        'method': method,
        'status': status,
        'newBalance': newBalance,
        'timestamp': DateTime.now().toIso8601String(),
      },
      timestamp: DateTime.now(),
      isRead: false,
      priority: 'high',
    );

    await createNotification(notification);
  }

  Future<void> createSystemNotification({
    required String userId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
    String priority = 'medium',
  }) async {
    final notification = AppNotification(
      id: 'system_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      title: title,
      message: message,
      type: 'system',
      data: data,
      timestamp: DateTime.now(),
      isRead: false,
      priority: priority,
    );

    await createNotification(notification);
  }

  Stream<List<AppNotification>> getUserNotifications(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromMap(doc.data()))
            .toList());
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
    }
  }

  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

// Transaction Service with Notification Integration
class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  static const String phpServiceUrl =
      'https://dighostassettech.com.ng/send_receipt.php';

  Future<String?> findUserByAccountNumber(String accountNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('accountNumber', isEqualTo: accountNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error finding user by account number: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error getting user data: $e');
      return null;
    }
  }

  Future<void> updateUserBalance(String userId, double amountChange) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'balance': FieldValue.increment(amountChange),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('💰 Updated balance for user $userId by $amountChange');
    } catch (e) {
      debugPrint('❌ Error updating user balance: $e');
      rethrow;
    }
  }

  Future<void> createRecipientTransaction(Transaction senderTransaction) async {
    try {
      if (senderTransaction.recipientUserId == null) {
        debugPrint('⚠️ No recipient user ID, skipping recipient transaction');
        return;
      }

      final senderData = await getUserData(senderTransaction.userId);
      final senderName = senderData?['name'] ??
          senderData?['email']?.split('@').first ??
          'User';
      final senderAccount = senderData?['accountNumber'] ?? 'N/A';

      final recipientTransaction = Transaction(
        id: '${senderTransaction.id}_RECIPIENT',
        userId: senderTransaction.recipientUserId!,
        recipientName: senderName,
        recipientAccount: senderAccount,
        bankName: senderTransaction.bankName,
        amount: senderTransaction.amount,
        fee: 0.0,
        description: 'Received from $senderName',
        timestamp: DateTime.now(),
        status: 'Completed',
        transactionType: 'Incoming Transfer',
        reference: senderTransaction.reference,
        recipientUserId: senderTransaction.userId,
        senderName: senderName,
        senderAccount: senderAccount,
        transactionCategory: 'transfer_received',
      );

      await _firestore
          .collection('users')
          .doc(senderTransaction.recipientUserId!)
          .collection('transactions')
          .doc(recipientTransaction.id)
          .set(recipientTransaction.toMap());

      final recipientData =
          await getUserData(senderTransaction.recipientUserId!);
      final recipientNewBalance =
          (recipientData?['balance'] ?? 0.0).toDouble() +
              senderTransaction.amount;

      await _notificationService.createRecipientTransactionNotification(
        userId: senderTransaction.recipientUserId!,
        transaction: recipientTransaction,
        newBalance: recipientNewBalance,
      );

      debugPrint(
          '✅ Created recipient transaction for ${senderTransaction.recipientUserId}');
    } catch (e) {
      debugPrint('❌ Error creating recipient transaction: $e');
    }
  }

  Future<void> saveTransaction(Transaction transaction) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(transaction.userId);
      final transactionRef = _firestore
          .collection('users')
          .doc(transaction.userId)
          .collection('transactions')
          .doc(transaction.id);

      String? recipientUserId;
      if (transaction.transactionType == 'Alpha Users' ||
          transaction.transactionType == 'Bank Transfer') {
        recipientUserId =
            await findUserByAccountNumber(transaction.recipientAccount);
        transaction = Transaction(
          id: transaction.id,
          userId: transaction.userId,
          recipientName: transaction.recipientName,
          recipientAccount: transaction.recipientAccount,
          bankName: transaction.bankName,
          amount: transaction.amount,
          fee: transaction.fee,
          description: transaction.description,
          timestamp: transaction.timestamp,
          status: 'Completed',
          transactionType: transaction.transactionType,
          reference: transaction.reference,
          recipientUserId: recipientUserId,
          currency: transaction.currency,
          senderName: await getCurrentUserName(transaction.userId),
          senderAccount: await getCurrentUserAccountNumber(transaction.userId),
          transactionCategory: 'transfer_sent',
        );
      }

      batch.set(transactionRef, transaction.toMap());

      batch.update(userRef, {
        'balance': FieldValue.increment(-transaction.totalAmount),
        'lastTransaction': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      final senderData = await getUserData(transaction.userId);
      final senderNewBalance =
          (senderData?['balance'] ?? 0.0).toDouble() - transaction.totalAmount;

      await _notificationService.createSenderTransactionNotification(
        userId: transaction.userId,
        transaction: transaction,
        newBalance: senderNewBalance,
      );

      if (recipientUserId != null) {
        await updateUserBalance(recipientUserId, transaction.amount);
        await createRecipientTransaction(transaction);
      }

      debugPrint('✅ Transaction saved successfully with notifications');
    } catch (e) {
      debugPrint('❌ Error saving transaction: $e');
      rethrow;
    }
  }

  Future<void> saveDepositTransaction({
    required String userId,
    required double amount,
    required String method,
    required String description,
    double fee = 0.0,
    String status = 'pending',
    String? reference,
  }) async {
    try {
      final transactionId = 'DEP${DateTime.now().millisecondsSinceEpoch}';
      final transaction = Transaction(
        id: transactionId,
        userId: userId,
        recipientName: 'Self',
        recipientAccount: await getCurrentUserAccountNumber(userId),
        bankName: 'Alpha Bank',
        amount: amount,
        fee: fee,
        description: description,
        timestamp: DateTime.now(),
        status: status,
        transactionType: 'Deposit',
        reference: reference,
        currency: 'USD',
        transactionCategory: 'deposit',
      );

      final transactionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId);

      await transactionRef.set(transaction.toMap());

      if (status == 'completed') {
        await updateUserBalance(userId, amount - fee);

        final userData = await getUserData(userId);
        final newBalance = (userData?['balance'] ?? 0.0).toDouble();

        await _notificationService.createDepositNotification(
          userId: userId,
          amount: amount,
          method: method,
          status: status,
          newBalance: newBalance,
          transactionId: transactionId,
        );
      } else if (status == 'pending') {
        await _notificationService.createDepositNotification(
          userId: userId,
          amount: amount,
          method: method,
          status: status,
          newBalance: 0.0,
          transactionId: transactionId,
        );
      }

      debugPrint('✅ Deposit transaction saved: $transactionId');
    } catch (e) {
      debugPrint('❌ Error saving deposit transaction: $e');
      rethrow;
    }
  }

  Future<void> saveWithdrawalTransaction({
    required String userId,
    required double amount,
    required String method,
    required String description,
    double fee = 0.0,
    String status = 'pending',
    String? reference,
  }) async {
    try {
      final transactionId = 'WDL${DateTime.now().millisecondsSinceEpoch}';
      final transaction = Transaction(
        id: transactionId,
        userId: userId,
        recipientName: 'Self',
        recipientAccount: await getCurrentUserAccountNumber(userId),
        bankName: 'Alpha Bank',
        amount: amount,
        fee: fee,
        description: description,
        timestamp: DateTime.now(),
        status: status,
        transactionType: 'Withdrawal',
        reference: reference,
        currency: 'USD',
        transactionCategory: 'withdrawal',
      );

      final transactionRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .doc(transactionId);

      await transactionRef.set(transaction.toMap());

      if (status == 'completed') {
        await updateUserBalance(userId, -(amount + fee));

        final userData = await getUserData(userId);
        final newBalance = (userData?['balance'] ?? 0.0).toDouble();

        await _notificationService.createWithdrawalNotification(
          userId: userId,
          amount: amount,
          method: method,
          status: status,
          newBalance: newBalance,
          transactionId: transactionId,
        );
      } else if (status == 'processing') {
        await _notificationService.createWithdrawalNotification(
          userId: userId,
          amount: amount,
          method: method,
          status: status,
          newBalance: 0.0,
          transactionId: transactionId,
        );
      }

      debugPrint('✅ Withdrawal transaction saved: $transactionId');
    } catch (e) {
      debugPrint('❌ Error saving withdrawal transaction: $e');
      rethrow;
    }
  }

  Future<String> getCurrentUserName(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['name'] ?? data?['email']?.split('@').first ?? 'User';
    } catch (e) {
      debugPrint('❌ Error getting user name: $e');
      return 'User';
    }
  }

  Future<String> getCurrentUserAccountNumber(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['accountNumber'] ?? 'N/A';
    } catch (e) {
      debugPrint('❌ Error getting user account number: $e');
      return 'N/A';
    }
  }

  Future<List<Transaction>> getUserTransactions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('transactions')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Transaction.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching transactions: $e');
      return [];
    }
  }

  Future<double> getUserBalance(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return (data?['balance'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('❌ Error fetching balance: $e');
      return 0.0;
    }
  }

  Future<String?> getUserPin(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['pin'] as String?;
    } catch (e) {
      debugPrint('❌ Error fetching PIN: $e');
      return null;
    }
  }

  Future<bool> validateUserPin(String userId, String enteredPin) async {
    try {
      final storedPin = await getUserPin(userId);
      return storedPin == enteredPin;
    } catch (e) {
      debugPrint('❌ Error validating PIN: $e');
      return false;
    }
  }

  Future<void> sendReceiptEmail(Transaction transaction) async {
    try {
      final user = _auth.currentUser;
      if (user?.email == null) {
        debugPrint('⚠️ User email not available for receipt');
        return;
      }

      final emailData = transaction.toEmailData(user!.email!);
      final response = await http.post(
        Uri.parse(phpServiceUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(emailData),
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200 && result['success']) {
        debugPrint('📧 Receipt email sent successfully');
      } else {
        debugPrint('❌ Failed to send receipt email: ${result['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error sending receipt email: $e');
    }
  }
}

// PinAuthenticationScreen
class PinAuthenticationScreen extends StatefulWidget {
  final Transaction transaction;

  const PinAuthenticationScreen({super.key, required this.transaction});

  @override
  State<PinAuthenticationScreen> createState() =>
      _PinAuthenticationScreenState();
}

class _PinAuthenticationScreenState extends State<PinAuthenticationScreen> {
  String enteredPin = '';
  bool _isLoading = false;
  bool _isFetchingPin = false;
  bool _showError = false;
  int _attemptsRemaining = 3;
  String? _storedPin;
  final TransactionService _transactionService = TransactionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _recipientUserId;

  @override
  void initState() {
    super.initState();
    _fetchUserPin();
    _checkRecipient();
  }

  Future<void> _fetchUserPin() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isFetchingPin = true;
    });

    try {
      final pin = await _transactionService.getUserPin(user.uid);
      setState(() {
        _storedPin = pin;
        _isFetchingPin = false;
      });

      if (_storedPin == null) {
        _showErrorDialog('PIN not set. Please contact support.');
      }
    } catch (e) {
      setState(() {
        _isFetchingPin = false;
      });
      _showErrorDialog('Error fetching PIN: $e');
    }
  }

  Future<void> _checkRecipient() async {
    try {
      if (widget.transaction.transactionType == 'Alpha Users' ||
          widget.transaction.transactionType == 'Bank Transfer') {
        _recipientUserId = await _transactionService
            .findUserByAccountNumber(widget.transaction.recipientAccount);
        if (_recipientUserId != null) {
          debugPrint('Recipient is an Alpha Bank user: $_recipientUserId');
        } else {
          debugPrint('Recipient is not an Alpha Bank user');
        }
      }
    } catch (e) {
      debugPrint('Error checking recipient: $e');
    }
  }

  void _onNumberPressed(String number) {
    if (enteredPin.length < 4 && _storedPin != null) {
      setState(() {
        enteredPin += number;
        _showError = false;
      });

      if (enteredPin.length == 4) {
        _validatePin();
      }
    }
  }

  void _onDeletePressed() {
    if (enteredPin.isNotEmpty) {
      setState(() {
        enteredPin = enteredPin.substring(0, enteredPin.length - 1);
        _showError = false;
      });
    }
  }

  Future<void> _validatePin() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('User not authenticated');
      return;
    }

    if (_storedPin == null) {
      _showErrorDialog('PIN not available. Please contact support.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final isValidPin = await _transactionService.validateUserPin(
        user.uid,
        enteredPin,
      );

      if (isValidPin) {
        final balance = await _transactionService.getUserBalance(user.uid);
        if (balance < widget.transaction.totalAmount) {
          setState(() {
            _isLoading = false;
            _showError = true;
            enteredPin = '';
          });
          _showErrorDialog('Insufficient balance');
          return;
        }

        setState(() {
          _isLoading = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ProcessingScreen(transaction: widget.transaction),
          ),
        );
      } else {
        setState(() {
          _attemptsRemaining--;
          _showError = true;
          enteredPin = '';
          _isLoading = false;
        });

        if (_attemptsRemaining <= 0) {
          _showLockedOutDialog();
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showError = true;
        enteredPin = '';
      });
      _showErrorDialog('Error validating PIN: $e');
    }
  }

  void _showLockedOutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Locked'),
        content: const Text(
          'Too many incorrect PIN attempts. Please try again later or contact customer support.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _forgotPin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text(
          'Please contact customer support to reset your PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text('Enter PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Transfer to ${widget.transaction.recipientName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${widget.transaction.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF003366),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Including \$${widget.transaction.fee.toStringAsFixed(2)} fee',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_recipientUserId != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF003366).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Alpha Bank User',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF003366),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      if (_isFetchingPin)
                        const Column(
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF003366),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Loading PIN...',
                              style: TextStyle(
                                color: Color(0xFF003366),
                              ),
                            ),
                          ],
                        )
                      else if (_storedPin == null)
                        const Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'PIN not configured',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Please contact support',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        const Text(
                          'Enter your 4-digit PIN',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF003366),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (index) {
                            return Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: index < enteredPin.length
                                    ? const Color(0xFF003366)
                                    : Colors.grey[300],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),
                        if (_showError)
                          Column(
                            children: [
                              Text(
                                'Incorrect PIN. $_attemptsRemaining attempts remaining',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        if (authProvider.isLoading || _isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(
                              color: Color(0xFF003366),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                if (_storedPin != null && !_isFetchingPin)
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildKeypadButton('1', isNumber: true),
                      _buildKeypadButton('2', isNumber: true),
                      _buildKeypadButton('3', isNumber: true),
                      _buildKeypadButton('4', isNumber: true),
                      _buildKeypadButton('5', isNumber: true),
                      _buildKeypadButton('6', isNumber: true),
                      _buildKeypadButton('7', isNumber: true),
                      _buildKeypadButton('8', isNumber: true),
                      _buildKeypadButton('9', isNumber: true),
                      _buildKeypadButton('Forgot PIN?', isAction: true),
                      _buildKeypadButton('0', isNumber: true),
                      _buildKeypadButton(
                        '',
                        isDelete: true,
                        icon: Icons.backspace_outlined,
                      ),
                    ],
                  ),
                if (_storedPin == null && !_isFetchingPin)
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003366),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Go Back',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String text,
      {bool isNumber = false,
      bool isDelete = false,
      bool isAction = false,
      IconData? icon}) {
    return GestureDetector(
      onTap: () {
        if (isNumber) {
          _onNumberPressed(text);
        } else if (isDelete) {
          _onDeletePressed();
        } else if (isAction) {
          _forgotPin();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isAction
              ? Colors.transparent
              : isDelete
                  ? Colors.grey[100]
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isAction
              ? null
              : Border.all(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
          boxShadow: isAction
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: isDelete && icon != null
              ? Icon(
                  icon,
                  color: const Color(0xFF003366),
                  size: 24,
                )
              : Text(
                  text,
                  style: TextStyle(
                    fontSize: isAction ? 14 : 22,
                    fontWeight: isAction ? FontWeight.normal : FontWeight.w600,
                    color: const Color(0xFF003366),
                  ),
                ),
        ),
      ),
    );
  }
}

// AmountInputScreen
class AmountInputScreen extends StatefulWidget {
  final String recipientName;
  final String recipientAccount;
  final String transactionType;
  final String bankName;
  final double initialAmount;
  final String description;

  const AmountInputScreen({
    super.key,
    required this.recipientName,
    required this.recipientAccount,
    required this.transactionType,
    required this.bankName,
    this.initialAmount = 0.0,
    this.description = '',
  });

  @override
  State<AmountInputScreen> createState() => _AmountInputScreenState();
}

class _AmountInputScreenState extends State<AmountInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  double _fee = 0.0;
  double _userBalance = 0.0;
  bool _isLoading = false;
  String? _recipientUserId;

  @override
  void initState() {
    super.initState();
    _loadUserBalance();
    _checkRecipient();

    if (widget.initialAmount > 0) {
      _amountController.text = widget.initialAmount.toStringAsFixed(2);
    }
    if (widget.description.isNotEmpty) {
      _noteController.text = widget.description;
    }
    _amountController.addListener(_calculateFee);
    _calculateFee();
  }

  Future<void> _loadUserBalance() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final balance = await _transactionService.getUserBalance(user.uid);
      setState(() {
        _userBalance = balance;
      });
    } catch (e) {
      debugPrint('Error loading balance: $e');
    }
  }

  Future<void> _checkRecipient() async {
    try {
      if (widget.transactionType == 'Alpha Users' ||
          widget.transactionType == 'Bank Transfer') {
        _recipientUserId = await _transactionService
            .findUserByAccountNumber(widget.recipientAccount);
        if (_recipientUserId != null) {
          debugPrint('Recipient is an Alpha Bank user: $_recipientUserId');
        } else {
          debugPrint('Recipient is not an Alpha Bank user');
        }
      }
    } catch (e) {
      debugPrint('Error checking recipient: $e');
    }
  }

  void _calculateFee() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      _fee = _calculateTransactionFee(amount);
    });
  }

  double _calculateTransactionFee(double amount) {
    if (amount <= 0) return 0.0;

    if (widget.transactionType == 'Bank Transfer') {
      if (amount <= 5000) return 10.0;
      if (amount <= 50000) return 25.0;
      return 50.0;
    } else if (widget.transactionType == 'Mobile Money') {
      if (amount <= 1000) return 5.0;
      if (amount <= 10000) return 15.0;
      return 30.0;
    } else if (widget.transactionType == 'Alpha Users') {
      return 0.0;
    } else if (widget.transactionType == 'International') {
      return amount * 0.02;
    } else {
      return amount * 0.01;
    }
  }

  void _processPayment() async {
    final user = _auth.currentUser;
    if (user == null) {
      _showErrorDialog('Please log in to continue');
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (amount <= 0) {
      _showErrorDialog('Please enter a valid amount');
      return;
    }

    if (amount > 1000000) {
      _showErrorDialog('Amount exceeds maximum limit of \$1,000,000');
      return;
    }

    final totalAmount = amount + _fee;
    if (totalAmount > _userBalance) {
      _showErrorDialog('Insufficient balance');
      return;
    }

    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    final transaction = Transaction(
      id: 'TXN${DateTime.now().millisecondsSinceEpoch}',
      userId: user.uid,
      recipientName: widget.recipientName,
      recipientAccount: widget.recipientAccount,
      bankName: widget.bankName,
      amount: amount,
      fee: _fee,
      description: _noteController.text.isNotEmpty
          ? _noteController.text
          : 'Money Transfer',
      timestamp: DateTime.now(),
      status: 'Successful',
      transactionType: widget.transactionType,
      reference: 'REF${DateTime.now().millisecondsSinceEpoch}',
      recipientUserId: _recipientUserId,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PinAuthenticationScreen(transaction: transaction),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = (double.tryParse(_amountController.text) ?? 0.0) + _fee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text('Enter Amount'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 4),
                            ],
                          ),
                          Text(
                            '\$${_userBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF003366),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF003366),
                                  Color(0xFF0055AA),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                widget.recipientName.substring(0, 1),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.recipientName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003366),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.recipientAccount,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      widget.bankName.isNotEmpty
                                          ? widget.bankName
                                          : widget.transactionType,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    if (_recipientUserId != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF003366)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Alpha User',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF003366),
                                            fontWeight: FontWeight.w500,
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
                    )
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Enter Amount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003366),
                    ),
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 28,
                      color: Colors.grey,
                    ),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickAmountButton('100'),
                      const SizedBox(width: 12),
                      _buildQuickAmountButton('500'),
                      const SizedBox(width: 12),
                      _buildQuickAmountButton('1000'),
                      const SizedBox(width: 12),
                      _buildQuickAmountButton('5000'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Amount',
                          '\$${_amountController.text.isEmpty ? '0.00' : _amountController.text}'),
                      _buildDetailRow(
                          'Transaction Fee', '\$${_fee.toStringAsFixed(2)}'),
                      const Divider(height: 20),
                      _buildDetailRow(
                        'Total Amount',
                        '\$${totalAmount.toStringAsFixed(2)}',
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: 'Add Note (Optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.note_rounded),
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountButton(String amount) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _amountController.text = amount;
          _calculateFee();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF003366).withOpacity(0.2),
          ),
        ),
        child: Text(
          '\$$amount',
          style: const TextStyle(
            color: Color(0xFF003366),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              color: Colors.grey[600],
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? const Color(0xFF003366) : Colors.grey[700],
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ProcessingScreen with Notifications
class ProcessingScreen extends StatefulWidget {
  final Transaction transaction;

  const ProcessingScreen({super.key, required this.transaction});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  bool _isProcessing = true;
  bool _isSuccess = false;
  bool _emailSent = false;
  final TransactionService _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    _processTransaction();
  }

  Future<void> _processTransaction() async {
    try {
      await Future.delayed(const Duration(seconds: 2));

      await _transactionService.saveTransaction(widget.transaction);

      await _transactionService.sendReceiptEmail(widget.transaction);

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _emailSent = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ReceiptScreen(transaction: widget.transaction),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Transaction Failed'),
            content: Text('Error: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF003366),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              const Text(
                'Processing Transaction',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Transfer to ${widget.transaction.recipientName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '\$${widget.transaction.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else if (_isSuccess) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 20),
              const Text(
                'Transaction Successful!',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Icon(
                Icons.notifications_active,
                color: Colors.green,
                size: 40,
              ),
              const SizedBox(height: 10),
              const Text(
                'Notification sent to both users',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.green,
                ),
              ),
              if (_emailSent)
                const Text(
                  'Receipt email sent to your registered email',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                  ),
                )
              else
                Text(
                  'Redirecting to receipt...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
            ] else ...[
              const Icon(
                Icons.error_rounded,
                color: Colors.white,
                size: 80,
              ),
              const SizedBox(height: 20),
              const Text(
                'Transaction Failed',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Notification Screen Widget
class NotificationScreen extends StatefulWidget {
  final String userId;

  const NotificationScreen({super.key, required this.userId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  final TransactionService _transactionService = TransactionService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          StreamBuilder<int>(
            stream: _notificationService.getUnreadCount(widget.userId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              if (unreadCount == 0) return const SizedBox();

              return TextButton.icon(
                onPressed: () async {
                  await _notificationService.markAllAsRead(widget.userId);
                },
                icon: const Icon(Icons.mark_email_read),
                label: Text('Mark All ($unreadCount)'),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getUserNotifications(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No notifications yet'),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationItem(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        _notificationService.deleteNotification(widget.userId, notification.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: notification.isRead ? Colors.white : Colors.blue[50],
        child: ListTile(
          leading: _getNotificationIcon(notification.type),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight:
                  notification.isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Text(notification.message),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(notification.timestamp),
                style: const TextStyle(fontSize: 12),
              ),
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          onTap: () async {
            await _notificationService.markAsRead(
                widget.userId, notification.id);

            if (notification.data != null &&
                notification.type == 'transaction') {
              _handleTransactionNotification(notification.data!);
            }
          },
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'transaction':
        return const Icon(Icons.account_balance_wallet, color: Colors.green);
      case 'deposit':
        return const Icon(Icons.arrow_downward, color: Colors.blue);
      case 'withdrawal':
        return const Icon(Icons.arrow_upward, color: Colors.orange);
      case 'transfer':
        return const Icon(Icons.swap_horiz, color: Colors.purple);
      case 'system':
        return const Icon(Icons.info, color: Colors.grey);
      default:
        return const Icon(Icons.notifications, color: Colors.blue);
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleTransactionNotification(Map<String, dynamic> data) {
    final transactionId = data['transactionId'];
    final amount = data['amount'];
    final recipientName = data['recipientName'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transaction Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction ID: $transactionId'),
            Text('Amount: \$${amount.toStringAsFixed(2)}'),
            Text('Recipient: $recipientName'),
            if (data['status'] != null) Text('Status: ${data['status']}'),
            if (data['newBalance'] != null)
              Text('New Balance: \$${data['newBalance'].toStringAsFixed(2)}'),
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
}

// Receipt Screen
class ReceiptScreen extends StatefulWidget {
  final Transaction transaction;

  const ReceiptScreen({super.key, required this.transaction});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final TransactionService _transactionService = TransactionService();
  bool _isSaving = false;

  Future<void> _shareAsImage() async {
    setState(() => _isSaving = true);

    try {
      final Uint8List? image = await _screenshotController.capture();

      if (image != null) {
        final directory = await getTemporaryDirectory();
        final imagePath =
            '${directory.path}/receipt_${widget.transaction.id}.png';
        final file = File(imagePath);
        await file.writeAsBytes(image);

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: 'Transaction Receipt - ${widget.transaction.id}',
        );
      }
    } catch (e) {
      _showError('Failed to share receipt: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _shareAsPDF() async {
    setState(() => _isSaving = true);

    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'ALPHA BANK',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'TRANSACTION RECEIPT',
                    style: const pw.TextStyle(fontSize: 18),
                  ),
                ),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Transaction ID: ${widget.transaction.id}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Date: ${_formatDate(widget.transaction.timestamp)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Time: ${_formatTime(widget.transaction.timestamp)}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Text(
                  'Recipient: ${widget.transaction.recipientName}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'Account: ${widget.transaction.recipientAccount}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Bank: ${widget.transaction.bankName}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Amount:', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      '\$${widget.transaction.amount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Fee:', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      '\$${widget.transaction.fee.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total:', style: const pw.TextStyle(fontSize: 14)),
                    pw.Text(
                      '\$${widget.transaction.totalAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Status: ${widget.transaction.status}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: widget.transaction.status == 'Completed'
                        ? PdfColors.green
                        : PdfColors.red,
                  ),
                ),
                pw.Text(
                  'Type: ${widget.transaction.transactionType}',
                  style: const pw.TextStyle(fontSize: 12),
                ),
                if (widget.transaction.reference != null)
                  pw.Text(
                    'Reference: ${widget.transaction.reference}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                pw.SizedBox(height: 30),
                pw.Center(
                  child: pw.Text(
                    'Thank you for banking with us!',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Alpha Bank - Secure Banking',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final pdfPath = '${directory.path}/receipt_${widget.transaction.id}.pdf';
      final file = File(pdfPath);
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(pdfPath)],
        text: 'Transaction Receipt - ${widget.transaction.id}',
      );
    } catch (e) {
      _showError('Failed to generate PDF: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _goToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        title: const Text('Transaction Receipt'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _goToHome,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Screenshot(
                  controller: _screenshotController,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
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
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 60,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Transaction Successful!',
                                style: TextStyle(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.transaction.id,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Receipt sent to your email',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[300]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Amount',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '\$${widget.transaction.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF003366),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildReceiptDetail(
                                  'To', widget.transaction.recipientName),
                              _buildReceiptDetail('Account',
                                  widget.transaction.recipientAccount),
                              _buildReceiptDetail(
                                  'Bank', widget.transaction.bankName),
                              _buildReceiptDetail('Transaction Type',
                                  widget.transaction.transactionType),
                              _buildReceiptDetail('Description',
                                  widget.transaction.description),
                              _buildReceiptDetail('Date',
                                  _formatDate(widget.transaction.timestamp)),
                              _buildReceiptDetail('Time',
                                  _formatTime(widget.transaction.timestamp)),
                              _buildReceiptDetail(
                                  'Status', widget.transaction.status,
                                  valueColor:
                                      widget.transaction.status == 'Completed'
                                          ? Colors.green
                                          : Colors.orange),
                              _buildReceiptDetail('Transaction Fee',
                                  '\$${widget.transaction.fee.toStringAsFixed(2)}'),
                              if (widget.transaction.reference != null)
                                _buildReceiptDetail(
                                    'Reference', widget.transaction.reference!),
                              const Divider(height: 32),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF003366),
                                    ),
                                  ),
                                  Text(
                                    '\$${widget.transaction.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF003366),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green[100]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.security_rounded,
                                  color: Colors.green[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This transaction is secured with 256-bit encryption. Keep this receipt for your records. A copy has been sent to your email.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _shareAsImage,
                          icon: const Icon(Icons.image_rounded),
                          label: const Text('Share as Image'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _shareAsPDF,
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          label: const Text('Share as PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _goToHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003366),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptDetail(String label, String value, {Color? valueColor}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? const Color(0xFF003366),
              ),
            ),
          ],
        ));
  }
}

// Main App to test the flow
class TransferApp extends StatelessWidget {
  const TransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Transfer',
      theme: ThemeData(
        primaryColor: const Color(0xFF003366),
        scaffoldBackgroundColor: const Color(0xFFF8FAFD),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003366),
          foregroundColor: Colors.white,
        ),
      ),
      home: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Money Transfer Demo'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AmountInputScreen(
                            recipientName: 'John Doe',
                            recipientAccount: 'ALPHA123456',
                            transactionType: 'Bank Transfer',
                            bankName: 'Alpha Bank',
                          ),
                        ),
                      );
                    },
                    child: const Text('Start Transfer'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'For testing:\n- Enter any amount\n- Use your stored PIN from Firestore\n- For Alpha Bank users, recipient balance will be updated\n- Notifications will be sent to both users',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
