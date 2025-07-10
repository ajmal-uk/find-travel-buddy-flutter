import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../login_screen.dart';

import '../../utils/app_theme.dart';
import 'chat_&_group/chatScreen/chat_utils.dart';
import 'chat_&_group/chat_and_grroup_nav_screen.dart';
import 'homeScreen/home_screen.dart';
import 'packageAndTripassists/packages_and_assist.dart';
import 'userManageScreens/temporarly_removed_screen.dart';
import 'userSearchScreen/user_search_screen.dart';
import 'profileScreen/profile_screen.dart';

class UserScreen extends StatefulWidget {
  final int initialIndex;
  const UserScreen({super.key, this.initialIndex = 2});

  @override
  UserScreenState createState() => UserScreenState();
}

class UserScreenState extends State<UserScreen> {
  late int _selectedIndex;
  final List<Widget> _pages = [
    const PackageAndTripAssistScreen(),
    const SearchPage(),
    const HomePage(),
    const ChatAndGroup(),
    const ProfilePage(),
  ];

  Future<void> clearFirestoreCache() async {
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } catch (e) {
      print('Error clearing Firestore cache: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final isRemoved = userDoc.data()?['isRemoved'] ?? false;

          if (isRemoved) {
            try {
              final userId = FirebaseAuth.instance.currentUser?.uid;
              if (userId != null) {
                // Clear OneSignal player ID
                final playerId = OneSignal.User.pushSubscription.id;
                final userDocRef =
                    FirebaseFirestore.instance.collection('user').doc(userId);
                final userDocSnapshot = await userDocRef.get();

                // Update OneSignal IDs
                List<String> existingPlayerIds = [];
                if (userDocSnapshot.exists) {
                  final userData = userDocSnapshot.data();
                  existingPlayerIds =
                      List<String>.from(userData?['onId'] ?? []);
                  existingPlayerIds.remove(playerId);

                  if (existingPlayerIds.isNotEmpty) {
                    await userDocRef.set(
                        {'onId': existingPlayerIds}, SetOptions(merge: true));
                  } else {
                    await userDocRef.update({'onId': FieldValue.delete()});
                  }
                }
                // Clear group chat data
                final prefs = await SharedPreferences.getInstance();
                final keys = prefs.getKeys().toList();

                for (final key in keys) {
                  if (key.startsWith('cached_messages_') ||
                      key.startsWith('cached_chats') ||
                      key.startsWith('chat_') ||
                      key.startsWith('group_') ||
                      key.startsWith('messages_') ||
                      key == 'groups') {
                    await prefs.remove(key);
                  }
                }

                // Clear image caches
                await OptimizedNetworkImage.clearImageCache();
                imageCache.clear();
                imageCache.clearLiveImages();

                // Clear Firestore cache
                await clearFirestoreCache();

                // Clear all app preferences
                await PreferencesManager.clearPreferences();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Error occurred during logout. Please try again.')));
              }
            } finally {
              // Sign out from Firebase
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const TemporaryRemovedPopup();
                  },
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static const IconData card = IconData(0xe140, fontFamily: 'MaterialIcons');

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
            icon: Icon(card),
            label: 'Packages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: appTheme.textColor,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
