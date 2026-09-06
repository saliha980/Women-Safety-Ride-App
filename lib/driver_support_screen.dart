import 'package:flutter/material.dart';

class DriverSupportScreen extends StatelessWidget {
  const DriverSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Support", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.headset_mic, color: Color(0xFF9C27B0), size: 36),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Need Assistance?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9C27B0))),
                        SizedBox(height: 4),
                        Text("Our rider support center is available 24/7 for safety issues and ride queries.", style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text("Frequently Asked Questions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
            const SizedBox(height: 10),
            _buildFAQTile("How do I receive payments?", "Fares are instantly credited to your app wallet once a ride is completed by the passenger."),
            _buildFAQTile("What to do in an emergency?", "Tap the 'SOS Emergency' floating button on your dashboard to instantly alert emergency contacts with live GPS coordinates."),
            _buildFAQTile("How do I update my vehicle info?", "Go to Driver Settings from the side navigation drawer and click 'Edit Driver Profile'."),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}