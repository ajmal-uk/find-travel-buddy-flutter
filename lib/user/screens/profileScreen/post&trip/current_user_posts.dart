import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/post/firebase_post.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/image_swipe.dart';
import '../../../../utils/loading.dart';
import 'post_complete_screen.dart';
import 'post_detail_screen.dart';

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
  final UserPostServices _userPostServices = UserPostServices();

  void showPostOptions(BuildContext context, Map<String, dynamic> post) {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final appTheme = themeManager.currentTheme;
    showModalBottomSheet(
      backgroundColor: appTheme.secondaryColor,
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!(post['tripCompleted'] ?? false))
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                  title: Text(
                    'Complete',
                    style: TextStyle(color: appTheme.textColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostCompleteScreen(
                          postId: post['postId'],
                        ),
                      ),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                ),
                title:
                    Text('Delete', style: TextStyle(color: appTheme.textColor)),
                onTap: () {
                  showConfirmationDialog(
                    context: context,
                    title: 'Delete Image',
                    message: 'Are you sure you want to delete this post?',
                    cancelButtonText: 'Cancel',
                    confirmButtonText: 'Delete',
                    onConfirm: () async {
                      Navigator.of(context).pop();
                      await _userPostServices.deletePost(post['postId']);
                      setState(() {});
                    },
                    titleIcon:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    titleColor: Colors.redAccent,
                    cancelButtonColor: Colors.blue,
                    confirmButtonColor: Colors.red,
                    subMessage:
                        'This action is irreversible. The post will be permanently deleted.',
                  );
                },
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userPostServices.fetchUserPosts(userId: widget.userId),
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
                          builder: (context) => CurrentUserPostDetailScreen(
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
                        Positioned(
                          top: 4,
                          right: 4,
                          child: IconButton(
                            icon: const Icon(Icons.more_vert),
                            onPressed: () => showPostOptions(context, post),
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
