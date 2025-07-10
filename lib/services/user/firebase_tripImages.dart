import 'package:cloud_firestore/cloud_firestore.dart';

class UserTripImageServices {
  
  final FirebaseFirestore firestore = FirebaseFirestore.instance;


  Future<void> deleteTripPhoto(String userId, String photoUrl) async {
    try {
      await firestore.collection('user').doc(userId).update({
        'tripimages': FieldValue.arrayRemove([photoUrl]),
      });
      print('Deleted trip photo: $photoUrl');
    } catch (e) {
      print('Error deleting trip photo: $e');
    }
  }

  Stream<List<String>> fetchUserTripImagesStream(String userId) {
    return firestore
        .collection('user')
        .doc(userId)
        .snapshots() // Listen for changes to the user document
        .map((docSnapshot) {
          if (docSnapshot.exists) {
            final data = docSnapshot.data() as Map<String, dynamic>;
            return List<String>.from(data['tripimages'] ?? []);
          } else {
            return [];
          }
        });
  }
}
