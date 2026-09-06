import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sos_service.dart';

class SOSDialog {
  /// Call this method from ANY screen (LoginScreen, HomeScreen, SignUpScreen, etc.)
  static void show(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator:
          true, // Guarantees dialog sits on top of all stack routes
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("🚨 ", style: TextStyle(fontSize: 22)),
              Flexible(
                child: Text(
                  "SOS Emergency",
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: const Text(
            "Alert emergency contacts and send your current live GPS location silently?",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext, rootNavigator: true).pop(),
              child: const Text(
                "CANCEL",
                style: TextStyle(
                  color: Colors.pink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () async {
                // Safely dismiss dialog using root navigator
                Navigator.of(dialogContext, rootNavigator: true).pop();

                // Show processing SnackBar safely on outer context
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text("🚨 Triggering Silent SOS Emergency Alert..."),
                      backgroundColor: Colors.orange,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                await _executeSOS(context);
              },
              child: const Text(
                "SEND",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Internal logic to capture location and trigger silent background SOS
  static Future<void> _executeSOS(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'unauthenticated_user';
      List<String> targetPhoneNumbers = [];

      // 1. Fetch user personal emergency contact if logged in
      if (user != null) {
        try {
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('women_safety_data')
              .doc('users_data')
              .collection('profiles')
              .doc(userId)
              .get()
              .timeout(const Duration(seconds: 5));

          if (userDoc.exists && userDoc.data() != null) {
            final data = userDoc.data() as Map<String, dynamic>;
            if (data.containsKey('emergency_contacts')) {
              final contacts =
                  data['emergency_contacts'] as Map<String, dynamic>?;
              targetPhoneNumbers = contacts?.values
                      .map((phone) => phone.toString())
                      .where((phone) => phone.isNotEmpty)
                      .toList() ??
                  [];
            }
          }
        } catch (_) {
          // Fall back gracefully if user profile fetch fails
        }
      }

      // 2. Fetch Admin configured emergency number from Firestore if user has no personal contact or is on Login/Signup screen
      if (targetPhoneNumbers.isEmpty) {
        try {
          DocumentSnapshot adminConfigDoc = await FirebaseFirestore.instance
              .collection('women_safety_data')
              .doc('admin_settings')
              .collection('sos_config')
              .doc('emergency_contact')
              .get()
              .timeout(const Duration(seconds: 5));

          if (adminConfigDoc.exists && adminConfigDoc.data() != null) {
            final data = adminConfigDoc.data() as Map<String, dynamic>;
            final adminPhone = data['emergency_phone']?.toString() ?? "";
            if (adminPhone.isNotEmpty) {
              targetPhoneNumbers = [adminPhone];
            }
          }
        } catch (_) {
          // Fall back gracefully if admin config fetch fails
        }
      }

      // 3. Last fallback if Admin has not configured a number yet
      if (targetPhoneNumbers.isEmpty) {
        targetPhoneNumbers = ["03000000000"]; // Default safe dummy number
      }

      // 4. Delegate to SOSService (Fetches GPS, posts to Firestore, & sends SILENT Native SMS)
      final SOSService sosService = SOSService();
      await sosService.sendSOSAlert(emergencyPhones: targetPhoneNumbers);

      // 5. Success UI Feedback
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "✅ Silent SOS Alert Dispatched to ${targetPhoneNumbers.join(', ')}!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Error sending SOS: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
