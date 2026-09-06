import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'ride_history_screen.dart';
import 'sos_service.dart';
import 'support_screen.dart';
import 'settings_screen.dart';
import 'sos_history_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isOnline = true;

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isOnline = value);
    User? user = _auth.currentUser;

    if (user != null) {
      await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(user.uid)
          .update({'isAvailable': value});
    }
  }

  Future<void> _executeDriverSOS() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      List<String> targetPhoneNumbers = [];

      DocumentSnapshot driverDoc = await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(user.uid)
          .get();

      if (driverDoc.exists && driverDoc.data() != null) {
        var data = driverDoc.data() as Map<String, dynamic>;
        if (data.containsKey('emergency_contacts')) {
          var contacts = data['emergency_contacts'] as Map<String, dynamic>?;
          targetPhoneNumbers = contacts?.values
                  .map((phone) => phone.toString())
                  .where((phone) => phone.isNotEmpty)
                  .toList() ??
              [];
        }
      }
      if (targetPhoneNumbers.isEmpty) {
        DocumentSnapshot adminConfigDoc = await _firestore
            .collection('women_safety_data')
            .doc('admin_settings')
            .collection('sos_config')
            .doc('emergency_contact')
            .get();

        if (adminConfigDoc.exists && adminConfigDoc.data() != null) {
          var data = adminConfigDoc.data() as Map<String, dynamic>;
          final adminPhone = data['emergency_phone']?.toString() ?? "";
          if (adminPhone.isNotEmpty) {
            targetPhoneNumbers = [adminPhone];
          }
        }
      }

      if (targetPhoneNumbers.isEmpty) {
        targetPhoneNumbers = ["03000000000"];
      }

      final SOSService sosService = SOSService();
      await sosService.sendSOSAlert(emergencyPhones: targetPhoneNumbers);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "✅ Silent SOS Alert Dispatched to ${targetPhoneNumbers.join(', ')}!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Error sending SOS: ${e.toString().replaceAll('Exception: ', '')}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDriverSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("🚨 ", style: TextStyle(fontSize: 22)),
            Flexible(
              child: Text(
                "Driver SOS Emergency",
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: const Text(
          "Alert your emergency contact and send your current live GPS location silently?",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL",
                style:
                    TextStyle(color: Colors.pink, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4D4D),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🚨 Triggering Silent SOS Emergency Alert..."),
                  backgroundColor: Colors.orange,
                ),
              );
              await _executeDriverSOS();
            },
            child: const Text("SEND",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptRide(String rideId, String driverName, String driverPhone,
      String driverVehicleNumber) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'accepted',
        'driverId': user.uid,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverVehicleNumber': driverVehicleNumber,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Ride accepted! Head to pickup location."),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _rejectRide(String rideId) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'rejected',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Ride request declined."),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cancelRideByDriver(String rideId) async {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Are you sure you want to cancel this accepted ride?"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: "Reason for cancellation (optional)",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("NO, KEEP RIDE"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              String reason = reasonController.text.trim().isEmpty
                  ? "Cancelled by driver"
                  : reasonController.text.trim();

              try {
                await _firestore.collection('rides').doc(rideId).update({
                  'status': 'cancelled',
                  'cancelledBy': 'driver',
                  'cancellationReason': reason,
                  'cancelledAt': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Ride cancelled successfully."),
                        backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Error cancelling ride: $e"),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("YES, CANCEL"),
          ),
        ],
      ),
    );
  }

  Future<void> _completeRide(String rideId) async {
    User? driver = _auth.currentUser;
    if (driver == null) return;

    try {
      DocumentSnapshot rideDoc =
          await _firestore.collection('rides').doc(rideId).get();
      if (!rideDoc.exists) {
        throw Exception("Ride document does not exist.");
      }

      var rideData = rideDoc.data() as Map<String, dynamic>;
      String? passengerId = rideData['passengerId'];
      double fare = (rideData['fare'] as num?)?.toDouble() ?? 0.0;

      if (passengerId == null || passengerId.isEmpty) {
        throw Exception("Invalid passenger ID for this ride.");
      }

      DocumentReference passengerRef = _firestore
          .collection('women_safety_data')
          .doc('users_data')
          .collection('profiles')
          .doc(passengerId);

      DocumentReference driverRef = _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(driver.uid);

      DocumentReference rideRef = _firestore.collection('rides').doc(rideId);

      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot passengerSnapshot =
            await transaction.get(passengerRef);

        double passengerBalance = 0.0;
        if (passengerSnapshot.exists && passengerSnapshot.data() != null) {
          var pData = passengerSnapshot.data() as Map<String, dynamic>;
          passengerBalance =
              (pData['walletBalance'] as num?)?.toDouble() ?? 0.0;
        }

        if (passengerBalance < fare) {
          throw Exception(
              "Passenger has insufficient wallet balance (Rs. ${passengerBalance.toStringAsFixed(2)}).");
        }

        transaction.set(
            passengerRef,
            {'walletBalance': FieldValue.increment(-fare)},
            SetOptions(merge: true));

        transaction.set(
            driverRef,
            {'walletBalance': FieldValue.increment(fare)},
            SetOptions(merge: true));

        transaction.update(rideRef, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'paidAmount': fare,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Ride completed! Rs. ${fare.toStringAsFixed(2)} transferred to your wallet."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Error completing ride: ${e.toString().replaceAll("Exception: ", "")}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: (user != null)
          ? _firestore
              .collection('women_safety_data')
              .doc('riders_data')
              .collection('profiles')
              .doc(user.uid)
              .snapshots()
          : null,
      builder: (context, profileSnapshot) {
        String driverName = "Driver";
        String vehicleType = "Scooty";
        String driverCity = "Faisalabad";
        String driverPhone = "";
        String driverVehicleNumber = "";
        String? driverProfilePic;

        if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
          var data = profileSnapshot.data!.data() as Map<String, dynamic>?;
          if (data != null) {
            driverName = data['name'] ?? "Driver";
            vehicleType = data['vehicleType'] ?? "Scooty";
            driverCity = data['city'] ?? "Faisalabad";
            driverPhone = data['phone'] ?? "";
            driverVehicleNumber = data['vehicleNumber'] ?? "";
            driverProfilePic = data['profilePic'] ?? data['profileImagePath'];
            if (data.containsKey('isAvailable')) {
              _isOnline = data['isAvailable'] ?? true;
            }
          }
        }

        final ThemeData theme = Theme.of(context);
        final bool isDarkMode = theme.brightness == Brightness.dark;
        final Color primaryTextColor = theme.colorScheme.onSurface;
        final Color secondaryTextColor =
            isDarkMode ? Colors.white70 : Colors.grey.shade600;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Driver Dashboard",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showDriverSOSDialog,
            backgroundColor: const Color(0xFFFF4D4D),
            icon: const Icon(Icons.warning, color: Colors.white),
            label: const Text("SOS EMERGENCY",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          drawer: Drawer(
            child: Column(
              children: [
                UserAccountsDrawerHeader(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: _profileImage(driverProfilePic),
                    child: _profileImage(driverProfilePic) == null
                        ? Text(
                            driverName.isNotEmpty
                                ? driverName[0].toUpperCase()
                                : "D",
                            style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE91E63)),
                          )
                        : null,
                  ),
                  accountName: Text(driverName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  accountEmail: Text(
                      "$vehicleType • $driverCity | Status: ${_isOnline ? 'Online' : 'Offline'}"),
                ),
                ListTile(
                  leading: const Icon(Icons.dashboard_outlined,
                      color: Color(0xFFE91E63)),
                  title: const Text("Dashboard",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.history_outlined,
                      color: Color(0xFFE91E63)),
                  title: const Text("Ride History",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const RideHistoryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.history_toggle_off, color: Colors.red),
                  title: const Text(
                    'SOS History',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SOSHistoryScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sos, color: Colors.red),
                  title: const Text("Emergency SOS Alert",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _showDriverSOSDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent_outlined,
                      color: Color(0xFFE91E63)),
                  title: const Text("Support",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SupportScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined,
                      color: Color(0xFFE91E63)),
                  title: const Text("Settings",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(context);
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Logout",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? const [Color(0xFF1B171D), Color(0xFF2A202B)]
                    : [Colors.pink.shade50, Colors.purple.shade50],
              ),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.purple.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.pink.shade100,
                            child: const Icon(Icons.person,
                                color: Color(0xFFE91E63), size: 32),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driverName,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : const Color(0xFFC2185B))),
                                Text(
                                    "Vehicle: $vehicleType • City: $driverCity",
                                    style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 13)),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                _isOnline ? "ONLINE" : "OFFLINE",
                                style: TextStyle(
                                    color:
                                        _isOnline ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                              Switch(
                                value: _isOnline,
                                activeColor: const Color(0xFFE91E63),
                                onChanged: _toggleAvailability,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (user != null)
                        Builder(
                          builder: (context) {
                            double walletBalance = 0.0;
                            double driverRating = 5.0;
                            int totalRatings = 0;

                            if (profileSnapshot.hasData &&
                                profileSnapshot.data!.exists) {
                              var data = profileSnapshot.data!.data()
                                  as Map<String, dynamic>?;
                              if (data != null) {
                                walletBalance = (data['walletBalance'] as num?)
                                        ?.toDouble() ??
                                    0.0;
                                driverRating =
                                    (data['rating'] as num?)?.toDouble() ?? 5.0;
                                totalRatings =
                                    (data['totalRatings'] as num?)?.toInt() ??
                                        0;
                              }
                            }

                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border:
                                    Border.all(color: Colors.purple.shade100),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.account_balance_wallet,
                                              color: Color(0xFF9C27B0),
                                              size: 18),
                                          SizedBox(width: 6),
                                          Text("Wallet",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF9C27B0))),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        "Rs. ${walletBalance.toStringAsFixed(2)}",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE91E63),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.star,
                                              color: Colors.amber, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            driverRating.toStringAsFixed(1),
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: primaryTextColor),
                                          ),
                                        ],
                                      ),
                                      Text("($totalRatings reviews)",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Active & Pending Rides ($driverCity)",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFFC2185B))),
                  ),
                ),
                Expanded(
                  child: !_isOnline
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.portable_wifi_off,
                                  size: 60, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              const Text(
                                  "You are currently Offline.\nSwitch to Online to accept ride requests.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 15)),
                            ],
                          ),
                        )
                      : StreamBuilder<QuerySnapshot>(
                          stream: _firestore.collection('rides').snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFFE91E63)));
                            }

                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return Center(
                                  child: Text(
                                      "No ride requests available in $driverCity.",
                                      style:
                                          const TextStyle(color: Colors.grey)));
                            }

                            var rides = snapshot.data!.docs.where((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              String status = data['status'] ?? '';
                              String driverId = data['driverId'] ?? '';
                              String rideCity = (data['city'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();
                              String rideVehicle = (data['vehicleType'] ?? '')
                                  .toString()
                                  .trim()
                                  .toLowerCase();

                              bool matchesCity =
                                  rideCity == driverCity.trim().toLowerCase();
                              bool matchesVehicle = rideVehicle ==
                                  vehicleType.trim().toLowerCase();
                              bool isValidStatus = status == 'pending' ||
                                  (status == 'accepted' &&
                                      driverId == user?.uid);

                              return matchesCity &&
                                  matchesVehicle &&
                                  isValidStatus;
                            }).toList();

                            if (rides.isEmpty) {
                              return Center(
                                  child: Text(
                                      "No active ride requests in $driverCity.",
                                      style:
                                          const TextStyle(color: Colors.grey)));
                            }

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: rides.length,
                              itemBuilder: (context, index) {
                                var ride =
                                    rides[index].data() as Map<String, dynamic>;
                                String rideId = rides[index].id;
                                String status = ride['status'] ?? 'pending';

                                return Card(
                                  elevation: 4,
                                  margin: const EdgeInsets.only(bottom: 15),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                                ride['passengerName'] ??
                                                    "Passenger",
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                            Text("Rs. ${ride['fare'] ?? '0'}",
                                                style: const TextStyle(
                                                    color: Color(0xFFE91E63),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18)),
                                          ],
                                        ),
                                        const Divider(),
                                        Row(
                                          children: [
                                            const Icon(Icons.my_location,
                                                color: Colors.green, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Text(
                                                    "Pickup: ${ride['pickupLocation'] ?? ''}",
                                                    style: const TextStyle(
                                                        fontSize: 14))),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on,
                                                color: Colors.red, size: 20),
                                            const SizedBox(width: 10),
                                            Expanded(
                                                child: Text(
                                                    "Dropoff: ${ride['dropoffLocation'] ?? ''}",
                                                    style: const TextStyle(
                                                        fontSize: 14))),
                                          ],
                                        ),
                                        const SizedBox(height: 15),
                                        if (status == 'pending') ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _rejectRide(rideId),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(
                                                        color: Colors.red),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8),
                                                  ),
                                                  child: const Text("DECLINE",
                                                      maxLines: 1),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () => _acceptRide(
                                                      rideId,
                                                      driverName,
                                                      driverPhone,
                                                      driverVehicleNumber),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFE91E63),
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8),
                                                  ),
                                                  child: const Text("ACCEPT",
                                                      maxLines: 1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ] else if (status == 'accepted') ...[
                                          Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: OutlinedButton(
                                                  onPressed: () =>
                                                      _cancelRideByDriver(
                                                          rideId),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.red,
                                                    side: const BorderSide(
                                                        color: Colors.red),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6),
                                                  ),
                                                  child: const Text("CANCEL",
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 1,
                                                child: ElevatedButton.icon(
                                                  onPressed: () =>
                                                      _completeRide(rideId),
                                                  icon: const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.white,
                                                      size: 16),
                                                  label: const Text("COMPLETE",
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6),
                                                  ),
                                                ),
                                              ),
                                            ],
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ImageProvider? _profileImage(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    final File file = File(path.replaceFirst('file://', ''));
    return file.existsSync() ? FileImage(file) : null;
  }
}
