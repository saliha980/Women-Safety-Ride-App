import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'login_screen.dart';
import 'package:geolocator/geolocator.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  // Function to show location disclaimer dialog
  Future<void> _showLocationDialog(BuildContext context, bool isSignUp) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.location_on, color: Colors.pink.shade400),
              const SizedBox(width: 10),
              const Text(
                "Enable Location",
                style: TextStyle(
                  color: Color(0xFFC2185B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Women Ride Safety uses your location to:",
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 15),
              _buildBulletPoint("Find nearby rides"),
              _buildBulletPoint("Share live location during rides"),
              _buildBulletPoint("SOS alerts share your location"),
              _buildBulletPoint("Track your ride history"),
              const SizedBox(height: 15),
              Text(
                "You can enable anytime in settings",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            // Cancel button - proceed without location
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                // Navigate to appropriate screen based on isSignUp
                if (isSignUp) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              child: Text(
                "Skip",
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            // Enable button - turn on location
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog

                // Request location permission
                LocationPermission permission = await Geolocator.requestPermission();

                if (permission == LocationPermission.always ||
                    permission == LocationPermission.whileInUse) {
                  // Location enabled
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("📍 Location enabled successfully"),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // Navigate to appropriate screen based on isSignUp
                if (isSignUp) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
              ),
              child: const Text("Enable"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.pink.shade400, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.pink.shade50,
                  Colors.purple.shade50,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      image: const DecorationImage(
                        image: AssetImage('assets/images/logo.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Welcome Text
                  const Text(
                    "Welcome to",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    "Women Ride Safety App",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    "Your trusted companion for safe travel. Join thousands of women who ride with confidence.",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // CREATE ACCOUNT Button
                  Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        // Show location dialog before navigating to SignUp
                        _showLocationDialog(context, true); // true = isSignUp
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "CREATE ACCOUNT",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Login Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                          );
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Color(0xFFE91E63),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // SOS Button
          Positioned(
            top: 40,
            right: 20,
            child: GestureDetector(
              onTap: () {
                _showSOSDialog(context);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSOSDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("🚨 SOS Emergency"),
          content: const Text(
            "Emergency services will be notified immediately. Continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🚨 SOS Alert Sent!"),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text("SEND SOS"),
            ),
          ],
        );
      },
    );
  }
}