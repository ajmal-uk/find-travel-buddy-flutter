import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../services/cloudinary_upload.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/loading.dart';

class ImageUploader extends StatefulWidget {
  const ImageUploader({super.key});

  @override
  _ImageUploaderState createState() => _ImageUploaderState();
}

class _ImageUploaderState extends State<ImageUploader> {
  File? _selectedImage;
  String? _uploadedImageUrl;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        if (!mounted) return;
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null || _isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final response = await CloudinaryService(uploadPreset: 'tripimages')
          .uploadImage(selectedImage: _selectedImage);

      if (!mounted) return;
      setState(() {
        _uploadedImageUrl = response;
      });
      if (_uploadedImageUrl != null) {
        await _saveImageUrlToFirestore(_uploadedImageUrl!);
      }
    } catch (e) {
      print('Error uploading image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _saveImageUrlToFirestore(String imageUrl) async {
    try {
      String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final userRef =
          FirebaseFirestore.instance.collection('user').doc(currentUserId);
      final userDoc = await userRef.get();

      List<String> tripImages = [];

      if (userDoc.exists) {
        tripImages = List<String>.from(userDoc['tripimages'] ?? []);
        tripImages.insert(0, imageUrl);
      }

      await userRef.update({
        'tripimages': tripImages,
      });
    } catch (e) {
      print('Error saving to Firestore: $e');
    } finally {
      if (mounted) {
        Navigator.pop(context);
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  Widget _buildLoadingOverlay() {
    return _isUploading ? LoadingAnimationOverLay() : SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 300,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          color: appTheme.secondaryColor,
                        ),
                        child: _selectedImage != null
                            ? FittedBox(
                                fit: BoxFit.contain,
                                child: Image.file(_selectedImage!),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 40, color: appTheme.textColor),
                                  SizedBox(height: 8),
                                  Text(
                                    'Add Image',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: appTheme.secondaryTextColor),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _selectedImage == null || _isUploading
                      ? null
                      : _uploadImage,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    disabledBackgroundColor: Colors.grey,
                    disabledForegroundColor: Colors.white,
                  ),
                  child: Text(
                    'Upload',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildLoadingOverlay(),
        ],
      ),
    );
  }
}
