import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('🔍 Testing Firestore connection and rules...');
  print('Current date: ${DateTime.now()}');

  try {
    // Test write permission
    await firestore.collection('test_connection').doc('test').set({
      'timestamp': FieldValue.serverTimestamp(),
      'message': 'Testing rules',
    });
    print('✅ Write permission: GRANTED');

    // Test read permission
    final doc = await firestore.collection('test_connection').doc('test').get();
    print('✅ Read permission: GRANTED');
    print('   Document data: ${doc.data()}');

    // Clean up
    await firestore.collection('test_connection').doc('test').delete();
    print('✅ Delete permission: GRANTED');

    print('\n🎉 All permissions are working correctly!');
    print('Your rules are active until the expiration date.');
  } catch (e) {
    print('\n❌ Permission DENIED: $e');
    print('\n⚠️  Please update your Firestore rules immediately!');
    print('   Rules have likely expired.');
    print('   Go to: Firebase Console → Firestore → Rules');
    print('   Update the expiration date to a future date.');
  }
}
