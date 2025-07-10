import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../services/cloudinary_upload.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/floating_button.dart';
import '../../../../utils/loading.dart';

class Group {
  final String id;
  final String name;
  final String creatorId;
  final List<String> adminIds;
  final List<String> memberIds;
  final DateTime createdAt;
  final String imageUrl;
  final Map<String, int> unreadMessages;
  final DateTime? lastMessageTimestamp;

  Group({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.adminIds,
    required this.memberIds,
    required this.createdAt,
    this.imageUrl =
        'https://res.cloudinary.com/dakew8wni/image/upload/v1735062043/pngtree-group-icon-png-image_1796653_foxnfp.jpg',
    this.unreadMessages = const {},
    this.lastMessageTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'creatorId': creatorId,
      'adminIds': adminIds,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'imageUrl': imageUrl,
      'unreadMessages': unreadMessages,
      'lastMessageTimestamp': lastMessageTimestamp?.toIso8601String(),
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'],
      name: map['name'],
      creatorId: map['creatorId'],
      adminIds: List<String>.from(map['adminIds']),
      memberIds: List<String>.from(map['memberIds']),
      createdAt: DateTime.parse(map['createdAt']),
      imageUrl: map['imageUrl'] ??
          'https://res.cloudinary.com/dakew8wni/image/upload/v1735062043/pngtree-group-icon-png-image_1796653_foxnfp.jpg',
      unreadMessages: Map<String, int>.from(map['unreadMessages'] ?? {}),
      lastMessageTimestamp: map['lastMessageTimestamp'] != null
          ? DateTime.parse(map['lastMessageTimestamp'])
          : null,
    );
  }
}

