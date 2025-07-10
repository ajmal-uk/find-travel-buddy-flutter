import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/one_signal.dart';
import '../../../../user/screens/profileScreen/post&trip/current_user_tripimage.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/counder.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/loading.dart';
import '../../messageScreen/sent_message_screen.dart';
import 'BuddyScreen/buddies_screen_for_admin.dart';
import 'BuddyScreen/buddying_screen_for_admin.dart';
import 'adminViewPost&trip/user_posts.dart';

class OtherProfilePageForAdmin extends StatefulWidget {
  final String userId;
  const OtherProfilePageForAdmin({super.key, required this.userId});

  @override
  OtherProfilePageStateForAdmin createState() =>
      OtherProfilePageStateForAdmin();
}

class OtherProfilePageStateForAdmin extends State<OtherProfilePageForAdmin> {
  bool showPosts = true;
  int totalPosts = 0;
  int completedPosts = 0;
  int buddiesCount = 0;
  int buddyingCount = 0;

  void _showConfirmationDialog(
      String userId, bool isRemoved, String username, List<String> onId) {
    showConfirmationDialog(
      context: context,
      title: isRemoved ? 'Restrict User' : 'Reinstate User',
      message: isRemoved
          ? 'Are you sure you want to restrict this $username?'
          : 'Are you sure you want to reinstate this  $username?',
      cancelButtonText: 'Cancel',
      confirmButtonText: isRemoved ? 'Remove' : 'Add',
      onConfirm: () async {
        try {
          await FirebaseFirestore.instance
              .collection('user')
              .doc(widget.userId)
              .update({'isRemoved': isRemoved});

          final List<String> playerIds = onId;
          if (playerIds.isNotEmpty) {
            final title = isRemoved ? "Temporarily banned" : "Unbanned";
            final description = isRemoved
                ? "Your account has been restricted."
                : "Your account has been reinstated.";
            await NotificationService().sentNotificationtoUser(
              title: title,
              description: description,
              onIds: playerIds,
            );
          }

          setState(() {});
        } catch (e) {
          print("Error updating user status: $e");
        }
      },
      titleIcon: isRemoved
          ? const Icon(Icons.delete_forever, color: Colors.red)
          : const Icon(Icons.add, color: Colors.green),
      titleColor: isRemoved ? Colors.redAccent : Colors.greenAccent,
      cancelButtonColor: Colors.blue,
      confirmButtonColor: isRemoved ? Colors.red : Colors.green,
    );
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

  Future<void> _getUserProfilePosts() async {
    try {
      String userId = widget.userId;
      QuerySnapshot userPostsSnapshot = await FirebaseFirestore.instance
          .collection('post')
          .where('userid', isEqualTo: userId)
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
        backgroundColor: appTheme.secondaryColor,
        title: Text(
          'Profile..',
          style: TextStyle(color: appTheme.textColor),
        ),
        iconTheme: IconThemeData(
          color: appTheme.textColor,
        ),
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
            return const Center(child: Text("Error loading profile data"));
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
                                          builder: (context) =>
                                              BuddiesPageForAdmin(
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
                                                color: appTheme.textColor),
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
                                              BuddyingUserPageForAdmin(
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
                                                color: appTheme.textColor),
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
                                            color: appTheme.textColor),
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
                                            color: appTheme.textColor),
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
                        Text(
                          'DOB: ${profileData['dob']}',
                          style: TextStyle(color: appTheme.textColor),
                        ),
                        const SizedBox(height: 8),
                        Text('Gender: ${profileData['gender']}',
                            style: TextStyle(color: appTheme.textColor)),
                        const SizedBox(height: 8),
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
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SentMessagePage(
                                          userNameFromPreviousPage:
                                              profileData['username'],
                                          disableSendToAll: true,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.greenAccent,
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: 0.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  child: const Text("Notify"),
                                ),
                              ),
                              const SizedBox(width: 5),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.45,
                                child: ElevatedButton(
                                  onPressed: () {
                                    bool currentStatus =
                                        profileData['isRemoved'] ?? false;

                                    _showConfirmationDialog(
                                        widget.userId,
                                        !currentStatus,
                                        profileData['username'],
                                        List<String>.from(
                                            profileData['onId'] ?? []));
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor:
                                        (profileData['isRemoved'] ?? false)
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: 0.3,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  child: Text(
                                    (profileData['isRemoved'] ?? false)
                                        ? "Add"
                                        : "Remove",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
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
                                color: appTheme.textColor,
                              ),
                              label: Text(
                                'Posts',
                                style: TextStyle(color: appTheme.textColor),
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
                                color: appTheme.textColor,
                              ),
                              label: Text(
                                'Trip Images',
                                style: TextStyle(color: appTheme.textColor),
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
            return const Text("No data available");
          }
        },
      ),
    );
  }
}
