import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/counder.dart';
import '../../../../utils/image_swipe.dart';
import '../../../../utils/loading.dart';
import '../../commentScreen/package_comment_screen.dart';

class PackageDetailsScreen extends StatefulWidget {
  final String documentId;
  final int commentCount;

  const PackageDetailsScreen(
      {super.key, required this.documentId, required this.commentCount});

  @override
  PackageDetailsScreenState createState() => PackageDetailsScreenState();
}

class PackageDetailsScreenState extends State<PackageDetailsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _hasPosted = false;

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PackageCommentSheet(packageId: widget.documentId),
    );
  }

  @override
  void initState() {
    super.initState();
    _checkIfPosted();
  }

  Future<void> _checkIfPosted() async {
    final packageDoc = await FirebaseFirestore.instance
        .collection('packages')
        .doc(widget.documentId)
        .get();

    final packageData = packageDoc.data()!;

    if (packageData['postedUsers'] == null) {
      if (mounted) {
        setState(() {
          _hasPosted = false;
        });
      }
    } else {
      final isPosted = packageData['postedUsers'] != null &&
          packageData['postedUsers'].containsKey(currentUserId);

      if (mounted) {
        setState(() {
          _hasPosted = isPosted;
        });
      }
    }
  }

  void _showPostConfirmationDialog(Map<String, dynamic> packageData) {
    showConfirmationDialog(
      context: context,
      title: _hasPosted ? 'Post Again' : 'Post',
      message: _hasPosted
          ? 'Would you like to post this package Again?'
          : 'Would you like to post this package?',
      cancelButtonText: 'Cancel',
      confirmButtonText: 'Post',
      onConfirm: () {
        uploadPost(packageData);
      },
      titleIcon: const Icon(Icons.post_add, color: Colors.blue),
      titleColor: Colors.blueAccent,
      cancelButtonColor: Colors.red,
      confirmButtonColor: Colors.blue,
    );
  }

  Future<void> uploadPost(Map<String, dynamic> packageData) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: LoadingAnimation(),
      ),
    );

    try {
      final postData = {
        'locationName': packageData['locationName'],
        'locationDescription': packageData['locationDescription'],
        'locationImages': packageData['locationImages'],
        'planToVisitPlaces': packageData['planToVisitPlaces'],
        'tripDuration': packageData['tripDuration'],
        'tripCompleted': false,
        'userid': currentUserId,
        'tripRating': null,
        'tripBuddies': null,
        'tripFeedback': null,
        'visitedPlaces': null,
        'uploadedDateTime': FieldValue.serverTimestamp(),
        'likes': null,
        'tripCompletedDuration': null,
        'postedFrom': widget.documentId,
      };

      DocumentReference docRef =
          await FirebaseFirestore.instance.collection('post').add(postData);

      final uploadedByData = {
        'postDocId': docRef.id,
      };

      await FirebaseFirestore.instance
          .collection('packages')
          .doc(widget.documentId)
          .update({
        'postedUsers.$currentUserId': FieldValue.arrayUnion([uploadedByData]),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload post: $e')),
        );
      }
    }
  }

  Future<void> _launchPhoneDialer(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      throw 'Could not launch phone dialer';
    }
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
          'Package Details..',
          style: TextStyle(color: appTheme.textColor),
        ),
        iconTheme: IconThemeData(
          color: appTheme.textColor,
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('packages')
            .doc(widget.documentId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: LoadingAnimation());
          }

          final package = snapshot.data!;
          final locationName = package['locationName'];
          final planToVisitPlaces = package['planToVisitPlaces'] as List;
          final images = package['locationImages'] as List;
          final prize = package['prize'];
          final description = package['locationDescription'];
          final packageData = snapshot.data!.data() as Map<String, dynamic>;

          return ListView(
            children: [
              ImageCarousel(locationImages: images),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.comment_outlined,
                      color: appTheme.secondaryTextColor,
                      size: 30,
                    ),
                    onPressed: () => _showCommentSheet(context),
                  ),
                  Text(
                    formatCount(widget.commentCount),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: appTheme.secondaryTextColor),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            locationName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: appTheme.textColor),
                          ),
                          const SizedBox(height: 16),
                          _hasPosted
                              ? ElevatedButton(
                                  onPressed: () {
                                    _showPostConfirmationDialog(packageData);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    'Post Again',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: () {
                                    _showPostConfirmationDialog(packageData);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    elevation: 5,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 15),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: const Text(
                                    'Add in Your Post',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 16),
                          Text(
                            'Places to Visit:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: appTheme.textColor),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount =
                            (constraints.maxWidth / 100).floor();
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                crossAxisCount > 0 ? crossAxisCount : 1,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: 2,
                          ),
                          itemCount: planToVisitPlaces.length,
                          itemBuilder: (context, index) {
                            final placeName = planToVisitPlaces[index];

                            return GestureDetector(
                              onTap: () {
                                showPlaceDialog(
                                    context: context, placeName: placeName);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  color: appTheme.secondaryColor,
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(30.0),
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
                    const SizedBox(height: 16),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Prize: ₹$prize',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: appTheme.textColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '$description',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: appTheme.textColor),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 79),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 49,
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('packages')
            .doc(widget.documentId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final package = snapshot.data!;
          final contact = package['contact'];

          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 180,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.lightGreen,
                borderRadius: BorderRadius.circular(30),
              ),
              child: FloatingActionButton(
                onPressed: () => _launchPhoneDialer(contact),
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      'Contact',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
