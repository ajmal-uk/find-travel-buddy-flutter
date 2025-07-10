import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../utils/app_theme.dart';
import '../../../../../utils/counder.dart';

class AdminViewCommentSheet extends StatefulWidget {
  final String postId;

  const AdminViewCommentSheet({
    super.key,
    required this.postId,
  });

  @override
  AdminViewCommentSheetState createState() => AdminViewCommentSheetState();
}

class AdminViewCommentSheetState extends State<AdminViewCommentSheet> {
  List<Map<String, dynamic>> comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .get();

      final commentsMap =
          postDoc.data()?['comments'] as Map<String, dynamic>? ?? {};

      final List<Map<String, dynamic>> loadedComments = [];
      for (var entry in commentsMap.entries) {
        final commentData = entry.value as Map<String, dynamic>;
        final userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(commentData['commentBy'])
            .get();

        loadedComments.add({
          'id': entry.key,
          ...commentData,
          'username': userDoc.data()?['username'],
          'userimage': userDoc.data()?['userimage'],
        });
      }

      final allComments = loadedComments.toList();
      allComments.shuffle();

      setState(() {
        comments = [...allComments];
      });
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .update({
        'comments.$commentId': FieldValue.delete(),
      });
      _loadComments();
    } catch (e) {
      print('Error deleting comment: $e');
    }
  }

  void _showCommentOptions(Map<String, dynamic> comment) {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final appTheme = themeManager.currentTheme;
    showModalBottomSheet(
      backgroundColor: appTheme.secondaryColor,
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text('Delete',
                style: TextStyle(color: appTheme.textColor)),
            onTap: () {
              Navigator.pop(context);
              _deleteComment(comment['id']);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: appTheme.primaryColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appTheme.secondaryColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Comments:',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textColor),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      formatCount(comments.length),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: appTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: appTheme.secondaryTextColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: comments.length,
              itemBuilder: (context, index) {
                final comment = comments[index];
                return Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            CachedNetworkImageProvider(comment['userimage']),
                      ),
                      title: Text(comment['username'],
                          style: TextStyle(color: appTheme.textColor)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['comment'],
                            style: TextStyle(
                                fontSize: 14, color: appTheme.textColor),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatTimestamp(
                              (comment['commentedTime'] as Timestamp).toDate(),
                            ),
                            style: TextStyle(
                              color: appTheme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.more_vert,
                                color: appTheme.secondaryTextColor),
                            onPressed: () => _showCommentOptions(comment),
                          ),
                        ],
                      ),
                    ),
                    if (index != comments.length - 1) const Divider(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
