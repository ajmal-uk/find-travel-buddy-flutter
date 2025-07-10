import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary;
  CloudinaryService({String cloudName = 'dakew8wni', required uploadPreset})
      : cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);
  Future<String?> uploadImage({required File? selectedImage}) async {
    if (selectedImage == null) {
      return null;
    }
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          selectedImage.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl; 
    } catch (e) {
      print('Error uploading image: $e'); 
      return null; 
    }
  }
}
