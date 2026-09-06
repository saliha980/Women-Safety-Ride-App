import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Direct Firebase Import

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Updated colors to match your Login/Signup theme
  final Color primaryPink = const Color(0xFFE91E63);
  final Color darkPink = const Color(0xFFC2185B);
  final Color primaryPurple = const Color(0xFF9C27B0);

  bool _isLoading = false;
  bool _emailSent = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  // --- Logic: Direct Firebase Password Reset ---
  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Firebase direct call to send reset link
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() => _emailSent = true);
        _showSnackBar("Reset link sent successfully!", Colors.green);
      }
    } on FirebaseAuthException catch (e) {
      String message = "An error occurred";
      if (e.code == 'user-not-found') {
        message = "No account exists with this email.";
      } else if (e.code == 'invalid-email') {
        message = "The email address is badly formatted.";
      }
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar("Check your internet connection.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient matching your other screens
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: darkPink),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Matching Icon styling
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: primaryPink.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _emailSent ? Icons.mark_email_read : Icons.lock_reset,
                          size: 80,
                          color: primaryPink,
                        ),
                      ),
                      const SizedBox(height: 30),

                      Text(
                        _emailSent ? 'Check Email' : 'Reset Password',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: darkPink,
                        ),
                      ),
                      const SizedBox(height: 15),

                      Text(
                        _emailSent
                            ? 'A reset link has been sent to ${_emailController.text.trim()}.'
                            : 'Enter your registered email below to receive a password reset link.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
                      ),
                      const SizedBox(height: 40),

                      if (!_emailSent) ...[
                        _buildInputField(),
                        const SizedBox(height: 30),
                        _buildSubmitButton(),
                      ] else ...[
                        TextButton(
                          onPressed: () => setState(() => _emailSent = false),
                          child: Text("Use a different email", style: TextStyle(color: primaryPurple)),
                        ),
                      ],

                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Back to Login", style: TextStyle(color: primaryPink, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || !value.contains('@')) return 'Enter a valid email';
          return null;
        },
        decoration: InputDecoration(
          hintText: "Enter your email",
          prefixIcon: Icon(Icons.email, color: primaryPink),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryPink, primaryPurple]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        onPressed: _isLoading ? null : _sendPasswordResetEmail,
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
          "SEND RESET LINK",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}