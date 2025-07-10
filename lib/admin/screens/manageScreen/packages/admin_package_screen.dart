import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/counder.dart';
import '../../../../utils/image_swipe.dart';
import '../../../../utils/loading.dart';
import 'admin_package_comment_view_screen.dart';
import 'admin_package_details_screen.dart';
import 'package_uplaod_screen.dart';

class AdminPackagesScreen extends StatefulWidget {
  const AdminPackagesScreen({super.key});

  @override
  AdminPackagesScreenState createState() => AdminPackagesScreenState();
}

class AdminPackagesScreenState extends State<AdminPackagesScreen> {
  TextEditingController searchController = TextEditingController();
  String _searchQuery = '';
  bool isSearchTriggered = false;
  bool isOffline = false;
  List<String> suggestions = [];
  List<QueryDocumentSnapshot> packages = [];
  bool isLoading = false;

  Map<String, int> commentCounts = {};

  Future<void> _fetchCommentCounts(String packageId) async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('packages')
          .doc(packageId)
          .get();
      final comments =
          postDoc.data()?['comments'] as Map<String, dynamic>? ?? {};
      setState(() {
        commentCounts[packageId] = comments.length;
      });
    } catch (e) {
      print('Error fetching comment count: $e');
    }
  }

  void _showCommentSheet(BuildContext context, String packageId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AdminViewPackageCommentSheet(packageId: packageId),
    );
  }

  late StreamSubscription connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _fetchSuggestions();
    _fetchPackages();
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initializeConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (mounted) {
        setState(() {
          isOffline = connectivityResult == ConnectivityResult.none;
        });
      }

      connectivitySubscription =
          Connectivity().onConnectivityChanged.listen((connectivityResult) {
        if (mounted) {
          setState(() {
            isOffline = connectivityResult == ConnectivityResult.none;
          });
        }
      });
    } catch (e) {
      print('Error initializing connectivity: $e');
    }
  }

  Future<void> _fetchSuggestions() async {
    final querySnapshot =
        await FirebaseFirestore.instance.collection('packages').get();

    final suggestionSet = <String>{};
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      suggestionSet.add(data['locationName'] ?? '');
      suggestionSet.addAll(List<String>.from(data['planToVisitPlaces'] ?? []));
    }

    setState(() {
      suggestions = suggestionSet.toList();
    });
  }

  Future<void> _fetchPackages() async {
    if (isOffline) return;

    setState(() {
      isLoading = true;
    });

    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('packages').get();
      setState(() {
        packages = querySnapshot.docs;
        packages.shuffle();
      });
      for (var doc in packages) {
        final packageId = doc.id;
        _fetchCommentCounts(packageId);
      }
    } catch (e) {
      print('Error fetching packages: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _filterPackages() {
    if (_searchQuery.isEmpty) {
      _fetchPackages();
      return;
    }

    setState(() {
      packages = packages.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final locationName = data['locationName'].toString().toLowerCase();
        final planToVisitPlaces = (data['planToVisitPlaces'] as List)
            .map((place) => place.toString().toLowerCase())
            .toList();

        return locationName.contains(_searchQuery.toLowerCase()) ||
            planToVisitPlaces
                .any((place) => place.contains(_searchQuery.toLowerCase()));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: appTheme.primaryColor,
        title: TextField(
          enabled: !isOffline,
          controller: searchController,
          onChanged: isOffline
              ? null
              : (value) {
                  setState(() {
                    _searchQuery = value;
                    isSearchTriggered = false;
                  });
                },
          onSubmitted: isOffline
              ? null
              : (value) {
                  setState(() {
                    _searchQuery = value;
                    isSearchTriggered = true;
                  });
                },
          decoration: InputDecoration(
            filled: true,
            fillColor: appTheme.primaryColor,
            hintText: isOffline
                ? 'You are offline'
                : 'Search by location or places...',
            hintStyle: isOffline
                ? TextStyle(color: Colors.red[500], fontSize: 16)
                : TextStyle(color: appTheme.secondaryTextColor, fontSize: 16),
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
                    onPressed: isOffline
                        ? null
                        : () {
                            setState(() {
                              searchController.clear();
                              _searchQuery = "";
                              isSearchTriggered = false;
                              _filterPackages();
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
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: LoadingAnimation())
              : RefreshIndicator(
                  onRefresh: isOffline ? () async {} : _fetchPackages,
                  child: packages.isEmpty
                      ? const Center(
                          child: Text(
                            'No packages available',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1,
                          ),
                          itemCount: packages.length,
                          itemBuilder: (context, index) {
                            final package = packages[index];
                            final data = package.data() as Map<String, dynamic>;
                            final images = data['locationImages'] as List;
                            final locationName = data['locationName'];
                            final prize = data['prize'];

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminPackageDetailsScreen(
                                      documentId: package.id,
                                      commentCount:
                                          commentCounts[package.id] ?? 0,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                color: appTheme.secondaryColor,
                                margin: const EdgeInsets.all(0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    ImageCarousel(locationImages: images),
                                    Padding(
                                      padding: const EdgeInsets.all(5),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            locationName,
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: appTheme.textColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Prize: ₹$prize',
                                            style: TextStyle(
                                              color:
                                                  appTheme.secondaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.comment_outlined,
                                                  color: appTheme
                                                      .secondaryTextColor,
                                                  size: 24,
                                                ),
                                                onPressed: () =>
                                                    _showCommentSheet(
                                                        context, package.id),
                                              ),
                                              Text(
                                                formatCount(
                                                    commentCounts[package.id] ??
                                                        0),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: appTheme
                                                      .secondaryTextColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
          if (_searchQuery.isNotEmpty && !isSearchTriggered)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Material(
                elevation: 4,
                child: ListView.builder(
                  itemCount: suggestions.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    if (!suggestion
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase())) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      title: Text(suggestion),
                      trailing: const Icon(Icons.search),
                      onTap: () {
                        setState(() {
                          searchController.text = suggestion;
                          _searchQuery = suggestion;
                          isSearchTriggered = true;
                          _filterPackages();
                          FocusScope.of(context).unfocus();
                        });
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PackageUploader()),
          );
        },
        backgroundColor: Colors.blue,
        mini: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
