import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utils/app_theme.dart';
import 'feedback.dart';
import 'report.dart';

class TopNavigationScreen extends StatelessWidget {
  const TopNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appTheme.secondaryColor,
          bottom: TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: appTheme.textColor,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(
                child: Text(
                  'Reports',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  'Feedback',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          toolbarHeight: 10,
        ),
        body: TabBarView(
          children: [
            ReportsPage(), // First tab content
            FeedbackPage(), // Second tab content
          ],
        ),
      ),
    );
  }
}
