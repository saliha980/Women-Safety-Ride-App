import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'driver_dashboard_screen.dart';
import 'splash_screen.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  final prefs = await SharedPreferences.getInstance();
  final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
  await loadDarkMode(isDriver: await _currentUserIsDriver());

  runApp(MyApp(isFirstTime: isFirstTime));
}

Future<bool> _currentUserIsDriver() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final driverProfile = await FirebaseFirestore.instance
      .collection('women_safety_data')
      .doc('riders_data')
      .collection('profiles')
      .doc(user.uid)
      .get();
  return driverProfile.exists;
}

class MyApp extends StatelessWidget {
  final bool isFirstTime;
  const MyApp({super.key, required this.isFirstTime});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkModeNotifier,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'Women Ride Safety',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: const Color(0xFFE91E63),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF9C27B0),
              primary: const Color(0xFFE91E63),
              secondary: const Color(0xFF9C27B0),
              surface: Colors.white,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF9C27B0),
              brightness: Brightness.dark,
              primary: const Color(0xFFE91E63),
              secondary: const Color(0xFF9C27B0),
            ),
            useMaterial3: true,
          ),
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: isFirstTime ? const SplashScreen() : const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final String uid = snapshot.data!.uid;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('women_safety_data')
                .doc('riders_data')
                .collection('profiles')
                .doc(uid)
                .get(),
            builder: (context, driverSnapshot) {
              if (driverSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

              if (driverSnapshot.hasData && driverSnapshot.data!.exists) {
                return const DriverDashboardScreen();
              }

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('women_safety_data')
                    .doc('users_data')
                    .collection('profiles')
                    .doc(uid)
                    .get(),
                builder: (context, docSnapshot) {
                  if (docSnapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }

                  if (docSnapshot.hasData && docSnapshot.data!.exists) {
                    final data =
                        docSnapshot.data!.data() as Map<String, dynamic>?;
                    final String role = data?['role'] ?? '';

                    if (role.toLowerCase() == 'admin') {
                      return const AdminDashboardScreen();
                    }
                  }

                  return HomeScreen();
                },
              );
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}
