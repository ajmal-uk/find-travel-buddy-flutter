import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/one_signal.dart';
import '../../../../services/user/user_services.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/loading.dart';
import 'user_profile_view_screen.dart';

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({Key? key}) : super(key: key);

  @override
  UserSearchPageState createState() => UserSearchPageState();
}

class UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String query = "";
  String selectedCategory = "All";
  final List<String> categories = ["All", "Active", "Removed"];
  final UserService userService = UserService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> getFilteredUsers() async {
    try {
      final allUsers = await userService.fetchUsers();
      List<Map<String, dynamic>> filteredUsers = [];

      if (selectedCategory == "All") {
        filteredUsers = allUsers;
      } else if (selectedCategory == "Active") {
        filteredUsers = allUsers.where((user) => !user['isRemoved']).toList();
      } else if (selectedCategory == "Removed") {
        filteredUsers = allUsers.where((user) => user['isRemoved']).toList();
      }

      if (query.isNotEmpty) {
        filteredUsers = filteredUsers
            .where((user) => user['userName']
                .toString()
                .toLowerCase()
                .startsWith(query.toLowerCase()))
            .toList();
      }

      return filteredUsers;
    } catch (e) {
      print("Error fetching users: $e");
      return [];
    }
  }

  void _showConfirmationDialog(String userId, bool isRemoved, String username) {
    showConfirmationDialog(
      context: context,
      title: isRemoved ? 'Restrict User' : 'Reinstate User',
      message: isRemoved
          ? 'Are you sure you want to restrict $username?'
          : 'Are you sure you want to reinstate $username?',
      cancelButtonText: 'Cancel',
      confirmButtonText: isRemoved ? 'Remove' : 'Add',
      onConfirm: () async {
        await updateUserStatus(userId, isRemoved);
      },
      titleIcon: isRemoved
          ? const Icon(Icons.delete_forever, color: Colors.red)
          : const Icon(Icons.add, color: Colors.green),
      titleColor: isRemoved ? Colors.redAccent : Colors.greenAccent,
      cancelButtonColor: Colors.blue,
      confirmButtonColor: isRemoved ? Colors.red : Colors.green,
    );
  }

  Future<void> updateUserStatus(String userId, bool isRemoved) async {
    try {
      await userService.updateUserRemovalStatus(
          userId: userId, isRemoved: isRemoved);
      final user = await userService.fetchUserDetails(userId: userId);
      final List<String> playerIds = List<String>.from(user['onId'] ?? []);

      if (playerIds.isNotEmpty) {
        final title = isRemoved ? "Account Restricted" : "Account Reinstated";
        final description = isRemoved
            ? "Your account has been restricted. Please contact support for more details."
            : "Your account has been reinstated. You can now access all features.";
        await NotificationService().sentNotificationtoUser(
          title: title,
          description: description,
          onIds: playerIds,
        );
      }
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print("Error updating user status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context, listen: false);
    final appTheme = themeManager.currentTheme;

    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: appTheme.textColor),
                decoration: InputDecoration(
                  hintText: 'Search....',
                  hintStyle: TextStyle(color: appTheme.secondaryTextColor),
                  prefixIcon:
                      Icon(Icons.search, color: appTheme.secondaryTextColor),
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
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              query = '';
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  final isSelected = category == selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: MaterialButton(
                      onPressed: () {
                        setState(() {
                          selectedCategory = category;
                        });
                      },
                      color: isSelected ? Colors.blue : appTheme.secondaryColor,
                      shape: RoundedRectangleBorder(
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
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: getFilteredUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingAnimation());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text(
                        "No users found",
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    );
                  }

                  final filteredUsers = snapshot.data!;
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4.0,
                          horizontal: 8.0,
                        ),
                        color: appTheme.secondaryColor,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(user['userImage']),
                            radius: 20,
                          ),
                          title: Text(
                            user['userName'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: appTheme.textColor,
                            ),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              _showConfirmationDialog(
                                user['userId'],
                                !user['isRemoved'],
                                user['userName'],
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  user['isRemoved'] ? Colors.green : Colors.red,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(4),
                            ),
                            child: Text(
                              user['isRemoved'] ? "+" : "-",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 12.0,
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OtherProfilePageForAdmin(
                                  userId: user['userId'],
                                ),
                              ),
                            );
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
    );
  }
}
