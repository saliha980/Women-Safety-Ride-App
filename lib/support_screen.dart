import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'user_support_chat_screen.dart';
import 'email_support_dialog.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  Future<void> _openDialPad() async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: '15',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not open dial pad for 15');
    }
  }

  void _showEmailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const EmailSupportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Support")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const Icon(Icons.support_agent, size: 80, color: Color(0xFF9C27B0)),
                    const SizedBox(height: 20),
                    const Text("How can we help you?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    _supportOption(
                      Icons.chat, 
                      "Chat with Support", 
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UserSupportChatScreen()),
                        );
                      },
                    ),
                    _supportOption(
                      Icons.email, 
                      "Email Us", 
                      onTap: () => _showEmailDialog(context),
                    ),
                    _supportOption(
                      Icons.phone, 
                      "Call Emergency Helpline", 
                      onTap: _openDialPad,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 10),
              child: InkWell(
                onTap: _openDialPad,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7B72),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notification_important_outlined, 
                        color: Colors.black87,
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Call 15",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supportOption(IconData icon, String label, {VoidCallback? onTap}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE91E63)),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}