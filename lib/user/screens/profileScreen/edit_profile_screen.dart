import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../services/cloudinary_upload.dart';
import '../../../utils/app_theme.dart';
import '../../../utils/loading.dart';

class EditProfileScreen extends StatefulWidget {
  final String uuid;
  const EditProfileScreen({super.key, required this.uuid});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _selectedImage;
  String? _currentImageUrl;
  bool _isChanged = false;
  bool _isSaving = false;

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  String? _gender;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.uuid)
        .get();

    if (userDoc.exists) {
      final data = userDoc.data()!;
      setState(() {
        _currentImageUrl = data['userimage'] ?? '';
        _fullNameController.text = data['fullname'] ?? '';
        _gender = data['gender'] ?? '';
        _dob = DateTime.parse(data['dob'] ?? '');
        _locationController.text = data['location'] ?? '';
        _bioController.text = data['userbio'] ?? '';
        _instagramController.text = data['instagram'] ?? '';
        _facebookController.text = data['facebook'] ?? '';
        _xController.text = data['x'] ?? "";
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isChanged = true;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() {
      _isSaving = true;
    });

    String? newImageUrl;

    if (_selectedImage != null) {
      if (_currentImageUrl !=
          "https://res.cloudinary.com/dakew8wni/image/upload/v1733819145/public/userImage/fvv6lbzdjhyrc1fhemaj.jpg") {}

      newImageUrl = await CloudinaryService(uploadPreset: 'userimages')
          .uploadImage(selectedImage: _selectedImage);
    }

    String? formattedDob;
    if (_dob != null) {
      formattedDob = DateFormat('yyyy-MM-dd').format(_dob!);
    }

    final updatedData = {
      'fullname': _fullNameController.text,
      'gender': _gender,
      'dob': formattedDob,
      'location': _locationController.text,
      'userbio': _bioController.text,
      'instagram': _instagramController.text,
      'facebook': _facebookController.text,
      'x': _xController.text,
      if (newImageUrl != null) 'userimage': newImageUrl,
    };

    await FirebaseFirestore.instance
        .collection('user')
        .doc(widget.uuid)
        .update(updatedData);

    setState(() {
      _isSaving = false;
      _isChanged = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );

      Navigator.of(context).pop();
    }
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
          _fullNameController.text.isNotEmpty
              ? _fullNameController.text
              : 'Edit Profile',
          style: TextStyle(color: appTheme.textColor),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      _currentImageUrl != null
                          ? CircleAvatar(
                              radius: 60,
                              backgroundImage: _selectedImage != null
                                  ? FileImage(_selectedImage!)
                                  : NetworkImage(_currentImageUrl!)
                                      as ImageProvider,
                            )
                          : const CircularProgressIndicator(),
                      TextButton(
                        onPressed: _pickImage,
                        child: const Text(
                          'Edit Image',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 350,
                  child: TextField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      labelStyle: TextStyle(color: appTheme.secondaryTextColor),
                    ),
                    style: TextStyle(color: appTheme.textColor),
                    onChanged: (_) => setState(() => _isChanged = true),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _gender,
                        items: [
                          DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male',
                                  style: TextStyle(color: appTheme.textColor))),
                          DropdownMenuItem(
                              value: 'Female',
                              child: Text(
                                'Female',
                                style: TextStyle(color: appTheme.textColor),
                              )),
                          DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other',
                                  style: TextStyle(color: appTheme.textColor))),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _gender = value;
                            _isChanged = true;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          labelStyle:
                              TextStyle(color: appTheme.secondaryTextColor),
                        ),
                        dropdownColor: appTheme.secondaryColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _dob ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );

                          if (pickedDate != null) {
                            setState(() {
                              _dob = pickedDate;
                              _isChanged = true;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              labelStyle:
                                  TextStyle(color: appTheme.secondaryTextColor),
                            ),
                            controller: TextEditingController(
                              text: _dob != null
                                  ? '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}'
                                  : '',
                            ),
                            readOnly:
                                true, // Makes the TextFormField non-editable
                            style: TextStyle(color: appTheme.textColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 350,
                  child: TextField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle:
                            TextStyle(color: appTheme.secondaryTextColor),
                      ),
                      onChanged: (_) => setState(() => _isChanged = true),
                      style: TextStyle(color: appTheme.textColor)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 350,
                  child: TextField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle:
                            TextStyle(color: appTheme.secondaryTextColor),
                      ),
                      onChanged: (_) => setState(() => _isChanged = true),
                      style: TextStyle(color: appTheme.textColor)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 350,
                  child: TextField(
                      controller: _instagramController,
                      decoration: InputDecoration(
                        labelText: 'Instagram',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle:
                            TextStyle(color: appTheme.secondaryTextColor),
                      ),
                      onChanged: (_) => setState(() => _isChanged = true),
                      style: TextStyle(color: appTheme.textColor)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 350,
                  child: TextField(
                      controller: _facebookController,
                      decoration: InputDecoration(
                        labelText: 'Facebook',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle:
                            TextStyle(color: appTheme.secondaryTextColor),
                      ),
                      onChanged: (_) => setState(() => _isChanged = true),
                      style: TextStyle(color: appTheme.textColor)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 350,
                  child: TextField(
                      controller: _xController,
                      decoration: InputDecoration(
                        labelText: 'X',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle:
                            TextStyle(color: appTheme.secondaryTextColor),
                      ),
                      onChanged: (_) => setState(() => _isChanged = true),
                      style: TextStyle(color: appTheme.textColor)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _isChanged ? _saveChanges : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: LoadingAnimation(),
              ),
            ),
        ],
      ),
    );
  }
}
