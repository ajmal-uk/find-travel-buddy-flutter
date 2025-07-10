import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../services/cloudinary_upload.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/loading.dart';

class UploadAgencyPage extends StatefulWidget {
  const UploadAgencyPage({super.key});

  @override
  UploadAgencyPageState createState() => UploadAgencyPageState();
}

class UploadAgencyPageState extends State<UploadAgencyPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _webController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  File? _selectedImage;
  final CloudinaryService _cloudinaryService =
      CloudinaryService(uploadPreset: 'agencyImages');

  final List<String> _keywords = [];
  bool _isLoading = false;

  Future<void> _uploadAgency() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl =
          await _cloudinaryService.uploadImage(selectedImage: _selectedImage);
    }

    final newAgency = {
      'agencyName': _nameController.text,
      'agencyWeb': _webController.text,
      'agencyKeywords': _keywords,
      'category': _categoryController.text,
      'agencyImage': imageUrl,
    };

    await FirebaseFirestore.instance.collection('agencies').add(newAgency);

    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _onKeywordEntered(String value) {
    if (value.isNotEmpty && !_keywords.contains(value)) {
      setState(() {
        _keywords.add(value);
      });
    }
    _keywordsController.clear();
  }

  void _removeKeyword(String keyword) {
    setState(() {
      _keywords.remove(keyword);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        backgroundColor: appTheme.secondaryColor,
        title: Text(
          'Upload Agency',
          style: TextStyle(color: appTheme.textColor),
        ),
        
        iconTheme: IconThemeData(
          color: appTheme.textColor,
        ),
      ),
      body: _isLoading
          ? Center(child: LoadingAnimationOverLay())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _selectedImage != null
                        ? Center(
                            child: Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: Image.file(
                                        _selectedImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImage = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
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
                          ),
                    SizedBox(height: 20),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Agency Name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a name' : null,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    SizedBox(height: 10),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        controller: _webController,
                        decoration: InputDecoration(
                          labelText: 'Agency Url',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Please enter a valid URL' : null,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        controller: _keywordsController,
                        decoration: InputDecoration(
                          labelText: 'Agency Tags',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        onFieldSubmitted: _onKeywordEntered,
                        onChanged: (value) {
                          if (value.endsWith(',')) {
                            _onKeywordEntered(
                                value.substring(0, value.length - 1));
                          }
                        },
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Container(
                      height: 200,
                      width: 350,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.all(4),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12.0,
                          runSpacing: 12.0,
                          children: _keywords.map((keyword) {
                            return GestureDetector(
                              onTap: () {
                                showPlaceDialog(
                                    context: context, placeName: keyword);
                              },
                              child: Container(
                                constraints: BoxConstraints(maxWidth: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: appTheme.secondaryColor,
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        keyword,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: appTheme.textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => _removeKeyword(keyword),
                                      child: const Icon(
                                        Icons.close,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Agency Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        color: appTheme.primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _uploadAgency,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                    shadowColor: Colors.black.withOpacity(0.25),
                  ),
                  child: const Text(
                    'Upload Agency',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
