import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/loading.dart';
import 'chatScreen/chat_screen.dart';
import 'groupScreen/group.dart';

class ChatAndGroup extends StatefulWidget {
  const ChatAndGroup({super.key});

  @override
  ChatAndGroupState createState() => ChatAndGroupState();
}

class ChatAndGroupState extends State<ChatAndGroup> {
  late FirebaseService firebaseService;
  String? currentUserId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeUserAndService();
  }

  Future<void> _initializeUserAndService() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      currentUserId = user.uid;
      final prefs = await SharedPreferences.getInstance();
      firebaseService = FirebaseService(prefs);
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    if (isLoading) {
      return const Center(
        child: LoadingAnimation(),
      );
    }

    if (currentUserId == null) {
      return Center(
        child: Text(
          'User not logged in',
          style: TextStyle(color: appTheme.textColor),
        ),
      );
    }

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
                  'Chat',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Tab(
                child: Text(
                  'Group',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          toolbarHeight: 10,
        ),
        body: TabBarView(
          children: [
            const ChatHomeScreen(),
            GroupHomeScreen(
              currentUserId: currentUserId!,
              firebaseService: firebaseService,
            ),
          ],
        ),
      ),
    );
  }
}
