import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import 'login_screen.dart';
import 'sos_screen.dart';

class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length > 13) {
      digitsOnly = digitsOnly.substring(0, 13);
    }

    StringBuffer formatted = StringBuffer();

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 5 || i == 12) {
        formatted.write('-');
      }
      formatted.write(digitsOnly[i]);
    }

    String formattedText = formatted.toString();

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: "+92");
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _vehicleNumberController = TextEditingController();

  final _motherContactController = TextEditingController(text: "+92");
  final _parentContactController = TextEditingController(text: "+92");

  final _cnicTextController = TextEditingController();

  String _selectedVehicleType = 'Scooty';
  final List<String> _vehicleTypes = ['Scooty', 'Car', 'Rickshaw'];

  String _selectedLocation = 'Faisalabad';
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

  File? _cnicImage;
  String? _extractedCnicFromImage;
  final ImagePicker _picker = ImagePicker();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String _selectedRole = 'Passenger';
  final List<String> _roles = ['Passenger', 'Driver'];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleNumberController.dispose();
    _motherContactController.dispose();
    _parentContactController.dispose();
    _cnicTextController.dispose();
    super.dispose();
  }

  bool _isValidName(String name) {
    RegExp nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    return name.trim().length > 4 && nameRegex.hasMatch(name.trim());
  }

  bool _isValidEmail(String email) {
    RegExp emailRegex = RegExp(r'^[^@]{4,}@[^@]+\.com$');
    return emailRegex.hasMatch(email.trim());
  }

  bool _isValidPassword(String password) {
    if (password.length < 8) return false;
    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return hasUppercase && hasSpecialChar;
  }

  bool _isValidPhoneNumber(String phone) {
    String cleaned = phone.trim();

    RegExp phoneRegex = RegExp(r'^\+923\d{9}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return false;
    }

    String subscriberNumber = cleaned.substring(4);

    Set<String> uniqueDigits = subscriberNumber.split('').toSet();
    if (uniqueDigits.length == 1) {
      return false;
    }

    if (subscriberNumber == "123456789" || subscriberNumber == "987654321" || subscriberNumber == "012345678") {
      return false;
    }

    return true;
  }

  Future<bool> _isPhoneNumberAlreadyRegistered(String phone) async {
    String trimmedPhone = phone.trim();

    QuerySnapshot userSnapshot = await _firestore
        .collection('women_safety_data')
        .doc('users_data')
        .collection('profiles')
        .where('phone', isEqualTo: trimmedPhone)
        .get();

    if (userSnapshot.docs.isNotEmpty) return true;

    QuerySnapshot riderSnapshot = await _firestore
        .collection('women_safety_data')
        .doc('riders_data')
        .collection('profiles')
        .where('phone', isEqualTo: trimmedPhone)
        .get();

    return riderSnapshot.docs.isNotEmpty;
  }

  String? _extractCnicNumber(String rawText) {
    RegExp cnicRegex = RegExp(r'\b\d{5}[-]?\d{7}[-]?\d{1}\b');
    Iterable<Match> matches = cnicRegex.allMatches(rawText);

    for (Match match in matches) {
      String clean = match.group(0)!.replaceAll('-', '');
      if (clean.length == 13) {
        return clean;
      }
    }
    return null;
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

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);

    setState(() => _isLoading = true);

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      String? detectedCnic = _extractCnicNumber(recognizedText.text);

      if (detectedCnic == null) {
        if (mounted) {
          _showErrorDialog("INVALID PICTURE\n\nThe uploaded image does not contain a valid CNIC card number. Please upload a clear photo of your CNIC.", title: "Invalid CNIC Image");
        }
        setState(() {
          _cnicImage = null;
          _extractedCnicFromImage = null;
        });
        return;
      }

      int lastDigit = int.parse(detectedCnic.substring(detectedCnic.length - 1));
      if (lastDigit % 2 != 0) {
        if (mounted) {
          String userRole = _selectedRole.toLowerCase();
          _showErrorDialog("CNIC Error: Only female ${userRole}s can register. The CNIC provided belongs to a male user.", title: "CNIC Error");
        }
        setState(() {
          _cnicImage = null;
          _extractedCnicFromImage = null;
        });
        return;
      }

      setState(() {
        _cnicImage = imageFile;
        _extractedCnicFromImage = detectedCnic;
      });

    } catch (e) {
      _showErrorDialog("Failed to process image: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateTypedCnic(String cnicInput) {
    if (cnicInput.isEmpty && _cnicImage == null) {
      _showErrorDialog("Please upload a valid CNIC image or type your CNIC number.", title: "CNIC Required");
      return false;
    }

    if (cnicInput.isNotEmpty) {
      String cleanCnic = cnicInput.replaceAll('-', '');

      if (cleanCnic.length != 13 || int.tryParse(cleanCnic) == null) {
        _showErrorDialog("Please enter a valid 13-digit CNIC number.", title: "Invalid CNIC Format");
        return false;
      }

      int lastDigit = int.parse(cleanCnic.substring(cleanCnic.length - 1));

      if (lastDigit % 2 != 0) {
        String userRole = _selectedRole.toLowerCase();
        _showErrorDialog("CNIC Error: Only female ${userRole}s can register.", title: "Gender Verification Failed");
        return false;
      }
    }

    return true;
  }

  Future<void> _signUp() async {
    if (!_isValidName(_nameController.text)) {
      _showErrorDialog("Name must contain only alphabets and be more than 4 characters long.", title: "Invalid Name");
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      _showErrorDialog("Email must have at least 4 characters before '@' and end with '.com'.", title: "Invalid Email");
      return;
    }

    String phone = _phoneController.text.trim();
    if (!_isValidPhoneNumber(phone)) {
      _showErrorDialog("Your phone number must start with +923 followed by 9 valid digits. Dummy or repetitive numbers are not allowed.", title: "Invalid Personal Phone");
      return;
    }

    if (_selectedRole == 'Passenger') {
      String motherPhone = _motherContactController.text.trim();
      String parentPhone = _parentContactController.text.trim();

      if (!_isValidPhoneNumber(motherPhone)) {
        _showErrorDialog("Mother's contact number must start with +923 followed by 9 valid digits.", title: "Invalid Mother's Phone");
        return;
      }
      if (!_isValidPhoneNumber(parentPhone)) {
        _showErrorDialog("Father/Guardian contact number must start with +923 followed by 9 valid digits.", title: "Invalid Guardian's Phone");
        return;
      }

      if (phone == motherPhone || phone == parentPhone || motherPhone == parentPhone) {
        _showErrorDialog("All contact numbers must be distinct and unique.", title: "Duplicate Phone Numbers");
        return;
      }

      if (!_validateTypedCnic(_cnicTextController.text.trim())) {
        return;
      }
    } else if (_selectedRole == 'Driver') {
      if (_vehicleNumberController.text.trim().isEmpty) {
        _showErrorDialog("Please enter your vehicle number plate.", title: "Missing Vehicle Number");
        return;
      }

      if (!_validateTypedCnic(_cnicTextController.text.trim())) {
        return;
      }
    }

    if (!_isValidPassword(_passwordController.text)) {
      _showErrorDialog("Password must be at least 8 characters long and include at least one uppercase letter and one special character.", title: "Invalid Password");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog("Passwords do not match.", title: "Password Mismatch");
      return;
    }

    String finalCnic = _cnicTextController.text.trim().isNotEmpty
        ? _cnicTextController.text.trim()
        : (_extractedCnicFromImage ?? "");

    setState(() => _isLoading = true);

    try {
      bool phoneExists = await _isPhoneNumberAlreadyRegistered(phone);
      if (phoneExists) {
        _showErrorDialog("This phone number is already registered with another account.", title: "Phone Already Registered");
        setState(() => _isLoading = false);
        return;
      }

      bool cnicExists = await _isCnicAlreadyRegistered(finalCnic);
      if (cnicExists) {
        _showErrorDialog("This CNIC number is already registered with another account.", title: "CNIC Already Registered");
        setState(() => _isLoading = false);
        return;
      }

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      String uid = userCredential.user!.uid;

      if (_selectedRole == 'Driver') {
        Map<String, dynamic> driverData = {
          'uid': uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': phone,
          'city': _selectedLocation,
          'role': 'driver',
          'vehicleType': _selectedVehicleType,
          'vehicleNumber': _vehicleNumberController.text.trim(),
          'cnic_number': finalCnic,
          'cnic': finalCnic,
          'cnic_status': 'verified',
          'isAvailable': true,
          'rating': 5.0,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('women_safety_data')
            .doc('riders_data')
            .collection('profiles')
            .doc(uid)
            .set(driverData);

      } else {
        Map<String, dynamic> passengerData = {
          'uid': uid,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': phone,
          'city': _selectedLocation,
          'role': 'passenger',
          'cnic_number': finalCnic,
          'cnic': finalCnic,
          'cnic_status': 'verified',
          'emergency_contacts': {
            'mother': _motherContactController.text.trim(),
            'parent': _parentContactController.text.trim(),
          },
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore
            .collection('women_safety_data')
            .doc('users_data')
            .collection('profiles')
            .doc(uid)
            .set(passengerData);
      }

      // SIGN OUT USER AFTER REGISTRATION TO PREVENT DIRECT DASHBOARD LOGIN
      await _auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account created successfully! Please log in to continue."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String dialogTitle = "Authentication Error";
      String dialogMessage = e.message ?? "An error occurred during authentication.";

      switch (e.code) {
        case 'email-already-in-use':
          dialogTitle = "Email Already in Use";
          dialogMessage = "This email address is already registered. Please sign in.";
          break;
        case 'invalid-email':
          dialogTitle = "Invalid Email";
          dialogMessage = "The email address entered is invalid.";
          break;
        case 'weak-password':
          dialogTitle = "Weak Password";
          dialogMessage = "The password provided is too weak.";
          break;
        case 'network-request-failed':
          dialogTitle = "Network Error";
          dialogMessage = "Please check your internet connection.";
          break;
        default:
          dialogTitle = "Sign Up Error";
          break;
      }

      _showErrorDialog(dialogMessage, title: dialogTitle);
    } catch (e) {
      _showErrorDialog("Error: ${e.toString().replaceAll("Exception: ", "")}", title: "Registration Error");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.pink.shade50, Colors.purple.shade50],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Image.asset('assets/images/logo.png', height: 80, errorBuilder: (c, e, s) => const Icon(Icons.local_taxi, size: 80, color: Colors.pink)),
                  const Text("Create Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
                  const SizedBox(height: 20),

                  _buildInputField(controller: _nameController, hint: "Full Name", icon: Icons.person),
                  const SizedBox(height: 15),
                  _buildInputField(controller: _emailController, hint: "Email", icon: Icons.email, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _phoneController, 
                    hint: "Phone (+923XXXXXXXXX)", 
                    icon: Icons.phone, 
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\+0-9]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: _inputDecoration(),
                    child: DropdownButtonFormField<String>(
                      value: _selectedLocation,
                      decoration: const InputDecoration(
                        labelText: 'Select Location', 
                        prefixIcon: Icon(Icons.location_on, color: Color(0xFFE91E63)),
                        border: InputBorder.none,
                      ),
                      items: _locations.map((location) => DropdownMenuItem(value: location, child: Text(location))).toList(),
                      onChanged: (val) => setState(() => _selectedLocation = val!),
                    ),
                  ),
                  const SizedBox(height: 15),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: _inputDecoration(),
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      decoration: const InputDecoration(labelText: 'Join as', border: InputBorder.none),
                      items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                      onChanged: (val) => setState(() {
                        _selectedRole = val!;
                        _cnicImage = null;
                        _extractedCnicFromImage = null;
                        _cnicTextController.clear();
                        _vehicleNumberController.clear();
                      }),
                    ),
                  ),
                  const SizedBox(height: 15),

                  if (_selectedRole == 'Driver') ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      decoration: _inputDecoration(),
                      child: DropdownButtonFormField<String>(
                        value: _selectedVehicleType,
                        decoration: const InputDecoration(
                          labelText: 'Select Vehicle / Ride Type',
                          prefixIcon: Icon(Icons.directions_car, color: Color(0xFFE91E63)),
                          border: InputBorder.none,
                        ),
                        items: _vehicleTypes.map((vehicle) {
                          IconData vehicleIcon;
                          if (vehicle == 'Scooty') {
                            vehicleIcon = Icons.motorcycle;
                          } else if (vehicle == 'Rickshaw') {
                            vehicleIcon = Icons.electric_rickshaw;
                          } else {
                            vehicleIcon = Icons.directions_car;
                          }

                          return DropdownMenuItem(
                            value: vehicle,
                            child: Row(
                              children: [
                                Icon(vehicleIcon, color: const Color(0xFFE91E63), size: 20),
                                const SizedBox(width: 10),
                                Text(vehicle),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedVehicleType = val!),
                      ),
                    ),
                    const SizedBox(height: 15),

                    _buildInputField(
                      controller: _vehicleNumberController,
                      hint: "Vehicle Registration Number (e.g. LEB-1234)",
                      icon: Icons.pin_outlined,
                    ),
                    const SizedBox(height: 15),

                    _buildCnicSection(),
                  ]
                  else if (_selectedRole == 'Passenger') ...[
                    _buildInputField(
                      controller: _motherContactController,
                      hint: "Mother's Contact (+923XXXXXXXXX)",
                      icon: Icons.woman, 
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\+0-9]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildInputField(
                      controller: _parentContactController,
                      hint: "Father/Guardian Contact (+923XXXXXXXXX)",
                      icon: Icons.person, 
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\+0-9]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                    ),
                    const SizedBox(height: 15),

                    _buildCnicSection(),
                  ],

                  _buildInputField(
                    controller: _passwordController,
                    hint: "Password",
                    icon: Icons.lock,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInputField(
                    controller: _confirmPasswordController,
                    hint: "Confirm Password",
                    icon: Icons.lock_outline,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Container(
                    width: double.infinity, 
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white) 
                          : const Text("SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          Positioned(
            top: 40,
            right: 20,
            child: FloatingActionButton.small(
              backgroundColor: Colors.red,
              onPressed: () => SOSDialog.show(context),
              child: const Icon(Icons.warning, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCnicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputField(
          controller: _cnicTextController,
          hint: "CNIC Number (e.g. 35201-XXXXXXX-X)",
          icon: Icons.badge_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CnicInputFormatter(),
          ],
        ),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            "OR Upload CNIC Image for Verification", 
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Camera"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pink.shade300, foregroundColor: Colors.white),
            ),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.image),
              label: const Text("Gallery"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade300, foregroundColor: Colors.white),
            ),
          ],
        ),
        if (_cnicImage != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_cnicImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                ),
                if (_extractedCnicFromImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      "Verified CNIC: $_extractedCnicFromImage",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint, 
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: _inputDecoration(),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          counterText: "",
          labelText: hint,
          labelStyle: const TextStyle(color: Colors.grey),
          floatingLabelStyle: const TextStyle(color: Color(0xFFC2185B)),
          prefixIcon: Icon(icon, color: const Color(0xFFE91E63)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        ),
      ),
    );
  }

  BoxDecoration _inputDecoration() {
    return BoxDecoration(
      color: Colors.white, 
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.purple.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
    );
  }

  void _showErrorDialog(String message, {String title = 'Registration Error'}) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Color(0xFFC2185B), fontWeight: FontWeight.bold)), 
        content: Text(message), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ]
      )
    );
  }
}