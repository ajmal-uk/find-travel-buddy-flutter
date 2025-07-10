import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/loading.dart';
import '../userDetailsScreen/others_user_profile.dart';
import '../userDetailsScreen/post&trip/post&trip/other_user_post_detail_screen.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    _markNotificationsAsSeen();
  }

  Future<void> _markNotificationsAsSeen() async {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final userCollection = FirebaseFirestore.instance.collection('user').doc(currentUserId);
    try {
      final querySnapshot = await userCollection
          .collection('notifications')
          .where('isSeen', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in querySnapshot.docs) {
          batch.update(doc.reference, {'isSeen': true});
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error marking notifications as seen: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final userCollection = FirebaseFirestore.instance.collection('user').doc(currentUserId);
      final querySnapshot = await userCollection.collection('notifications').get();
      
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing notifications: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('user')
          .doc(currentUserId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final String? postId = notification['postId'];
    final String? postUserId = notification['postUserId'];
    final String? userId = notification['userId'];

    if (postId != null && postUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherUserPostDetailScreen(
            postId: postId,
            userId: postUserId,
          ),
        ),
      );
    } else if (userId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtherProfilePage(userId: userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('User not logged in')),
      );
    }

    final userCollection = FirebaseFirestore.instance.collection('user').doc(currentUserId);

    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        iconTheme: IconThemeData(color: appTheme.textColor),
        backgroundColor: appTheme.secondaryColor,
        title: Text('Notifications', style: TextStyle(color: appTheme.textColor)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: appTheme.textColor),
            onSelected: (value) {
              if (value == 'clear_all') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Notifications'),
                    content: const Text('Are you sure you want to clear all notifications?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          _clearAllNotifications();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear All'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: userCollection
            .collection('notifications')
            .orderBy('time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingAnimation());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No notifications available',
                  style: TextStyle(color: appTheme.textColor)),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final notificationId = notifications[index].id;
              final title = notification['title'] ?? 'No Title';
              final message = notification['message'] ?? 'No Message';
              final date = notification['date'] != null
                  ? DateTime.parse(notification['date']).toLocal()
                  : null;
              final isSeen = notification['isSeen'] ?? true;

              return Card(
                color: appTheme.secondaryColor,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: ListTile(
                  onTap: () => _handleNotificationTap(notification),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: appTheme.textColor,
                          ),
                        ),
                      ),
                      if (!isSeen)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: TextStyle(color: appTheme.secondaryTextColor),
                      ),
                      if (date != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}',
                              style: TextStyle(
                                color: appTheme.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _deleteNotification(notificationId),
                    color: appTheme.textColor,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}