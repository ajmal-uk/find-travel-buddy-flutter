import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import '../../../../../services/post/firebase_post.dart';
import '../../../../../services/user/user_services.dart';
import '../../../../../utils/app_colors.dart';
import '../../../../../utils/app_theme.dart';
import '../../../../../utils/image_swipe.dart';
import '../../../../../utils/dialogues.dart';
import '../../../../../utils/counder.dart';
import '../../../../../utils/loading.dart';
import '../user_profile_view_screen.dart';
import 'admin_comment_view_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String userId;

  const PostDetailScreen({
    super.key,
    required this.postId,
    required this.userId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final UserService _userService = UserService();
  final UserPostServices _userPostServices = UserPostServices();

  int likeCount = 0;
  int commentCounts = 0;

  Future<void> _fetchCommentCounts() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .get();
      final comments =
          postDoc.data()?['comments'] as Map<String, dynamic>? ?? {};
      setState(() {
        commentCounts = comments.length;
      });
    } catch (e) {
      print('Error fetching comment count: $e');
    }
  }

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminViewCommentSheet(postId: widget.postId),
    );
  }

  Future<void> _countLikes() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .get();

      if (postDoc.exists) {
        final likes = List<String>.from(postDoc.data()?['likes'] ?? []);
        setState(() {
          likeCount = likes.length;
        });
      }
    } catch (e) {
      print('Error checking like status: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _countLikes();
    _fetchCommentCounts();
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
          'Post Details',
          style: TextStyle(
            color: appTheme.textColor,
          ),
        ),
        iconTheme: IconThemeData(
          color: appTheme.textColor,
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

            final tripFeedback = postData['tripFeedback'];
            final tripBuddies = postData['tripBuddies'] ?? ['user1', 'user2'];
            final locationImages = postData['locationImages'] ?? [];
            final visitedPalaces = postData['visitedPlaces'] ?? [];
            final planToVisitPlaces = postData['planToVisitPlaces'];
            final tripCompletedDuration = postData['tripCompletedDuration'];

            final uploadTime = postData['uploadedDateTime'] != null
                ? (postData['uploadedDateTime'] as Timestamp).toDate()
                : null;

            final formattedUploadTime =
                uploadTime != null ? formatTimestamp(uploadTime) : "N/A";

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
                        const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 28,
                        ),
                        Text(
                          formatCount(likeCount),
                          style: TextStyle(
                            fontSize: 14,
                            color: appTheme.textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 30),
                        IconButton(
                          icon: Icon(
                            Icons.comment_outlined,
                            color: appTheme.textColor,
                            size: 30,
                          ),
                          onPressed: () => _showCommentSheet(context),
                        ),
                        Text(
                          formatCount(commentCounts),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: appTheme.textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
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
                                        Color gridColor =
                                            AppColors.genderBorderColor(gender);
                                        return GestureDetector(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    OtherProfilePageForAdmin(
                                                  userId: buddyUserId,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Card(
                                            elevation: 5.0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10.0),
                                            ),
                                            color: gridColor,
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
                                            final placeName =
                                                visitedPalaces[index];

                                            return GestureDetector(
                                              onTap: () {
                                                showPlaceDialog(
                                                    context: context,
                                                    placeName: placeName);
                                              },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.all(8.0),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue
                                                      .withOpacity(0.1),
                                                  border: Border.all(
                                                      color: Colors.grey),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30.0),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    placeName.length > 15
                                                        ? '${placeName.substring(0, 12)}...'
                                                        : placeName,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
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
