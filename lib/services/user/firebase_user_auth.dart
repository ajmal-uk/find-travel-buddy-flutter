import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserAuthServices {
  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  //-------------------  Register && ForgetPassword   ---------------------//

  //used to Register the credentials in the database
  Future<void> userRegisterInFirebase({
    required BuildContext context,
    required String username,
    required String fullname,
    required String dob,
    required String gender,
    required String phoneno,
    required String aadharno,
    required String email,
    required String password,
    required String location,
  }) async {
    try {
      final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      String userUid = userCredential.user?.uid ?? '';
      String cleanedAadhar = aadharno.replaceAll(RegExp(r'\D'), '');
      await firestore.collection('user').doc(userUid).set({
        'username': username,
        'phoneno': phoneno,
        'email': email,
        'dob': dob,
        'gender': gender,
        'fullname': fullname,
        'aadharno': cleanedAadhar,
        'tripimages': null,
        'facebook': null,
        'instagram': null,
        'userbio': null,
        'userimage':
            'https://res.cloudinary.com/dakew8wni/image/upload/v1733819145/public/userImage/fvv6lbzdjhyrc1fhemaj.jpg',
        'x': null,
        'isRemoved': false,
        'location': location,
        'buddies': null,
        'buddying': null,
        'notifications': null,
        'onId': null,
        'joinAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration Successful for $username'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration Unsuccessful'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  //used for check the user credentials is already exist in the database for Registration
  Future<List<String>> checkIfUserExists({
    required String username,
    required String email,
    required String mobile,
    required String aadharno,
  }) async {
    try {
      List<String> conflicts = [];

      final usernameSnapshot = await firestore
          .collection('user')
          .where('username', isEqualTo: username)
          .get();
      if (usernameSnapshot.docs.isNotEmpty) {
        conflicts.add("Username");
      }

      final emailSnapshot = await firestore
          .collection('user')
          .where('email', isEqualTo: email)
          .get();
      if (emailSnapshot.docs.isNotEmpty) {
        conflicts.add("Email");
      }

      final adminEmailSnapshot = await firestore
          .collection('admin')
          .where('email', isEqualTo: email)
          .get();
      if (adminEmailSnapshot.docs.isNotEmpty) {
        conflicts.add("Email");
      }
      final mobileSnapshot = await firestore
          .collection('user')
          .where('phoneno', isEqualTo: mobile)
          .get();
      if (mobileSnapshot.docs.isNotEmpty) {
        conflicts.add("Mobile number");
      }

      String cleanedAadhar = aadharno.replaceAll(RegExp(r'\D'), '');
      final aadharSnapshot = await firestore
          .collection('user')
          .where('aadharno', isEqualTo: cleanedAadhar)
          .get();
      if (aadharSnapshot.docs.isNotEmpty) {
        conflicts.add("Aadhar number");
      }

      return conflicts;
    } catch (e) {
      return ["Error checking user data"];
    }
  }

  //used for check the user credentials is exist or not in database for Forget Password
  Future<String?> checkUserExistence(String identifier) async {
    try {
      final QuerySnapshot userSnapshot = await firestore
          .collection('user')
          .where('username', isEqualTo: identifier)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        return userSnapshot.docs.first.id;
      }

      final QuerySnapshot emailSnapshot = await firestore
          .collection('user')
          .where('email', isEqualTo: identifier)
          .limit(1)
          .get();

      if (emailSnapshot.docs.isNotEmpty) {
        return emailSnapshot.docs.first.id;
      }

      final QuerySnapshot adminEmailSnapshot = await firestore
          .collection('admin')
          .where('email', isEqualTo: identifier)
          .limit(1)
          .get();

      if (adminEmailSnapshot.docs.isNotEmpty) {
        return adminEmailSnapshot.docs.first.id;
      }
      final QuerySnapshot phoneSnapshot = await firestore
          .collection('user')
          .where('phoneno', isEqualTo: identifier)
          .limit(1)
          .get();

      if (phoneSnapshot.docs.isNotEmpty) {
        return phoneSnapshot.docs.first.id;
      }
      final QuerySnapshot aadharSnapshot = await firestore
          .collection('user')
          .where('aadharno', isEqualTo: identifier)
          .limit(1)
          .get();

      if (aadharSnapshot.docs.isNotEmpty) {
        return aadharSnapshot.docs.first.id;
      }

      return null;
    } catch (e) {
      throw Exception('Error checking user existence: ${e.toString()}');
    }
  }

  //used to get the userEmail for Forgetpassword using UserId
  Future<String?> getUserEmailById(String userId) async {
    try {
      final userDoc = await firestore.collection('user').doc(userId).get();
      final adminDoc = await firestore.collection('user').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data()?['email'] as String?;
      } else if (adminDoc.exists) {
        return adminDoc.data()?['email'] as String?;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}
