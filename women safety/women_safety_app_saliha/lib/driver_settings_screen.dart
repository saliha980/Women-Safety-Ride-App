import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'theme_controller.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _name = "";
  String _email = "";
  String _phone = "";
  String _city = "Faisalabad";
  String _vehicleType = "Scooty";
  String _vehicleNumber = "";
  String _motherPhone = "";
  String _fatherPhone = "";
  String? _profilePic;
  bool _isUploading = false;

  // Local UI state for Settings switches/dropdowns
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    loadDarkMode(isDriver: true);
    _loadDriverProfile();
  }

  Future<void> _loadDriverProfile() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    _email = user.email ?? "";

    try {
      DocumentSnapshot driverDoc = await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(user.uid)
          .get();

      if (driverDoc.exists && driverDoc.data() != null) {
        var data = driverDoc.data() as Map<String, dynamic>;
        var contacts = data['emergency_contacts'] as Map<String, dynamic>?;

        if (mounted) {
          setState(() {
            _name = data['name'] ?? "";
            _phone = data['phone'] ?? "";
            _city = data['city'] ?? "Faisalabad";
            _vehicleType = data['vehicleType'] ?? "Scooty";
            _vehicleNumber = data['vehicleNumber'] ?? "";
            _motherPhone = contacts?['mother'] ?? "";
            _fatherPhone = contacts?['parent'] ?? "";
            _profilePic = data['profilePic'] ?? data['profileImagePath'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndSaveProfileImage() async {
    final User? user = _auth.currentUser;
    if (user == null || _isUploading) return;

    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String imagePath = '${appDirectory.path}/profile_${user.uid}.jpg';
      await File(image.path).copy(imagePath);
      await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(user.uid)
          .set({
        'profilePic': imagePath,
        'profileImagePath': imagePath,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _profilePic = imagePath;
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profile picture updated successfully.'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not update profile picture: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  ImageProvider? _profileImage() {
    if (_profilePic == null || _profilePic!.isEmpty) return null;
    if (_profilePic!.startsWith('http://') ||
        _profilePic!.startsWith('https://')) {
      return NetworkImage(_profilePic!);
    }
    final File file = File(_profilePic!.replaceFirst('file://', ''));
    return file.existsSync() ? FileImage(file) : null;
  }

  Future<void> _updateDriverProfile({
    required String name,
    required String phone,
    required String city,
    required String vehicleType,
    required String vehicleNumber,
    required String motherPhone,
    required String fatherPhone,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(user.uid)
          .set({
        'name': name,
        'phone': phone,
        'city': city,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        'emergency_contacts': {
          'mother': motherPhone,
          'parent': fatherPhone,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _name = name;
          _phone = phone;
          _city = city;
          _vehicleType = vehicleType;
          _vehicleNumber = vehicleNumber;
          _motherPhone = motherPhone;
          _fatherPhone = fatherPhone;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Driver Profile updated successfully!"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error updating profile: $e"),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showEditProfileModal() {
    final nameController = TextEditingController(text: _name);
    final phoneController = TextEditingController(text: _phone);
    final vehicleNumController = TextEditingController(text: _vehicleNumber);
    final motherPhoneController = TextEditingController(text: _motherPhone);
    final fatherPhoneController = TextEditingController(text: _fatherPhone);
    String selectedCity = _city.isNotEmpty ? _city : "Faisalabad";
    String selectedVehicle = _vehicleType.isNotEmpty ? _vehicleType : "Scooty";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Edit Driver Profile",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE91E63))),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person, color: Color(0xFFE91E63)),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: Icon(Icons.phone, color: Color(0xFFE91E63)),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCity,
                        decoration: const InputDecoration(
                            labelText: "City", border: OutlineInputBorder()),
                        items: ["Faisalabad", "Lahore", "Islamabad", "Karachi"]
                            .map((city) {
                          return DropdownMenuItem(
                              value: city, child: Text(city));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => selectedCity = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedVehicle,
                        decoration: const InputDecoration(
                            labelText: "Vehicle", border: OutlineInputBorder()),
                        items: ["Scooty", "Bike", "Car", "Rikshaw"].map((type) {
                          return DropdownMenuItem(
                              value: type, child: Text(type));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null)
                            setModalState(() => selectedVehicle = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: vehicleNumController,
                  decoration: const InputDecoration(
                      labelText: "Vehicle Number (Plate)",
                      prefixIcon: Icon(Icons.numbers, color: Color(0xFFE91E63)),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motherPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Mother's Contact",
                      prefixIcon: Icon(Icons.female, color: Color(0xFFE91E63)),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatherPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: "Father/Guardian Contact",
                      prefixIcon: Icon(Icons.male, color: Color(0xFFE91E63)),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _updateDriverProfile(
                      name: nameController.text.trim(),
                      phone: phoneController.text.trim(),
                      city: selectedCity,
                      vehicleType: selectedVehicle,
                      vehicleNumber: vehicleNumController.text.trim(),
                      motherPhone: motherPhoneController.text.trim(),
                      fatherPhone: fatherPhoneController.text.trim(),
                    );
                  },
                  child: const Text("SAVE CHANGES",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                "Privacy Policy",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Women Ride Safety App",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 25),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      "1. Information Collection",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "We collect essential details to facilitate safe rides, including your registered name, phone number, city, and live location during active ride bookings.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.black.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "2. Location Data Usage",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "GPS location data is accessed solely to calculate pickup and dropoff routes, locate nearby available drivers, and ensure emergency safety tracking.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.black.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "3. Emergency & SOS Protection",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "In case of an activated SOS alert, your ride details and location coordinates are instantly prioritized to trigger quick emergency contacts and safety responses.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.black.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "4. Data Security & Storage",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Your credentials and booking records are securely handled using Firebase cloud encryption. We do not sell or trade your personal information to third parties.",
                      style: TextStyle(
                          fontSize: 13, color: Colors.black.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text("CLOSE",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Settings",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE91E63)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _pickAndSaveProfileImage,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.pink.shade100,
                                      backgroundImage: _profileImage(),
                                      child: _profileImage() == null
                                          ? const Icon(Icons.two_wheeler,
                                              color: Color(0xFFE91E63),
                                              size: 36)
                                          : null,
                                    ),
                                    if (_isUploading)
                                      const CircularProgressIndicator(
                                          color: Color(0xFFE91E63)),
                                    if (!_isUploading)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                              color: Color(0xFFE91E63),
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.camera_alt,
                                              size: 12, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_name.isEmpty ? "Driver" : _name,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    Text(_email,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                    Text(
                                        "${_phone.isEmpty ? 'No phone' : _phone} • $_city",
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 13)),
                                    Text(
                                        "Vehicle: $_vehicleType (${_vehicleNumber.isEmpty ? 'N/A' : _vehicleNumber})",
                                        style: const TextStyle(
                                            color: Color(0xFFE91E63),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.pink.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "DRIVER",
                                  style: TextStyle(
                                      color: Color(0xFFE91E63),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE91E63),
                              side: const BorderSide(color: Color(0xFFE91E63)),
                              minimumSize: const Size.fromHeight(42),
                            ),
                            onPressed: _showEditProfileModal,
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text("EDIT DRIVER PROFILE",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // PREFERENCES SECTION
                  Material(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    elevation: 1,
                    child: Column(
                      children: [
                        // Dark Mode Toggle Switch
                        ValueListenableBuilder<bool>(
                          valueListenable: darkModeNotifier,
                          builder: (context, isDarkMode, child) {
                            return SwitchListTile(
                              title: const Text("Dark Mode"),
                              value: isDarkMode,
                              activeColor: const Color(0xFFE91E63),
                              onChanged: (value) =>
                                  setDarkMode(value, isDriver: true),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // Language Dropdown (English only)
                        ListTile(
                          title: const Text(
                            "Language",
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLanguage,
                              items: <String>['English'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(
                                    value,
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedLanguage = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const Divider(height: 1),

                        // Privacy Policy
                        ListTile(
                          title: const Text(
                            "Privacy Policy",
                            style: const TextStyle(fontSize: 16),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: _showPrivacyPolicyModal,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
