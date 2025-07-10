import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/loading.dart';
import '../manageScreen/usersScreen/user_profile_view_screen.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  ReportsPageState createState() => ReportsPageState();
}

class ReportsPageState extends State<ReportsPage> {
  String selectedCategory = "Unchecked";
  List<String> categories = ["Unchecked", "Checked"];

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      body: Column(
        children: [
          SizedBox(
            height: 10,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                final isSelected = category == selectedCategory;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
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
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reports')
                  .where('isChecked', isEqualTo: selectedCategory == "Checked")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: LoadingAnimation());
                }
                final reports = snapshot.data!.docs;
                if (reports.isEmpty) {
                  return const Center(child: Text("No reports found."));
                }
                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final reportingUserId = report['reportingUser'];

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('user')
                          .doc(reportingUserId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return SizedBox();
                        }

                        final userData = userSnapshot.data!;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: userData['userimage'] != null
                                ? NetworkImage(userData['userimage'])
                                : AssetImage('assets/default_avatar.png')
                                    as ImageProvider,
                          ),
                          title: Text(
                            userData['username'],
                            style: TextStyle(color: appTheme.textColor),
                          ),
                          subtitle: Text(
                              report['description'].toString().length > 20
                                  ? '${report['description'].toString().substring(0, 20)}...'
                                  : report['description'].toString(),
                              style: TextStyle(
                                  color: appTheme.secondaryTextColor)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportDetailsPage(
                                  reportId: report.id,
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
}

class ReportDetailsPage extends StatefulWidget {
  final String reportId;

  const ReportDetailsPage({super.key, required this.reportId});

  @override
  ReportDetailsPageState createState() => ReportDetailsPageState();
}

class ReportDetailsPageState extends State<ReportDetailsPage> {
  bool _isLoading = false;
  bool _isChecked = false; // Track the checked state

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        
        backgroundColor: appTheme.secondaryColor,
        iconTheme: IconThemeData(
          color: appTheme.textColor,
        ),
        title: Text(
          "Report Details",
          style: TextStyle(color: appTheme.textColor),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('reports')
            .doc(widget.reportId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: LoadingAnimation());
          }

          final reportData = snapshot.data!;
          final reportingUserId = reportData['reportingUser'];
          final reportedUserId = reportData['reportedUser'];
          final reportedTime = reportData['reportedTime'].toDate();
          final formattedReportedTime =
              DateFormat.yMMMd().add_jm().format(reportedTime);

          // Set initial checked state from Firestore
          if (!_isChecked && reportData['isChecked'] != null) {
            _isChecked = reportData['isChecked'];
          }

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Reported Time:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: appTheme.textColor),
                                ),
                                Text(
                                  formattedReportedTime,
                                  style: TextStyle(
                                      color: appTheme.secondaryTextColor),
                                ),
                              ],
                            ),
                            SizedBox(height: 40),
                            FutureBuilder<List<DocumentSnapshot>>(
                              future: Future.wait([
                                FirebaseFirestore.instance
                                    .collection('user')
                                    .doc(reportingUserId)
                                    .get(),
                                FirebaseFirestore.instance
                                    .collection('user')
                                    .doc(reportedUserId)
                                    .get(),
                              ]),
                              builder: (context, usersSnapshot) {
                                if (!usersSnapshot.hasData) {
                                  return Center(child: LoadingAnimation());
                                }

                                final reportingUser = usersSnapshot.data![0];
                                final reportedUser = usersSnapshot.data![1];

                                return GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                OtherProfilePageForAdmin(
                                                    userId: reportingUserId),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            backgroundImage: NetworkImage(
                                                reportingUser['userimage']),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            reportingUser['username'],
                                            style: TextStyle(
                                                color: appTheme.textColor),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "Reporting",
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                OtherProfilePageForAdmin(
                                                    userId: reportedUserId),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            backgroundImage: NetworkImage(
                                                reportedUser['userimage']),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            reportedUser['username'],
                                            style: TextStyle(
                                                color: appTheme.textColor),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            "Reported",
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  reportData['description'],
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5), // Overlay effect
                    child: Center(child: LoadingAnimationOverLay()),
                  ),
                ),
              // Floating action button at the center bottom
              Positioned(
                bottom: 16, // Distance from the bottom
                left: MediaQuery.of(context).size.width / 2 -
                    30, // Center horizontally
                child: FloatingActionButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                          });

                          await FirebaseFirestore.instance
                              .collection('reports')
                              .doc(widget.reportId)
                              .update({'isChecked': !_isChecked});

                          setState(() {
                            _isChecked = !_isChecked; // Toggle the state
                            _isLoading = false;
                          });
                        },
                  backgroundColor: _isChecked ? Colors.red : Colors.blue,
                  child: Icon(
                    _isChecked ? Icons.close : Icons.check,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
