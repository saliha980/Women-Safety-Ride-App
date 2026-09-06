import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailSupportDialog extends StatefulWidget {
  const EmailSupportDialog({super.key});

  @override
  State<EmailSupportDialog> createState() => _EmailSupportDialogState();
}

class _EmailSupportDialogState extends State<EmailSupportDialog> {
  final TextEditingController _adminEmailController =
      TextEditingController(text: "admin123@gmail.com");
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  void _sendEmailInquiry() async {
    String adminEmail = _adminEmailController.text.trim();
    String subject = _subjectController.text.trim();
    String message = _messageController.text.trim();

    if (adminEmail.isEmpty || subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please complete all fields."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String senderEmail = user?.email ?? "Anonymous User";
      String senderUid = user?.uid ?? "unknown_uid";

      await FirebaseFirestore.instance.collection('support_emails').add({
        'adminEmail': adminEmail,
        'senderEmail': senderEmail,
        'senderUid': senderUid,
        'subject': subject,
        'message': message,
        'status': 'Unread',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Message sent to Admin Panel successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to send message: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.email, color: Color(0xFFE91E63)),
          SizedBox(width: 8),
          Text("Send Email to Admin"),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _adminEmailController,
              decoration: const InputDecoration(
                labelText: "Target Admin Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.admin_panel_settings),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(
                labelText: "Subject",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.subject),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Your Message",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE91E63),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSending ? null : _sendEmailInquiry,
          child: _isSending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text("Send"),
        ),
      ],
    );
  }
}