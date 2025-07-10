import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';

import '../../../../services/cloudinary_upload.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/dialogues.dart';
import '../../../../utils/loading.dart';

class PackageEditScreen extends StatefulWidget {
  final String documentId;

  const PackageEditScreen({super.key, required this.documentId});

  @override
  PackageEditScreenState createState() => PackageEditScreenState();
}

class PackageEditScreenState extends State<PackageEditScreen> {
  late TextEditingController _locationNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _prizeController;
  late TextEditingController _placeController;
  late TextEditingController _phoneNoController;
  late CloudinaryService _cloudinaryService;
  List<String> _images = [];
  List<String> _placesToVisit = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _locationNameController = TextEditingController();
    _descriptionController = TextEditingController();
    _prizeController = TextEditingController();
    _placeController = TextEditingController();
    _phoneNoController = TextEditingController();
    _cloudinaryService = CloudinaryService(uploadPreset: 'packageImages');
    _loadPackageData();
  }

  Future<void> _loadPackageData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('packages')
          .doc(widget.documentId)
          .get();

      final data = doc.data()!;

      _phoneNoController.text = data['contact'];
      _locationNameController.text = data['locationName'];
      _descriptionController.text = data['locationDescription'];
      _prizeController.text = data['prize'].toString();
      _images = List<String>.from(data['locationImages']);
      _placesToVisit = List<String>.from(data['planToVisitPlaces']);

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading package data: $e')),
        );
      }
    }
  }

  Future<void> _addImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final imageUrl = await _cloudinaryService.uploadImage(
          selectedImage: File(image.path),
        );

        if (imageUrl != null) {
          setState(() {
            _images.add(imageUrl);
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to upload image')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading image: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _addPlace(String place) {
    if (place.isNotEmpty) {
      setState(() {
        _placesToVisit.add(place);
        _placeController.clear();
      });
    }
  }

  void _removePlace(int index) {
    setState(() {
      _placesToVisit.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    if (_locationNameController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _prizeController.text.isEmpty ||
        _phoneNoController.text.isEmpty ||
        _images.isEmpty ||
        _placesToVisit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('packages')
          .doc(widget.documentId)
          .update({
        'contact': _phoneNoController.text,
        'locationName': _locationNameController.text,
        'locationDescription': _descriptionController.text,
        'prize': int.parse(_prizeController.text),
        'locationImages': _images,
        'planToVisitPlaces': _placesToVisit,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Package updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating package: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final appTheme = themeManager.currentTheme;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: LoadingAnimation()),
      );
    }

    return Scaffold(
      backgroundColor: appTheme.primaryColor,
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: appTheme.textColor,
        ),
        backgroundColor: appTheme.secondaryColor,
        title: Text(
          'Edit Package',
          style: TextStyle(color: appTheme.textColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length + 1,
                itemBuilder: (context, index) {
                  if (index == _images.length) {
                    return GestureDetector(
                      onTap: _addImage,
                      child: Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: appTheme.secondaryTextColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add_photo_alternate,
                          size: 40,
                          color: appTheme.secondaryTextColor,
                        ),
                      ),
                    );
                  }

                  return Stack(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        margin: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: _images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 16,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: appTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: appTheme.textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _locationNameController,
              decoration: InputDecoration(
                labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                labelText: 'Location Name',
                hintStyle: TextStyle(color: appTheme.secondaryTextColor),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: appTheme.textColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              style: TextStyle(color: appTheme.textColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneNoController,
              decoration: InputDecoration(
                labelText: 'Contact',
                labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                border: OutlineInputBorder(),
                prefixText: '📞  ',
              ),
              style: TextStyle(color: appTheme.textColor),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _prizeController,
              decoration: InputDecoration(
                labelText: 'Prize',
                labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              style: TextStyle(color: appTheme.textColor),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _placeController,
              decoration: InputDecoration(
                hintText: 'Enter place',
                labelText: 'Places',
                hintStyle: TextStyle(color: appTheme.secondaryTextColor),
                labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: appTheme.textColor),
              onSubmitted: _addPlace,
              onChanged: (value) {
                if (value.endsWith(',')) {
                  _addPlace(value.substring(0, value.length - 1).trim());
                }
              },
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: 400,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.all(4),
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = (constraints.maxWidth / 100).floor();
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount > 0 ? crossAxisCount : 1,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                        childAspectRatio: 2,
                      ),
                      itemCount: _placesToVisit.length,
                      itemBuilder: (context, index) {
                        final placeName = _placesToVisit[index];
                        return GestureDetector(
                          onTap: () {
                            showPlaceDialog(
                                context: context, placeName: placeName);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: appTheme.secondaryColor,
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: Text(
                                    _placesToVisit[index],
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: appTheme.textColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removePlace(index),
                                  child: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _saveChanges,
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.2),
            side: BorderSide(color: Colors.blueAccent.shade700, width: 2),
          ),
          child: const Text(
            'Save Changes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationNameController.dispose();
    _descriptionController.dispose();
    _prizeController.dispose();
    _placeController.dispose();
    super.dispose();
  }
}
