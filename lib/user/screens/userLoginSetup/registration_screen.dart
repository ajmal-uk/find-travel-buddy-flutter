import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:pinput/pinput.dart';
import '../../../services/one_signal.dart';
import '../../../services/otp.dart';
import '../../../services/user/firebase_user_auth.dart';
import '../../../login_screen.dart';
import 'get_started_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final fullNameController = TextEditingController();
  final dobController = TextEditingController();
  final locationController = TextEditingController();
  final aadharController = TextEditingController();
  final usernameController = TextEditingController();
  final mobileNumberController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final OTPService otpService = OTPService();
  String? _gender;
  int _step = 1;
  String otp = "";
  String generatedOtp = "";
  Timer? _timer;
  int _start = 60;
  bool _isLoading = false;
  bool _isVerifyLoading = false;
  String? usernameError;
  String? mobileError;
  String? emailError;
  String? aadharError;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      prefixIcon: Icon(icon, color: Colors.white),
      fillColor: Colors.black.withOpacity(0.3),
      filled: true,
    );
  }

  InputDecoration _inputDecorationWithEye(
      String label, IconData icon, bool isVisible, VoidCallback onPressed) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.white, width: 2),
      ),
      prefixIcon: Icon(icon, color: Colors.white),
      suffixIcon: IconButton(
        icon: Icon(
          isVisible ? Icons.visibility : Icons.visibility_off,
          color: Colors.white,
        ),
        onPressed: onPressed,
      ),
      fillColor: Colors.black.withOpacity(0.3),
      filled: true,
    );
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.lightBlueAccent,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.lightBlueAccent,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (selectedDate != null) {
      if (mounted) {
        setState(() {
          dobController.text = "${selectedDate.toLocal()}".split(' ')[0];
        });
      }
    }
  }

  void startTimer() {
    _start = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        if (mounted) {
          setState(() {
            _timer?.cancel();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _start--;
          });
        }
      }
    });
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (mounted) {
        setState(() {
          _step++;
        });
      }
    }
  }

  String _generateOtp() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString();
  }

  Future<void> _sendOtp(String mobileNumber) async {
    if (mounted) {
      setState(() {
        generatedOtp = _generateOtp();
      });
    }
    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId != null) {
      await NotificationService().sendOtpNotificationToUser(
          otp: generatedOtp, title: 'Your OTP Code', playerId: playerId);
      print("Notification Sent to $playerId: $generatedOtp");
    } else {
      print('Player ID is null');
    }
    print("OTP Sent to $mobileNumber: $generatedOtp");
    String result = await otpService.sendOTP(mobileNumber, generatedOtp);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result)),
      );
    }
    startTimer();
  }

  Future<void> _storeUserDetails() async {
    String genderController = _gender.toString();
    try {
      await UserAuthServices().userRegisterInFirebase(
        context: context,
        username: usernameController.text.trim(),
        fullname: fullNameController.text.trim(),
        dob: dobController.text,
        gender: genderController,
        phoneno: mobileNumberController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        aadharno: aadharController.text.trim(),
        location: locationController.text.trim(),
      );
    } catch (e) {
      throw Exception("Failed to store user details: $e");
    }
  }

  String? _validateAadhar(String value) {
    String cleanedValue = value.replaceAll(' ', '');
    if (cleanedValue.isEmpty) {
      return "Please enter your Aadhar number";
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(cleanedValue)) {
      return "Aadhar number must only contain digits";
    }
    if (cleanedValue.length != 12) {
      return "Aadhar number must be 12 digits long";
    }
    return null;
  }

  String _formatAadhar(String value) {
    String cleanedValue = value.replaceAll(RegExp(r'\D'), '');
    if (cleanedValue.length > 12) {
      cleanedValue = cleanedValue.substring(0, 12);
    }
    String formattedValue = cleanedValue.replaceAllMapped(
      RegExp(r'(\d{4})(?=\d)'),
      (match) => '${match.group(1)} ',
    );

    return formattedValue;
  }

  @override
  void initState() {
    super.initState();
    usernameController.addListener(() {
      if (mounted) {
        setState(() {
          if (usernameController.text.isNotEmpty) {
            usernameError = null;
          }
        });
      }
    });

    mobileNumberController.addListener(() {
      if (mounted) {
        setState(() {
          if (mobileNumberController.text.isNotEmpty) {
            mobileError = null;
          }
        });
      }
    });

    emailController.addListener(() {
      if (mounted) {
        setState(() {
          if (emailController.text.isNotEmpty) {
            emailError = null;
          }
        });
      }
    });

    aadharController.addListener(() {
      if (mounted) {
        setState(() {
          if (aadharController.text.isNotEmpty) {
            aadharError = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    mobileNumberController.dispose();
    emailController.dispose();
    aadharController.dispose();

    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/system/bg/registration.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Become a part of us!",
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 70),
                    Form(
                      key: _formKey,
                      child: _step == 1
                          ? _buildStep1()
                          : _step == 2
                              ? _buildStep2()
                              : _buildStep3(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: fullNameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Full Name", Icons.person),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your full name";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: DropdownButtonFormField<String>(
            value: _gender,
            decoration: _inputDecoration("Gender", Icons.person_outline),
            items: ["Male", "Female", "Other"]
                .map((gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(
                        gender,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ))
                .toList(),
            dropdownColor: const Color.fromARGB(255, 77, 154, 255),
            onChanged: (value) {
              setState(() {
                _gender = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please select your gender";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: dobController,
            readOnly: true,
            style: const TextStyle(color: Colors.white),
            onTap: _selectDate,
            decoration: _inputDecoration("DOB", Icons.cake),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please select your date of birth";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: locationController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Location", Icons.location_on),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your location";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightBlueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            "Next",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              ),
            );
          },
          child: RichText(
            text: const TextSpan(
              text: 'Don\'t have an account? ',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: 'Login',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Username", Icons.person),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[^a-zA-Z0-9_]')),
            ],
            onChanged: (value) {
              String newValue = value.toLowerCase();
              if (newValue != value) {
                usernameController.value = TextEditingValue(
                  text: newValue,
                  selection: TextSelection.collapsed(offset: newValue.length),
                );
              }
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your username";
              }
              return null;
            },
          ),
        ),
        if (usernameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              usernameError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: aadharController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Aadhar Number", Icons.credit_card),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {
                aadharError = _validateAadhar(value);
                String formattedValue = _formatAadhar(value);
                aadharController.text = formattedValue;
                aadharController.selection = TextSelection.fromPosition(
                    TextPosition(offset: aadharController.text.length));
              });
            },
            validator: (value) {
              if (aadharError != null) {
                return aadharError;
              }
              return null;
            },
          ),
        ),
        if (aadharError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              aadharError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: mobileNumberController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [
              LengthLimitingTextInputFormatter(10),
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: _inputDecoration("Mobile Number", Icons.phone),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your mobile number";
              }
              return mobileError;
            },
          ),
        ),
        if (mobileError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              mobileError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: emailController,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDecoration("Email", Icons.email),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your email";
              }
              final emailRegex =
                  RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
              if (!emailRegex.hasMatch(value)) {
                return "Please enter a valid email address";
              }
              return emailError;
            },
          ),
        ),
        if (emailError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              emailError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: passwordController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecorationWithEye(
                "New Password", Icons.lock, isPasswordVisible, () {
              if (mounted) {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              }
            }),
            obscureText: !isPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please enter your password";
              }
              if (value.length < 6) {
                return "Password cannot exceed 6 characters";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 350,
          child: TextFormField(
            controller: confirmPasswordController,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecorationWithEye(
                "Confirm Password", Icons.lock, isConfirmPasswordVisible, () {
              if (mounted) {
                setState(() {
                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                });
              }
            }),
            obscureText: !isConfirmPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return "Please confirm your password";
              }
              if (value.length < 6) {
                return "Password cannot exceed 6 characters";
              }
              if (value != passwordController.text) {
                return "Passwords do not match";
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _step = 1;
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "Back",
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 50),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        if (mounted) {
                          setState(() {
                            _isLoading = true;
                            usernameError = null;
                            mobileError = null;
                            emailError = null;
                          });
                        }
                        List<String> conflicts =
                            await UserAuthServices().checkIfUserExists(
                          username: usernameController.text,
                          email: emailController.text,
                          mobile: mobileNumberController.text,
                          aadharno: aadharController.text,
                        );

                        if (conflicts.isNotEmpty) {
                          if (mounted) {
                            setState(() {
                              if (conflicts.contains("Username")) {
                                usernameError =
                                    "This username is already taken";
                              }
                              if (conflicts.contains("Email")) {
                                emailError = "This email is already registered";
                              }
                              if (conflicts.contains("Mobile number")) {
                                mobileError =
                                    "This mobile number is already registered";
                              }
                              if (conflicts.contains("Aadhar number")) {
                                aadharError =
                                    "Aadhar number is already registered";
                              }
                              _isLoading = false;
                            });
                          }
                          return;
                        }
                        await _sendOtp(mobileNumberController.text);
                        if (mounted) {
                          setState(() {
                            _isLoading = false;
                            _step = 3;
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlueAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Register"),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        const Text(
          "Enter OTP",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.topRight,
          child: IconButton(
            icon: const Icon(
              Icons.edit,
              color: Colors.white,
            ),
            onPressed: () {
              if (mounted) {
                setState(() {
                  _step = 2;
                });
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        Pinput(
          length: 6,
          onChanged: (value) {
            otp = value;
          },
          onCompleted: (value) {
            if (mounted) {
              setState(() {
                otp = value;
              });
            }
          },
          defaultPinTheme: PinTheme(
            height: 56,
            width: 56,
            textStyle: const TextStyle(fontSize: 22, color: Colors.black),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Resend OTP in $_start seconds",
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isVerifyLoading
              ? null
              : () async {
                  if (otp == generatedOtp) {
                    if (mounted) {
                      setState(() {
                        _isVerifyLoading = true;
                      });
                    }

                    try {
                      await _storeUserDetails();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const GetStartedPage()),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("An error occurred: $e")),
                      );
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isVerifyLoading = false;
                        });
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Invalid OTP")),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.lightGreenAccent,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isVerifyLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("Verify OTP"),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _start == 0
              ? () async {
                  startTimer();
                  await _sendOtp(mobileNumberController.text);
                  if (mounted) {
                    setState(() {});
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 255, 92, 51),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            "Resend OTP",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
