import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SOSHistoryScreen extends StatelessWidget {
  const SOSHistoryScreen({super.key});

  String _formatTimestamp(dynamic value) {
    if (value is! Timestamp) return 'Time unavailable';
    final DateTime date = value.toDate().toLocal();
    final String hour = date.hour == 0
        ? '12'
        : date.hour > 12
            ? '${date.hour - 12}'
            : '${date.hour}';
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.day}/${date.month}/${date.year} at $hour:$minute $period';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS History'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please sign in to view SOS history.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('sos_alerts')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load SOS history.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE91E63)),
                  );
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> alerts =
                    [...?snapshot.data?.docs];
                alerts.sort((a, b) {
                  final Timestamp? first = a.data()['timestamp'] as Timestamp?;
                  final Timestamp? second = b.data()['timestamp'] as Timestamp?;
                  return (second?.millisecondsSinceEpoch ?? 0)
                      .compareTo(first?.millisecondsSinceEpoch ?? 0);
                });

                if (alerts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 12),
                          Text('No SOS alerts yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('Your SOS alerts will appear here.'),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> alert = alerts[index].data();
                    final String status = (alert['status'] ?? 'ACTIVE').toString();
                    final String address = (alert['address'] ?? 'Location unavailable').toString();
                    final String mapLink = (alert['googleMapsLink'] ?? '').toString();
                    final double? latitude = (alert['latitude'] as num?)?.toDouble();
                    final double? longitude = (alert['longitude'] as num?)?.toDouble();

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFFFEBEE),
                                  child: Icon(Icons.sos, color: Colors.red),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text('SOS Alert', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_formatTimestamp(alert['timestamp']))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                                const SizedBox(width: 8),
                                Expanded(child: Text(address)),
                              ],
                            ),
                            if (latitude != null && longitude != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Coordinates: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                            if (mapLink.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SelectableText(
                                mapLink,
                                style: const TextStyle(color: Color(0xFFE91E63), fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
