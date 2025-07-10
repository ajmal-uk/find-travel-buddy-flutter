import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../services/user/firebase_user_auth.dart';
import '../../../../../utils/app_theme.dart';
import '../../../../../utils/dialogues.dart';
import '../../edit_profile_screen.dart';

class AccountManagementPage extends StatelessWidget {
  AccountManagementPage({super.key});

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final UserAuthServices _authServices = UserAuthServices();

  void _showConfirmationDialog(BuildContext context) {
    showConfirmationDialog(
      context: context,
      title: 'Change Password',
      message: 'Are you sure you want to change password?',
      cancelButtonText: 'Cancel',
      confirmButtonText: 'Yes',
      onConfirm: () async {
        try {
          final userEmail = await _authServices.getUserEmailById(currentUserId);

          if (userEmail != null) {
            await FirebaseAuth.instance
                .sendPasswordResetEmail(email: userEmail);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Reset link sent. Check your email to reset your password.',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: Could not retrieve user email.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      titleIcon: const Icon(Icons.lock_reset, color: Colors.red),
      titleColor: Colors.redAccent,
      cancelButtonColor: Colors.blue,
      confirmButtonColor: Colors.red,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        title: Text(
          'Account Management',
          style: TextStyle(color: appTheme.textColor),
        ),
        backgroundColor: appTheme.secondaryColor,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.blue, Colors.lightBlueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text('Edit Profile',
                style: TextStyle(color: appTheme.textColor)),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        EditProfileScreen(uuid: currentUserId)),
              );
            },
          ),
          ListTile(
            leading: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.orange, Colors.yellow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                Icons.lock,
                color: Colors.white,
              ),
            ),
            title: Text('Change Password',
                style: TextStyle(color: appTheme.textColor)),
            trailing:
                Icon(Icons.chevron_right, color: appTheme.secondaryTextColor),
            onTap: () {
              _showConfirmationDialog(context);
            },
          ),
        ],
      ),
    );
  }
}