// models/message.dart
class Message {
  final String id;
  final String groupId;
  final String senderId;
  final String senderUsername;
  final String content;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderUsername,
    required this.content,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'senderId': senderId,
      'senderUsername': senderUsername,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      groupId: map['groupId'],
      senderId: map['senderId'],
      senderUsername: map['senderUsername'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences _prefs;

  FirebaseService(this._prefs);

  // Create a new group
  Future<void> createGroup(
      String name, String creatorId, List<String> memberIds) async {
    final group = Group(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      creatorId: creatorId,
      adminIds: [creatorId],
      memberIds: [...memberIds, creatorId],
      createdAt: DateTime.now(),
    );

    await _firestore.collection('groups').doc(group.id).set(group.toMap());
    await _saveGroupLocally(group);
  }

  Stream<List<Group>> getUserGroups(String userId) async* {
    try {
      // First emit cached data
      final cachedGroups = await _getCachedGroups(userId);
      if (cachedGroups.isNotEmpty) {
        yield cachedGroups;
      }

      // Then listen to Firestore updates
      await for (final snapshot in _firestore
          .collection('groups')
          .where('memberIds', arrayContains: userId)
          .snapshots()) {
        final groups =
            snapshot.docs.map((doc) => Group.fromMap(doc.data())).toList();

        // Update cache
        await _cacheGroups(groups);

        // Get latest message timestamp for each group
        final groupsWithTimestamp = await Future.wait(
          groups.map((group) async {
            final latestMessageSnapshot = await _firestore
                .collection('groups')
                .doc(group.id)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(1)
                .get();

            final timestamp = latestMessageSnapshot.docs.isNotEmpty
                ? DateTime.parse(latestMessageSnapshot.docs.first['timestamp'])
                : group.createdAt;

            return MapEntry(group, timestamp);
          }),
        );

        // Sort groups by latest message timestamp
        groupsWithTimestamp.sort((a, b) => b.value.compareTo(a.value));
        yield groupsWithTimestamp.map((e) => e.key).toList();
      }
    } catch (e) {
      print('Error in getUserGroups: $e');
      rethrow;
    }
  }

  // Cache management methods remain the same
  Future<List<Group>> _getCachedGroups(String userId) async {
    try {
      final cachedGroupsJson = _prefs.getString('cached_groups_$userId');
      if (cachedGroupsJson != null) {
        final List<dynamic> groupsList = json.decode(cachedGroupsJson);
        return groupsList.map((json) => Group.fromMap(json)).toList();
      }
    } catch (e) {
      print('Error reading cached groups: $e');
    }
    return [];
  }

  Future<void> _cacheGroups(List<Group> groups) async {
    try {
      final groupsJson = json.encode(groups.map((g) => g.toMap()).toList());
      await _prefs.setString(
          'cached_groups_${groups.first.creatorId}', groupsJson);
    } catch (e) {
      print('Error caching groups: $e');
    }
  }

  Future<void> sendMessage(Message message) async {
    // Start a batch write
    final batch = _firestore.batch();

    // Add the message
    final messageRef = _firestore
        .collection('groups')
        .doc(message.groupId)
        .collection('messages')
        .doc(message.id);
    batch.set(messageRef, message.toMap());

    // Update the group's lastMessageTimestamp
    final groupRef = _firestore.collection('groups').doc(message.groupId);
    batch.update(groupRef, {
      'lastMessageTimestamp': message.timestamp.toIso8601String(),
    });

    // Commit the batch
    await batch.commit();
    await _saveMessageLocally(message);
  }

  // Get group messages
  Stream<List<Message>> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList();
    });
  }

  // Add user to group
  Future<void> addUserToGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
    });
  }

  // Remove user from group
  Future<void> removeUserFromGroup(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
    });
  }

  // Make user admin
  Future<void> makeUserAdmin(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
    });
  }

  // Local storage methods
  Future<void> _saveGroupLocally(Group group) async {
    final groups = _prefs.getStringList('groups') ?? [];
    groups.add(group.id);
    await _prefs.setStringList('groups', groups);
    await _prefs.setString('group_${group.id}', group.toMap().toString());
  }

  Future<void> _saveMessageLocally(Message message) async {
    final messages = _prefs.getStringList('messages_${message.groupId}') ?? [];
    messages.add(message.id);
    await _prefs.setStringList('messages_${message.groupId}', messages);
    await _prefs.setString('message_${message.id}', message.toMap().toString());
  }

  Future<void> updateGroup(String groupId, String name, String imageUrl) async {
    await _firestore.collection('groups').doc(groupId).update({
      'name': name,
      'imageUrl': imageUrl,
    });
  }

  Future<void> incrementUnreadMessages(String groupId, String senderId) async {
    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    final group = Group.fromMap(groupDoc.data()!);

    for (String memberId in group.memberIds) {
      if (memberId != senderId) {
        await _firestore.collection('groups').doc(groupId).update({
          'unreadMessages.$memberId': FieldValue.increment(1),
        });
      }
    }
  }

  Future<void> clearUnreadMessages(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'unreadMessages.$userId': 0,
    });
  }
}

class GroupHomeScreen extends StatefulWidget {
  final String currentUserId;
  final FirebaseService firebaseService;

  const GroupHomeScreen({
    super.key,
    required this.currentUserId,
    required this.firebaseService,
  });

  @override
  GroupHomeScreenState createState() => GroupHomeScreenState();
}

