import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../utils/app_theme.dart';

class MainHelpPage extends StatelessWidget {
  const MainHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
          title:
              Text('Help Center', style: TextStyle(color: appTheme.textColor)),
          backgroundColor: appTheme.secondaryColor),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title:
                Text('Login Help', style: TextStyle(color: appTheme.textColor)),
            trailing:
                Icon(Icons.chevron_right, color: appTheme.secondaryTextColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginHelpPage(),
                ),
              );
            },
          ),
          ListTile(
            title: Text('Recover a Removed Account',
                style: TextStyle(color: appTheme.textColor)),
            trailing:
                Icon(Icons.chevron_right, color: appTheme.secondaryTextColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecoverAccountHelpPage(),
                ),
              );
            },
          ),
          ListTile(
            title: Text('Using Explore Together',
                style: TextStyle(color: appTheme.textColor)),
            trailing:
                Icon(Icons.chevron_right, color: appTheme.secondaryTextColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsingAppHelpPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class LoginHelpPage extends StatelessWidget {
  const LoginHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        title: Text(
          'Login Help',
          style: TextStyle(color: appTheme.textColor),
        ),
        backgroundColor: appTheme.secondaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SizedBox(height: 10),
            Text(
              '1. Enter your username, email, phone, or Aadhaar in the first field.\n'
              '2. Enter your password in the second field.\n'
              '3. If you forgot your password, click on "Forgot Password?".\n'
              '4. New users can click "Signup" to register.\n',
              style: TextStyle(fontSize: 16, color: appTheme.textColor),
            ),
          ],
        ),
      ),
    );
  }
}

class RecoverAccountHelpPage extends StatelessWidget {
  const RecoverAccountHelpPage({super.key});

  Future<String> fetchEmail() async {
    try {
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Manage')
          .doc('appData')
          .get();
      if (document.exists && document['appEmail'] != null) {
        return document['appEmail'];
      } else {
        return 'travellbuddyfinder@gmail.com@gmail.com';
      }
    } catch (e) {
      return 'travellbuddyfinder@gmail.com@gmail.com';
    }
  }

  void _launchEmail(String email) {
    launchUrl(Uri(
      scheme: 'mailto',
      path: email,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
          title: Text('Recover Account',
              style: TextStyle(color: appTheme.textColor)),
          backgroundColor: appTheme.secondaryColor),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SizedBox(
              height: 30,
            ),
            Text(
              'Accounts may be temporarily removed due to the following reasons:\n'
              '- Violation of community guidelines or policies.\n'
              '- Inactivity for a prolonged period.\n'
              '- Fraudulent or suspicious activity.\n'
              '- Incorrect or incomplete account information.\n\n'
              'If your account was removed and you believe this was a mistake, you can contact our support team to recover it. Provide all the necessary details, such as your full name, email, and username.',
              style:
                  TextStyle(fontSize: 16, color: appTheme.secondaryTextColor),
            ),
            const SizedBox(height: 30),
            // FutureBuilder to fetch and display the email
            FutureBuilder<String>(
              future: fetchEmail(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return const Text('Error fetching email',
                      style: TextStyle(fontSize: 16, color: Colors.red));
                } else if (snapshot.hasData) {
                  // Get the email from the snapshot
                  String email = snapshot.data ?? 'timeload@gmail.com';
                  return Center(
                    child: ElevatedButton(
                      onPressed: () => _launchEmail(email),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Contact Us',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  );
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class UsingAppHelpPage extends StatelessWidget {
  const UsingAppHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        title: Text('Using Explore Together',
            style: TextStyle(color: appTheme.textColor)),
        backgroundColor: appTheme.secondaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SizedBox(height: 10),
            Text(
              'Explore Together is designed to connect solo travelers with others who share similar destinations and interests. Here’s how you can use it:\n\n'
              '- Create a profile with your travel preferences.\n'
              '- Search for fellow travelers heading to your destination.\n'
              '- Use the in-app chat feature to connect and plan trips together.\n'
              '- Review safety tips and guidelines before meeting new people.\n\n'
              'Enjoy a secure and seamless travel experience with Explore Together.',
              style: TextStyle(fontSize: 16, color: appTheme.textColor),
            ),
          ],
        ),
      ),
    );
  }
}
