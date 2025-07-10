import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../utils/app_theme.dart';
import '../feedback_popup.dart';
import 'faq.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  Future<String> fetchEmail() async {
    try {
      // Get the app management data from Firestore
      DocumentSnapshot document = await FirebaseFirestore.instance
          .collection('Manage')
          .doc('appData')
          .get();

      // Check if the document exists and if appEmail is available
      if (document.exists &&
          document['appEmail'] != null &&
          document['appEmail'].isNotEmpty) {
        return document['appEmail'];
      } else {
        return 'travellbuddyfinder@gmail.com';
      }
    } catch (e) {
      return 'travellbuddyfinder@gmail.com';
    }
  }

  void _launchEmail(String email) {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );
    launchUrl(emailLaunchUri);
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: appTheme.textColor,
        ),
        title: Text(
          'Support',
          style: TextStyle(color: appTheme.textColor),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.email,
              color: appTheme.secondaryTextColor,
            ),
            title: Text(
              'Contact Us',
              style: TextStyle(color: appTheme.textColor),
            ),
            subtitle: Text('Email support or chat with us directly.',
                style: TextStyle(color: appTheme.secondaryTextColor)),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () async {
              String email = await fetchEmail();
              _launchEmail(email);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.question_answer,
              color: appTheme.secondaryTextColor,
            ),
            title: Text('FAQs', style: TextStyle(color: appTheme.textColor)),
            subtitle: Text('Find answers to common questions.',
                style: TextStyle(color: appTheme.secondaryTextColor)),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FAQPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(
              Icons.feedback,
              color: appTheme.secondaryTextColor,
            ),
            title:
                Text('Feedback', style: TextStyle(color: appTheme.textColor)),
            subtitle: Text('Share suggestions or feature requests.',
                style: TextStyle(color: appTheme.secondaryTextColor)),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return FeedbackPopup();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
