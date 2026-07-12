// lib/core/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/data/models/user_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if user code exists (created by admin)
  Future<UserModel?> getUserByCode(String userCode) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('userCode', isEqualTo: userCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      final user = UserModel.fromMap({'id': doc.id, ...doc.data()});

      return user;
    } catch (e) {
      print('Error getting user by code: $e');
      return null;
    }
  }

  // Update user after registration (set password and pin)
  Future<bool> completeUserRegistration({
    required String userId,
    required String password,
    required String transactionPin,
  }) async {
    try {
      // In production, hash the password and pin properly
      final passwordHash = _hashPassword(password);
      final pinHash = _hashPin(transactionPin);

      await _firestore.collection('users').doc(userId).update({
        'passwordHash': passwordHash,
        'transactionPinHash': pinHash,
        'status': UserStatus.active.toString().split('.').last,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      print('Error completing registration: $e');
      return false;
    }
  }

  String _hashPassword(String password) {
    // Use proper hashing in production (bcrypt, Argon2, etc.)
    // For now, simple demo hashing
    return 'hashed_${password}_demo';
  }

  String _hashPin(String pin) {
    // Use proper hashing for PIN
    return 'hashed_${pin}_demo';
  }

  // Verify user login
  Future<UserModel?> verifyUserLogin(String email, String password) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return null;
      }

      final doc = query.docs.first;
      final userData = doc.data();
      final user = UserModel.fromMap({'id': doc.id, ...userData});

      // Check if password matches (in production, use proper hashing comparison)
      if (userData['passwordHash'] == _hashPassword(password) &&
          user.status == UserStatus.active) {
        // Update last login
        await _firestore.collection('users').doc(doc.id).update({
          'lastLogin': DateTime.now().toIso8601String(),
        });

        return user;
      }

      return null;
    } catch (e) {
      print('Error verifying login: $e');
      return null;
    }
  }

  // Check if transaction PIN is correct
  Future<bool> verifyTransactionPin(String userId, String pin) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;

      final userData = doc.data();
      return userData?['transactionPinHash'] == _hashPin(pin);
    } catch (e) {
      print('Error verifying PIN: $e');
      return false;
    }
  }
}
