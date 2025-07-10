import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../utils/app_theme.dart';
import '../../../../utils/loading.dart';

class TravelAgencyPage extends StatefulWidget {
  const TravelAgencyPage({super.key});

  @override
  TravelAgencyPageState createState() => TravelAgencyPageState();
}

class TravelAgencyPageState extends State<TravelAgencyPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> filteredAgencies = [];
  List<Map<String, dynamic>> allAgencies = [];
  String selectedCategory = "All";

  @override
  void initState() {
    super.initState();
    _fetchAgencies();
  }

  Future<void> _fetchAgencies() async {
    final firestore = FirebaseFirestore.instance;

    try {
      final snapshot = await firestore.collection('agencies').get();
      final agenciesList = snapshot.docs.map((doc) {
        return doc.data();
      }).toList();

      agenciesList.shuffle();

      if (mounted) {
        setState(() {
          allAgencies = agenciesList;
          filteredAgencies = agenciesList;
        });
      }
    } catch (e) {
      print("Error fetching agencies: $e");
    }
  }

  // Extract unique categories dynamically
  List<String> getCategories() {
    final categories = allAgencies.map((agency) => agency['category']).toSet();
    return ['All', ...categories];
  }

  // Filter data based on search query and category
  void _filterAgencies(String query) {
    setState(() {
      filteredAgencies = allAgencies.where((agency) {
        final matchSearch =
            agency['agencyName'].toLowerCase().contains(query.toLowerCase());
        final matchCategory =
            selectedCategory == "All" || agency['category'] == selectedCategory;

        return matchSearch && matchCategory;
      }).toList();
    });
  }

  Future<void> _refreshData() async {
    await _fetchAgencies();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = getCategories();
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: appTheme.primaryColor,
        toolbarHeight: kToolbarHeight + 10.0,
        title: TextField(
          controller: _searchController,
          onChanged: (query) => _filterAgencies(query),
          decoration: InputDecoration(
            filled: true,
            fillColor: appTheme.primaryColor,
            hintText: 'Search...',
            hintStyle:
                TextStyle(color: appTheme.secondaryTextColor, fontSize: 16),
            prefixIcon: Icon(Icons.search, color: appTheme.secondaryTextColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: appTheme.secondaryTextColor),
                    onPressed: () {
                      _searchController.clear();
                      _filterAgencies('');
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
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                final isSelected = category == selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                      _filterAgencies(_searchController.text);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : appTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : appTheme.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 4,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                ),
                itemCount: filteredAgencies.length,
                itemBuilder: (context, index) {
                  final agency = filteredAgencies[index];
                  return GestureDetector(
                    onTap: () {
                      final url = Uri.parse(agency['agencyWeb']!);
                      if (url.scheme == 'http' || url.scheme == 'https') {
                        launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        ).catchError((error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Could not open ${url.toString()}')),
                            );
                          }
                          return true;
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Invalid URL: ${url.toString()}')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        color: appTheme.secondaryColor,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                            color: Colors.black.withOpacity(0.1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CachedNetworkImage(
                            imageUrl: agency['agencyImage']!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const LoadingAnimation(),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              agency['agencyName']!,
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: appTheme.textColor),
                            ),
                          ),
                          const Icon(Icons.arrow_forward, color: Colors.blue),
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
    );
  }
}
