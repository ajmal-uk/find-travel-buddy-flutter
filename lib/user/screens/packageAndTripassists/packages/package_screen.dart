import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/counder.dart';
import '../../../../utils/image_swipe.dart';
import '../../../../utils/loading.dart';
import '../../commentScreen/package_comment_screen.dart';
import 'package_details_screen.dart';

class PackagesScreen extends StatefulWidget {
  const PackagesScreen({super.key});

  @override
  PackagesScreenState createState() => PackagesScreenState();
}

class PackagesScreenState extends State<PackagesScreen> {
  TextEditingController searchController = TextEditingController();
  String _searchQuery = '';
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool isSearchTriggered = false;
  bool isOffline = false;
  List<String> suggestions = [];
  List<QueryDocumentSnapshot> packages = [];
  bool isLoading = false;

  late StreamSubscription connectivitySubscription;

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

  Future<void> _saveSearchAsInterest(String searchQuery) async {
    try {
      final userRef =
          FirebaseFirestore.instance.collection('user').doc(currentUserId);

      final currentUserDoc = await userRef.get();
      final List<dynamic> currentInterests =
          (currentUserDoc.data()?['interest'] as List?)?.cast<String>() ?? [];

      if (currentInterests.length >= 30) {
        currentInterests.removeAt(0);
      }

      currentInterests.add(searchQuery);
      await userRef.update({'interest': currentInterests});
    } catch (e) {
      print('Error saving search as interest: $e');
    }
  }

  void _showCommentSheet(BuildContext context, String packageId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PackageCommentSheet(packageId: packageId),
    );
  }

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
      packages.clear();
    });

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(currentUserId)
          .get();

      final List<dynamic> userInterests =
          (currentUserDoc.data()?['interest'] as List?)?.cast<String>() ?? [];

      final querySnapshot =
          await FirebaseFirestore.instance.collection('packages').get();

      Set<String> packageIds = {}; // To avoid duplicates
      List<Map<String, dynamic>> scoredPackages = [];

      for (var doc in querySnapshot.docs) {
        final package = doc.data();
        int score = 0;

        final locationName =
            (package['locationName'] as String?)?.toLowerCase() ?? '';
        final planToVisitPlaces = (package['planToVisitPlaces'] as List?)
                ?.map((place) => place.toString().toLowerCase())
                .toList() ??
            [];

        final searchFields = [locationName, ...planToVisitPlaces];

        for (int i = 0; i < userInterests.length; i++) {
          final interest = userInterests[i].toString().toLowerCase();
          final matchScore =
              searchFields.any((field) => field.contains(interest))
                  ? (userInterests.length - i) * 10
                  : 0;
          score += matchScore;
        }

        scoredPackages.add({
          'doc': doc,
          'score': score,
          'randomTiebreaker': Random().nextDouble()
        });
      }

      scoredPackages.sort((a, b) {
        int scoreComparison = b['score'].compareTo(a['score']);
        return scoreComparison != 0
            ? scoreComparison
            : b['randomTiebreaker'].compareTo(a['randomTiebreaker']);
      });

      // Separate prioritized and non-prioritized packages
      final List<QueryDocumentSnapshot> prioritizedPackages = [];
      final List<QueryDocumentSnapshot> nonPrioritizedPackages = [];

      for (var item in scoredPackages) {
        if (item['score'] > 0) {
          prioritizedPackages.add(item['doc']);
        } else {
          nonPrioritizedPackages.add(item['doc']);
        }
      }

      List<QueryDocumentSnapshot> combinedPackages = [];
      int nonPrioritizedIndex = 0;

      // Interleave prioritized and non-prioritized packages
      for (int i = 0; i < prioritizedPackages.length; i++) {
        final package = prioritizedPackages[i];
        if (!packageIds.contains(package.id)) {
          combinedPackages.add(package);
          packageIds.add(package.id);
        }

        if ((i + 1) % 2 == 0 &&
            nonPrioritizedIndex < nonPrioritizedPackages.length) {
          final nonPrioritized = nonPrioritizedPackages[nonPrioritizedIndex];
          if (!packageIds.contains(nonPrioritized.id)) {
            combinedPackages.add(nonPrioritized);
            packageIds.add(nonPrioritized.id);
          }
          nonPrioritizedIndex++;
        }
      }

      // Add remaining non-prioritized packages if needed
      while (nonPrioritizedIndex < nonPrioritizedPackages.length) {
        final package = nonPrioritizedPackages[nonPrioritizedIndex];
        if (!packageIds.contains(package.id)) {
          combinedPackages.add(package);
          packageIds.add(package.id);
        }
        nonPrioritizedIndex++;
      }

      // Limit to 50 packages
      List<QueryDocumentSnapshot> limitedPackages =
          combinedPackages.take(50).toList();

      // Fetch extra packages only if needed and avoid duplicates
      if (limitedPackages.length < 50) {
        final additionalPackagesQuery = await FirebaseFirestore.instance
            .collection('packages')
            .limit(50 - limitedPackages.length)
            .get();

        for (var doc in additionalPackagesQuery.docs) {
          if (!packageIds.contains(doc.id)) {
            limitedPackages.add(doc);
            packageIds.add(doc.id);
          }
        }
      }

      // Fetch comment counts for each package
      for (var doc in limitedPackages) {
        _fetchCommentCounts(doc.id);
      }

      if (mounted) {
        setState(() {
          packages = limitedPackages;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching interest-based packages: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                  if (mounted) {
                    setState(() {
                      _searchQuery = value;
                      isSearchTriggered = false;
                    });
                  }
                },
          onSubmitted: isOffline
              ? null
              : (value) async {
                  if (mounted) {
                    setState(() {
                      _searchQuery = value;
                      isSearchTriggered = true;
                    });
                  }
                  await _saveSearchAsInterest(_searchQuery);
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
            prefixIcon: Icon(Icons.search, color: appTheme.secondaryTextColor),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: appTheme.secondaryTextColor),
                    onPressed: isOffline
                        ? null
                        : () {
                            setState(() {
                              searchController.clear();
                              _searchQuery = "";
                              isSearchTriggered = false;
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
          style: TextStyle(color: appTheme.textColor),
        ),
      ),
      body: Stack(
        children: [
          isLoading
              ? const Center(child: LoadingAnimation())
              : RefreshIndicator(
                  onRefresh: isOffline ? () async {} : _fetchPackages,
                  child: packages.isEmpty
                      ? Center(
                          child: Text(
                            'No packages available',
                            style: TextStyle(
                                fontSize: 18, color: appTheme.textColor),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 1,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.9,
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
                                    builder: (context) => PackageDetailsScreen(
                                      documentId: package.id,
                                      commentCount:
                                          commentCounts[package.id] ?? 0,
                                    ),
                                  ),
                                );
                              },
                              child: Card(
                                color: appTheme.secondaryColor,
                                margin: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),
                                    Expanded(
                                      child:
                                          ImageCarousel(locationImages: images),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
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
    );
  }
}
