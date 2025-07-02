import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../Components/API.dart';
import '../Components/Custom_Buttons.dart';
import '../Components/TextField.dart';
import 'package:text_field_validation/text_field_validation.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  TextEditingController txtEmail = TextEditingController();
  TextEditingController txtName = TextEditingController();
  TextEditingController txtSurname = TextEditingController();
  TextEditingController txtAddress = TextEditingController();
  TextEditingController txtContactNumber = TextEditingController();

  TextEditingController txtPassword = TextEditingController();
  TextEditingController txtConfirmPassword = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _obscureText2 = true;
  bool isChecked = false;
  Api backendService = Api();
  List roles = ['Member', 'Seller'];
  String role = '';

  //create functionality to retrieve the user's current address using relevant packages

  @override
  void initState() {
    // TODO: implement initState
    _getAddress();
    super.initState();
  }

  Future<void> _getAddress() async {
    try {
      // Check and request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          throw Exception('Location permission not granted');
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first;
        String fullAddress =
            "${p.name}, ${p.street}, ${p.locality}, ${p.administrativeArea}, ${p.country}";
        txtAddress.text = fullAddress;
      } else {
        txtAddress.text = "Address not found";
      }
    } catch (e) {
      txtAddress.text = "Error: ${e.toString()}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        {};
    String email = args['email'] ?? '';
    final colorScheme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sign up",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  "Create an account to get started",
                  style: TextStyle(color: colorScheme.hintColor, fontSize: 16),
                ),

                Form(
                  autovalidateMode: AutovalidateMode.onUnfocus,
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthTextField(
                        placeholder: 'Name',
                        controller: txtName,
                        onValidate: (value) => TextFieldValidation.name(value!),
                      ),

                      AuthTextField(
                        placeholder: 'Surname',
                        controller: txtSurname,
                        onValidate: (value) => TextFieldValidation.name(value!),
                      ),
                      TextField(
                        controller: txtAddress,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.hintColor,
                            ),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: colorScheme.hintColor,
                            ),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          fillColor: colorScheme.scaffoldBackgroundColor,
                          filled: true, 
                          hintText: 'Address',
                          hintStyle: TextStyle(color: colorScheme.hintColor),
                        ), 
                      ), 
                      //User should be able to select a role using an expansion tile
                      SizedBox(height: 10),
                      ExpansionTile(
                        title: Text(
                          role.isEmpty ? 'Select Role' : role,
                          style: TextStyle(color: colorScheme.primaryColor),
                        ),
                        children: [
                          ...roles
                              .map(
                                (userRole) => RadioListTile<String>(
                                  value: userRole,
                                  groupValue: role,
                                  onChanged: (val) {
                                    setState(() {
                                      role = val as String;
                                    });
                                  },
                                  title: Text(userRole),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                      AuthTextField(
                        placeholder: 'Contact Number',
                        controller: txtContactNumber,
                        onValidate: (value) =>
                            TextFieldValidation.number(value!),
                      ),
                      if (email.isEmpty)
                        AuthTextField(
                          placeholder: 'Email Address',
                          controller: txtEmail,
                          onValidate: (value) =>
                              TextFieldValidation.email(value!),
                        ),
                      if (email.isEmpty)
                        TextField(
                          controller: txtPassword,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.hintColor,
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.hintColor,
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            fillColor: colorScheme.scaffoldBackgroundColor,
                            filled: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: colorScheme.hintColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                            hintText: 'Password',
                            hintStyle: TextStyle(color: colorScheme.hintColor),
                          ),
                          obscureText: _obscureText,
                        ),
                      SizedBox(height: 8),

                      if (email.isEmpty)
                        TextField(
                          controller: txtConfirmPassword,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.hintColor,
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: colorScheme.hintColor,
                              ),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            fillColor: colorScheme.scaffoldBackgroundColor,
                            filled: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText2
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: colorScheme.hintColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureText2 = !_obscureText2;
                                });
                              },
                            ),
                            hintStyle: TextStyle(color: colorScheme.hintColor),
                            hintText: 'Confirm Password',
                          ),
                          obscureText: _obscureText2,
                        ),

                      SizedBox(height: 15),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            checkColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            activeColor: Theme.of(context).primaryColor,
                            value: isChecked,
                            onChanged: (val) =>
                                setState(() => isChecked = val!),
                          ),
                          SizedBox(width: 8.0),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: "I've read and agree with the ",
                                  ),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {},
                                      child: Text(
                                        "Terms and Conditions",
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  TextSpan(text: " and the "),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: () {},
                                      child: Text(
                                        "Privacy Policy.",
                                        style: TextStyle(
                                          color: Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Custom_Button(
                        minWidth: double.infinity,
                        text: email.isEmpty ? "Create account" : "Continue",
                        backgroundColor: isChecked
                            ? colorScheme.primaryColor
                            : colorScheme.hintColor,
                        foregroundColor: !isChecked
                            ? colorScheme.scaffoldBackgroundColor
                            : colorScheme.scaffoldBackgroundColor,
                        onPressed: () async {
                          if (isChecked) {
                            if (_formKey.currentState!.validate()) {
                              if (txtPassword.text == txtConfirmPassword.text) {
                                if (email.isNotEmpty) {
                                  try {
                                    backendService.showLoading(context);

                                    final FirebaseFirestore _firestore =
                                        FirebaseFirestore.instance;
                                    FirebaseAuth user =
                                        await FirebaseAuth.instance;

                                    if (user != null) {
                                      await _firestore
                                          .collection('users')
                                          .doc(user.currentUser!.uid)
                                          .set({
                                            "name": txtName.text,
                                            "email": email,
                                            "profileUrl": "",
                                            "Address": txtAddress.text,
                                            "Contact Number":
                                                txtContactNumber.text,
                                            "role": role,
                                          });
                                    }
                                    Navigator.pop(context);
                                    Navigator.pushNamed(context, '/main-menu');
                                  } catch (e) {
                                    backendService.showMessage(
                                      context,
                                      e.toString(),
                                    );
                                  }
                                  return null;
                                } else {
                                  backendService.signUp(
                                    txtName.text,
                                    txtEmail.text,
                                    txtPassword.text,
                                    txtAddress.text,
                                    txtContactNumber.text,
                                    role,

                                    context,
                                  );
                                }
                              } else {
                                backendService.showMessage(
                                  context,
                                  "Passwords do not match!",
                                );
                              }
                            }
                          }
                        },
                      ),

                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Have an account? ",
                            style: TextStyle(color: colorScheme.hintColor),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Login",
                              style: TextStyle(
                                color: colorScheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
