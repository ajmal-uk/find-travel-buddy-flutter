import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/user/firebase_user_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgetPasswordScreen extends StatefulWidget {
  const ForgetPasswordScreen({super.key});

  @override
  State<ForgetPasswordScreen> createState() => _ForgetPasswordScreenState();
}

class _ForgetPasswordScreenState extends State<ForgetPasswordScreen> {
  final TextEditingController identifierController = TextEditingController();
  final UserAuthServices _authServices = UserAuthServices();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool isLoadingCheckUser = false;

  Future<void> checkUserExistenceAndSendResetLink() async {
    final identifier = identifierController.text.trim();

    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid identifier'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    setState(() {
      isLoadingCheckUser = true;
    });

    try {
      final foundUserId = await _authServices.checkUserExistence(identifier);

      if (foundUserId != null) {
        final userEmail = await _authServices.getUserEmailById(foundUserId);

        if (userEmail != null) {
          await _firebaseAuth.sendPasswordResetEmail(email: userEmail);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Reset link sent. Check your email to reset your password.'),
              backgroundColor: Colors.green,
            ));
            Navigator.of(context).pop();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Please try again.'),
              backgroundColor: Colors.red,
            ));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('User not found. Please try again.'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Please try again.'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      setState(() {
        isLoadingCheckUser = false;
      });
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      prefixIcon: Icon(icon, color: Colors.white),
      fillColor: Colors.black.withOpacity(0.3),
      filled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Image.asset(
            'assets/system/bg/registration.png',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Forgot Password',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        controller: identifierController,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(
                            "Username, email, phone, or Aadhaar", Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isLoadingCheckUser
                          ? null
                          : checkUserExistenceAndSendResetLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lightBlueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: isLoadingCheckUser
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Check User',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
