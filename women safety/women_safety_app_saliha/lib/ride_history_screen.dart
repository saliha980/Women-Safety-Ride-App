import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RideHistoryScreen extends StatelessWidget {
  const RideHistoryScreen({super.key});

  // Helper method to format Firestore Timestamps using native Dart
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      DateTime dt = timestamp.toDate();
      
      List<String> months = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
      ];
      
      String month = months[dt.month - 1];
      String day = dt.day.toString().padLeft(2, '0');
      int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      String minute = dt.minute.toString().padLeft(2, '0');
      String period = dt.hour >= 12 ? 'PM' : 'AM';

      return "$month $day, ${dt.year} • $hour:$minute $period";
    }
    return "N/A";
  }

  // Get status badge properties
  Map<String, dynamic> _getStatusBadge(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return {'color': Colors.green, 'text': 'Completed', 'icon': Icons.check_circle_outline};
      case 'cancelled':
        return {'color': Colors.red, 'text': 'Cancelled', 'icon': Icons.cancel_outlined};
      case 'accepted':
        return {'color': Colors.blue, 'text': 'In Progress', 'icon': Icons.directions_car};
      case 'rejected':
        return {'color': Colors.orange, 'text': 'Declined', 'icon': Icons.block};
      case 'pending':
      default:
        return {'color': Colors.amber.shade800, 'text': 'Pending', 'icon': Icons.hourglass_empty};
    }
  }

  // Bottom sheet modal for detailed ride timeline & info
  void _showRideDetailsBottomSheet(BuildContext context, Map<String, dynamic> ride, String currentUserId) {
    String status = ride['status'] ?? 'pending';
    var badge = _getStatusBadge(status);
    bool isDriver = ride['driverId'] == currentUserId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Ride Details",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (badge['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(badge['icon'], size: 16, color: badge['color']),
                        const SizedBox(width: 4),
                        Text(
                          badge['text'],
                          style: TextStyle(
                            color: badge['color'],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const Divider(height: 25),

              const Text("Timeline", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              _timelineTile(
                icon: Icons.access_time_filled,
                color: Colors.blue,
                title: "Requested At",
                subtitle: _formatTimestamp(ride['createdAt']),
              ),
              if (ride['acceptedAt'] != null)
                _timelineTile(
                  icon: Icons.local_taxi,
                  color: Colors.orange,
                  title: "Accepted / Started",
                  subtitle: _formatTimestamp(ride['acceptedAt']),
                ),
              if (ride['completedAt'] != null)
                _timelineTile(
                  icon: Icons.flag,
                  color: Colors.green,
                  title: "Completed At",
                  subtitle: _formatTimestamp(ride['completedAt']),
                ),
              if (ride['cancelledAt'] != null)
                _timelineTile(
                  icon: Icons.highlight_off,
                  color: Colors.red,
                  title: "Cancelled At",
                  subtitle: _formatTimestamp(ride['cancelledAt']),
                ),

              const Divider(height: 25),

              Text(
                isDriver ? "Passenger Details" : "Driver & Vehicle",
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFFCE4EC),
                    child: Icon(Icons.person, color: Color(0xFFE91E63)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDriver
                            ? (ride['passengerName'] ?? "Passenger")
                            : (ride['driverName'] ?? "Driver Not Assigned"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        "Vehicle Type: ${ride['vehicleType'] ?? 'N/A'} • ${ride['rideCategory'] ?? 'Individual'}",
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  )
                ],
              ),

              const Divider(height: 25),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.my_location, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Pickup Location", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(ride['pickupLocation'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Dropoff Location", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(ride['dropoffLocation'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),

              if (status == 'cancelled') ...[
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Cancelled By: ${ride['cancelledBy'] == 'driver' ? 'Driver' : 'Passenger'}",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Reason: ${ride['cancellationReason'] ?? 'No reason provided'}",
                        style: const TextStyle(color: Colors.black87, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // children: [
                    //   const Text("Total Fare", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    //   Text(
                    //     "Rs. ${ride['fare'] ?? '0'}",
                    //     style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFE91E63)),
                    //   ),
                    // ],
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("CLOSE"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _timelineTile({required IconData icon, required Color color, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(subtitle, style: const TextStyle(color: Colors.black87, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride History", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
          ),
        ),
      ),
      body: user == null
          ? const Center(child: Text("Please log in to view ride history."))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('rides').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("No ride history found.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                // Filter rides where user is passenger OR driver
                var docs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['passengerId'] == user.uid || data['driverId'] == user.uid;
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("No ride history found.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                docs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  Timestamp? timeA = dataA['createdAt'] as Timestamp?;
                  Timestamp? timeB = dataB['createdAt'] as Timestamp?;
                  if (timeA == null) return 1;
                  if (timeB == null) return -1;
                  return timeB.compareTo(timeA);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var ride = docs[index].data() as Map<String, dynamic>;
                    String status = ride['status'] ?? 'pending';
                    var badge = _getStatusBadge(status);

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        onTap: () => _showRideDetailsBottomSheet(context, ride, user.uid),
                        leading: CircleAvatar(
                          backgroundColor: (badge['color'] as Color).withOpacity(0.15),
                          child: Icon(badge['icon'], color: badge['color']),
                        ),
                        title: Text(
                          "To: ${ride['dropoffLocation'] ?? 'Unknown Location'}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Text(
                                "Status: ${badge['text']}",
                                style: TextStyle(color: badge['color'], fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const Text(" • ", style: TextStyle(color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  _formatTimestamp(ride['createdAt']),
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // trailing: Text(
                        //   "Rs. ${ride['fare'] ?? '0'}",
                        //   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFE91E63)),
                        // ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}