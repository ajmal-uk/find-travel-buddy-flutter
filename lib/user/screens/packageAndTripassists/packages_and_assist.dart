import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utils/app_theme.dart';
import 'packages/package_screen.dart';
import 'tripAssistScreen/travel_assist_screen.dart';

class PackageAndTripAssistScreen extends StatelessWidget {
  const PackageAndTripAssistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: appTheme.primaryColor,
        appBar: AppBar(
          backgroundColor: appTheme.secondaryColor,
          bottom: TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: appTheme.textColor,
            indicatorColor: Colors.blue,
            tabs: [
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
              )
            ],
          ),
          toolbarHeight: 10,
        ),
        body: const TabBarView(
          children: [
            PackagesScreen(),
            TravelAgencyPage(),
          ],
        ),
      ),
    );
  }
}
