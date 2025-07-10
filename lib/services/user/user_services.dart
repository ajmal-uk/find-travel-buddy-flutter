import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //fetch Corresponding User Data using UserId
  Future<Map<String, dynamic>> fetchUserDetails(
      {required String userId}) async {
    final userDoc = await _firestore.collection('user').doc(userId).get();
    if (userDoc.exists) {
      return userDoc.data()!;
    } else {
      throw Exception('User not found');
    }
  }

  //fetch all Users for user search Page(both admin and user)
  Future<List<Map<String, dynamic>>> fetchUsers() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('user').get();
      return snapshot.docs.map((doc) {
        return {
          'userId': doc.id,
          'userName': doc['username'],
          'userImage': doc['userimage'],
          'userGender': doc['gender'],
          'isRemoved': doc['isRemoved'] ?? false,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  //Admin And add Remove User
  Future<void> updateUserRemovalStatus(
      {required String userId, required bool isRemoved}) async {
    await FirebaseFirestore.instance
        .collection('user')
        .doc(userId)
        .update({'isRemoved': isRemoved});
  }
}
