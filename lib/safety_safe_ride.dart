import 'package:flutter/material.dart';

class SafetyTipsScreen extends StatelessWidget {
  const SafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Safety Tips")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SafetyTipCard(
              title: "Check the Plate",
              desc: "Always match the driver's plate with the app info."),
          SafetyTipCard(
              title: "Share Ride Status",
              desc: "Use the 'Track Ride' feature to keep family updated."),
          SafetyTipCard(
              title: "One-Tap SOS",
              desc: "Use the red button if you feel unsafe at any moment."),
        ],
      ),
    );
  }
}

class SafetyTipCard extends StatelessWidget {
  final String title, desc;
  const SafetyTipCard({super.key, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.shield, color: Color(0xFFE91E63)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc),
      ),
    );
  }
}
