import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController(text: "+92");
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _cnicController = TextEditingController();
  final TextEditingController _vehicleNumberController = TextEditingController();

  String _selectedLocation = 'Faisalabad';
  String _selectedRole = 'Driver';
  String _selectedVehicleType = 'Scooty';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cnicController.dispose();
    _vehicleNumberController.dispose();
    super.dispose();
  }

  bool _isValidPhoneNumber(String phone) {
    RegExp phoneRegex = RegExp(r'^\+923\d{9}$');
    if (!phoneRegex.hasMatch(phone)) {
      return false;
    }

    String digitsAfterCountryCode = phone.substring(3);
    bool isAllSameDigits = digitsAfterCountryCode.split('').every((char) => char == digitsAfterCountryCode[0]);

    return !isAllSameDigits;
  }

  Future<bool> _isCnicAlreadyRegistered(String targetCnic) async {
    String formattedCnic = targetCnic.trim();
    String rawDigitsOnly = formattedCnic.replaceAll('-', '');

    List<String> cnicVariations = [formattedCnic, rawDigitsOnly];

    QuerySnapshot userSnapshotNumber = await _firestore
        .collection('women_safety_data')
        .doc('users_data')
        .collection('profiles')
        .where('cnic_number', whereIn: cnicVariations)
        .get();

    if (userSnapshotNumber.docs.isNotEmpty) return true;

    QuerySnapshot userSnapshotCnic = await _firestore
        .collection('women_safety_data')
        .doc('users_data')
        .collection('profiles')
        .where('cnic', whereIn: cnicVariations)
        .get();

    if (userSnapshotCnic.docs.isNotEmpty) return true;

    QuerySnapshot riderSnapshotNumber = await _firestore
        .collection('women_safety_data')
        .doc('riders_data')
        .collection('profiles')
        .where('cnic_number', whereIn: cnicVariations)
        .get();

    if (riderSnapshotNumber.docs.isNotEmpty) return true;

    QuerySnapshot riderSnapshotCnic = await _firestore
        .collection('women_safety_data')
        .doc('riders_data')
        .collection('profiles')
        .where('cnic', whereIn: cnicVariations)
        .get();

    return riderSnapshotCnic.docs.isNotEmpty;
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red),
      );
      return;
    }

    String cnicVal = _cnicController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (cnicVal.isNotEmpty) {
        bool cnicExists = await _isCnicAlreadyRegistered(cnicVal);
        if (cnicExists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("This CNIC is already registered to another user."),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      String uid = userCredential.user!.uid;

      Map<String, dynamic> userData = {
        'uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _selectedLocation,
        'role': _selectedRole.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == 'Driver') {
        userData['vehicleType'] = _selectedVehicleType;
        userData['vehicleNumber'] = _vehicleNumberController.text.trim();
        userData['cnic'] = cnicVal;
        userData['cnic_number'] = cnicVal;
        userData['isAvailable'] = true;
        userData['rating'] = 5.0;
      }

      await _firestore
          .collection('women_safety_data')
          .doc('riders_data')
          .collection('profiles')
          .doc(uid)
          .set(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration Successful!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Registration failed"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildCustomInputDecoration({
    required String labelText,
    required Widget prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: Color(0xFFD81B60), fontWeight: FontWeight.bold),
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: prefixIcon,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD81B60), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDEBF3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),

                TextFormField(
                  controller: _nameController,
                  decoration: _buildCustomInputDecoration(
                    labelText: "Full Name",
                    prefixIcon: const Icon(Icons.person, color: Color(0xFFD81B60)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Enter full name";
                    if (val.trim().length <= 4) return "Name must be more than 4 characters";
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(val.trim())) {
                      return "Name can only contain alphabets";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildCustomInputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email, color: Color(0xFFD81B60)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Enter email address";
                    if (!RegExp(r'^[^@]{4,}@[^@]+\.com$').hasMatch(val.trim())) {
                      return "Email must have 4+ chars before @ and end in .com";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\+0-9]')),
                    LengthLimitingTextInputFormatter(13),
                  ],
                  decoration: _buildCustomInputDecoration(
                    labelText: "Phone",
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFFD81B60)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return "Enter phone number";
                    if (!_isValidPhoneNumber(val.trim())) {
                      return "Number must start with +923 & non-identical digits";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedLocation,
                  decoration: _buildCustomInputDecoration(
                    labelText: "Select Location",
                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFFD81B60)),
                  ),
                  items: ['Faisalabad', 'Lahore', 'Islamabad', 'Karachi'].map((String city) {
                    return DropdownMenuItem<String>(
                      value: city,
                      child: Text(city, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLocation = val!),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: _buildCustomInputDecoration(
                    labelText: "Join as",
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFD81B60)),
                  ),
                  items: ['Driver', 'Passenger'].map((String role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRole = val!),
                ),
                const SizedBox(height: 16),

                if (_selectedRole == 'Driver') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedVehicleType,
                    decoration: _buildCustomInputDecoration(
                      labelText: "Select Vehicle / Ride Type",
                      prefixIcon: const Icon(Icons.directions_bike, color: Color(0xFFD81B60)),
                    ),
                    items: ['Scooty', 'Car', 'Rickshaw'].map((String vehicle) {
                      return DropdownMenuItem<String>(
                        value: vehicle,
                        child: Text(vehicle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedVehicleType = val!),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _vehicleNumberController,
                    decoration: _buildCustomInputDecoration(
                      labelText: "Vehicle Registration Number (e.g. LEB-1234)",
                      prefixIcon: const Icon(Icons.pin, color: Color(0xFFD81B60)),
                    ),
                    validator: (val) {
                      if (_selectedRole == 'Driver' && (val == null || val.trim().isEmpty)) {
                        return "Enter vehicle number plate";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _cnicController,
                    keyboardType: TextInputType.number,
                    decoration: _buildCustomInputDecoration(
                      labelText: "CNIC Number (e.g. 35201-XXXXXXX-X)",
                      prefixIcon: const Icon(Icons.badge, color: Color(0xFFD81B60)),
                    ),
                    validator: (val) {
                      if (_selectedRole == 'Driver' && (val == null || val.trim().isEmpty)) {
                        return "Enter CNIC number";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _buildCustomInputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFD81B60)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.length <= 8) return "Password must be over 8 characters";
                    if (!val.contains(RegExp(r'[A-Z]'))) return "Must contain at least 1 capital letter";
                    if (!val.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return "Must contain at least 1 special character";
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _buildCustomInputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock, color: Color(0xFFD81B60)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty ? "Confirm your password" : null,
                ),
                const SizedBox(height: 24),

                Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF8E24AA)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "SIGN UP",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}