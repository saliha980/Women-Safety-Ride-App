import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'login_screen.dart';
import 'theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local UI State for Settings
  bool _isUploading = false;
  bool _isDriverProfile = false;
  String _selectedLanguage = 'English';

  final List<String> _locations = [
    'Faisalabad',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Karachi',
    'Multan',
    'Peshawar',
    'Sialkot',
  ];

  final List<String> _vehicleTypes = ['Scooty', 'Car', 'Rickshaw'];

  @override
  void initState() {
    super.initState();
    _loadThemeForProfile();
  }

  Future<void> _loadThemeForProfile() async {
    final profile = await _getUserProfile();
    if (!mounted) return;

    final isDriver = profile?.reference.parent.parent?.id == 'riders_data';
    setState(() => _isDriverProfile = isDriver);
    await loadDarkMode(isDriver: isDriver);
  }

  // --- PHONE VALIDATION HELPER ---
  bool _isValidPhoneNumber(String phone) {
    String cleaned = phone.trim();

    RegExp phoneRegex = RegExp(r'^\+923\d{9}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return false;
    }

    String remainingDigits = cleaned.substring(4);

    Set<String> uniqueDigits = remainingDigits.split('').toSet();
    if (uniqueDigits.length == 1) {
      return false;
    }

    return true;
  }

  // --- FETCH USER OR DRIVER PROFILE DATA ---
  Future<DocumentSnapshot?> _getUserProfile() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot userDoc = await _firestore
        .collection('women_safety_data')
        .doc('users_data')
        .collection('profiles')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      return userDoc;
    }

    DocumentSnapshot driverDoc = await _firestore
        .collection('women_safety_data')
        .doc('riders_data')
        .collection('profiles')
        .doc(user.uid)
        .get();

    if (driverDoc.exists) {
      return driverDoc;
    }

    return null;
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
      final DocumentSnapshot? profile = await _getUserProfile();
      if (profile == null) return;

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String imagePath = '${appDirectory.path}/profile_${user.uid}.jpg';
      await File(image.path).copy(imagePath);
      await profile.reference.set({
        'profilePic': imagePath,
        'profileImagePath': imagePath,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isUploading = false);
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

  ImageProvider? _profileImage(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    final File file = File(path.replaceFirst('file://', ''));
    return file.existsSync() ? FileImage(file) : null;
  }

  // --- DELETE ACCOUNT CONFIRMATION & EXECUTION ---
  void _confirmDeleteAccount(Map<String, dynamic> userData) {
    final String role =
        (userData['role'] ?? 'passenger').toString().toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "Delete Account",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to permanently delete your account? This action cannot be undone and all your profile data will be removed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeAccountDeletion(role);
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAccountDeletion(String role) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      ),
    );

    try {
      if (role == 'driver') {
        await _firestore
            .collection('women_safety_data')
            .doc('riders_data')
            .collection('profiles')
            .doc(user.uid)
            .delete();
      } else {
        await _firestore
            .collection('women_safety_data')
            .doc('users_data')
            .collection('profiles')
            .doc(user.uid)
            .delete();
      }

      await user.delete();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account successfully deleted."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);

      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Please log out and log back in to verify your identity before deleting your account."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Deletion failed: ${e.message}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("An error occurred: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- EDIT PROFILE DIALOG ---
  void _showEditProfileModal(Map<String, dynamic> currentData) {
    final String role =
        (currentData['role'] ?? 'passenger').toString().toLowerCase();
    final bool isDriver = role == 'driver';

    final nameController =
        TextEditingController(text: currentData['name'] ?? '');
    final phoneController =
        TextEditingController(text: currentData['phone'] ?? '');

    Map<String, dynamic> emergencyContacts =
        currentData['emergency_contacts'] != null
            ? Map<String, dynamic>.from(currentData['emergency_contacts'])
            : {};

    final motherPhoneController =
        TextEditingController(text: emergencyContacts['mother'] ?? '+92');
    final parentPhoneController =
        TextEditingController(text: emergencyContacts['parent'] ?? '+92');

    final vehicleNumberController =
        TextEditingController(text: currentData['vehicleNumber'] ?? '');
    String selectedVehicleType = currentData['vehicleType'] ?? 'Scooty';
    if (!_vehicleTypes.contains(selectedVehicleType)) {
      selectedVehicleType = 'Scooty';
    }

    String selectedCity = currentData['city'] ?? 'Faisalabad';
    if (!_locations.contains(selectedCity)) {
      selectedCity = 'Faisalabad';
    }

    bool isUpdating = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final ThemeData theme = Theme.of(context);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Edit Profile (${isDriver ? 'Driver' : 'Passenger'})",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE91E63),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 15),
                  Expanded(
                    child: ListView(
                      children: [
                        const SizedBox(height: 10),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: "Full Name",
                            prefixIcon:
                                Icon(Icons.person, color: Color(0xFFE91E63)),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 13,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\+0-9]')),
                            LengthLimitingTextInputFormatter(13),
                          ],
                          decoration: const InputDecoration(
                            counterText: "",
                            labelText: "Phone Number (+923XXXXXXXXX)",
                            prefixIcon:
                                Icon(Icons.phone, color: Color(0xFFE91E63)),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: selectedCity,
                          decoration: const InputDecoration(
                            labelText: "City",
                            prefixIcon: Icon(Icons.location_city,
                                color: Color(0xFFE91E63)),
                            border: OutlineInputBorder(),
                          ),
                          items: _locations
                              .map((loc) => DropdownMenuItem(
                                  value: loc, child: Text(loc)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setModalState(() => selectedCity = val);
                          },
                        ),
                        const SizedBox(height: 15),
                        if (isDriver) ...[
                          DropdownButtonFormField<String>(
                            value: selectedVehicleType,
                            decoration: const InputDecoration(
                              labelText: "Vehicle Type",
                              prefixIcon: Icon(Icons.directions_car,
                                  color: Color(0xFFE91E63)),
                              border: OutlineInputBorder(),
                            ),
                            items: _vehicleTypes
                                .map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null)
                                setModalState(() => selectedVehicleType = val);
                            },
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: vehicleNumberController,
                            decoration: const InputDecoration(
                              labelText: "Vehicle Number Plate",
                              prefixIcon: Icon(Icons.pin_outlined,
                                  color: Color(0xFFE91E63)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 15),
                        ] else ...[
                          TextField(
                            controller: motherPhoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 13,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\+0-9]')),
                              LengthLimitingTextInputFormatter(13),
                            ],
                            decoration: const InputDecoration(
                              counterText: "",
                              labelText: "Mother's Contact (+923XXXXXXXXX)",
                              prefixIcon:
                                  Icon(Icons.woman, color: Color(0xFFE91E63)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextField(
                            controller: parentPhoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 13,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\+0-9]')),
                              LengthLimitingTextInputFormatter(13),
                            ],
                            decoration: const InputDecoration(
                              counterText: "",
                              labelText:
                                  "Father/Guardian Contact (+923XXXXXXXXX)",
                              prefixIcon:
                                  Icon(Icons.person, color: Color(0xFFE91E63)),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: isUpdating
                        ? null
                        : () async {
                            final mainPhone = phoneController.text.trim();
                            final motherPhone =
                                motherPhoneController.text.trim();
                            final parentPhone =
                                parentPhoneController.text.trim();

                            if (!_isValidPhoneNumber(mainPhone)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      "Main phone must start with +923, have 11 total digits, and non-identical digits."),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            if (!isDriver) {
                              if (!_isValidPhoneNumber(motherPhone)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Mother's contact must start with +923 and have valid digits."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              if (!_isValidPhoneNumber(parentPhone)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Father/Guardian contact must start with +923 and have valid digits."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              if (mainPhone == motherPhone ||
                                  mainPhone == parentPhone ||
                                  motherPhone == parentPhone) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Personal Phone, Mother's Contact, and Guardian's Contact must all be completely unique."),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }

                            setModalState(() => isUpdating = true);
                            User? user = _auth.currentUser;
                            if (user != null) {
                              try {
                                Map<String, dynamic> updatedData = {
                                  'name': nameController.text.trim(),
                                  'phone': mainPhone,
                                  'city': selectedCity,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };

                                if (isDriver) {
                                  updatedData['vehicleType'] =
                                      selectedVehicleType;
                                  updatedData['vehicleNumber'] =
                                      vehicleNumberController.text.trim();

                                  await _firestore
                                      .collection('women_safety_data')
                                      .doc('riders_data')
                                      .collection('profiles')
                                      .doc(user.uid)
                                      .update(updatedData);
                                } else {
                                  updatedData['emergency_contacts'] = {
                                    'mother': motherPhone,
                                    'parent': parentPhone,
                                  };

                                  await _firestore
                                      .collection('women_safety_data')
                                      .doc('users_data')
                                      .collection('profiles')
                                      .doc(user.uid)
                                      .update(updatedData);
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text("Profile updated successfully!"),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text("Error updating profile: $e"),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } finally {
                                setModalState(() => isUpdating = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isUpdating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("SAVE CHANGES",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPrivacyPolicyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final ThemeData theme = Theme.of(context);

        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
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
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7)),
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
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7)),
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
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7)),
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
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.7)),
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
                  minimumSize: const Size(double.infinity, 45),
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
    final Color primaryTextColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: primaryTextColor,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFE91E63)));
          }

          Map<String, dynamic> userData = {};
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.exists) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          }

          String name = userData['name'] ?? 'User';
          String email =
              userData['email'] ?? _auth.currentUser?.email ?? 'No email';
          String phone = userData['phone'] ?? 'No phone';
          String city = userData['city'] ?? 'No city';
          String role =
              (userData['role'] ?? 'passenger').toString().toUpperCase();
          final ImageProvider? profileImage = _profileImage(
            userData['profilePic'] ?? userData['profileImagePath'],
          );

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              // --- ACCOUNT PROFILE CARD ---
              Container(
                margin: const EdgeInsets.all(15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: GestureDetector(
                          onTap: _pickAndSaveProfileImage,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    const Color(0xFFE91E63).withOpacity(0.1),
                                backgroundImage: profileImage,
                                child: profileImage == null
                                    ? const Icon(Icons.person,
                                        size: 32, color: Color(0xFFE91E63))
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
                        title: Text(
                          name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        subtitle: Text("$email\n$phone • $city"),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            role,
                            style: const TextStyle(
                              color: Color(0xFFE91E63),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditProfileModal(userData),
                        icon: const Icon(Icons.edit,
                            size: 18, color: Color(0xFFE91E63)),
                        label: const Text(
                          "EDIT PROFILE",
                          style: TextStyle(
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE91E63)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- PREFERENCES & OPTIONS ---
              Material(
                color: theme.cardColor,
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
                              setDarkMode(value, isDriver: _isDriverProfile),
                        );
                      },
                    ),
                    const Divider(height: 1),

                    // Language Dropdown (English only)
                    ListTile(
                      title: const Text(
                        "Language",
                        style: TextStyle(fontSize: 16),
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
                        style: TextStyle(fontSize: 16),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                      onTap: _showPrivacyPolicyModal,
                    ),
                    const Divider(height: 1),

                    // Delete Account
                    ListTile(
                      title: const Text(
                        "Delete Account",
                        style: TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                      onTap: () => _confirmDeleteAccount(userData),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
