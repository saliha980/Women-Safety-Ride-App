import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import all your screens
import 'login_screen.dart';
import 'ride_history_screen.dart';
import 'payment_screen.dart';
import 'safety_safe_ride.dart';
import 'emergency_contacts_screen.dart';
import 'support_screen.dart';
import 'admin_dashboard_screen.dart';
import 'settings_screen.dart';
import 'sos_screen.dart';
import 'sos_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final DateTime bookingCutoffDate =
      DateTime(2026, 9, 12, 23, 59, 59);

  final MapController _mapController = MapController();
  final TextEditingController _destinationController = TextEditingController();

  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  String _currentAddress = "Fetching position...";
  String _currentCity = "Faisalabad";

  String _selectedRideType = 'Individual';
  String _selectedVehicleOption = 'Rickshaw';
  bool _isSidebarOpen = false;
  bool _isBooking = false;
  String _userName = "Loading...";
  String _userCity = "Fetching position...";
  String? _profilePic;
  bool _isAdmin = false;

  // First ride discount tracking
  bool _hasUsedFirstRideDiscount = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _userProfileSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenToUserData();
  }

  @override
  void dispose() {
    _userProfileSubscription?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  // Real-time listener fetching profile & discount state
  void _listenToUserData() {
    User? user = _auth.currentUser;
    if (user == null) return;

    if (user.email == "admin123@gmail.com") {
      setState(() {
        _isAdmin = true;
        _userName = "Admin Panel";
        _userCity = "Admin Location";
      });
      return;
    }

    DocumentReference userRef = _firestore
        .collection('women_safety_data')
        .doc('users_data')
        .collection('profiles')
        .doc(user.uid);

    _userProfileSubscription = userRef.snapshots().listen((docSnapshot) {
      if (docSnapshot.exists && docSnapshot.data() != null) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _userName = data['name'] ?? "User";
            _userCity = data['city'] ?? "Faisalabad";
            _profilePic = data['profilePic'] ?? data['profileImagePath'];
            _currentCity = _userCity;
            _hasUsedFirstRideDiscount =
                data['hasUsedFirstRideDiscount'] ?? false;
          });
        }
      } else {
        _userProfileSubscription?.cancel();
        DocumentReference riderRef = _firestore
            .collection('women_safety_data')
            .doc('riders_data')
            .collection('profiles')
            .doc(user.uid);

        _userProfileSubscription = riderRef.snapshots().listen((riderSnapshot) {
          if (riderSnapshot.exists && riderSnapshot.data() != null) {
            Map<String, dynamic> data =
                riderSnapshot.data() as Map<String, dynamic>;
            if (mounted) {
              setState(() {
                _userName = data['name'] ?? "User";
                _userCity = data['city'] ?? "Faisalabad";
                _profilePic = data['profilePic'] ?? data['profileImagePath'];
                _currentCity = _userCity;
                _hasUsedFirstRideDiscount =
                    data['hasUsedFirstRideDiscount'] ?? false;
              });
            }
          }
        });
      }
    });
  }

  Future<void> _handleLogout() async {
    await _userProfileSubscription?.cancel();
    await _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _navigateTo(Widget screen) async {
    setState(() => _isSidebarOpen = false);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    LatLng userLatLng = LatLng(position.latitude, position.longitude);

    if (mounted) {
      setState(() {
        _currentPosition = userLatLng;
      });
    }

    _mapController.move(userLatLng, 15.0);
    _getAddressFromCoordinates(userLatLng, isPickup: true);
  }

  Future<void> _getAddressFromCoordinates(LatLng point,
      {bool isPickup = false}) async {
    try {
      final geocoding.Geocoding geocodingService = geocoding.Geocoding();
      List<geocoding.Placemark> placemarks =
          await geocodingService.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks[0];
        String addressStr =
            "${place.street ?? ''}, ${place.subLocality ?? place.locality ?? ''}"
                .trim();
        if (addressStr.startsWith(','))
          addressStr = addressStr.substring(1).trim();

        if (mounted) {
          setState(() {
            if (isPickup) {
              _currentAddress =
                  addressStr.isNotEmpty ? addressStr : "Current Location";
            } else {
              _destinationPosition = point;
              _destinationController.text = addressStr.isNotEmpty
                  ? addressStr
                  : "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
            }
          });
        }
      }
    } catch (e) {
      if (!isPickup && mounted) {
        setState(() {
          _destinationPosition = point;
          _destinationController.text =
              "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
        });
      }
    }
  }

  void _onMapTapped(TapPosition tapPosition, LatLng point) {
    _getAddressFromCoordinates(point, isPickup: false);
  }

  Future<void> _cancelRideByPassenger(String rideId) async {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Are you sure you want to cancel this ride request?"),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
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
                  ? "Cancelled by passenger"
                  : reasonController.text.trim();

              try {
                await _firestore.collection('rides').doc(rideId).update({
                  'status': 'cancelled',
                  'cancelledBy': 'passenger',
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

  Future<void> _submitRideRequest() async {
    if (DateTime.now().isAfter(bookingCutoffDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ride booking is no longer available."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String destination = _destinationController.text.trim();

    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a destination or tap on the map."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    User? user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("User session invalid. Please log in again.")),
      );
      return;
    }

    setState(() => _isBooking = true);

    try {
      QuerySnapshot driverSnapshot = await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .where('isAvailable', isEqualTo: true)
          .where('vehicleType', isEqualTo: _selectedVehicleOption)
          .where('city', isEqualTo: _currentCity)
          .get();

      if (driverSnapshot.docs.isEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("No Drivers Available"),
              content: Text(
                  "There are currently no online $_selectedVehicleOption drivers available in $_currentCity. Please try again shortly."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK",
                      style: TextStyle(color: Color(0xFFE91E63))),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Calculate Fare: 20% discount if first ride
      double baseFare = 150.0;
      bool isDiscountApplied = !_hasUsedFirstRideDiscount;
      double finalFare = isDiscountApplied ? (baseFare * 0.80) : baseFare;

      DocumentReference rideRef = await _firestore.collection('rides').add({
        'passengerId': user.uid,
        'passengerName': _userName,
        'pickupLocation': _currentAddress,
        'pickupLat': _currentPosition?.latitude,
        'pickupLng': _currentPosition?.longitude,
        'dropoffLocation': destination,
        'dropoffLat': _destinationPosition?.latitude,
        'dropoffLng': _destinationPosition?.longitude,
        'rideCategory': _selectedRideType,
        'vehicleType': _selectedVehicleOption,
        'city': _currentCity,
        'fare': finalFare,
        'isFirstRideDiscountApplied': isDiscountApplied,
        'status': 'pending',
        'driverId': null,
        'driverName': null,
        'driverPhone': null,
        'driverVehicleNumber': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _destinationController.clear();
        _destinationPosition = null;
        _showRideStatusBottomSheet(rideRef.id);
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Firebase error (${e.code}): ${e.message ?? e}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to place ride request: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  // --- RATING & FEEDBACK SYSTEM ---
  Future<void> _showRatingDialog(String rideId, String driverUid) async {
    double rating = 5.0;
    TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Rate Your Driver",
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("How was your ride experience?",
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          rating = index + 1.0;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: reviewController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: "Write a short feedback (optional)...",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _submitFeedback(
                      rideId, driverUid, rating, reviewController.text.trim());
                },
                child: const Text("SUBMIT FEEDBACK",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitFeedback(
      String rideId, String driverUid, double rating, String review) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'rating': rating,
        'review': review,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      if (driverUid.isNotEmpty) {
        DocumentReference driverRef = _firestore
            .collection('women_safety_data')
            .doc('riders_data')
            .collection('profiles')
            .doc(driverUid);

        await _firestore.runTransaction((transaction) async {
          DocumentSnapshot driverSnap = await transaction.get(driverRef);
          if (driverSnap.exists) {
            var data = driverSnap.data() as Map<String, dynamic>;
            int totalRatings = (data['totalRatings'] ?? 0) + 1;
            double currentAvg = (data['rating'] as num?)?.toDouble() ?? 5.0;

            double newAvg =
                ((currentAvg * (totalRatings - 1)) + rating) / totalRatings;

            transaction.set(
                driverRef,
                {
                  'rating': double.parse(newAvg.toStringAsFixed(1)),
                  'totalRatings': totalRatings,
                },
                SetOptions(merge: true));
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Thank you for your feedback!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error submitting feedback: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper method to mark first ride discount as used upon completion
  Future<void> _markFirstRideDiscountUsed(String passengerId) async {
    try {
      await _firestore
          .collection('women_safety_data')
          .doc('users_data')
          .collection('profiles')
          .doc(passengerId)
          .set({'hasUsedFirstRideDiscount': true}, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating discount status: $e");
    }
  }

  void _showRideStatusBottomSheet(String rideId) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _firestore.collection('rides').doc(rideId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFE91E63))),
              );
            }

            var ride = snapshot.data!.data() as Map<String, dynamic>;
            String status = ride['status'] ?? 'pending';

            if (status == 'pending') {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFE91E63)),
                    const SizedBox(height: 20),
                    const Text("Finding your driver...",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        "Notifying nearby $_selectedVehicleOption drivers in $_currentCity.",
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _cancelRideByPassenger(rideId),
                      icon: const Icon(Icons.cancel),
                      label: const Text("CANCEL REQUEST"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white),
                    )
                  ],
                ),
              );
            } else if (status == 'accepted') {
              String driverUid = ride['driverId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: driverUid.isNotEmpty
                    ? _firestore
                        .collection('women_safety_data')
                        .doc('riders_data')
                        .collection('profiles')
                        .doc(driverUid)
                        .get()
                    : null,
                builder: (context, driverSnapshot) {
                  String driverName = ride['driverName'] ?? 'Assigned Driver';
                  String driverPhone = ride['driverPhone'] ?? 'N/A';
                  String vehicleType = ride['vehicleType'] ?? '';
                  String vehiclePlate = ride['driverVehicleNumber'] ??
                      ride['vehicleNumber'] ??
                      '';

                  if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
                    var driverData =
                        driverSnapshot.data!.data() as Map<String, dynamic>;
                    if (driverName == 'Assigned Driver' || driverName.isEmpty) {
                      driverName = driverData['name'] ?? driverName;
                    }
                    if (driverPhone == 'N/A' || driverPhone.isEmpty) {
                      driverPhone = driverData['phone'] ?? driverPhone;
                    }
                    if (vehiclePlate.isEmpty || vehiclePlate == 'N/A') {
                      vehiclePlate = driverData['vehicleNumber'] ??
                          driverData['vehicleNo'] ??
                          driverData['plateNumber'] ??
                          '';
                    }
                  }

                  String vehicleText =
                      vehicleType.isNotEmpty ? vehicleType : 'Vehicle';
                  if (vehiclePlate.isNotEmpty && vehiclePlate != 'N/A') {
                    vehicleText = "$vehicleText ($vehiclePlate)";
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Ride Accepted!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          "Driver: $driverName",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Phone: $driverPhone",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Vehicle: $vehicleText",
                          style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          "Your driver is on the way!",
                          style: TextStyle(
                            color: Color(0xFFC2185B),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () => _cancelRideByPassenger(rideId),
                          icon: const Icon(Icons.cancel_outlined,
                              color: Color(0xFFE53935), size: 18),
                          label: const Text(
                            "CANCEL RIDE",
                            style: TextStyle(
                              color: Color(0xFFE53935),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE53935)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 10),
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            } else if (status == 'completed') {
              String driverUid = ride['driverId'] ?? '';
              String passengerId = ride['passengerId'] ?? '';
              bool isRated = ride.containsKey('rating');

              // Ensure the first-ride discount flag is set to used in Firestore
              if (ride['isFirstRideDiscountApplied'] == true &&
                  passengerId.isNotEmpty) {
                _markFirstRideDiscountUsed(passengerId);
              }

              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 60),
                    const SizedBox(height: 10),
                    const Text("Ride Completed!",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text("Total Fare Paid: Rs. ${ride['fare']}",
                        style: const TextStyle(fontSize: 16)),
                    if (ride['isFirstRideDiscountApplied'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 4.0),
                        child: Text(
                          "(20% First Ride Discount Applied)",
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (!isRated) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRatingDialog(rideId, driverUid);
                        },
                        icon: const Icon(Icons.star, color: Colors.white),
                        label: const Text("GIVE FEEDBACK"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[800],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE91E63),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("DONE"),
                    )
                  ],
                ),
              );
            } else if (status == 'rejected') {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel, color: Colors.red, size: 60),
                    const SizedBox(height: 10),
                    const Text("Ride Declined",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                    const SizedBox(height: 10),
                    const Text("The driver was unable to accept your request.",
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white),
                      child: const Text("TRY AGAIN"),
                    )
                  ],
                ),
              );
            } else if (status == 'cancelled') {
              String cancelledBy =
                  ride['cancelledBy'] == 'driver' ? 'Driver' : 'You';
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.orange, size: 60),
                    const SizedBox(height: 10),
                    const Text("Ride Cancelled",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange)),
                    const SizedBox(height: 10),
                    Text("This ride was cancelled by $cancelledBy.",
                        style: const TextStyle(color: Colors.grey)),
                    if (ride['cancellationReason'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text("Reason: ${ride['cancellationReason']}",
                            style: const TextStyle(
                                color: Colors.black54,
                                fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          foregroundColor: Colors.white),
                      child: const Text("CLOSE"),
                    )
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _currentPosition == null
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.pink))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('women_safety_data')
                      .doc('riders_data')
                      .collection('profiles')
                      .where('isAvailable', isEqualTo: true)
                      .where('vehicleType', isEqualTo: _selectedVehicleOption)
                      .where('city', isEqualTo: _currentCity)
                      .snapshots(),
                  builder: (context, driverSnapshot) {
                    List<Marker> markers = [];

                    markers.add(
                      Marker(
                        point: _currentPosition!,
                        width: 45,
                        height: 45,
                        child: const Icon(Icons.my_location,
                            color: Color(0xFFE91E63), size: 36),
                      ),
                    );

                    if (_destinationPosition != null) {
                      markers.add(
                        Marker(
                          point: _destinationPosition!,
                          width: 45,
                          height: 45,
                          child: const Icon(Icons.location_on,
                              color: Colors.purple, size: 40),
                        ),
                      );
                    }

                    if (driverSnapshot.hasData) {
                      for (var doc in driverSnapshot.data!.docs) {
                        var data = doc.data() as Map<String, dynamic>;
                        if (data['latitude'] != null &&
                            data['longitude'] != null) {
                          markers.add(
                            Marker(
                              point:
                                  LatLng(data['latitude'], data['longitude']),
                              width: 40,
                              height: 40,
                              child: Icon(
                                _selectedVehicleOption == 'Scooty'
                                    ? Icons.motorcycle
                                    : (_selectedVehicleOption == 'Car'
                                        ? Icons.directions_car
                                        : Icons.electric_rickshaw),
                                color: Colors.green,
                                size: 30,
                              ),
                            ),
                          );
                        }
                      }
                    }

                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition!,
                        initialZoom: 15.0,
                        onTap: _onMapTapped,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.women_safety_ride',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    );
                  },
                ),
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _isSidebarOpen = true),
                  child: _circleButton(Icons.menu),
                ),
                GestureDetector(
                  onTap: () => _showSOSDialog(context),
                  child: _circleButton(Icons.warning,
                      color: Colors.red, iconColor: Colors.white),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.54,
            child: FloatingActionButton(
              heroTag: "recenter_btn",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (_currentPosition != null) {
                  _mapController.move(_currentPosition!, 15.0);
                }
              },
              child: const Icon(Icons.gps_fixed, color: Color(0xFFE91E63)),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomBookingSheet(),
          ),
          if (_isSidebarOpen) _buildSidebarOverlay(),
          if (_isSidebarOpen) _buildSidebarMenu(),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon,
      {Color color = Colors.white, Color iconColor = const Color(0xFFE91E63)}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)]),
      child: Icon(icon, color: iconColor),
    );
  }

  Widget _buildSidebarOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _isSidebarOpen = false),
      child: Container(color: Colors.black.withOpacity(0.5)),
    );
  }

  Widget _buildRideTypeButton(String type, IconData icon) {
    bool isSelected = _selectedRideType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRideType = type;
          if (_selectedRideType == 'Group' &&
              _selectedVehicleOption == 'Scooty') {
            _selectedVehicleOption = 'Rickshaw';
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE91E63) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  isSelected ? const Color(0xFFE91E63) : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(type,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPlace(String place) {
    return InkWell(
      onTap: () {
        setState(() {
          _destinationController.text = place;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.history, color: Colors.purple, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                place,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPlacesList() {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('rides')
          .where('passengerId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child:
                LinearProgressIndicator(color: Color(0xFFE91E63), minHeight: 2),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No recent places found",
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          );
        }

        List<String> places = [];
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          String? dropoff = data['dropoffLocation'] as String?;
          if (dropoff != null &&
              dropoff.trim().isNotEmpty &&
              !places.contains(dropoff.trim())) {
            places.add(dropoff.trim());
          }
          if (places.length >= 3) break;
        }

        if (places.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No recent places found",
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          );
        }

        return Column(
          children: places.map((place) => _buildRecentPlace(place)).toList(),
        );
      },
    );
  }

  Widget _buildSidebarMenu() {
    String currentModeText = _isAdmin ? "Admin Mode" : "User Mode";
    Color modeButtonColor = _isAdmin ? const Color(0xFF9C27B0) : Colors.pink;
    final ThemeData theme = Theme.of(context);

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Material(
        color: theme.colorScheme.surface,
        child: SizedBox(
          width: 280,
          child: Column(
            children: [
              _buildSidebarHeader(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _menuItem(Icons.home, "Home",
                        () => setState(() => _isSidebarOpen = false)),
                    if (_isAdmin) ...[
                      const Divider(thickness: 2, color: Colors.purple),
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                        child: Text("ADMIN Panel",
                            style: TextStyle(
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      _menuItem(Icons.admin_panel_settings, "Admin Dashboard",
                          () => _navigateTo(const AdminDashboardScreen()),
                          color: Colors.purple),
                      const Divider(thickness: 2, color: Colors.purple),
                    ],
                    _menuItem(Icons.history, "Ride History",
                        () => _navigateTo(const RideHistoryScreen())),
                    _menuItem(Icons.payment, "Payments",
                        () => _navigateTo(const PaymentsScreen())),
                    _menuItem(Icons.security, "Safety Tips",
                        () => _navigateTo(const SafetyTipsScreen())),
                    _menuItem(Icons.contact_phone, "Emergency Contacts",
                        () => _navigateTo(const EmergencyContactsScreen())),
                    _menuItem(Icons.history_toggle_off, "SOS History",
                        () => _navigateTo(const SOSHistoryScreen())),
                    _menuItem(Icons.support_agent, "Support",
                        () => _navigateTo(const SupportScreen())),
                    _menuItem(Icons.settings, "Settings",
                        () => _navigateTo(const SettingsScreen())),
                    const Divider(),
                    _menuItem(Icons.logout, "Logout", _handleLogout,
                        color: Colors.red),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 20.0),
                child: InkWell(
                  onTap: () {
                    if (_isAdmin) _navigateTo(const AdminDashboardScreen());
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: modeButtonColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: modeButtonColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        currentModeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    ImageProvider? profileImage;
    if (_profilePic != null && _profilePic!.isNotEmpty) {
      if (_profilePic!.startsWith('http://') ||
          _profilePic!.startsWith('https://')) {
        profileImage = NetworkImage(_profilePic!);
      } else {
        final File file = File(_profilePic!.replaceFirst('file://', ''));
        if (file.existsSync()) profileImage = FileImage(file);
      }
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient:
            LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.white,
              backgroundImage: profileImage,
              child: profileImage == null
                  ? Icon(_isAdmin ? Icons.admin_panel_settings : Icons.person,
                      size: 40, color: const Color(0xFFE91E63))
                  : null,
            ),
            const SizedBox(height: 15),
            Text(_userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(_isAdmin ? "System Administrator" : "📍 $_userCity",
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    final Color itemColor = color ?? Theme.of(context).colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, color: itemColor),
      title: Text(title,
          style: TextStyle(color: itemColor, fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  Widget _buildBottomBookingSheet() {
    final ThemeData theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 15),

            // DYNAMIC DISCOUNT BANNER: Hidden once the first ride discount is used
            if (!_hasUsedFirstRideDiscount) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    "20% OFF on your first ride!",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 15),
            ],

            Row(
              children: [
                Expanded(
                    child: _buildRideTypeButton('Individual', Icons.person)),
                const SizedBox(width: 10),
                Expanded(child: _buildRideTypeButton('Group', Icons.people)),
              ],
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                hintText: "Where to? (Tap map or enter place)",
                prefixIcon: Icon(Icons.search, color: Color(0xFFE91E63)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            Text("Choose a ride",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _rideOption(Icons.motorcycle, "Scooty"),
                _rideOption(Icons.directions_car, "Car"),
                _rideOption(Icons.electric_rickshaw, "Rickshaw"),
              ],
            ),
            const SizedBox(height: 15),

            Text("Recent places",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 5),
            _buildRecentPlacesList(),
            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: _isBooking ? null : _submitRideRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: _isBooking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _hasUsedFirstRideDiscount
                          ? "FIND RIDE"
                          : "FIND RIDE (20% OFF APPLIED)",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _rideOption(IconData icon, String label) {
    bool isSelected = _selectedVehicleOption == label;
    bool isDisabled = _selectedRideType == 'Group' && label == 'Scooty';

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () => setState(() => _selectedVehicleOption = label),
      child: Opacity(
        opacity: isDisabled ? 0.35 : 1.0,
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: isSelected
                  ? const Color(0xFFE91E63)
                  : (isDisabled ? Colors.grey[200] : Colors.pink[50]),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDisabled ? Colors.grey : const Color(0xFFE91E63)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? const Color(0xFFE91E63)
                    : (isDisabled
                        ? Colors.grey
                        : Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    SOSDialog.show(context);
  }
}
