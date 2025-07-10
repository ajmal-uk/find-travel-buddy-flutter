import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../../../services/cloudinary_upload.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/loading.dart';

class PackageUploader extends StatefulWidget {
  const PackageUploader({super.key});

  @override
  PackageUploaderState createState() => PackageUploaderState();
}

class PackageUploaderState extends State<PackageUploader> {
  final _formKey = GlobalKey<FormState>();

  List<File> _selectedImages = [];
  String? _locationName;
  String? _locationDescription;
  int? _tripDuration;
  String? _phoneNumber;
  int? _prize;

  final List<String> _tags = [];
  String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final TextEditingController _tagController = TextEditingController();

  bool _isPosting = false;

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await ImagePicker().pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(
            pickedFiles.map((pickedFile) => File(pickedFile.path)).toList(),
          );
          if (_selectedImages.length > 3) {
            _selectedImages = _selectedImages.take(3).toList();
          }
        });
      }
    } catch (e) {
      print('Error picking images: $e');
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty) {
      if (_tags.length >= 8) {
        return;
      }
      if (!_tags.contains(tag)) {
        setState(() {
          _tags.add(tag);
        });
        _tagController.clear();
      } else {
        _tagController.clear();
      }
    }
  }

  void _handleTagInput(String value) {
    String tag = value.trim().replaceAll(',', '').replaceAll('\n', '').trim();
    if (tag.isNotEmpty) {
      _addTag(tag);
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _post() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one image!")),
      );
      return;
    }

    final String remainingTag = _tagController.text.trim();
    if (remainingTag.isNotEmpty) {
      _addTag(remainingTag);
    }

    setState(() {
      _isPosting = true;
    });

    List<String> uploadedImageUrls = [];

    try {
      for (File image in _selectedImages) {
        final response = await CloudinaryService(uploadPreset: 'packageImages')
            .uploadImage(selectedImage: image);
        if (response != null) {
          uploadedImageUrls.add(response);
        }
      }

      final packageData = {
        'locationName': _locationName,
        'locationDescription': _locationDescription,
        'locationImages': uploadedImageUrls,
        'planToVisitPlaces': _tags,
        'tripDuration': _tripDuration,
        'PostedBy': currentUserId,
        'uploadedDateTime': FieldValue.serverTimestamp(),
        'contact': _phoneNumber,
        'prize': _prize,
        'postedUsers': null
      };
      await FirebaseFirestore.instance.collection('packages').add(packageData);

      setState(() {
        _selectedImages.clear();
        _tags.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Package successfully uploaded!")),
        );
      }
    } catch (e) {
      print('Error uploading Package: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Failed to upload package. Please try again.")),
        );
      }
    } finally {
      setState(() {
        _isPosting = false;
      });

      if (mounted) {
        Navigator.pop(context);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  Widget _imagePickerWidget() {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    return SizedBox(
      height: 200,
      child: _selectedImages.isEmpty
          ? Center(
              child: GestureDetector(
                onTap: _pickImages,
                child: Container(
                  width: 200,
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
                        'Add Images\n(max 3)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: appTheme.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount:
                  _selectedImages.length + (_selectedImages.length < 3 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _selectedImages.length) {
                  return GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 40,
                            color: appTheme.textColor,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Add Images\n(max 3)',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: appTheme.secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 200,
                          height: 200,
                          child: Image.file(
                            _selectedImages[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 16,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
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
                );
              },
            ),
    );
  }

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
          'Upload Package',
          style: TextStyle(
            color: appTheme.textColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _imagePickerWidget(),
                    ),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Location Name',
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter location name'
                            : null,
                        onSaved: (value) => _locationName = value,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        keyboardType: TextInputType
                            .phone, // Updated for better semantic use
                        decoration: InputDecoration(
                          labelText: 'Contact Number',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter contact number';
                          }
                          if (!RegExp(r'^\d+$').hasMatch(value)) {
                            return 'Enter a valid numeric contact number';
                          }
                          if (value.length < 7 || value.length > 15) {
                            return 'Contact number must be between 7 and 15 digits';
                          }
                          return null;
                        },
                        onSaved: (value) => _phoneNumber = value,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Package Price',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter package price';
                          }
                          final parsedValue = int.tryParse(value);
                          if (parsedValue == null || parsedValue <= 0) {
                            return 'Enter a valid positive price';
                          }
                          return null;
                        },
                        onSaved: (value) => _prize = int.tryParse(value!),
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        decoration: InputDecoration(
                          labelText: 'Location Description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter location description'
                            : null,
                        onSaved: (value) => _locationDescription = value,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Trip Duration (in days)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter trip duration';
                          }
                          if (int.tryParse(value) == null ||
                              int.parse(value) <= 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          _tripDuration = int.tryParse(value!);
                        },
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 350,
                      child: TextFormField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          labelText: 'Plan to Visit Places',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.add, color: appTheme.textColor),
                            onPressed: _tags.length < 8
                                ? () => _addTag(_tagController.text)
                                : null,
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        onChanged: (value) {
                          if (_tags.length < 8 &&
                              (value.endsWith(",") || value.endsWith("\n"))) {
                            _handleTagInput(value);
                          }
                        },
                        onFieldSubmitted: (value) =>
                            _tags.length < 8 ? _addTag(value) : null,
                        enabled: _tags.length < 8,
                        style: TextStyle(color: appTheme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                          children: _tags.map((tag) {
                            return GestureDetector(
                              onTap: () {
                                showPlaceDialog(
                                    context: context, placeName: tag);
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
                                        tag,
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
                                      onTap: () => _removeTag(tag),
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          if (_isPosting) const LoadingAnimationOverLay()
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: appTheme.primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200, // Adjust the width as needed
                child: ElevatedButton(
                  onPressed: _isPosting
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            _post();
                          }
                        },
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
                    'Post',
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
