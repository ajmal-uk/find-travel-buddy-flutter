import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../../../services/post/firebase_post.dart';
import '../../../../services/user/user_services.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/counder.dart';
import '../../../../utils/loading.dart';
import '../../commentScreen/comment_screen.dart';
import '../../userDetailsScreen/others_user_profile.dart';
import '../../user_screen.dart';
import 'post_complete_screen.dart';
import '../../../../utils/image_swipe.dart';

class CurrentUserPostDetailScreen extends StatefulWidget {
  final String postId;
  final String userId;
  final int commentCount;

  const CurrentUserPostDetailScreen({
    super.key,
    required this.postId,
    required this.userId,
    this.commentCount = -1,
  });

  @override
  State<CurrentUserPostDetailScreen> createState() =>
      _CurrentUserPostDetailScreenState();
}

class _CurrentUserPostDetailScreenState
    extends State<CurrentUserPostDetailScreen> {
  final UserService _userService = UserService();
  final UserPostServices _userPostServices = UserPostServices();
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool isLiked = false;
  int likeCount = 0;

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentSheet(postId: widget.postId, postUserId: widget.userId),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .get();

      if (postDoc.exists) {
        final likes = List<String>.from(postDoc.data()?['likes'] ?? []);
        setState(() {
          isLiked = likes.contains(currentUserId);
          likeCount = likes.length;
        });
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  Future<void> _toggleLike() async {
    try {
      final postRef =
          FirebaseFirestore.instance.collection('post').doc(widget.postId);

      setState(() {
        isLiked = !isLiked;
        likeCount += isLiked ? 1 : -1;
      });

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) {
          throw Exception('Post does not exist!');
        }

        List<String> likes = List<String>.from(postDoc.data()?['likes'] ?? []);

        if (isLiked) {
          if (!likes.contains(currentUserId)) {
            likes.add(currentUserId);
          }
        } else {
          likes.remove(currentUserId);
        }

        transaction.update(postRef, {'likes': likes});
      });
    } catch (e) {
      setState(() {
        isLiked = !isLiked;
        likeCount += isLiked ? 1 : -1;
      });
      print('Error toggling like: $e');
    }
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
          'Post Details',
          style: TextStyle(
            color: appTheme.textColor,
          ),
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          _userService.fetchUserDetails(userId: widget.userId),
          _userPostServices.fetchPostDetails(postId: widget.postId),
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingAnimation();
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final userData = snapshot.data![0] as Map<String, dynamic>;
            final postData = snapshot.data![1] as Map<String, dynamic>;
            final username = userData['username'];
            final userimage = userData['userimage'] ??
                [
                  'https://res.cloudinary.com/dakew8wni/image/upload/v1733819145/public/userImage/fvv6lbzdjhyrc1fhemaj.jpg'
                ];

            final locationDescription =
                postData['locationDescription'] ?? 'unKnown';
            final locationName = postData['locationName'] ?? 'unKnown';
            final tripDuration = postData['tripDuration'] ?? 0;
            final isTripCompleted = postData['tripCompleted'];
            final tripRating = (postData['tripRating'] ?? 0).toDouble();

            final uploadTime = postData['uploadedDateTime'] != null
                ? (postData['uploadedDateTime'] as Timestamp).toDate()
                : null;

            final formattedUploadTime =
                uploadTime != null ? formatTimestamp(uploadTime) : "N/A";

            final tripFeedback = postData['tripFeedback'];
            final tripBuddies = postData['tripBuddies'] ?? ['user1', 'user2'];
            final locationImages = postData['locationImages'] ?? [];
            final visitedPalaces = postData['visitedPlaces'] ?? [];
            final planToVisitPlaces = postData['planToVisitPlaces'];
            final tripCompletedDuration = postData['tripCompletedDuration'];

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: CircleAvatar(
                            radius: 30.0,
                            backgroundImage:
                                CachedNetworkImageProvider(userimage),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              username,
                              style: TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                  color: appTheme.textColor),
                            )
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    ImageCarousel(locationImages: locationImages),
                    const SizedBox(height: 16.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.favorite,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 30,
                          ),
                          onPressed: _toggleLike,
                        ),
                        Text(
                          formatCount(likeCount),
                          style: TextStyle(
                            fontSize: 14,
                            color: appTheme.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: Icon(
                            Icons.comment_outlined,
                            color: appTheme.textColor,
                            size: 30,
                          ),
                          onPressed: () => _showCommentSheet(context),
                        ),
                        if (widget.commentCount != -1)
                          Text(
                            formatCount(widget.commentCount),
                            style: TextStyle(
                              fontSize: 14,
                              color: appTheme.textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (uploadTime != null)
                              Text(
                                'Posted at $formattedUploadTime',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: appTheme.secondaryTextColor,
                                ),
                              ),
                            const SizedBox(height: 8.0),
                            Text(
                              'Trip to $locationName ',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: appTheme.textColor),
                            ),
                            const SizedBox(height: 8.0),
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              child: Text(
                                locationDescription,
                                textAlign: TextAlign.center,
                                softWrap: true,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: appTheme.secondaryTextColor),
                              ),
                            ),
                            const SizedBox(height: 10.0),
                          ],
                        ),
                      ],
                    ),
                    const Divider(
                      thickness: 2.0,
                      indent: 20.0,
                      endIndent: 20.0,
                    ),
                    const SizedBox(height: 10.0),
                    if (!isTripCompleted) ...[
                      Center(
                        child: Text(
                          'Trip Duration Plan : $tripDuration days',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: appTheme.textColor),
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      if (planToVisitPlaces.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: Text(
                                  'Visiting Places Plan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 255, 200, 118),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      (constraints.maxWidth / 100).floor();
                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount > 0
                                          ? crossAxisCount
                                          : 1,
                                      crossAxisSpacing: 8.0,
                                      mainAxisSpacing: 8.0,
                                      childAspectRatio: 2,
                                    ),
                                    itemCount: planToVisitPlaces.length,
                                    itemBuilder: (context, index) {
                                      final placeName =
                                          planToVisitPlaces[index];

                                      return GestureDetector(
                                        onTap: () {
                                          showPlaceDialog(
                                              context: context,
                                              placeName: placeName);
                                        },
                                        child: Container(
                                          padding: EdgeInsets.all(8.0),
                                          decoration: BoxDecoration(
                                            color: appTheme.secondaryColor,
                                            border:
                                                Border.all(color: Colors.grey),
                                            borderRadius:
                                                BorderRadius.circular(30.0),
                                          ),
                                          child: Center(
                                            child: Text(
                                              placeName.length > 15
                                                  ? '${placeName.substring(0, 12)}...'
                                                  : placeName,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: appTheme.textColor),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8.0),
                    ],
                    if (isTripCompleted) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.green[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Trip Completed',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                            const SizedBox(height: 8.0),
                            if (tripBuddies.isNotEmpty) ...[
                              GridView.builder(
                                shrinkWrap: true,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10.0,
                                  mainAxisSpacing: 10.0,
                                ),
                                itemCount: tripBuddies.length,
                                itemBuilder: (context, index) {
                                  final buddyUserId = tripBuddies[index];
                                  return FutureBuilder<Map<String, dynamic>>(
                                    future: _userService.fetchUserDetails(
                                        userId: buddyUserId),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasData) {
                                        final buddy = snapshot.data!;
                                        String gender =
                                            buddy['gender'].toLowerCase();

                                        return GestureDetector(
                                          onTap: () {
                                            if (buddyUserId != currentUserId) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      OtherProfilePage(
                                                    userId: buddyUserId,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const UserScreen(
                                                          initialIndex: 4),
                                                ),
                                              );
                                            }
                                          },
                                          child: Card(
                                            elevation: 5.0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            ),
                                            color: AppColors.genderBorderColor(
                                                gender),
                                            child: Column(
                                              children: [
                                                const SizedBox(height: 20.0),
                                                CircleAvatar(
                                                  radius: 25.0,
                                                  backgroundImage:
                                                      CachedNetworkImageProvider(
                                                          buddy['userimage']),
                                                ),
                                                const SizedBox(width: 10.0),
                                                Expanded(
                                                  child: Text(
                                                    buddy['username'],
                                                    style: const TextStyle(
                                                        fontSize: 10),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Center(
                                            child: Text(
                                                'Error: ${snapshot.error}'));
                                      }
                                      return const SizedBox();
                                    },
                                  );
                                },
                              )
                            ],
                            const SizedBox(height: 15.0),
                            if (visitedPalaces.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Center(
                                      child: Text(
                                        'Visited Places',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              Color.fromARGB(255, 255, 104, 16),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final crossAxisCount =
                                            (constraints.maxWidth / 100)
                                                .floor();
                                        return GridView.builder(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: crossAxisCount > 0
                                                ? crossAxisCount
                                                : 1,
                                            crossAxisSpacing: 8.0,
                                            mainAxisSpacing: 8.0,
                                            childAspectRatio: 2,
                                          ),
                                          itemCount: visitedPalaces.length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              padding:
                                                  const EdgeInsets.all(8.0),
                                              decoration: BoxDecoration(
                                                color: const Color.fromARGB(
                                                    255, 179, 255, 251),
                                                border: Border.all(
                                                    color: Colors.grey),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  visitedPalaces[index],
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 8.0),
                            if (tripRating != null)
                              RatingBar.builder(
                                initialRating: tripRating,
                                minRating: 0,
                                itemSize: 20,
                                direction: Axis.horizontal,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.yellow,
                                ),
                                onRatingUpdate: (rating) {
                                  print(rating);
                                },
                              ),
                            const SizedBox(height: 20.0),
                            if (tripFeedback != null)
                              Text(
                                'Feedback : $tripFeedback',
                                style: const TextStyle(fontSize: 16),
                              ),
                            const SizedBox(height: 8.0),
                            if (tripCompletedDuration != null)
                              Text(
                                'Trip Duration : $tripCompletedDuration',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              showConfirmationDialog(
                                context: context,
                                title: 'Delete Image',
                                message:
                                    'Are you sure you want to delete this post?',
                                cancelButtonText: 'Cancel',
                                confirmButtonText: 'Delete',
                                onConfirm: () async {
                                  await UserPostServices()
                                      .deletePost(widget.postId);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                                titleIcon: const Icon(Icons.delete_forever,
                                    color: Colors.red),
                                titleColor: Colors.redAccent,
                                cancelButtonColor: Colors.blue,
                                confirmButtonColor: Colors.red,
                                subMessage:
                                    'This action is irreversible. The post will be permanently deleted.',
                              );
                            },
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Remove',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          if (!isTripCompleted)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostCompleteScreen(
                                      postId: widget.postId,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.done,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'complete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            return const Center(child: Text('No data found.'));
          }
        },
      ),
    );
  }
}
