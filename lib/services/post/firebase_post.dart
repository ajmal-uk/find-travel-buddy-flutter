import 'package:cloud_firestore/cloud_firestore.dart';

class UserPostServices {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  //used for delete the post using the post id
  Future<void> deletePost(String postId) async {
    try {
      await firestore.collection('post').doc(postId).delete();
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  //used for fetch post details of the give postid
  Future<Map<String, dynamic>> fetchPostDetails(
      {required String postId}) async {
    final postDoc =
        await FirebaseFirestore.instance.collection('post').doc(postId).get();
    if (postDoc.exists) {
      return postDoc.data()!;
    } else {
      throw Exception('Post not found');
    }
  }
  
  Future<List<Map<String, dynamic>>> fetchUserPosts(
      {required String userId}) async {
    try {
      final querySnapshot = await firestore
          .collection('post')
          .where('userid', isEqualTo: userId)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['postId'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error fetching posts: $e');
      return [];
    }
  }
}