class GroupHomeScreenState extends State<GroupHomeScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;

    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      floatingActionButton: FloatingChatButton(
        heroTag: 'CreateGroup',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateGroupScreen(
                currentUserId: widget.currentUserId,
                firebaseService: widget.firebaseService,
              ),
            ),
          );
        },
        imageIcon: const AssetImage("assets/system/iconImage/createGroup.png"),
        buttonColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                fillColor: appTheme.primaryColor,
                hintText: 'Search...',
                hintStyle:
                    TextStyle(color: appTheme.secondaryTextColor, fontSize: 16),
                prefixIcon:
                    Icon(Icons.search, color: appTheme.secondaryTextColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: appTheme.secondaryTextColor),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
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
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: TextStyle(color: appTheme.textColor),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Group>>(
              stream:
                  widget.firebaseService.getUserGroups(widget.currentUserId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: appTheme.textColor),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {});
                          },
                          child: Text(
                            'Retry',
                            style: TextStyle(color: appTheme.textColor),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LoadingAnimation(),
                        SizedBox(height: 16),
                        Text(
                          'Loading groups...',
                          style: TextStyle(color: appTheme.textColor),
                        ),
                      ],
                    ),
                  );
                }

                final groups = snapshot.data!;
                final filteredGroups = groups
                    .where((group) => group.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                if (filteredGroups.isEmpty) {
                  if (_searchQuery.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_outlined,
                              size: 48, color: appTheme.secondaryTextColor),
                          SizedBox(height: 16),
                          Text(
                            'No groups yet',
                            style: TextStyle(color: appTheme.textColor),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a new group to get started',
                            style:
                                TextStyle(color: appTheme.secondaryTextColor),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 48, color: appTheme.secondaryTextColor),
                          const SizedBox(height: 16),
                          Text(
                            'No groups found matching "$_searchQuery"',
                            style: TextStyle(color: appTheme.textColor),
                          ),
                        ],
                      ),
                    );
                  }
                }

                return ListView.builder(
                  itemCount: filteredGroups.length,
                  itemBuilder: (context, index) {
                    final group = filteredGroups[index];
                    final unreadCount =
                        group.unreadMessages[widget.currentUserId] ?? 0;

                    return StreamBuilder<List<Message>>(
                      stream: widget.firebaseService.getGroupMessages(group.id),
                      builder: (context, messageSnapshot) {
                        String lastMessage = '';
                        if (messageSnapshot.hasData &&
                            messageSnapshot.data!.isNotEmpty) {
                          final latestMessage = messageSnapshot.data!.first;
                          lastMessage =
                              '${latestMessage.senderUsername}: ${_truncateMessage(latestMessage.content)}';
                        }

                        return ListTile(
                          leading: CachedNetworkImage(
                            imageUrl: group.imageUrl,
                            imageBuilder: (context, imageProvider) =>
                                CircleAvatar(
                              backgroundImage: imageProvider,
                              radius: 25,
                            ),
                            placeholder: (context, url) => CircleAvatar(
                              radius: 25,
                              child: Icon(Icons.group,
                                  color: appTheme.secondaryTextColor),
                            ),
                            errorWidget: (context, url, error) =>
                                const CircleAvatar(
                              radius: 25,
                              child: Icon(
                                Icons.error,
                                color: Colors.red,
                              ),
                            ),
                          ),
                          title: Text(
                            group.name.length > 19
                                ? '${group.name.substring(0, 15)}...'
                                : group.name,
                            style: TextStyle(
                                fontSize: 18, color: appTheme.textColor),
                          ),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: appTheme.secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                          trailing: unreadCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            widget.firebaseService.clearUnreadMessages(
                                group.id, widget.currentUserId);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupChatScreen(
                                  group: group,
                                  currentUserId: widget.currentUserId,
                                  firebaseService: widget.firebaseService,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _truncateMessage(String message, {int maxLength = 30}) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }
}

// screens/create_group_screen.dart
class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;
  final FirebaseService firebaseService;

  const CreateGroupScreen({
    super.key,
    required this.currentUserId,
    required this.firebaseService,
  });

  @override
  CreateGroupScreenState createState() => CreateGroupScreenState();
}

class CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final Set<String> _selectedUsers = {};
  String _searchQuery = '';

  bool get _isCreateGroupEnabled {
    return _selectedUsers.isNotEmpty && _nameController.text.isNotEmpty;
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
          'Create Group',
          style: TextStyle(color: appTheme.textColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isCreateGroupEnabled ? _createGroup : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: 350,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Enter Group Name',
                  hintStyle: TextStyle(
                      color: appTheme.secondaryTextColor, fontSize: 16),
                  filled: true,
                  fillColor: appTheme.primaryColor,
                  prefixIcon: Icon(
                    Icons.group,
                    color: appTheme.secondaryTextColor,
                  ),
                  suffixIcon: _nameController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: appTheme.secondaryTextColor,
                          ),
                          onPressed: () {
                            setState(() {
                              _nameController.clear();
                            });
                          },
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        BorderSide(color: appTheme.textColor, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        BorderSide(color: appTheme.textColor, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        BorderSide(color: appTheme.textColor, width: 0.5),
                  ),
                ),
                onChanged: (value) => setState(() {}),
                style: TextStyle(color: appTheme.textColor),
              ),
            ),
          ),
          SizedBox(height: 20),
          Divider(
            height: 3,
            thickness: 5,
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                filled: true,
                fillColor: appTheme.primaryColor,
                hintText: 'Search Users',
                hintStyle:
                    TextStyle(color: appTheme.secondaryTextColor, fontSize: 16),
                prefixIcon: Icon(
                  Icons.search,
                  color: appTheme.secondaryTextColor,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: appTheme.secondaryTextColor,
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
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
              onChanged: (value) => setState(() => _searchQuery = value),
              style: TextStyle(color: appTheme.textColor),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('user').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: LoadingAnimation());
                }

                final users = snapshot.data!.docs
                    .where((doc) => doc.id != widget.currentUserId)
                    .where((doc) => doc['isRemoved'] == false)
                    .where((doc) => doc['username']
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final userId = user.id;
                    final username = user['username'];
                    final userImage = user['userimage'];
                    final isSelected = _selectedUsers.contains(userId);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userImage != null
                            ? CachedNetworkImageProvider(userImage)
                            : null,
                        child: userImage == null ? Text(username[0]) : null,
                      ),
                      title: Text(
                        username,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: isSelected
                              ? Colors.green
                              : appTheme.secondaryTextColor,
                        ),
                        onPressed: () => setState(() {
                          if (isSelected) {
                            _selectedUsers.remove(userId);
                          } else {
                            _selectedUsers.add(userId);
                          }
                        }),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 60,
          height: 60,
          child: FloatingActionButton(
            heroTag: 'Creating_Group',
            onPressed: _isCreateGroupEnabled ? _createGroup : null,
            backgroundColor:
                _isCreateGroupEnabled ? Colors.blue : Colors.blueGrey,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.check,
              size: 30,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createGroup() async {
    if (_nameController.text.isEmpty || _selectedUsers.isEmpty) return;

    try {
      await widget.firebaseService.createGroup(
        _nameController.text,
        widget.currentUserId,
        _selectedUsers.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    }
  }
}

// screens/group_chat_screen.dart
class GroupChatScreen extends StatefulWidget {
  final Group group;
  final String currentUserId;
  final FirebaseService firebaseService;

  const GroupChatScreen({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.firebaseService,
  });

  @override
  GroupChatScreenState createState() => GroupChatScreenState();
}

class GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();

  String _getDateDividerText(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool _shouldShowDateDivider(
      Message? previousMessage, Message currentMessage) {
    if (previousMessage == null) return true;

    final previousDate = DateTime(
      previousMessage.timestamp.year,
      previousMessage.timestamp.month,
      previousMessage.timestamp.day,
    );
    final currentDate = DateTime(
      currentMessage.timestamp.year,
      currentMessage.timestamp.month,
      currentMessage.timestamp.day,
    );

    return previousDate != currentDate;
  }

  Widget _buildDateDivider(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message, Message? previousMessage) {
    final isOwnMessage = message.senderId == widget.currentUserId;
    final showDateDivider = _shouldShowDateDivider(previousMessage, message);
    final showUsername =
        previousMessage == null || previousMessage.senderId != message.senderId;

    return Column(
      children: [
        if (showDateDivider)
          _buildDateDivider(_getDateDividerText(message.timestamp)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment:
                isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOwnMessage && showUsername) ...[
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('user')
                      .doc(message.senderId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final userImage =
                        snapshot.data?.get('userimage') as String?;
                    return Padding(
                      padding: const EdgeInsets.only(right: 0),
                      child: CircleAvatar(
                        radius: 10,
                        backgroundImage: userImage != null
                            ? CachedNetworkImageProvider(userImage)
                            : null,
                        child: userImage == null
                            ? Text(message.senderUsername[0].toUpperCase())
                            : null,
                      ),
                    );
                  },
                ),
              ],
              Flexible(
                child: Container(
                  margin: EdgeInsets.only(
                    left: (!isOwnMessage && !showUsername)
                        ? 20
                        : (isOwnMessage ? 50 : 0),
                    right: isOwnMessage ? 0 : 50,
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isOwnMessage ? Colors.blue : Colors.grey.shade300,
                    borderRadius: BorderRadius.only(
                      topLeft: isOwnMessage
                          ? const Radius.circular(20.0)
                          : (showUsername
                              ? Radius.zero
                              : const Radius.circular(20.0)),
                      topRight: const Radius.circular(20.0),
                      bottomLeft: const Radius.circular(20.0),
                      bottomRight: isOwnMessage
                          ? (showUsername
                              ? Radius.zero
                              : const Radius.circular(20.0))
                          : const Radius.circular(20.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: isOwnMessage
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (showUsername)
                        Text(
                          message.senderUsername,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color:
                                isOwnMessage ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        message.content,
                        style: TextStyle(
                          color: isOwnMessage ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isOwnMessage ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.group.adminIds.contains(widget.currentUserId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  CachedNetworkImageProvider(widget.group.imageUrl),
              radius: 15,
            ),
            const SizedBox(width: 8),
            Text(
              widget.group.name.length > 18
                  ? '${widget.group.name.substring(0, 16)}...'
                  : widget.group.name,
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              if (isAdmin) ...[
                const PopupMenuItem(
                  value: 'edit_group',
                  child: Text('Edit Group'),
                ),
                const PopupMenuItem(
                  value: 'manage_members',
                  child: Text('Manage Members'),
                ),
                const PopupMenuItem(
                  value: 'add_members',
                  child: Text('Add Members'),
                ),
              ] else ...[
                const PopupMenuItem(
                  value: 'view_members',
                  child: Text('View Members'),
                ),
              ],
              const PopupMenuItem(
                value: 'exit_group',
                child: Text('Exit Group'),
              ),
            ],
            onSelected: _handleMenuAction,
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: widget.firebaseService.getGroupMessages(widget.group.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: LoadingAnimation());
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final previousMessage = index < messages.length - 1
                        ? messages[index + 1]
                        : null;
                    return _buildMessageItem(message, previousMessage);
                  },
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        filled: true,
                        fillColor: Colors.grey[200],
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                      minLines: 1,
                      maxLines: 5,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.blueAccent,
                    ),
                    onPressed: _sendMessage,
                    splashColor: Colors.blueAccent.withOpacity(0.3),
                    splashRadius: 25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final userInput = _messageController.text;
    _messageController.clear();
    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      groupId: widget.group.id,
      senderId: widget.currentUserId,
      senderUsername: await _getUserUsername(widget.currentUserId),
      content: userInput,
      timestamp: DateTime.now(),
    );

    try {
      await widget.firebaseService.sendMessage(message);
      await widget.firebaseService
          .incrementUnreadMessages(widget.group.id, widget.currentUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Future<String> _getUserUsername(String userId) async {
    final doc =
        await FirebaseFirestore.instance.collection('user').doc(userId).get();
    return doc.data()?['username'] ?? 'Unknown User';
  }

  Future<void> _showAddMembersDialog() async {
    showDialog(
      context: context,
      builder: (context) => AddMembersDialog(
        groupId: widget.group.id,
        currentMembers: widget.group.memberIds,
        firebaseService: widget.firebaseService,
      ),
    );
  }

  Future<void> _showEditGroupDialog() async {
    showDialog(
      context: context,
      builder: (context) => EditGroupDialog(
        group: widget.group,
        firebaseService: widget.firebaseService,
        cloudinaryService: CloudinaryService(
          uploadPreset: 'groupimages',
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'manage_members':
        await _showManageMembersDialog();
        break;
      case 'exit_group':
        await _exitGroup();
        break;
      case 'view_members':
        await _showViewMembersDialog();
        break;
      case 'edit_group':
        await _showEditGroupDialog();
        break;
      case 'add_members':
        await _showAddMembersDialog();
        break;
    }
  }

  Future<void> _showManageMembersDialog() async {
    showDialog(
      context: context,
      builder: (context) => ManageMembersDialog(
        group: widget.group,
        firebaseService: widget.firebaseService,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  Future<void> _showViewMembersDialog() async {
    showDialog(
      context: context,
      builder: (context) => ViewMembersDialog(
        group: widget.group,
        firebaseService: widget.firebaseService,
        currentUserId: widget.currentUserId,
      ),
    );
  }

  Future<void> _exitGroup() async {
    showConfirmationDialog(
      context: context,
      title: 'Exit',
      message: 'Are you sure to exit from this app?',
      cancelButtonText: 'Cancel',
      confirmButtonText: 'Exit',
      onConfirm: () async {
        try {
          if (widget.group.creatorId == widget.currentUserId) {
            final newAdmin = widget.group.memberIds
                .where((id) => id != widget.currentUserId)
                .firstOrNull;
            if (newAdmin != null) {
              await widget.firebaseService
                  .makeUserAdmin(widget.group.id, newAdmin);
            }
          }
          await widget.firebaseService
              .removeUserFromGroup(widget.group.id, widget.currentUserId);
          if (mounted) {
            Navigator.pop(context);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to exit group: $e')),
            );
          }
        }
      },
      titleIcon: Icon(Icons.exit_to_app, color: Colors.red),
      titleColor: Colors.redAccent,
      cancelButtonColor: Colors.blue,
      confirmButtonColor: Colors.red,
    );
  }
}

// widgets/add_members_dialog.dart
class AddMembersDialog extends StatefulWidget {
  final String groupId;
  final List<String> currentMembers;
  final FirebaseService firebaseService;

  const AddMembersDialog({
    super.key,
    required this.groupId,
    required this.currentMembers,
    required this.firebaseService,
  });

  @override
  AddMembersDialogState createState() => AddMembersDialogState();
}

class AddMembersDialogState extends State<AddMembersDialog> {
  final Set<String> _selectedUsers = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Members'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Search Users',
                hintText: 'Search Users',
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[600],
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                        ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: Colors.grey, width: 1),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('user').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = snapshot.data!.docs
                      .where((doc) =>
                          !widget.currentMembers.contains(doc.id) &&
                          doc['username']
                              .toString()
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                      .toList();

                  return ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final userId = user.id;
                      final username = user['username'];
                      final userImage = user['userimage'];
                      final isSelected = _selectedUsers.contains(userId);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: userImage != null
                              ? NetworkImage(userImage)
                              : null,
                          child: userImage == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(username),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selectedUsers.add(userId);
                              } else {
                                _selectedUsers.remove(userId);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: Colors.blue,
            ),
          ),
        ),
        TextButton(
          onPressed: _selectedUsers.isEmpty ? null : _addMembers,
          child: Text(
            'Add',
            style: TextStyle(
              color: _selectedUsers.isEmpty ? Colors.grey : Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addMembers() async {
    try {
      for (final userId in _selectedUsers) {
        await widget.firebaseService.addUserToGroup(widget.groupId, userId);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add members: $e')),
        );
      }
    }
  }
}

// widgets/manage_members_dialog.dart
class ViewMembersDialog extends StatelessWidget {
  final Group group;
  final FirebaseService firebaseService;
  final String currentUserId;

  const ViewMembersDialog({
    super.key,
    required this.group,
    required this.firebaseService,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Members'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user')
              .where(FieldPath.documentId, whereIn: group.memberIds)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: LoadingAnimation());
            }

            final users = snapshot.data!.docs;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = user.id;
                final username = user['username'];
                final isAdmin = group.adminIds.contains(userId);
                final isCreator = group.creatorId == userId;
                final userImage = user['userimage'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userImage != null
                        ? CachedNetworkImageProvider(userImage)
                        : null,
                    child: userImage == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(username),
                  subtitle: Text(isCreator
                      ? 'Creator'
                      : isAdmin
                          ? 'Admin'
                          : 'Member'),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }
}

// widgets/manage_members_dialog.dart
class ManageMembersDialog extends StatelessWidget {
  final Group group;
  final FirebaseService firebaseService;
  final String currentUserId;

  const ManageMembersDialog({
    super.key,
    required this.group,
    required this.firebaseService,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Members'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('user')
              .where(FieldPath.documentId, whereIn: group.memberIds)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: LoadingAnimation());
            }

            final users = snapshot.data!.docs;
            return ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final userId = user.id;
                final username = user['username'];
                final isAdmin = group.adminIds.contains(userId);
                final isCreator = group.creatorId == userId;
                final userImage = user['userimage'];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: userImage != null
                        ? CachedNetworkImageProvider(userImage)
                        : null,
                    child: userImage == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(username),
                  subtitle: Text(isCreator
                      ? 'Creator'
                      : isAdmin
                          ? 'Admin'
                          : 'Member'),
                  trailing: userId != currentUserId && !isCreator
                      ? PopupMenuButton(
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle_admin',
                              child:
                                  Text(isAdmin ? 'Remove Admin' : 'Make Admin'),
                            ),
                            const PopupMenuItem(
                              child: Text('Remove from Group'),
                              value: 'remove',
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'toggle_admin') {
                              await _toggleAdmin(userId);
                            } else if (value == 'remove') {
                              await _removeMember(context, userId);
                            }
                          },
                        )
                      : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleAdmin(String userId) async {
    try {
      if (group.adminIds.contains(userId)) {
        await firebaseService.removeUserFromGroup(group.id, userId);
      } else {
        await firebaseService.makeUserAdmin(group.id, userId);
      }
    } catch (e) {
      print('Error toggling admin status: $e');
    }
  }

  Future<void> _removeMember(BuildContext context, String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await firebaseService.removeUserFromGroup(group.id, userId);
      } catch (e) {
        print('Error removing member: $e');
      }
    }
  }
}

class EditGroupDialog extends StatefulWidget {
  final Group group;
  final FirebaseService firebaseService;
  final CloudinaryService cloudinaryService;

  const EditGroupDialog({
    super.key,
    required this.group,
    required this.firebaseService,
    required this.cloudinaryService,
  });

  @override
  EditGroupDialogState createState() => EditGroupDialogState();
}

class EditGroupDialogState extends State<EditGroupDialog> {
  late TextEditingController _nameController;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _updateGroup() async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      String imageUrl = widget.group.imageUrl;

      if (_selectedImage != null) {
        final uploadedUrl = await widget.cloudinaryService.uploadImage(
          selectedImage: _selectedImage,
        );
        if (uploadedUrl != null) {
          imageUrl = uploadedUrl;
        }
      }

      await widget.firebaseService.updateGroup(
        widget.group.id,
        _nameController.text,
        imageUrl,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update group: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Group',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : CachedNetworkImageProvider(widget.group.imageUrl)
                            as ImageProvider,
                    backgroundColor: Colors.grey[200],
                  ),
                  // Camera overlay
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black
                          .withOpacity(0.3), // Semi-transparent overlay
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: TextStyle(
                  color: Colors.blueGrey[700],
                ),
                hintText: 'Enter group name',
                hintStyle: TextStyle(
                  color: Colors.blueGrey[400],
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blueGrey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.blueAccent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueGrey[700],
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
