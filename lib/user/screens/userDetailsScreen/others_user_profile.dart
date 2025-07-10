import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/counder.dart';
import '../../../utils/loading.dart';
import '../BuddyScreen/buddies_screen.dart';
import '../BuddyScreen/buddying_screen.dart';
import '../chat_&_group/chatScreen/chating_screen.dart';
import 'post&trip/post&trip/other_user_posts.dart';
import 'post&trip/post&trip/other_user_tripimage.dart';
import 'report_screen.dart';

class OtherProfilePage extends StatefulWidget {
  final String userId;
  const OtherProfilePage({super.key, required this.userId});

  @override
  OtherProfilePageState createState() => OtherProfilePageState();
}

class OtherProfilePageState extends State<OtherProfilePage> {
  bool showPosts = true;
  int totalPosts = 0;
  int completedPosts = 0;
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isBuddy = false;
  int buddiesCount = 0;
  int buddyingCount = 0;
  void _reloadChats() {}

  Future<void> _getBuddiesCount() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      final buddiesList = userDoc.data()?['buddies'] ?? [];
      setState(() {
        buddiesCount = buddiesList.length;
      });
    } catch (e) {
      print('Error fetching buddies count: $e');
    }
  }

  Future<void> _getBuddyingCount() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      final buddingList = userDoc.data()?['buddying'] ?? [];
      setState(() {
        buddyingCount = buddingList.length;
      });
    } catch (e) {
      print('Error fetching buddies count: $e');
    }
  }

  Future<String> _getOrCreateChatRoom() async {
    try {
      final chatQuery = await FirebaseFirestore.instance
          .collection('chat')
          .where('user', arrayContains: currentUserId)
          .get();
      for (var doc in chatQuery.docs) {
        final userIds = doc.data()['user'] as List<dynamic>? ?? [];
        if (userIds.contains(widget.userId)) {
          return doc.id;
        }
      }
      final newChatDoc =
          await FirebaseFirestore.instance.collection('chat').add({
        'user': [currentUserId, widget.userId],
        'latestMessage': '',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return newChatDoc.id;
    } catch (error) {
      throw Exception('Error creating or retrieving chat room: $error');
    }
  }

  Future<void> _checkBuddyingStatus() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        List<dynamic> buddiesList = userDoc['buddies'] ?? [];
        setState(() {
          isBuddy = buddiesList.contains(currentUserId);
        });
      }
    } catch (e) {
      print('Error checking following status: $e');
    }
  }

  Future<void> _toggleBuddy() async {
    try {
      DocumentReference userDocRef =
          FirebaseFirestore.instance.collection('user').doc(widget.userId);

      DocumentReference currentUserDocRef =
          FirebaseFirestore.instance.collection('user').doc(currentUserId);

      if (isBuddy) {
        await userDocRef.update({
          'buddies': FieldValue.arrayRemove([currentUserId]),
        });

        await currentUserDocRef.update({
          'buddying': FieldValue.arrayRemove([widget.userId]),
        });

        setState(() {
          isBuddy = false;
          buddiesCount = buddiesCount - 1;
        });
      } else {
        await userDocRef.update({
          'buddies': FieldValue.arrayUnion([currentUserId]),
        });

        await currentUserDocRef.update({
          'buddying': FieldValue.arrayUnion([widget.userId]),
        });
        setState(() {
          isBuddy = true;
          buddiesCount = buddiesCount + 1;
        });
      }
    } catch (e) {
      print('Error toggling buddy status: $e');
    }
  }

  Future<void> _getUserProfilePosts() async {
    try {
      QuerySnapshot userPostsSnapshot = await FirebaseFirestore.instance
          .collection('post')
          .where('userid', isEqualTo: currentUserId)
          .get();

      List<QueryDocumentSnapshot> userPosts = userPostsSnapshot.docs;

      setState(() {
        totalPosts = userPosts.length;
        completedPosts =
            userPosts.where((doc) => doc['tripCompleted'] == true).length;
      });
    } catch (e) {
      print('Error fetching user posts: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserProfilePosts();
    _checkBuddyingStatus();
    _getBuddiesCount();
    _getBuddyingCount();
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
        title: Text(
          'Profile..',
          style: TextStyle(color: appTheme.textColor),
        ),
        actions: [
          PopupMenuButton<String>(
            color: appTheme.secondaryColor,
            onSelected: (value) {
              if (value == 'Report') {
                showDialog(
                  context: context,
                  builder: (context) => ReportDialog(
                    userId: widget.userId,
                    currentUserId: currentUserId,
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'Report',
                  child: Text(
                    'Report',
                    style: TextStyle(color: appTheme.textColor),
                  ),
                ),
              ];
            },
            icon: Icon(
              Icons.more_vert,
              color: appTheme.secondaryTextColor,
            ),
            offset: const Offset(0, 50),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('user')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Stack(
              children: [
                Positioned(
                  left: 0.0,
                  top: 0.0,
                  right: 0.0,
                  bottom: 0.0,
                  child: Center(child: LoadingAnimation()),
                ),
              ],
            );
          } else if (snapshot.hasError) {
            return Center(
                child: Text(
              "Error loading profile data",
              style: TextStyle(color: appTheme.textColor),
            ));
          } else if (snapshot.hasData) {
            final profileData = snapshot.data?.data();
            var userImage = profileData!['userimage'];
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: InteractiveViewer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.genderBorderColor(
                                                profileData['gender'] ?? ''),
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                          child: Image(
                                            image: CachedNetworkImageProvider(
                                                userImage),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.genderBorderColor(
                                    profileData['gender'] ?? ''),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  CachedNetworkImageProvider(userImage),
                              backgroundColor: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => BuddiesPage(
                                              userId: widget.userId),
                                        ),
                                      );
                                    },
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            formatCount(buddiesCount),
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: appTheme.textColor),
                                          ),
                                          Text(
                                            'Buddies',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.normal,
                                                color: appTheme
                                                    .secondaryTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 30),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              BuddyingUserPage(
                                                  userId: widget.userId),
                                        ),
                                      );
                                    },
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            formatCount(buddyingCount),
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: appTheme.textColor),
                                          ),
                                          Text(
                                            'Buddying',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.normal,
                                                color: appTheme
                                                    .secondaryTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 30),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        formatCount(totalPosts),
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: appTheme.textColor),
                                      ),
                                      Text(
                                        'Posts',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.normal,
                                            color: appTheme.secondaryTextColor),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 30),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        formatCount(completedPosts),
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: appTheme.textColor),
                                      ),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.normal,
                                            color: appTheme.secondaryTextColor),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profileData['fullname'],
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: appTheme.textColor),
                        ),
                        const SizedBox(height: 8),
                        //Text('DOB: ${profileData['dob']}'),
                        // const SizedBox(height: 8),
                        // Text('Gender: ${profileData['gender']}'),
                        // const SizedBox(height: 16),
                        Text(profileData['userbio'] ?? '',
                            style: TextStyle(
                                fontSize: 12, color: appTheme.textColor)),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if ((profileData['instagram']?.isNotEmpty ?? false))
                        IconButton(
                          onPressed: () {
                            final instagramLink = profileData['instagram'];
                            launchUrl(Uri.parse(instagramLink));
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.instagram,
                            color: Colors.purple,
                            size: 15,
                          ),
                          tooltip: 'Instagram',
                        ),
                      if ((profileData['instagram']?.isNotEmpty ?? false))
                        const SizedBox(width: 6),

                      // Twitter (X) Icon
                      if ((profileData['x']?.isNotEmpty ?? false))
                        IconButton(
                          onPressed: () {
                            final twitterLink = profileData['x'];
                            launchUrl(Uri.parse(twitterLink));
                          },
                          icon: FaIcon(
                            FontAwesomeIcons.x,
                            color: appTheme.textColor,
                            size: 15,
                          ),
                          tooltip: 'X',
                        ),
                      if ((profileData['x']?.isNotEmpty ?? false))
                        const SizedBox(width: 6),
                      if ((profileData['facebook']?.isNotEmpty ?? false))
                        IconButton(
                          onPressed: () {
                            final facebookLink = profileData['facebook'];
                            launchUrl(Uri.parse(facebookLink));
                          },
                          icon: const FaIcon(
                            FontAwesomeIcons.facebook,
                            color: Colors.blue,
                            size: 15,
                          ),
                          tooltip: 'Facebook',
                        ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.95,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: ElevatedButton(
                                  onPressed: _toggleBuddy,
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: appTheme.textColor,
                                    backgroundColor: appTheme.secondaryColor,
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: 0.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  child: Text(isBuddy ? "Buddying" : "Buddy"),
                                ),
                              ),
                              const SizedBox(width: 5),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      final chatRoomId =
                                          await _getOrCreateChatRoom();
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ChatScreen(
                                            currentUserId: currentUserId,
                                            chatUserId: widget.userId,
                                            chatRoomId: chatRoomId,
                                            onMessageSent: _reloadChats,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(content: Text('Error: $e')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: appTheme.textColor,
                                    backgroundColor: appTheme.secondaryColor,
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: 0.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  child: const Text("Message"),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  showPosts = true;
                                });
                              },
                              icon: Icon(
                                Icons.grid_on,
                                color: showPosts
                                    ? Colors.blue
                                    : appTheme.textColor,
                              ),
                              label: Text(
                                'Posts',
                                style: TextStyle(
                                  color: showPosts
                                      ? Colors.blue
                                      : appTheme.textColor,
                                ),
                              ),
                            ),
                            if (showPosts)
                              Container(
                                height: 2,
                                width: 50,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  showPosts = false;
                                });
                              },
                              icon: Icon(
                                Icons.photo_album,
                                color: !showPosts
                                    ? Colors.blue
                                    : appTheme.textColor,
                              ),
                              label: Text(
                                'Trip Images',
                                style: TextStyle(
                                  color: !showPosts
                                      ? Colors.blue
                                      : appTheme.textColor,
                                ),
                              ),
                            ),
                            if (!showPosts)
                              Container(
                                height: 2,
                                width: 50,
                                color: Colors.blue,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (showPosts)
                    UserPostsWidget(userId: widget.userId)
                  else
                    UserTripImagesWidget(userId: widget.userId)
                ],
              ),
            );
          } else {
            return Text("No data available",
                style: TextStyle(color: appTheme.textColor));
          }
        },
      ),
    );
  }
}
