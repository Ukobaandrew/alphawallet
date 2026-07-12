// utils/chat_availability.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' show DateFormat;

class ChatAvailability {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> isLiveChatAvailable() async {
    try {
      final settings =
          await _firestore.collection('chat_settings').doc('general').get();

      if (settings.exists) {
        final data = settings.data();
        final isEnabled = data?['isLiveChatEnabled'] ?? false;

        if (!isEnabled) return false;

        // Check business hours
        final now = DateTime.now();
        final businessHours = data?['businessHours'];
        if (businessHours != null) {
          final days = List<String>.from(businessHours['days'] ?? []);
          final currentDay = DateFormat('EEEE').format(now);

          if (!days.contains(currentDay)) {
            return data?['offlineModeEnabled'] ?? false;
          }
        }

        return true;
      }
      return false;
    } catch (e) {
      print('Error checking chat availability: $e');
      return false;
    }
  }

  static Future<int> getEstimatedWaitTime() async {
    try {
      final settings =
          await _firestore.collection('chat_settings').doc('general').get();

      return settings.data()?['averageWaitTime'] ?? 5;
    } catch (e) {
      return 5;
    }
  }
}
