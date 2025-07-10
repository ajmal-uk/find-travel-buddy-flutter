import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import 'packages/admin_package_screen.dart';
import 'tripAssistScreen/agency_screen.dart';
import 'usersScreen/view_users_screen.dart';

class UserAndAgencyScreen extends StatelessWidget {
  const UserAndAgencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return DefaultTabController(
      length: 3,
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
                  'Users',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  'Packages',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  'Trip Assists',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          toolbarHeight: 10,
        ),
        body: const TabBarView(
          children: [
            UserSearchPage(),
            AdminPackagesScreen(),
            TravelAgencyPage(),
          ],
        ),
      ),
    );
  }
}
