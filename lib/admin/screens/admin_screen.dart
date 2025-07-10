import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import 'analysisScreen/analysis_screen.dart';
import 'manageScreen/user_packages_agencies.dart';
import 'messageScreen/sent_message_screen.dart';
import 'reportAndFeedBack/report_and_feedback_screen.dart';
import 'settingsScreen/setting_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  AdminScreenState createState() => AdminScreenState();
}

class AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 2;

  final List<Widget> _pages = [
    const SentMessagePage(),
    const UserAndAgencyScreen(),
    const AnalysisPage(),
    const TopNavigationScreen(),
    const SettingsPage(),
  ];

  // Function to switch between tabs
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: appTheme.secondaryColor,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        iconSize: 20,
        selectedIconTheme: const IconThemeData(
          size: 32,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Notify',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Manage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: appTheme.textColor,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
