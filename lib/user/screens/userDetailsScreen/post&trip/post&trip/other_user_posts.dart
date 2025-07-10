import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../services/post/firebase_post.dart';
import '../../../../../utils/app_theme.dart';
import '../../../../../utils/image_swipe.dart';
import '../../../../../utils/loading.dart';
import 'other_user_post_detail_screen.dart';

class UserPostsWidget extends StatefulWidget {
  final String userId;

  const UserPostsWidget({
    super.key,
    required this.userId,
  });

  @override
  UserPostsWidgetState createState() => UserPostsWidgetState();
}

class UserPostsWidgetState extends State<UserPostsWidget> {
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: UserPostServices().fetchUserPosts(userId: widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingAnimation();
        }

        if (snapshot.hasError) {
          return Center(
              child: Text(
            'Error fetching posts.',
            style: TextStyle(color: appTheme.textColor),
          ));
        }

        final userPosts = snapshot.data ?? [];

        return userPosts.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 50),
                    const Text('🚫', style: TextStyle(fontSize: 50)),
                    Text(
                      'No posts available',
                      style: TextStyle(color: appTheme.textColor),
                    ),
                  ],
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 0.80,
                ),
                itemCount: userPosts.length,
                itemBuilder: (context, index) {
                  final post = userPosts[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OtherUserPostDetailScreen(
                            postId: post['postId'],
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: appTheme.secondaryColor,
                            border: Border.all(
                                color: appTheme.secondaryTextColor,
                                width: 0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  height: 100,
                                  width: double.infinity,
                                  child: ImageCarousel(
                                    locationImages:
                                        post['locationImages']?.isNotEmpty ==
                                                true
                                            ? post['locationImages']
                                            : [
                                                'https://res.cloudinary.com/dakew8wni/image/upload/v1734019072/public/postimages/mwtjtugc4ppu02vwiv49.png',
                                              ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    Center(
                                      child: Text(
                                        post['locationName'] != null &&
                                                post['locationName']!.length >
                                                    10
                                            ? '${post['locationName']!.substring(0, 10)}...'
                                            : post['locationName'] ?? 'Unknown',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: appTheme.textColor,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                    if (post['tripCompleted'] ?? false)
                                      Center(
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(top: 4.0),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1.0),
                                          decoration: BoxDecoration(
                                            color: Colors.green[300],
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: const Text(
                                            'Completed',
                                            style: TextStyle(
                                              fontSize: 6,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
      },
    );
  }
}
