// save as fix_permissions.dart in your project root
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'firebase_options.dart';

void main() async {
  print('🔧 Running Firestore setup and permission fix...');

  try {
    // 1. Initialize Firebase
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firestore = FirebaseFirestore.instance;

    // 2. Test if we can access Firestore
    print('Testing Firestore connection...');

    try {
      // Create a test document
      await firestore.collection('connection_test').doc('test').set({
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Testing connection',
      });

      // Read it back
      final doc =
          await firestore.collection('connection_test').doc('test').get();
      print('✅ Firestore connection successful: ${doc.data()}');

      // Clean up
      await firestore.collection('connection_test').doc('test').delete();
    } catch (e) {
      print('❌ Firestore permission error: $e');
      print('\n⚠️  URGENT: Your Firestore rules have EXPIRED!');
      print('   Rules expire date: 2025-12-28');
      print('   Today\'s date: 2025-12-31');
      print('\n🔧 Steps to fix:');
      print('   1. Go to Firebase Console → Firestore → Rules');
      print('   2. Update expiration date to 2026-12-31');
      print('   3. Click "Publish"');
      print('   4. Wait 1 minute');
      print('   5. Run this script again');
      return;
    }

    // 3. Create the "anderson" user if it doesn't exist
    print('\n👤 Creating/checking user "anderson"...');

    final usersRef = firestore.collection('users');
    final andersonQuery =
        await usersRef.where('username', isEqualTo: 'anderson').limit(1).get();

    if (andersonQuery.docs.isEmpty) {
      print('   ➕ Creating user "anderson"...');

      await usersRef.add({
        'username': 'anderson',
        'email': 'anderson@example.com',
        'firstName': 'Anderson',
        'lastName': 'Smith',
        'name': 'Anderson Smith',
        'accountNumber': 'ACC-AND-001',
        'accountType': 'personal',
        'balance': 15000.00,
        'isActive': true,
        'isVerified': true,
        'role': 'user',
        'pin': '123456',
        'secureCode': '',
        'registrationStep': 4,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': null,
        'failedLoginAttempts': 0,
        'accountLocked': false,
        'preferredCurrency': 'USD',
        'notificationEnabled': true,
        'biometricEnabled': false,
      });

      print('   ✅ User "anderson" created');
    } else {
      print('   ✅ User "anderson" already exists');
    }

    // 4. Create other essential collections
    print('\n📊 Setting up essential collections...');

    await _setupEssentialCollections(firestore);

    print('\n🎉 Setup completed successfully!');
    print('\nNow you can:');
    print('   1. Run your app: flutter run');
    print('   2. Login with username: anderson, PIN: 123456');
  } catch (e) {
    print('\n❌ Setup failed: $e');
    print('\n⚠️  Please check:');
    print('   - Firebase project configuration');
    print('   - google-services.json / GoogleService-Info.plist files');
    print('   - Firestore rules (must be updated!)');
  }
}

Future<void> _setupEssentialCollections(FirebaseFirestore firestore) async {
  // Check/create exchange rates
  final exchangeRates =
      await firestore.collection('exchange_rates').limit(1).get();
  if (exchangeRates.docs.isEmpty) {
    await firestore.collection('exchange_rates').add({
      'baseCurrency': 'USD',
      'targetCurrency': 'EUR',
      'rate': 0.92,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    print('   ✅ Created exchange rates');
  }

  // Check/create banks
  final banks = await firestore.collection('banks').limit(1).get();
  if (banks.docs.isEmpty) {
    await firestore.collection('banks').add({
      'name': 'Alpha Bank',
      'code': 'ABL',
      'country': 'Greece',
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('   ✅ Created banks');
  }

  // Check/create countries
  final countries = await firestore.collection('countries').limit(1).get();
  if (countries.docs.isEmpty) {
    await firestore.collection('countries').add({
      'name': 'United States',
      'code': 'US',
      'currency': 'USD',
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('   ✅ Created countries');
  }
}
