import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final String firebaseApiKey = 'AIzaSyAMPF80n-u8yBPTn8KjtTDGAdp-FvyAcD8';
  final String supabaseUrl = 'https://tddaivhwsbqnaibdsvoe.supabase.co';
  final String supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRkZGFpdmh3c2JxbmFpYmRzdm9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDU1NzM2NTUsImV4cCI6MjA2MTE0OTY1NX0.QR1bRuxTi-aWk2ZLJ6ixyqCPWkV7GLygUZJbu80ibA0';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final _formKey = GlobalKey<FormState>();
  String? _gender;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.blueGrey,
              onPrimary: Colors.white,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        final age = DateTime.now().year - picked.year;
        ageController.text = age.toString();
      });
    }
  }

  Future<String?> _uploadImage(File image) async {
    try {
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('$supabaseUrl/storage/v1/object/profile_images/$fileName'),
        headers: {
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
        },
        body: bytes,
      );

      if (response.statusCode == 200) {
        return '$supabaseUrl/storage/v1/object/public/profile_images/$fileName';
      }
      return null;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_profileImage == null) {
      _showMessage('Please select a profile image');
      return;
    }
    if (_gender == null) {
      _showMessage('Please select your gender');
      return;
    }
    if (_selectedDate == null) {
      _showMessage('Please select your birth date');
      return;
    }

    final age = int.tryParse(ageController.text) ?? 0;
    if (age < 16) {
      _showMessage('You must be at least 16 years old to register');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Upload profile image
      final imageUrl = await _uploadImage(_profileImage!);
      if (imageUrl == null) {
        _showMessage('Failed to upload profile image');
        return;
      }

      // 2. Firebase authentication
      final url = Uri.parse(
        "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseApiKey",
      );

      final res = await http
          .post(
            url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "email": emailController.text.trim(),
              "password": passwordController.text,
              "returnSecureToken": true,
            }),
          )
          .timeout(Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode != 200) {
        final error = data["error"]["message"];
        _showMessage(_getFriendlyError(error));
        return;
      }

      // 3. Save additional user data to Firestore
      final userData = {
        "fields": {
          "email": {"stringValue": emailController.text.trim()},
          "username": {"stringValue": usernameController.text.trim()},
          "image_url": {"stringValue": imageUrl},
          "gender": {"stringValue": _gender},
          "birth_date": {"timestampValue": _selectedDate!.toIso8601String()},
          "age": {"integerValue": age},
          "created_at": {"timestampValue": DateTime.now().toIso8601String()},
        }
      };

      final firestoreUrl = Uri.parse(
        "https://firestore.googleapis.com/v1/projects/dezny-8bf09/databases/(default)/documents/users/${data['localId']}",
      );

      final firestoreRes = await http.patch(
        firestoreUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(userData),
      );

      if (firestoreRes.statusCode != 200) {
        _showMessage("Account created but failed to save additional data");
      }

      // 4. Send verification email
      final verifyUrl = Uri.parse(
        "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$firebaseApiKey",
      );

      await http.post(
        verifyUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "requestType": "VERIFY_EMAIL",
          "idToken": data['idToken'],
        }),
      );

      // 5. Show success dialog
      _showSuccessDialog(context, data['idToken'], data['localId']);
    } on TimeoutException {
      _showMessage("Connection timeout. Please try again.");
    } on Exception catch (e) {
      _showMessage("An error occurred: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(
      BuildContext context, String idToken, String localId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  spreadRadius: 5,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            padding: EdgeInsets.all(25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified,
                  color: Colors.greenAccent,
                  size: 60,
                ),
                SizedBox(height: 20),
                Text(
                  "Account Created!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "A verification email has been sent to your email address. Please verify your email to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 25),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Go back to login page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "Continue",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        backgroundColor: Colors.grey[800],
      ),
    );
  }

  String _getFriendlyError(String error) {
    switch (error) {
      case 'EMAIL_EXISTS':
        return "This email is already in use.";
      case 'OPERATION_NOT_ALLOWED':
        return "Password sign-in is disabled.";
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return "Too many attempts. Try again later.";
      default:
        return "Sign up failed: ${error.replaceAll('_', ' ').toLowerCase()}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: size.height * 0.05),

                  // Back button
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.grey[300]),
                    onPressed: () => Navigator.pop(context),
                  ),

                  SizedBox(height: 20),

                  // Title
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Create Account",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[300],
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Join us to get started",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),

                  // Profile Image Picker
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.grey[800],
                                backgroundImage: _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : null,
                                child: _profileImage == null
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Username Field
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TextFormField(
                        controller: usernameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Username",
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon:
                              Icon(Icons.person, color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorStyle: TextStyle(color: Colors.redAccent),
                          fillColor: Colors.grey[900],
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          if (value.length < 4) {
                            return 'Username must be at least 4 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Email Field
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TextFormField(
                        controller: emailController,
                        style: TextStyle(color: Colors.white),
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon:
                              Icon(Icons.email, color: Colors.grey[400]),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorStyle: TextStyle(color: Colors.redAccent),
                          fillColor: Colors.grey[900],
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Password Field
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TextFormField(
                        controller: passwordController,
                        style: TextStyle(color: Colors.white),
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.lock, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorStyle: TextStyle(color: Colors.redAccent),
                          fillColor: Colors.grey[900],
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Confirm Password Field
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: TextFormField(
                        controller: confirmPasswordController,
                        style: TextStyle(color: Colors.white),
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: "Confirm Password",
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.lock, color: Colors.grey[400]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[700]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.redAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorStyle: TextStyle(color: Colors.redAccent),
                          fillColor: Colors.grey[900],
                          filled: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  // Gender Selection (3D Choice Chip)
                  SlideTransition(
                    position: _slideAnimation,
                    child: SlideTransition(
  position: _slideAnimation,
  child: FadeTransition(
    opacity: _fadeAnimation,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Gender",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _gender = "Male";
                  });
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: _gender == "Male" ? Colors.blueGrey : Colors.grey[900],
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.male,
                      color: _gender == "Male" ? Colors.white : Colors.grey[400],
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Male",
                      style: TextStyle(
                        color: _gender == "Male" ? Colors.white : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _gender = "Female";
                  });
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: _gender == "Female" ? Colors.pink[300] : Colors.grey[900],
                  side: BorderSide(color: Colors.grey[700]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.female,
                      color: _gender == "Female" ? Colors.white : Colors.grey[400],
                    ),
                    SizedBox(width: 8),
                    Text(
                      "Female",
                      style: TextStyle(
                        color: _gender == "Female" ? Colors.white : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),


                    // child: FadeTransition(
                    //   opacity: _fadeAnimation,
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Text(
                    //         "Gender",
                    //         style: TextStyle(
                    //           color: Colors.grey[400],
                    //           fontSize: 14,
                    //         ),
                    //       ),
                    //       SizedBox(height: 8),
                    //       Row(
                    //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    //         children: [
                    //           // ChoiceChip3D(
                    //           //   width: size.width * 0.4,
                    //           //   height: 60,
                    //           //   style: ChoiceChip3DStyle(
                    //           //     topColor: _gender == "Male"
                    //           //         ? Colors.blueGrey
                    //           //         : Colors.grey[800]!,
                    //           //     backColor: Colors.grey[900]!,
                    //           //     borderRadius: BorderRadius.circular(12),
                    //           //   ),
                    //           //   onSelected: () {
                    //           //     setState(() {
                    //           //       _gender = "Male";
                    //           //     });
                    //           //   },
                    //           //   onUnSelected: () {},
                    //           //   selected: _gender == "Male",
                    //           //   child: Row(
                    //           //     mainAxisAlignment: MainAxisAlignment.center,
                    //           //     children: [
                    //           //       Icon(
                    //           //         Icons.male,
                    //           //         color: _gender == "Male"
                    //           //             ? Colors.white
                    //           //             : Colors.grey[400],
                    //           //       ),
                    //           //       SizedBox(width: 8),
                    //           //       Text(
                    //           //         "Male",
                    //           //         style: TextStyle(
                    //           //           color: _gender == "Male"
                    //           //               ? Colors.white
                    //           //               : Colors.grey[400],
                    //           //           fontWeight: FontWeight.bold,
                    //           //         ),
                    //           //       ),
                    //           //     ],
                    //           //   ),
                    //           // ),
                    //           // // ChoiceChip3D(
                    //           //   width: size.width * 0.4,
                    //           //   height: 60,
                    //           //   style: ChoiceChip3DStyle(
                    //           //     topColor: _gender == "Female"
                    //           //         ? Colors.pink[300]!
                    //           //         : Colors.grey[800]!,
                    //           //     backColor: Colors.grey[900]!,
                    //           //     borderRadius: BorderRadius.circular(12),
                    //           //   ),
                    //           //   onSelected: () {
                    //           //     setState(() {
                    //           //       _gender = "Female";
                    //           //     });
                    //           //   },
                    //           //   onUnSelected: () {},
                    //           //   selected: _gender == "Female",
                    //           //   child: Row(
                    //           //     mainAxisAlignment: MainAxisAlignment.center,
                    //           //     children: [
                    //           //       Icon(
                    //           //         Icons.female,
                    //           //         color: _gender == "Female"
                    //           //             ? Colors.white
                    //           //             : Colors.grey[400],
                    //           //       ),
                    //           //       SizedBox(width: 8),
                    //           //       Text(
                    //           //         "Female",
                    //           //         style: TextStyle(
                    //           //           color: _gender == "Female"
                    //           //               ? Colors.white
                    //           //               : Colors.grey[400],
                    //           //           fontWeight: FontWeight.bold,
                    //           //         ),
                    //           //       ),
                    //           //     ],
                    //           //   ),
                    //           // ),
                            
                    //         ],
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  
                  ),

                  SizedBox(height: 20),

                  // Birth Date and Age
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Birth Date",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[700]!,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    _selectedDate == null
                                        ? "Select your birth date"
                                        : DateFormat('MMMM d, y')
                                            .format(_selectedDate!),
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? Colors.grey[500]
                                          : Colors.white,
                                    ),
                                  ),
                                  Spacer(),
                                  if (_selectedDate != null)
                                    Text(
                                      "${DateTime.now().year - _selectedDate!.year} years",
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_selectedDate != null &&
                              (DateTime.now().year - _selectedDate!.year) < 16)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                "You must be at least 16 years old",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Sign Up Button
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: Colors.blueGrey.withOpacity(0.5),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  "SIGN UP",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Already have an account
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: "Sign In",
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
