import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// Rest of your MyApp class stays the SAME
// ... (keep all your existing theme code)

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Women Ride Safety',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFE91E63),
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF9C27B0),
          secondary: const Color(0xFFF8BBD9),
          surface: Colors.white,
          background: const Color(0xFFF3E5F5),
          onPrimary: Colors.white,
          onSecondary: Colors.black87,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}