// lib/core/initial_firebase_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseDataInitializer {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create test users for development
  static Future<void> createTestUsers() async {
    try {
      print('🔄 Creating test users...');
      
      // Test User 1 (Pending registration)
      await _firestore.collection('users').doc('test_001').set({
        'id': 'test_001',
        'fullName': 'John Smith',
        'email': 'john@alpha.gr',
        'phone': '+12345678901',
        'referralCode': 'REF001',
        'userCode': 'ALPHA001', // Registration code
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
        'balance': 0.0,
        'isVerified': false,
      });

      // Test User 2 (Already registered)
      await _firestore.collection('users').doc('test_002').set({
        'id': 'test_002',
        'fullName': 'Sarah Johnson',
        'email': 'sarah@alpha.gr',
        'phone': '+12345678902',
        'referralCode': 'REF002',
        'userCode': 'ALPHA002',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': 'active',
        'balance': 500.0,
        'isVerified': true,
        'passwordHash': 'hashed_password_123',
        'transactionPinHash': 'hashed_1234',
      });

      print('✅ Test users created successfully!');
      print('📋 Test codes: ALPHA001 (pending), ALPHA002 (active)');
      
    } catch (e) {
      print('❌ Error creating test users: $e');
      rethrow;
    }
  }

  // Initialize Firestore collections structure
  static Future<void> initializeCollections() async {
    try {
      print('🔄 Initializing collections...');
      
      // Try to check if collections exist by trying to read a document
      // If it throws an error, collection might not exist
      
      // Initialize users collection
      await _initializeCollection('users');
      
      // Initialize other collections
      await _initializeCollection('transactions');
      await _initializeCollection('bets');
      await _initializeCollection('promotions');
      await _initializeCollection('withdrawals');
      await _initializeCollection('deposits');
      
      print('✅ All collections initialized');
      
    } catch (e) {
      print('❌ Error initializing collections: $e');
    }
  }

  // Helper method to initialize a collection
  static Future<void> _initializeCollection(String collectionName) async {
    try {
      // Try to read a document to see if collection exists
      final snapshot = await _firestore
          .collection(collectionName)
          .doc('init')
          .get();
      
      if (!snapshot.exists) {
        // Create initialization document
        await _firestore.collection(collectionName).doc('init').set({
          'initialized': true,
          'timestamp': DateTime.now().toIso8601String(),
          'app': 'Alpha Wallet',
        });
        print('✅ $collectionName collection initialized');
      } else {
        print('📁 $collectionName collection already exists');
      }
    } catch (e) {
      // If error occurs (collection might not exist), create it
      try {
        await _firestore.collection(collectionName).doc('init').set({
          'initialized': true,
          'timestamp': DateTime.now().toIso8601String(),
          'app': 'Alpha Wallet',
        });
        print('✅ $collectionName collection created');
      } catch (createError) {
        print('⚠️ Could not create $collectionName: $createError');
      }
    }
  }

  // Alternative: Check if collection exists by attempting to add a document
  static Future<bool> _doesCollectionExist(String collectionName) async {
    try {
      // Try to add and immediately delete a test document
      final testDoc = _firestore.collection(collectionName).doc('_test_existence');
      await testDoc.set({
        '_test': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      // Delete the test document
      await testDoc.delete();
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Create admin user for testing
  static Future<void> createAdminTestUser() async {
    try {
      await _firestore.collection('users').doc('admin_001').set({
        'id': 'admin_001',
        'fullName': 'Admin User',
        'email': 'admin@alpha.gr',
        'phone': '+12345678900',
        'referralCode': 'ADMIN001',
        'userCode': 'ADMIN123',
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'status': 'active',
        'balance': 10000.0,
        'isVerified': true,
        'passwordHash': 'hashed_admin123',
        'transactionPinHash': 'hashed_9999',
        'isAdmin': true, // Flag for admin access
      });
      
      print('✅ Admin test user created');
      print('📋 Admin code: ADMIN123');
      
    } catch (e) {
      print('❌ Error creating admin user: $e');
    }
  }

  // Clear all test data (for resetting)
  static Future<void> clearTestData() async {
    try {
      print('🔄 Clearing test data...');
      
      // List of test documents to delete
      final testDocs = [
        'users/test_001',
        'users/test_002',
        'users/admin_001',
      ];
      
      for (var docPath in testDocs) {
        try {
          await _firestore.doc(docPath).delete();
          print('🗑️ Deleted: $docPath');
        } catch (e) {
          print('⚠️ Could not delete $docPath: $e');
        }
      }
      
      print('✅ Test data cleared');
      
    } catch (e) {
      print('❌ Error clearing test data: $e');
    }
  }
}