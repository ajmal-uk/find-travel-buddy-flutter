import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/counder.dart';
import '../../../utils/loading.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => AnalysisPageState();
}

class AnalysisPageState extends State<AnalysisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      body: FutureBuilder(
        future: _fetchAnalysisData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingAnimation();
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (snapshot.hasData) {
            final data = snapshot.data as Map<String, dynamic>;
            return _buildAnalysisContent(context, data);
          } else {
            return const Center(child: Text("No data available."));
          }
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchAnalysisData() async {
    final usersSnapshot = await _firestore.collection('user').get();
    final postsSnapshot = await _firestore.collection('post').get();
    final packagesSnapshot = await _firestore.collection('packages').get();

    // Fetch user statistics
    final users = usersSnapshot.docs.map((doc) => doc.data()).toList();
    final totalUsers = users.length;
    final totalRemovedUsers =
        users.where((user) => user['isRemoved'] == true).length;
    final totalActiveUsers = totalUsers - totalRemovedUsers;

    final maleCount = users
        .where((user) =>
            user['gender'].toLowerCase() == 'male' &&
            user['isRemoved'] == false)
        .length;
    final femaleCount = users
        .where((user) =>
            user['gender'].toLowerCase() == 'female' &&
            user['isRemoved'] == false)
        .length;
    final otherCount = users
        .where((user) =>
            user['gender'].toLowerCase() == 'other' &&
            user['isRemoved'] == false)
        .length;

    final removedMaleCount = users
        .where((user) =>
            user['gender'].toLowerCase() == 'male' && user['isRemoved'] == true)
        .length;
    final removedFemaleCount = users
        .where((user) =>
            user['gender'].toLowerCase() == 'female' &&
            user['isRemoved'] == true)
        .length;
    final removedOtherCount = users
        .where((user) =>
            user['gender'].toLowerCase() == 'other' &&
            user['isRemoved'] == true)
        .length;

    List<Map<String, dynamic>> packagePostCounts = [];
    for (var packageDoc in packagesSnapshot.docs) {
      final packageData = packageDoc.data();
      final postedUsers =
          packageData['postedUsers'] as Map<String, dynamic>? ?? {};

      packagePostCounts.add({
        'packageId': packageDoc.id,
        'locationName': packageData['locationName'] ?? 'Unknown Location',
        'postCount': postedUsers.length,
      });
    }

    // Sort packages by post count and take top 5
    packagePostCounts.sort((a, b) => b['postCount'].compareTo(a['postCount']));
    final topPostedPackages = packagePostCounts.take(5).toList();

    // Fetch post statistics
    final posts = postsSnapshot.docs.map((doc) => doc.data()).toList();

    // Create a list of posts with their like counts
    List<Map<String, dynamic>> postsWithLikes = [];
    for (var post in posts) {
      final userId = post['userid'] as String;
      final userDoc = await _firestore.collection('user').doc(userId).get();
      final username = userDoc.data()?['username'] ?? 'Unknown User';

      postsWithLikes.add({
        'locationName': post['locationName'] ?? 'Unknown Location',
        'likes': (post['likes'] as List?)?.length ?? 0,
        'username': username,
      });
    }

    // Sort posts by likes in descending order and take top 5
    postsWithLikes.sort((a, b) => b['likes'].compareTo(a['likes']));
    final topLikedPosts = postsWithLikes.take(5).toList();

    final totalPosts = posts.length;
    final completedPosts =
        posts.where((post) => post['tripCompleted'] == true).length;
    final incompletedPosts = totalPosts - completedPosts;

    return {
      'totalUsers': totalUsers,
      'totalRemovedUsers': totalRemovedUsers,
      'totalActiveUsers': totalActiveUsers,
      'maleCount': maleCount,
      'femaleCount': femaleCount,
      'otherCount': otherCount,
      'totalPosts': totalPosts,
      'completedPosts': completedPosts,
      'incompletedPosts': incompletedPosts,
      'removedMaleCount': removedMaleCount,
      'removedFemaleCount': removedFemaleCount,
      'removedOtherCount': removedOtherCount,
      'topLikedPosts': topLikedPosts,
      'topPostedPackages': topPostedPackages,
    };
  }

  Widget _buildAnalysisContent(
      BuildContext context, Map<String, dynamic> data) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              height: 40,
            ),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildStatColumn(data['totalUsers'], "Total Users"),
                  const SizedBox(width: 50),
                  _buildStatColumn(data['totalPosts'], "Total Posts"),
                ],
              ),
            ),
            Divider(thickness: 1, height: 20),
            const SizedBox(height: 30),
            _buildMostLikedPostsHistogram(context, data['topLikedPosts']),
            const SizedBox(height: 30),
            _buildMostPostedPackagesHistogram(
                context, data['topPostedPackages']),
            const SizedBox(height: 30),
            // Removed Users Pie Chart
            _buildPieChartWithHeading(
              context,
              'Users Status',
              [
                PieChartSectionData(
                  value: data['totalRemovedUsers'].toDouble(),
                  color: Colors.red,
                  title: ' ',
                  radius: 50,
                ),
                PieChartSectionData(
                  value: data['totalActiveUsers'].toDouble(),
                  color: Colors.green,
                  title: ' ',
                  radius: 50,
                ),
              ],
              [
                "Active : ${data['totalActiveUsers']}",
                "Removed : ${data['totalRemovedUsers']}"
              ],
            ),

            // Gender Distribution Pie Chart
            _buildPieChartWithHeading(
              context,
              'Gender Status',
              [
                PieChartSectionData(
                  value: data['maleCount'].toDouble(),
                  color: Colors.lightBlue,
                  title: ' ',
                  radius: 50,
                ),
                PieChartSectionData(
                  value: data['femaleCount'].toDouble(),
                  color: Colors.pink,
                  title: ' ',
                  radius: 50,
                ),
                PieChartSectionData(
                  value: data['otherCount'].toDouble(),
                  color: Colors.yellow,
                  title: ' ',
                  radius: 50,
                ),
              ],
              [
                "Male: ${data['maleCount']}",
                "Female: ${data['femaleCount']}",
                "Other: ${data['otherCount']}"
              ],
            ),

            // Post Completion Pie Chart
            _buildPieChartWithHeading(
              context,
              'Post Completion Status',
              [
                PieChartSectionData(
                  value: data['completedPosts'].toDouble(),
                  color: Colors.green,
                  title: ' ',
                  radius: 50,
                ),
                PieChartSectionData(
                  value: data['incompletedPosts'].toDouble(),
                  color: Colors.grey,
                  title: ' ',
                  radius: 50,
                ),
              ],
              [
                "Completed: ${data['completedPosts']}",
                "Incompleted: ${data['incompletedPosts']}"
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Column(
      children: [
        Text(
          "$count",
          style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: appTheme.textColor),
        ),
        Text(
          label,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: appTheme.secondaryTextColor),
        ),
      ],
    );
  }

  Widget _buildPieChartWithHeading(
    BuildContext context,
    String heading,
    List<PieChartSectionData> sections,
    List<String> legends,
  ) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Column(
      children: [
        Text(
          heading,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: appTheme.textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: isSmallScreen ? 150 : 200,
                      height: isSmallScreen ? 150 : 200,
                      child: PieChart(
                        PieChartData(
                          sections: sections,
                          sectionsSpace: 1,
                          centerSpaceRadius: 0,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: legends
                            .map((legend) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 15,
                                        height: 15,
                                        color: AppColors.getLegendColor(legend),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          legend,
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: appTheme.textColor),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const Divider(thickness: 1, height: 20),
      ],
    );
  }

  Widget _buildMostLikedPostsHistogram(
    BuildContext context,
    List<Map<String, dynamic>> topLikedPosts,
  ) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Column(
      children: [
        Text(
          'Most Liked Posts',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: appTheme.textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topLikedPosts.isEmpty
                  ? 10
                  : (topLikedPosts.first['likes'] * 1.2),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= topLikedPosts.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          topLikedPosts[value.toInt()]['locationName']
                              .toString(),
                          style: TextStyle(
                              fontSize: 10, color: appTheme.textColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        formatCount(value.toInt()),
                        style:
                            TextStyle(fontSize: 10, color: appTheme.textColor),
                      );
                    },
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: appTheme.textColor),
              ),
              barGroups: List.generate(
                topLikedPosts.length,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: topLikedPosts[index]['likes'].toDouble(),
                      color: Colors.blue,
                      width: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: topLikedPosts
              .map((post) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '${post['locationName']}: Posted by ${post['username']} (${formatCount(post['likes'])} likes)',
                      style: TextStyle(fontSize: 12, color: appTheme.textColor),
                      textAlign: TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        const Divider(color: Colors.grey, thickness: 1, height: 20),
      ],
    );
  }

  Widget _buildMostPostedPackagesHistogram(
    BuildContext context,
    List<Map<String, dynamic>> topPostedPackages,
  ) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Column(
      children: [
        Text(
          'Most Posted Packages',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: appTheme.textColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: topPostedPackages.isEmpty
                  ? 10
                  : (topPostedPackages.first['postCount'] * 1.2),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value < 0 || value >= topPostedPackages.length) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          topPostedPackages[value.toInt()]['locationName']
                              .toString(),
                          style: TextStyle(
                              fontSize: 10, color: appTheme.textColor),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        formatCount(value.toInt()),
                        style:
                            TextStyle(fontSize: 10, color: appTheme.textColor),
                      );
                    },
                  ),
                ),
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: appTheme.textColor),
              ),
              barGroups: List.generate(
                topPostedPackages.length,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: topPostedPackages[index]['postCount'].toDouble(),
                      color: Colors.orange,
                      width: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: topPostedPackages
              .map((package) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '${package['locationName']}: ${formatCount(package['postCount'])} posts',
                      style: TextStyle(fontSize: 12, color: appTheme.textColor),
                      textAlign: TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
        const Divider(thickness: 1, height: 20),
      ],
    );
  }
}
