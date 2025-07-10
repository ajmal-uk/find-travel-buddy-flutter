import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/counder.dart';
import '../../../utils/floating_button.dart';
import '../../../utils/image_swipe.dart';
import '../../../utils/loading.dart';
import '../aiChat/ai_chat_screen.dart';
import '../commentScreen/comment_screen.dart';
import '../profileScreen/post&trip/post_detail_screen.dart';
import '../uploadScreen/upload_bottom_sheet.dart';
import '../userDetailsScreen/others_user_profile.dart';
import '../userDetailsScreen/post&trip/post&trip/other_user_post_detail_screen.dart';
import '../user_screen.dart';
import 'notification_sceen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _searchQuery = "";
  List<String> suggestions = [];
  bool isSearchTriggered = false,
      isLoading = false,
      isFilterActive = false,
      _isSearching = false;
  List<DocumentSnapshot> posts = [];
  Map<String, Map<String, dynamic>> users = {};
  Map<String, bool> likedPosts = {};
  Map<String, int> commentCounts = {};
  Map<String, int> likeCounts = {};
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  String selectedGender = 'All';
  String selectedCompletion = 'All';

  Future<void> _fetchCommentCounts(String postId) async {
    try {
      final postDoc =
          await FirebaseFirestore.instance.collection('post').doc(postId).get();
      final comments =
          postDoc.data()?['comments'] as Map<String, dynamic>? ?? {};
      setState(() {
        commentCounts[postId] = comments.length;
      });
    } catch (e) {
      print('Error fetching comment count: $e');
    }
  }

  void _showCommentSheet(
      BuildContext context, String postId, String postUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentSheet(postId: postId, postUserId: postUserId),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchSuggestions();
    _fetchPostsWithInterestPriority();
  }

  Future<void> toggleLike(String postId) async {
    setState(() {
      bool newLikeStatus = !(likedPosts[postId] ?? false);
      likedPosts[postId] = newLikeStatus;
      likeCounts[postId] = (likeCounts[postId] ?? 0) + (newLikeStatus ? 1 : -1);
    });

    try {
      DocumentReference postRef =
          FirebaseFirestore.instance.collection('post').doc(postId);

      if (likedPosts[postId] ?? false) {
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUserId])
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUserId])
        });
      }
    } catch (e) {
      setState(() {
        bool revertedLikeStatus = !(likedPosts[postId] ?? false);
        likedPosts[postId] = revertedLikeStatus;
        likeCounts[postId] =
            (likeCounts[postId] ?? 0) + (revertedLikeStatus ? 1 : -1);
      });
      print('Error toggling like: $e');
    }
  }

  void _showSuggestions() {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final appTheme = themeManager.currentTheme;
    _removeOverlay();

    if (_searchQuery.isEmpty) return;
    final matchingSuggestions = suggestions
        .where((suggestion) =>
            suggestion.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (matchingSuggestions.isEmpty) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0.0, kToolbarHeight + 8.0),
          child: Material(
            elevation: 8.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: matchingSuggestions.length,
                  itemBuilder: (context, index) => _buildSuggestionTile(
                      matchingSuggestions[index],
                      appTheme.secondaryColor,
                      appTheme.textColor,
                      appTheme.secondaryTextColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildSuggestionTile(String suggestion, Color highlightColor,
      Color textColor, Color iconColor) {
    return Container(
      color: highlightColor,
      child: InkWell(
        onTap: () async {
          setState(() {
            _searchController.text = suggestion;
            _searchQuery = suggestion;
            isSearchTriggered = true;
          });
          await _saveSearchAsInterest(_searchQuery);
          _removeOverlay();
          _searchPosts();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  suggestion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.0,
                    color: textColor,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.north_west,
                  size: 18,
                  color: iconColor,
                ),
                onPressed: () {
                  _searchController.text = suggestion;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _searchController.text.length),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> fetchSuggestions() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('post')
        .where('userid', isNotEqualTo: currentUserId)
        .get();

    if (!mounted) return;

    // Using a Map to handle case-insensitive duplicates
    final suggestionMap = <String, String>{};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();

      // Handle locationName
      String locationName = (data['locationName']?.toString().trim() ?? '');
      if (locationName.isNotEmpty) {
        suggestionMap[locationName.toLowerCase()] = locationName;
      }

      // Handle visited places
      final visitedPlaces = List<String>.from(data['visitedPlaces'] ?? [])
          .where((place) => place.trim().isNotEmpty);
      for (var place in visitedPlaces) {
        suggestionMap[place.toLowerCase()] = place;
      }

      // Handle planned places
      final planToVisitPlaces =
          List<String>.from(data['planToVisitPlaces'] ?? [])
              .where((place) => place.trim().isNotEmpty);
      for (var place in planToVisitPlaces) {
        suggestionMap[place.toLowerCase()] = place;
      }
    }

    if (mounted) {
      setState(() {
        suggestions = suggestionMap.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    }
  }

  Future<void> _fetchPostsWithInterestPriority() async {
    setState(() {
      isLoading = true;
      posts.clear();
    });

    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(currentUserId)
          .get();

      final List<dynamic> userInterests =
          (currentUserDoc.data()?['interest'] as List?)?.cast<String>() ?? [];
      final List<dynamic> userBuddies =
          (currentUserDoc.data()?['buddying'] as List?)?.cast<String>() ?? [];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('post')
          .where('userid', isNotEqualTo: currentUserId)
          .get();

      // Use a Set to track unique post IDs
      final Set<String> processedPostIds = {};
      List<Map<String, dynamic>> scoredPosts = [];

      // Only process posts that haven't been seen yet
      for (var doc in querySnapshot.docs) {
        if (!processedPostIds.contains(doc.id)) {
          processedPostIds.add(doc.id);
          final post = doc.data();
          final userId = post['userid'] as String;
          int score = 0;

          final locationName =
              (post['locationName'] as String?)?.toLowerCase() ?? '';
          final visitedPlaces = (post['visitedPlaces'] as List?)
                  ?.map((place) => place.toString().toLowerCase())
                  .toList() ??
              [];
          final plannedPlaces = (post['planToVisitPlaces'] as List?)
                  ?.map((place) => place.toString().toLowerCase())
                  .toList() ??
              [];

          final searchFields = [
            locationName,
            ...visitedPlaces,
            ...plannedPlaces
          ];

          for (int i = 0; i < userInterests.length; i++) {
            final interest = userInterests[i].toString().toLowerCase();
            final matchScore =
                searchFields.any((field) => field.contains(interest))
                    ? (userInterests.length - i) * 10
                    : 0;
            score += matchScore;
          }

          if (userBuddies.contains(userId)) {
            score += 100;
          }

          scoredPosts.add({
            'doc': doc,
            'score': score,
            'randomTiebreaker': Random().nextDouble()
          });
        }
      }

      scoredPosts.sort((a, b) {
        int scoreComparison = b['score'].compareTo(a['score']);
        return scoreComparison != 0
            ? scoreComparison
            : b['randomTiebreaker'].compareTo(a['randomTiebreaker']);
      });

      final List<DocumentSnapshot> prioritizedPosts = scoredPosts
          .where((item) => item['score'] > 0)
          .map((item) => item['doc'] as DocumentSnapshot)
          .toList();

      final List<DocumentSnapshot> nonPrioritizedPosts = scoredPosts
          .where((item) => item['score'] == 0)
          .map((item) => item['doc'] as DocumentSnapshot)
          .toList();

      nonPrioritizedPosts.shuffle();
      prioritizedPosts.shuffle();

      // Combine posts ensuring no duplicates
      final List<DocumentSnapshot> combinedPosts = [];
      int prioritizedIndex = 0;
      int nonPrioritizedIndex = 0;

      while (combinedPosts.length < 50 &&
          (prioritizedIndex < prioritizedPosts.length ||
              nonPrioritizedIndex < nonPrioritizedPosts.length)) {
        // Add two prioritized posts if available
        for (int i = 0; i < 2; i++) {
          if (prioritizedIndex < prioritizedPosts.length &&
              combinedPosts.length < 50) {
            combinedPosts.add(prioritizedPosts[prioritizedIndex++]);
          }
        }

        // Add one non-prioritized post if available
        if (nonPrioritizedIndex < nonPrioritizedPosts.length &&
            combinedPosts.length < 50) {
          combinedPosts.add(nonPrioritizedPosts[nonPrioritizedIndex++]);
        }
      }

      await _fetchUsersForPosts(combinedPosts);

      if (mounted) {
        setState(() {
          posts = combinedPosts;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching interest-based posts: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _fetchPosts();
      }
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

  Future<void> _fetchPosts() async {
    setState(() {
      isLoading = true;
    });
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('post')
          .where('userid', isNotEqualTo: currentUserId)
          .get();
      await _fetchUsersForPosts(querySnapshot.docs);
      if (mounted) {
        setState(() {
          posts = querySnapshot.docs;
          posts.shuffle();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching posts: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUsersForPosts(List<DocumentSnapshot> newPosts) async {
    final userIds = newPosts.map((post) => post['userid']).toSet();

    if (userIds.isEmpty) return;

    try {
      final userSnapshots = await FirebaseFirestore.instance
          .collection('user')
          .where(FieldPath.documentId, whereIn: userIds.toList())
          .get();

      final newUsers = {for (var doc in userSnapshots.docs) doc.id: doc.data()};

      for (var post in newPosts) {
        final likes = List<String>.from(post['likes'] ?? []);
        likedPosts[post.id] = likes.contains(currentUserId);
        likeCounts[post.id] = likes.length;
      }

      for (var post in newPosts) {
        _fetchCommentCounts(post.id);
      }

      if (mounted) {
        setState(() {
          users.addAll(newUsers);
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _searchPosts() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        posts.clear();
      });
    }

    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('post').get();

      final filteredPosts = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final locationName =
            data['locationName']?.toString().toLowerCase() ?? "";
        final visitedPlaces = List<String>.from(data['visitedPlaces'] ?? [])
            .map((e) => e.toLowerCase())
            .toList();
        final planToVisitPlaces =
            List<String>.from(data['planToVisitPlaces'] ?? [])
                .map((e) => e.toLowerCase())
                .toList();

        final allSearchableFields = [
          locationName,
          ...visitedPlaces,
          ...planToVisitPlaces
        ];
        return allSearchableFields.any(
            (field) => field.similarityTo(_searchQuery.toLowerCase()) > 0.6);
      }).toList();

      await _fetchUsersForPosts(filteredPosts);

      if (mounted) {
        setState(() {
          posts = filteredPosts;
          posts.shuffle();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching posts: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshPosts() async {
    setState(() {
      posts.clear();
    });
    await _fetchPostsWithInterestPriority();
  }

  @override
  void dispose() {
    _removeOverlay();
    _searchController.dispose();
    _scrollController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _showFilterPopup(BuildContext context, ThemeManager themeManager) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: themeManager.currentTheme.secondaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      color: themeManager.currentTheme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: themeManager.currentTheme.textColor,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gender',
                    style: TextStyle(
                      color: themeManager.currentTheme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: themeManager.currentTheme.textColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedGender,
                      isExpanded: true,
                      dropdownColor: themeManager.currentTheme.secondaryColor,
                      style:
                          TextStyle(color: themeManager.currentTheme.textColor),
                      underline: Container(),
                      items: ['All', 'Male', 'Female', 'Other']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (mounted) {
                          setState(() {
                            selectedGender = newValue!;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Trip Status',
                    style: TextStyle(
                      color: themeManager.currentTheme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: themeManager.currentTheme.textColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: selectedCompletion,
                      isExpanded: true,
                      dropdownColor: themeManager.currentTheme.secondaryColor,
                      style:
                          TextStyle(color: themeManager.currentTheme.textColor),
                      underline: Container(),
                      items: ['All', 'Completed', 'Incompleted']
                          .map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          selectedCompletion = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedGender = 'All';
                      selectedCompletion = 'All';
                    });
                    Navigator.of(context).pop();
                    _resetFilter();
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(
                        color: isFilterActive
                            ? Colors.red
                            : themeManager.currentTheme.textColor),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _applyFilter();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyFilter() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        posts.clear();
      });
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('post')
          .where('userid', isNotEqualTo: currentUserId);

      final querySnapshot = await query.get();
      final filteredDocs = querySnapshot.docs.where((doc) {
        final post = doc.data() as Map<String, dynamic>;
        final userId = post['userid'];
        final user = users[userId];

        if (user == null) return false;

        bool matchesGender =
            selectedGender == 'All' || user['gender'] == selectedGender;

        bool matchesCompletion = selectedCompletion == 'All' ||
            (selectedCompletion == 'Completed' &&
                post['tripCompleted'] == true) ||
            (selectedCompletion == 'Incompleted' &&
                post['tripCompleted'] == false);

        return matchesGender && matchesCompletion;
      }).toList();
      if (mounted) {
        setState(() {
          posts = filteredDocs;
          isFilterActive =
              selectedGender != 'All' || selectedCompletion != 'All';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error applying filter: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _resetFilter() {
    if (mounted) {
      setState(() {
        selectedGender = 'All';
        selectedCompletion = 'All';
        isFilterActive = false;
      });
    }
    _fetchPostsWithInterestPriority();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 10.0),
        child: AppBar(
          backgroundColor: appTheme.primaryColor,
          toolbarHeight: kToolbarHeight + 10.0,
          title: CompositedTransformTarget(
            link: _layerLink,
            child: _isSearching
                ? TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        isSearchTriggered = false;
                        if (value.isNotEmpty) {
                          _showSuggestions();
                        } else {
                          _removeOverlay();
                        }
                      });
                    },
                    onSubmitted: (value) async {
                      setState(() {
                        _searchQuery = value;
                        isSearchTriggered = true;
                      });
                      await _saveSearchAsInterest(_searchQuery);
                      _removeOverlay();
                      _searchPosts();
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: appTheme.primaryColor,
                      hintText: 'Search...',
                      hintStyle: TextStyle(
                          color: appTheme.secondaryTextColor, fontSize: 16),
                      prefixIcon: Icon(Icons.search,
                          color: appTheme.secondaryTextColor),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear,
                            color: appTheme.secondaryTextColor),
                        onPressed: () {
                          setState(() {
                            _removeOverlay();
                            _isSearching = false;
                            _searchController.clear();
                            _searchQuery = "";
                            isSearchTriggered = false;
                            _fetchPostsWithInterestPriority();
                          });
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 16),
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
                    style: TextStyle(color: appTheme.textColor),
                  )
                : Text("Explore"),
          ),
          actions: [
            if (!_isSearching)
              IconButton(
                icon: Icon(Icons.search, color: appTheme.textColor),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            if (!_isSearching)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('user')
                    .doc(currentUserId)
                    .collection('notifications')
                    .where('isSeen', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  int unseenCount = 0;
                  if (snapshot.hasData) {
                    unseenCount = snapshot.data!.docs.length;
                  }

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications,
                          size: 30.0,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
                        },
                      ),
                      if (unseenCount > 0)
                        Positioned(
                          right: 14,
                          top: 13,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 10,
                              minHeight: 10,
                            ),
                            child: Text(
                              '$unseenCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 5,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            IconButton(
              icon: Icon(
                Icons.filter_alt_outlined,
                color: isFilterActive ? Colors.blue : appTheme.textColor,
                size: 28,
              ),
              onPressed: () => _showFilterPopup(context, themeManager),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_searchQuery.isNotEmpty && !isSearchTriggered)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = suggestions[index];
                    if (!suggestion
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase())) {
                      return const SizedBox.shrink();
                    }
                    return ListTile(
                      title: Text(suggestion),
                      onTap: () {
                        setState(() {
                          _searchController.text = suggestion;
                          _searchQuery = suggestion;
                          isSearchTriggered = true;
                          _searchPosts();
                        });
                      },
                    );
                  },
                ),
              Expanded(
                child: isLoading
                    ? const Center(child: LoadingAnimation())
                    : posts.isEmpty && isSearchTriggered
                        ? Center(
                            child: Text(
                              'No posts available',
                              style: TextStyle(
                                  fontSize: 18, color: appTheme.textColor),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshPosts,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: posts.length + (isLoading ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == posts.length) {
                                  return Center(
                                    child: const LoadingAnimation(),
                                  );
                                }

                                var post =
                                    posts[index].data() as Map<String, dynamic>;
                                String postId = posts[index].id;
                                String userId = post['userid'];
                                if (!users.containsKey(userId)) {
                                  return Container();
                                }

                                var user = users[userId]!;
                                if (user['isRemoved'] == true) {
                                  return Container();
                                }

                                String locationName = post['locationName'];
                                String locationDescription =
                                    post['locationDescription'];
                                List locationImages = post['locationImages'];
                                bool tripCompleted = post['tripCompleted'];
                                bool isLiked = likedPosts[postId] ?? false;
                                int likeCount = likeCounts[postId] ?? 0;

                                return GestureDetector(
                                  onTap: () {
                                    if (userId == currentUserId) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              CurrentUserPostDetailScreen(
                                            postId: postId,
                                            userId: userId,
                                            commentCount:
                                                commentCounts[postId] ?? 0,
                                          ),
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              OtherUserPostDetailScreen(
                                            postId: postId,
                                            userId: userId,
                                            commentCount:
                                                commentCounts[postId] ?? 0,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Card(
                                    elevation: 5,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(15)),
                                    color: appTheme.secondaryColor,
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () {
                                                      if (userId ==
                                                          currentUserId) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const UserScreen(
                                                                      initialIndex:
                                                                          4)),
                                                        );
                                                      } else {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) =>
                                                                  OtherProfilePage(
                                                                      userId:
                                                                          userId)),
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      width: 50,
                                                      height: 50,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: AppColors
                                                              .genderBorderColor(
                                                                  user[
                                                                      'gender']),
                                                          width: 2.0,
                                                        ),
                                                      ),
                                                      child: CircleAvatar(
                                                        radius: 20,
                                                        backgroundImage:
                                                            CachedNetworkImageProvider(
                                                                user[
                                                                    'userimage']),
                                                        backgroundColor:
                                                            Colors.transparent,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  GestureDetector(
                                                    onTap: () {
                                                      if (userId ==
                                                          currentUserId) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                const UserScreen(
                                                                    initialIndex:
                                                                        4),
                                                          ),
                                                        );
                                                      } else {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                OtherProfilePage(
                                                                    userId:
                                                                        userId),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Text(
                                                      user['username'],
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: appTheme
                                                              .textColor),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              ImageCarousel(
                                                  locationImages:
                                                      locationImages),
                                              const SizedBox(height: 16.0),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4.0),
                                                child: Text(
                                                  locationName,
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          appTheme.textColor),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 4.0,
                                                        horizontal: 30),
                                                child: Text(
                                                  locationDescription,
                                                  style: TextStyle(
                                                      color: appTheme
                                                          .secondaryTextColor),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (tripCompleted)
                                                Center(
                                                  child: Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            top: 4.0),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4,
                                                        vertical: 1.0),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[300],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8.0),
                                                    ),
                                                    child: const Text(
                                                      'Completed',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          left: 10,
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color: isLiked
                                                      ? Colors.red
                                                      : appTheme
                                                          .secondaryTextColor,
                                                  size: 28,
                                                ),
                                                onPressed: () =>
                                                    toggleLike(postId),
                                              ),
                                              Text(
                                                formatCount(likeCount),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: appTheme
                                                      .secondaryTextColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 10,
                                          right: 10,
                                          child: Row(
                                            children: [
                                              Text(
                                                formatCount(
                                                    commentCounts[postId] ?? 0),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: appTheme
                                                      .secondaryTextColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.comment_outlined,
                                                  color: appTheme
                                                      .secondaryTextColor,
                                                  size: 24,
                                                ),
                                                onPressed: () =>
                                                    _showCommentSheet(context,
                                                        postId, userId),
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
              ),
            ],
          ),
          Positioned(
            bottom: 16.0,
            right: 16.0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: 35,
                    height: 35,
                    child: FloatingChatButton(
                      heroTag: 'Home_AI_Chat',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AiChatPage()),
                        );
                      },
                      imageIcon: const AssetImage(
                          "assets/system/iconImage/blueaiIcon.png"),
                      buttonColor: appTheme.secondaryColor,
                      iconColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  type: MaterialType.transparency,
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: FloatingActionButton(
                      heroTag: 'Home_Upload_Button',
                      onPressed: () {
                        BottomSheetModal.showModal(context);
                      },
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
