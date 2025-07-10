import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';

class PostCompleteScreen extends StatefulWidget {
  final String postId;

  const PostCompleteScreen({
    required this.postId,
    super.key,
  });

  @override
  PostCompleteScreenState createState() => PostCompleteScreenState();
}

class PostCompleteScreenState extends State<PostCompleteScreen> {
  final TextEditingController tripBuddiesController = TextEditingController();
  final TextEditingController visitedPlacesController = TextEditingController();
  final TextEditingController tripDurationController = TextEditingController();
  final TextEditingController commentController = TextEditingController();

  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final List<String> tripBuddies = [];
  final Map<String, Map<String, String>> userDetails = {};
  final List<String> visitedPlaces = [];
  String? tripFeedback;
  double? tripRating;
  int? tripCompletedDuration;
  String? comment;
  bool isFromPackage = false;
  String? packageId;

  bool visitedPlacesDisabled = false;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfFromPackage();
  }

  Future<void> _checkIfFromPackage() async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .get();

      if (postDoc.exists && postDoc.data()?['postedFrom'] != null) {
        setState(() {
          packageId = postDoc.data()?['postedFrom'];
        });
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _addComment(int rating) async {
    if (commentController.text.trim().isEmpty || packageId == null) return;

    String stars = '⭐' * rating;

    try {
      final commentId = DateTime.now().millisecondsSinceEpoch.toString();
      final commentData = {
        'commentBy': currentUserId,
        'comment': '$stars ,${commentController.text.trim()}',
        'commentedTime': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('packages')
          .doc(packageId)
          .update({
        'comments.$commentId': commentData,
      });
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  void _setLoading(bool loading) {
    setState(() {
      isLoading = loading;
    });
  }

  @override
  void dispose() {
    tripBuddiesController.dispose();
    visitedPlacesController.dispose();
    tripDurationController.dispose();
    commentController.dispose();
    super.dispose();
  }

  Future<void> _addTag(
      String tag, TextEditingController controller, List<String> list) async {
    if (tag.isEmpty || list.contains(tag)) {
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duplicate or empty tag detected!")),
      );
      return;
    }

    _setLoading(true);
    try {
      QuerySnapshot query = await FirebaseFirestore.instance
          .collection('user')
          .where('username', isEqualTo: tag)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // Username exists, add the tag and save the document ID
        String userId = query.docs.first.id;
        String fullName = query.docs.first['fullname'] ?? "Unknown Name";
        String profileImage = query.docs.first['userimage'] ?? "";

        setState(() {
          list.add(tag);
          userDetails[tag] = {
            'userId': userId,
            'fullname': fullName,
            'userimage': profileImage,
          };
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username does not exist")),
          );
        }
      }
    } catch (e) {
      print(e);
    } finally {
      _setLoading(false);
      controller.clear();
    }
  }

  void _handleTagInput(
      String value, TextEditingController controller, List<String> list) {
    String tag = value.trim().replaceAll(',', '').replaceAll('\n', '').trim();
    if (tag.isNotEmpty) {
      _addTag(tag, controller, list);
    }
  }

  void _removeTag(String tag, List<String> list) {
    setState(() {
      list.remove(tag);
      userDetails.remove(tag);
    });
  }

  void _checkVisitedPlacesLimit() {
    if (visitedPlaces.length >= 8) {
      setState(() {
        visitedPlacesDisabled = true;
      });
    }
  }

  Future<void> _sendNotificationToBuddies(List<String> buddyIds) async {
    final postDoc = await FirebaseFirestore.instance
        .collection('post')
        .doc(widget.postId)
        .get();

    if (!postDoc.exists) return;

    final String postTitle = postDoc.data()?['title'] ?? 'A trip';
    final batch = FirebaseFirestore.instance.batch();

    for (String buddyId in buddyIds) {
      if (buddyId == currentUserId) {
        continue; 
      }

      final notificationRef = FirebaseFirestore.instance
          .collection('user')
          .doc(buddyId)
          .collection('notifications')
          .doc();

      batch.set(notificationRef, {
        'title': 'Trip Completed',
        'message': '$postTitle has been marked as completed',
        'time': FieldValue.serverTimestamp(),
        'isSeen': false,
        'date': DateTime.now().toIso8601String(),
        'postId': widget.postId,
        'postUserId': currentUserId,
      });
    }

    await batch.commit();
  }

  Future<void> _saveTripDetails() async {
    try {
      List<String> tripBuddiesIds = tripBuddies
          .map((username) {
            return userDetails[username]?['userId'] ?? '';
          })
          .where((id) => id.isNotEmpty)
          .toList();
      await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .update({
        'tripCompleted': true,
        'tripFeedback': tripFeedback,
        'tripRating': tripRating?.toInt(),
        'tripBuddies': tripBuddiesIds,
        'visitedPlaces': visitedPlaces,
        'tripCompletedDuration': tripCompletedDuration,
      });

      await _sendNotificationToBuddies(tripBuddiesIds);

      if (isFromPackage && packageId != null) {
        await _addComment(tripRating!.toInt());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip completed')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed')),
        );
      }
    }
  }

  Future<void> _onComplete() async {
    final String remainingBuddyText = tripBuddiesController.text.trim();
    final String remainingPlaceText = visitedPlacesController.text.trim();
    if (remainingPlaceText.isNotEmpty) {
      _addLocTag(remainingPlaceText, visitedPlacesController, visitedPlaces);
    }

    if (remainingBuddyText.isNotEmpty) {
      await _addTag(remainingBuddyText, tripBuddiesController, tripBuddies);
    }
    final List<String> nonExistentBuddies = tripBuddies.where((buddy) {
      return !userDetails.containsKey(buddy);
    }).toList();

    if (nonExistentBuddies.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Buddy not found: ${nonExistentBuddies.join(", ")}',
          ),
        ),
      );
      return;
    }
    if (tripBuddies.isEmpty ||
        visitedPlaces.isEmpty ||
        tripFeedback == null ||
        tripRating == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
    } else {
      _saveTripDetails();
    }
  }

  void _addLocTag(
      String tag, TextEditingController controller, List<String> list) {
    if (tag.isNotEmpty && !list.contains(tag)) {
      setState(() {
        list.add(tag);
      });
      controller.clear();
    } else {
      controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Duplicate tag detected!")),
      );
    }
  }

  void _handleLocTagInput(
      String value, TextEditingController controller, List<String> list) {
    String tag = value.trim().replaceAll(',', '').replaceAll('\n', '').trim();
    if (tag.isNotEmpty) {
      _addLocTag(tag, controller, list);
    }
  }

  void _removeLocTag(String tag, List<String> list) {
    setState(() {
      list.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        title: Text(
          'Complete Trip Details',
          style: TextStyle(color: appTheme.textColor),
        ),
        backgroundColor: appTheme.secondaryColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'Post_complete',
        onPressed: isLoading ? null : _onComplete,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('Complete', style: TextStyle(color: Colors.white)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 80.0,
            ),
            child: Column(
              children: [
                RatingBar.builder(
                  initialRating: tripRating ?? 0,
                  minRating: 1,
                  itemSize: 30,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemBuilder: (context, _) =>
                      const Icon(Icons.star, color: Colors.yellow),
                  unratedColor: appTheme.secondaryColor,
                  onRatingUpdate: (rating) =>
                      setState(() => tripRating = rating),
                ),
                const SizedBox(height: 10),
                if (packageId != null) ...[
                  CheckboxListTile(
                    title: Text(
                      'Completed from our package',
                      style: TextStyle(color: appTheme.textColor),
                    ),
                    value: isFromPackage,
                    onChanged: (bool? value) {
                      setState(() {
                        isFromPackage = value ?? false;
                      });
                    },
                    activeColor:
                        Colors.blue, // Color for the checkbox when selected
                    checkColor: Colors.white, // Checkmark color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          4), // Rounded corners for the checkbox
                    ),
                    controlAffinity:
                        ListTileControlAffinity.leading, // Checkbox on the left
                  ),
                  if (isFromPackage)
                    SizedBox(
                      width: 350,
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          labelText: 'Package Feedback',
                          hintText: 'Share your experience with this package',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        minLines: 1,
                        maxLines: 3,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                ],
                SizedBox(
                  height: 10,
                ),
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: tripBuddiesController,
                    decoration: InputDecoration(
                      labelText: 'Trip Buddies (comma separated)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                    ),
                    style: TextStyle(color: appTheme.textColor),
                    onChanged: (value) {
                      if (value.endsWith(",") || value.endsWith("\n")) {
                        _handleTagInput(
                            value, tripBuddiesController, tripBuddies);
                      }
                    },
                    onSubmitted: (value) {
                      _handleTagInput(
                          value, tripBuddiesController, tripBuddies);
                    },
                  ),
                ),
                SizedBox(height: 10),
                Container(
                  height: 200,
                  width: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(4),
                  child: SingleChildScrollView(
                    child: Wrap(
                      children: tripBuddies.map((tag) {
                        final userDetail = userDetails[tag];
                        final fullName = userDetail?['fullname'] ?? "Unknown";
                        final profileImage = userDetail?['userimage'] ?? "";

                        return Chip(
                          labelPadding: const EdgeInsets.all(4.0),
                          avatar: profileImage.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(profileImage),
                                  radius: 12,
                                )
                              : const CircleAvatar(
                                  backgroundColor: Colors.grey,
                                  radius: 12,
                                  child: Icon(Icons.person, size: 14),
                                ),
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                      fontSize: 7, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  fullName,
                                  style: const TextStyle(
                                      fontSize: 5, color: Colors.grey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag, tripBuddies),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: 250,
                        child: TextField(
                          controller: visitedPlacesController,
                          decoration: InputDecoration(
                            labelText: 'Visited Places (comma separated)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            labelStyle:
                                TextStyle(color: appTheme.secondaryTextColor),
                          ),
                          style: TextStyle(color: appTheme.textColor),
                          enabled: !visitedPlacesDisabled,
                          onChanged: (value) {
                            if (value.endsWith(",") || value.endsWith("\n")) {
                              _handleLocTagInput(value, visitedPlacesController,
                                  visitedPlaces);
                              _checkVisitedPlacesLimit();
                            }
                          },
                          onSubmitted: (value) {
                            if (!visitedPlacesDisabled) {
                              _handleLocTagInput(value, visitedPlacesController,
                                  visitedPlaces);
                              _checkVisitedPlacesLimit();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        _setLoading(true);
                        try {
                          DocumentSnapshot postSnapshot =
                              await FirebaseFirestore.instance
                                  .collection('post')
                                  .doc(widget.postId)
                                  .get();

                          if (postSnapshot.exists) {
                            List<dynamic> planToVisitPlaces =
                                postSnapshot['planToVisitPlaces']
                                    as List<dynamic>;

                            setState(() {
                              visitedPlaces.addAll(
                                planToVisitPlaces
                                    .map((place) => place.toString())
                                    .where((place) =>
                                        !visitedPlaces.contains(place)),
                              );
                            });
                            _checkVisitedPlacesLimit();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Post not found")),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Error fetching planned places")),
                            );
                          }
                        } finally {
                          _setLoading(false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      child: const Text(
                        'Same as \n Planned',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Container(
                  height: 200,
                  width: 350,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.all(4),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 12.0,
                      runSpacing: 12.0,
                      children: visitedPlaces.map((tag) {
                        return GestureDetector(
                          onTap: () => showPlaceDialog(
                            context: context,
                            placeName: tag,
                          ),
                          child: Container(
                            constraints: BoxConstraints(maxWidth: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: appTheme.secondaryColor,
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: appTheme.textColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () =>
                                      _removeLocTag(tag, visitedPlaces),
                                  child: const Icon(
                                    Icons.close,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 350,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Trip Experience',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                    ),
                    style: TextStyle(color: appTheme.textColor),
                    onChanged: (value) => tripFeedback = value,
                  ),
                ),
                SizedBox(height: 10),
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: tripDurationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Trip Duration (in Days)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                    ),
                    style: TextStyle(color: appTheme.textColor),
                    onChanged: (value) {
                      setState(() {
                        tripCompletedDuration = int.tryParse(value);
                      });
                    },
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
