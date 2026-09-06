import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'admin_support_chat_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    "User Management",
    "Driver Management",
    "Ride History",
    "Support Chats",
    "SOS Configuration",
  ];

  Future<void> _logout(BuildContext context) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out of the Admin Portal?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2185B)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseAuth.instance.signOut();

        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error logging out: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: const Color(0xFFC2185B),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: "Logout",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFC2185B)),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, color: Color(0xFFC2185B), size: 40),
              ),
              accountName: const Text(
                "Admin Management Portal",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              accountEmail: Text(
                FirebaseAuth.instance.currentUser?.email ?? "admin@portal.com",
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFFC2185B)),
              title: const Text("Users"),
              selected: _selectedIndex == 0,
              selectedTileColor: const Color(0xFFFFEBEE),
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_taxi, color: Color(0xFFC2185B)),
              title: const Text("Drivers"),
              selected: _selectedIndex == 1,
              selectedTileColor: const Color(0xFFFFEBEE),
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFFC2185B)),
              title: const Text("Rides"),
              selected: _selectedIndex == 2,
              selectedTileColor: const Color(0xFFFFEBEE),
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFFC2185B)),
              title: const Text("Support"),
              selected: _selectedIndex == 3,
              selectedTileColor: const Color(0xFFFFEBEE),
              onTap: () {
                setState(() => _selectedIndex = 3);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shield, color: Color(0xFFC2185B)),
              title: const Text("SOS Config"),
              selected: _selectedIndex == 4,
              selectedTileColor: const Color(0xFFFFEBEE),
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_selectedIndex != 4) const AdminSOSConfigCard(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                UserListStream(key: PageStorageKey('passenger_view'), role: 'passenger'),
                UserListStream(key: PageStorageKey('driver_view'), role: 'driver'),
                AllRideHistoryStream(key: PageStorageKey('rides_view')),
                AdminSupportChatListScreen(key: PageStorageKey('chats_view')),
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      AdminSOSConfigCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSOSConfigCard extends StatefulWidget {
  const AdminSOSConfigCard({super.key});

  @override
  State<AdminSOSConfigCard> createState() => _AdminSOSConfigCardState();
}

class _AdminSOSConfigCardState extends State<AdminSOSConfigCard> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCurrentEmergencyNumber();
  }

  Future<void> _fetchCurrentEmergencyNumber() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('women_safety_data')
          .doc('admin_settings')
          .collection('sos_config')
          .doc('emergency_contact')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _phoneController.text = data['emergency_phone'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _saveEmergencyNumber() async {
    String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('women_safety_data')
          .doc('admin_settings')
          .collection('sos_config')
          .doc('emergency_contact')
          .set({
        'emergency_phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Admin Emergency SOS Number Updated!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update number: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC2185B).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield, color: Color(0xFFC2185B)),
              SizedBox(width: 8),
              Text(
                "Login/Signup SOS Destination Number",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2185B), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: "Enter emergency number (e.g. 03001234567)",
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2185B)),
                onPressed: _isLoading ? null : _saveEmergencyNumber,
                child: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UserListStream extends StatefulWidget {
  final String role;
  const UserListStream({super.key, required this.role});

  @override
  State<UserListStream> createState() => _UserListStreamState();
}

class _UserListStreamState extends State<UserListStream> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  String _getDocPath() {
    return widget.role == 'driver' ? 'riders_data' : 'users_data';
  }

  Future<void> _deleteUser(BuildContext context, String docId, String userName) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete '$userName'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('women_safety_data')
            .doc(_getDocPath())
            .collection('profiles')
            .doc(docId)
            .delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$userName deleted successfully."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to delete user: $e"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDriver = widget.role == 'driver';
    String roleTitle = isDriver ? 'Drivers' : 'Users';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('women_safety_data')
          .doc(_getDocPath())
          .collection('profiles')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error fetching ${widget.role} data: ${snapshot.error}"));
        }

        final allUsers = snapshot.data?.docs ?? [];
        final int totalCount = allUsers.length;

        final filteredUsers = allUsers.where((doc) {
          final userData = doc.data() as Map<String, dynamic>;
          final email = (userData['email'] ?? '').toString().toLowerCase();
          final name = (userData['name'] ?? '').toString().toLowerCase();
          final phone = (userData['phone'] ?? '').toString().toLowerCase();

          return email.contains(_searchQuery) ||
              name.contains(_searchQuery) ||
              phone.contains(_searchQuery);
        }).toList();

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: const Color(0xFFC2185B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total Registered $roleTitle",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC2185B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "$totalCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search by email, name, or phone...",
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFC2185B)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: const Color(0xFFC2185B).withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: const Color(0xFFC2185B).withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xFFC2185B)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _searchQuery.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDriver ? Icons.local_taxi_outlined : Icons.person_search_outlined,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Type to search for a specific ${isDriver ? 'driver' : 'user'}",
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Text(
                            "No ${isDriver ? 'driver' : 'user'} matches '$_searchQuery'.",
                            style: const TextStyle(color: Colors.grey, fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredUsers.length,
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            final doc = filteredUsers[index];
                            final userData = doc.data() as Map<String, dynamic>;
                            final String name = userData['name'] ?? 'No Name';

                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDriver ? Colors.purple.shade100 : Colors.pink.shade100,
                                  child: Icon(
                                    isDriver ? Icons.local_taxi : Icons.person,
                                    color: const Color(0xFFC2185B),
                                  ),
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Email: ${userData['email'] ?? 'N/A'}"),
                                    Text("Phone: ${userData['phone'] ?? 'N/A'}"),
                                    if (isDriver) ...[
                                      Text("Vehicle: ${userData['vehicleType'] ?? 'N/A'}"),
                                      if (userData.containsKey('cnic_status'))
                                        Text("CNIC Status: ${userData['cnic_status']}"),
                                    ],
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteUser(context, doc.id, name),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class AllRideHistoryStream extends StatelessWidget {
  const AllRideHistoryStream({super.key});

  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return {'color': Colors.green, 'text': 'Completed', 'icon': Icons.check_circle};
      case 'cancelled':
        return {'color': Colors.red, 'text': 'Cancelled', 'icon': Icons.cancel};
      case 'accepted':
        return {'color': Colors.blue, 'text': 'In Progress', 'icon': Icons.directions_car};
      case 'rejected':
        return {'color': Colors.orange, 'text': 'Declined', 'icon': Icons.block};
      case 'pending':
      default:
        return {'color': Colors.amber.shade800, 'text': 'Pending', 'icon': Icons.hourglass_empty};
    }
  }

  Future<void> _deleteRideRecord(BuildContext context, String rideId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Ride Record"),
        content: const Text("Are you sure you want to permanently remove this ride log?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ride log deleted."), backgroundColor: Colors.redAccent),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error deleting ride: $e"), backgroundColor: Colors.orange),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text("Error fetching rides: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No ride history records found."));
        }

        var rides = snapshot.data!.docs;

        rides.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          Timestamp? timeA = dataA['createdAt'] as Timestamp?;
          Timestamp? timeB = dataB['createdAt'] as Timestamp?;
          if (timeA == null) return 1;
          if (timeB == null) return -1;
          return timeB.compareTo(timeA);
        });

        return ListView.builder(
          itemCount: rides.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final doc = rides[index];
            final ride = doc.data() as Map<String, dynamic>;
            final status = ride['status'] ?? 'pending';
            final statusStyle = _getStatusStyle(status);

            return Card(
              elevation: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_pin, color: Color(0xFFC2185B)),
                            const SizedBox(width: 6),
                            Text(
                              ride['passengerName'] ?? 'Passenger',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (statusStyle['color'] as Color).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(statusStyle['icon'], size: 14, color: statusStyle['color']),
                              const SizedBox(width: 4),
                              Text(
                                statusStyle['text'],
                                style: TextStyle(
                                  color: statusStyle['color'],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 15),
                    Row(
                      children: [
                        const Icon(Icons.drive_eta, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          "Driver: ${ride['driverName'] ?? 'Not Assigned'} (${ride['vehicleType'] ?? 'N/A'})",
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.my_location, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text("Pickup: ${ride['pickupLocation'] ?? 'N/A'}", style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text("Dropoff: ${ride['dropoffLocation'] ?? 'N/A'}", style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    if (status == 'cancelled') ...[
                      const SizedBox(height: 8),
                      Text(
                        "Cancelled By: ${ride['cancelledBy'] ?? 'N/A'} • Reason: ${ride['cancellationReason'] ?? 'None'}",
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                    const Divider(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Fare: Rs. ${ride['fare'] ?? '0'}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC2185B)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: "Delete Ride Record",
                          onPressed: () => _deleteRideRecord(context, doc.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}