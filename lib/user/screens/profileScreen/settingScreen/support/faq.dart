import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../utils/app_theme.dart';

class FAQPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: appTheme.secondaryColor,
        title: Text(
          'FAQs',
          style: TextStyle(color: appTheme.textColor),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(
              Icons.question_answer,
              color: appTheme.secondaryTextColor,
            ),
            title: Text(
              'What is Explore Together?',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: appTheme.textColor,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              _showAnswer(context,
                  'Explore Together is an app that helps you connect with others for shared activities and experiences.');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.question_answer,
              color: appTheme.secondaryTextColor,
            ),
            title: Text(
              'How do I create an account?',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: appTheme.textColor,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              _showAnswer(context,
                  'Simply click on the "Sign Up" button and fill in the necessary details to get started.');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.question_answer,
              color: appTheme.secondaryTextColor,
            ),
            title: Text(
              'How do I find activities?',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: appTheme.textColor,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              _showAnswer(context,
                  'You can browse through the activity feed or search for specific types of events near you.');
            },
          ),
          ListTile(
            leading: Icon(
              Icons.question_answer,
              color: appTheme.secondaryTextColor,
            ),
            title: Text(
              'Can I invite friends to join an activity?',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: appTheme.textColor,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: appTheme.secondaryTextColor,
            ),
            onTap: () {
              _showAnswer(context,
                  'Yes, you can easily send invites to friends via the app or through messaging platforms.');
            },
          ),
        ],
      ),
    );
  }

  void _showAnswer(BuildContext context, String answer) {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final appTheme = themeManager.currentTheme;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: appTheme.secondaryColor,
          title: Text(
            'Answer',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(answer, style: TextStyle(color: appTheme.textColor)),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
