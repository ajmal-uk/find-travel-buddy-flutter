import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../../../utils/app_theme.dart';
import '../../../../utils/counder.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/image_swipe.dart';
import '../../../../utils/loading.dart';
import 'admin_package_comment_view_screen.dart';
import 'edit_package_screen.dart';

class AdminPackageDetailsScreen extends StatefulWidget {
  final String documentId;
  final int commentCount;

  const AdminPackageDetailsScreen(
      {super.key, required this.documentId, required this.commentCount});

  @override
  AdminPackageDetailsScreenState createState() =>
      AdminPackageDetailsScreenState();
}

class AdminPackageDetailsScreenState extends State<AdminPackageDetailsScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _showCommentSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          AdminViewPackageCommentSheet(packageId: widget.documentId),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  void _showDeleteConfirmationDialog() {
    showConfirmationDialog(
      context: context,
      title: 'Delete Package',
      message: 'Are you sure you want to delete this package?',
      cancelButtonText: 'Cancel',
      confirmButtonText: 'Delete',
      onConfirm: () {
        _deletePackage();
      },
      titleIcon: Icon(Icons.delete_forever, color: Colors.red),
      titleColor: Colors.redAccent,
      cancelButtonColor: Colors.blue,
      confirmButtonColor: Colors.red,
    );
  }

  Future<void> _deletePackage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: LoadingAnimation(),
      ),
    );

    try {
      await FirebaseFirestore.instance
          .collection('packages')
          .doc(widget.documentId)
          .delete();

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete package: $e')),
        );
      }
    }
  }

  void _navigateToEditScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageEditScreen(documentId: widget.documentId),
      ),
    );
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
          'Package Details',
          style: TextStyle(color: appTheme.textColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: _navigateToEditScreen,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _showDeleteConfirmationDialog,
          ),
        ],
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
                      child: Text(
                        locationName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'Places to Visit:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 10),
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
                        children: [
                          Text(
                            'Prize: ₹$prize',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: appTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            description,
                            style: TextStyle(
                                fontSize: 16, color: appTheme.textColor),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
