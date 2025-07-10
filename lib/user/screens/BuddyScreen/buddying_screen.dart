import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../utils/app_colors.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/loading.dart';
import '../userDetailsScreen/others_user_profile.dart';
import '../user_screen.dart';

class BuddyingUserPage extends StatefulWidget {
  final String userId;

  const BuddyingUserPage({super.key, required this.userId});

  @override
  BuddyingUserPageState createState() => BuddyingUserPageState();
}

class BuddyingUserPageState extends State<BuddyingUserPage> {
  TextEditingController searchController = TextEditingController();
  List<Map<String, dynamic>> allBuddingUsers = [];
  List<Map<String, dynamic>> filteredBuddyingUsers = [];
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchBuddyingUsers();
    searchController.addListener(() {
      filterUsers();
    });
  }

  Future<void> fetchBuddyingUsers() async {
    setState(() {
      isLoading = true;
    });
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.userId)
        .get();

    if (userDoc.exists) {
      List<dynamic> buddyingUsersIds = userDoc['buddying'] ?? [];
      List<Map<String, dynamic>> buddyingUsers = [];
      for (String buddyingUsersId in buddyingUsersIds) {
        DocumentSnapshot followedUserDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(buddyingUsersId)
            .get();

        if (followedUserDoc.exists) {
          var buddyingUserData = followedUserDoc.data() as Map<String, dynamic>;
          buddyingUserData['userId'] = buddyingUsersId;

          buddyingUsers.add(buddyingUserData);
        }
      }

      setState(() {
        allBuddingUsers = buddyingUsers;
        filteredBuddyingUsers = buddyingUsers;
        isLoading = false;
      });
    }
  }

  void filterUsers() {
    String query = searchController.text.toLowerCase();

    setState(() {
      filteredBuddyingUsers = allBuddingUsers.where((user) {
        String username = user['username'].toLowerCase();
        return username.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
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
        backgroundColor: appTheme.secondaryColor,
        toolbarHeight: kToolbarHeight + 10.0,
        title: TextField(
          controller: searchController,
          decoration: InputDecoration(
            filled: true,
            fillColor: appTheme.primaryColor,
            hintText: 'Search by username...',
            hintStyle:
                TextStyle(color: appTheme.secondaryTextColor, fontSize: 16),
            prefixIcon: Icon(Icons.search, color: appTheme.secondaryTextColor),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: appTheme.secondaryTextColor,
                    ),
                    onPressed: () {
                      setState(() {
                        searchController.clear();
                        filterUsers();
                      });
                    },
                  )
                : null,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: appTheme.textColor, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: appTheme.textColor, width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide(color: appTheme.textColor, width: 0.5),
            ),
          ),
          style: TextStyle(color: appTheme.textColor),
        ),
      ),
      body: isLoading
          ? const Center(
              child: LoadingAnimation(),
            )
          : Column(
              children: [
                Expanded(
                    child: filteredBuddyingUsers.isEmpty
                        ? const Center(child: Text('No following users found.'))
                        : GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              childAspectRatio: 5,
                              mainAxisSpacing: 0.0,
                              crossAxisSpacing: 0.0,
                            ),
                            itemCount: filteredBuddyingUsers.length,
                            itemBuilder: (context, index) {
                              final user = filteredBuddyingUsers[index];
                              return GestureDetector(
                                onTap: () {
                                  if (user['userId'] != currentUserId) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => OtherProfilePage(
                                            userId: user['userId']),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const UserScreen(initialIndex: 4),
                                      ),
                                    );
                                  }
                                },
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  elevation: 5,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: appTheme.secondaryColor,
                                    ),
                                    child: Row(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(15.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color:
                                                    AppColors.genderBorderColor(
                                                        user['gender']),
                                                width: 2.5,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              backgroundImage:
                                                  CachedNetworkImageProvider(
                                                      user['userimage']),
                                              radius: 25,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            user['username'],
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: appTheme.textColor),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsets.only(right: 15.0),
                                          child: Icon(
                                            Icons.search,
                                            color: appTheme.secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )),
              ],
            ),
    );
  }
}
