import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _mapController = MapController();
  LatLng? _currentPosition;
  bool _locationEnabled = false;
  String _selectedRideType = 'Individual';
  bool _isSidebarOpen = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _locationEnabled = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _locationEnabled = true;
    });
    _mapController.move(_currentPosition!, 15.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map (Full Screen)
          _currentPosition == null
              ? const Center(child: CircularProgressIndicator(color: Colors.pink))
              : FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition!,
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.women_safety_ride',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on, color: Colors.pink, size: 30),
                  ),
                ],
              ),
            ],
          ),

          // Top Bar (Menu + SOS)
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Menu Button
                GestureDetector(
                  onTap: () => setState(() => _isSidebarOpen = true),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.menu, color: Color(0xFFE91E63)),
                  ),
                ),
                // SOS Button
                GestureDetector(
                  onTap: () => _showSOSDialog(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Content (All visible!)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Promotion Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          "20% OFF on your first ride!",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Individual/Group Selection
                    Row(
                      children: [
                        Expanded(
                          child: _buildRideTypeButton('Individual', Icons.person),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildRideTypeButton('Group', Icons.people),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const TextField(
                        decoration: InputDecoration(
                          hintText: "Where to?",
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search, color: Colors.pink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ride Options
                    const Text(
                      "Choose a ride",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildRideOption(Icons.motorcycle, "Scooty"),
                        const SizedBox(width: 10),
                        _buildRideOption(Icons.directions_car, "Car"),
                        const SizedBox(width: 10),
                        _buildRideOption(Icons.car_rental, "Ride Now"),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Recent Places
                    const Text(
                      "Recent places",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildRecentPlace("San Ram Road"),
                    _buildRecentPlace("International Housing Society"),
                    _buildRecentPlace("Green View Road"),
                    const SizedBox(height: 20),

                    // Find Ride Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text(
                          "FIND RIDE",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sidebar (Opens when menu clicked)
          if (_isSidebarOpen)
            GestureDetector(
              onTap: () => setState(() => _isSidebarOpen = false),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          if (_isSidebarOpen)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 280,
                color: Colors.white,
                child: Column(
                  children: [
                    // Profile Header
                    Container(
                      height: 180,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.person, color: Color(0xFFE91E63)),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _isSidebarOpen = false),
                                  child: const Icon(Icons.close, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Sarah Khan",
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _locationEnabled ? "📍 Location ON" : "📍 Location OFF",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Menu Items
                    Expanded(
                      child: ListView(
                        children: [
                          _buildMenuItem(Icons.home, "Home"),
                          _buildMenuItem(Icons.history, "Ride History"),
                          _buildMenuItem(Icons.payment, "Payments"),
                          _buildMenuItem(Icons.security, "Safety Tips"),
                          _buildMenuItem(Icons.contact_phone, "Emergency Contacts"),
                          _buildMenuItem(Icons.support_agent, "Support"),
                          _buildMenuItem(Icons.settings, "Settings"),
                          const Divider(),
                          _buildMenuItem(Icons.logout, "Logout", color: Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {Color color = Colors.black87}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: () {},
    );
  }

  Widget _buildRideTypeButton(String type, IconData icon) {
    bool isSelected = _selectedRideType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedRideType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.pink : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.pink : Colors.grey),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 5),
            Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildRideOption(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.pink),
            const SizedBox(height: 5),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentPlace(String place) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.purple, size: 16),
          const SizedBox(width: 10),
          Text(place),
        ],
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("🚨 SOS Emergency"),
        content: const Text("Your location will be shared with emergency contacts."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("🚨 SOS Alert Sent!"), backgroundColor: Colors.red),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("SEND SOS"),
          ),
        ],
      ),
    );
  }
}