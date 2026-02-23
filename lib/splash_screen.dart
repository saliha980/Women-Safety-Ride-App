import 'package:flutter/material.dart';
import 'onboarding_screen.dart';
import 'welcome_screen.dart'; // Add this import for logged-in users

// This is a simple class to simulate login state
// In Week 3 with Firebase, this will check real login status
class UserSession {
  static bool isLoggedIn = false; // Set to true to simulate logged-in user
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Wait 2 seconds then navigate based on login status
    Future.delayed(const Duration(seconds: 2), () {
      if (UserSession.isLoggedIn) {
        // User already logged in → go directly to Home screen
        // You'll need to import home_screen.dart and navigate there
        // For now, go to Welcome screen (replace with HomeScreen when ready)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(), // Change to HomeScreen when you want
          ),
        );
      } else {
        // New user → show onboarding
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const OnboardingScreen(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.pink.shade400,
              Colors.purple.shade600,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
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
              const Text(
                "Women Ride Safety App",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Safe Travel for Women",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 50),
              const CircularProgressIndicator(
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}