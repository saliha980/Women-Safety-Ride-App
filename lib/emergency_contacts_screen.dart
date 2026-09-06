import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream user profile document from Firestore
  Stream<DocumentSnapshot<Map<String, dynamic>>?> _getUserStream() async* {
    User? user = _auth.currentUser;
    if (user == null) {
      yield null;
      return;
    }

    yield* _firestore
        .collection('women_safety_data')
        .doc('users_data')
        .collection('profiles')
        .doc(user.uid)
        .snapshots();
  }

  // Extract raw digits for exact comparisons
  String _getPureDigits(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  // Helper validation function for phone numbers
  bool _isValidPhoneNumber(String phone) {
    String cleaned = phone.trim();

    // 1. Must match +923 followed by exactly 9 digits (Total 13 characters)
    RegExp phoneRegex = RegExp(r'^\+923\d{9}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return false;
    }

    // 2. Extract the 9 digits AFTER +923
    String digitsAfter3 = cleaned.substring(4); // gets index 4 to end

    // 3. Reject if all remaining 9 digits are identical (e.g., 000000000, 111111111)
    Set<String> uniqueDigitsAfter3 = digitsAfter3.split('').toSet();
    if (uniqueDigitsAfter3.length == 1) {
      return false;
    }

    return true;
  }

  // Add or update contact modal
  void _showAddOrEditContactDialog({
    String? existingKey,
    String? existingPhone,
    Map<String, dynamic>? currentContacts,
    String? userPersonalPhone,
  }) {
    User? user = _auth.currentUser;
    if (user == null) return;

    final TextEditingController labelController =
        TextEditingController(text: existingKey ?? '');
    final TextEditingController phoneController =
        TextEditingController(text: existingPhone ?? '+923');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            existingKey == null ? "Add Emergency Contact" : "Edit Contact",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFC2185B),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                enabled: true,
                decoration: const InputDecoration(
                  labelText:
                      "Relationship / Name (e.g. mother, parent, sister)",
                  prefixIcon: Icon(Icons.person, color: Color(0xFFE91E63)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 13,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\+0-9]')),
                  LengthLimitingTextInputFormatter(13),
                ],
                decoration: const InputDecoration(
                  counterText: "",
                  labelText: "Phone Number (+923XXXXXXXXX)",
                  prefixIcon: Icon(Icons.phone, color: Color(0xFFE91E63)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final key = labelController.text.trim().toLowerCase();
                String rawPhone = phoneController.text.trim();

                if (key.isEmpty || rawPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all fields")),
                  );
                  return;
                }

                // 1. Validate format (+923XXXXXXXXX) and ensure digits after 3 are not all identical
                if (!_isValidPhoneNumber(rawPhone)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          "Invalid number! Must be +923XXXXXXXXX and digits after 3 cannot be identical."),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                String inputDigits = _getPureDigits(rawPhone);

                // 2. Personal phone duplicate check
                if (userPersonalPhone != null) {
                  String personalDigits = _getPureDigits(userPersonalPhone);
                  if (inputDigits == personalDigits) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "Emergency contact cannot be identical to your personal account phone number."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                }

                // 3. Duplicate check among existing emergency contacts
                if (currentContacts != null) {
                  for (var entry in currentContacts.entries) {
                    if (existingKey != null && entry.key == existingKey) {
                      continue; // Skip comparing against current record during edit
                    }

                    String existingEntryDigits =
                        _getPureDigits(entry.value.toString());
                    if (existingEntryDigits == inputDigits ||
                        entry.value.toString().trim() == rawPhone) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "This phone number is already added under '${_formatLabel(entry.key)}'."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                  }
                }

                try {
                  Map<String, dynamic> updates = {
                    'emergency_contacts.$key': rawPhone,
                  };

                  // Remove old field if name key changed
                  if (existingKey != null && existingKey != key) {
                    updates['emergency_contacts.$existingKey'] =
                        FieldValue.delete();
                  }

                  await _firestore
                      .collection('women_safety_data')
                      .doc('users_data')
                      .collection('profiles')
                      .doc(user.uid)
                      .update(updates);

                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Emergency contact saved!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Failed to save: $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text("SAVE"),
            ),
          ],
        );
      },
    );
  }

  // Format relationship keys for user display (e.g., 'mother' -> 'Mother')
  String _formatLabel(String key) {
    if (key.isEmpty) return key;
    if (key == 'parent') return 'Father/Guardian';
    return key[0].toUpperCase() + key.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Contacts"),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
        stream: _getUserStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E63)),
            );
          }

          final userData = snapshot.data?.data();
          final String? userPersonalPhone = userData?['phone']?.toString();
          final Map<String, dynamic> emergencyContacts = (userData != null &&
                  userData.containsKey('emergency_contacts'))
              ? Map<String, dynamic>.from(userData['emergency_contacts'] ?? {})
              : {};

          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  "Contacts will receive an instant alert when you press SOS.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              if (emergencyContacts.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text(
                      "No emergency contacts added yet.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: emergencyContacts.entries.map((entry) {
                      return _contactItem(
                        entry.key,
                        entry.value.toString(),
                        emergencyContacts,
                        userPersonalPhone,
                      );
                    }).toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: () => _showAddOrEditContactDialog(
                    currentContacts: emergencyContacts,
                    userPersonalPhone: userPersonalPhone,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Emergency Contact"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contactItem(
    String key,
    String phone,
    Map<String, dynamic> currentContacts,
    String? userPersonalPhone,
  ) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.purple,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(
        _formatLabel(key),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(phone),
      onTap: () => _showAddOrEditContactDialog(
        existingKey: key,
        existingPhone: phone,
        currentContacts: currentContacts,
        userPersonalPhone: userPersonalPhone,
      ),
    );
  }
}
