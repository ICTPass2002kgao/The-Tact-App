import 'package:flutter/material.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Custom_Buttons.dart';
import 'package:ttact/Components/TextField.dart';

class MemberRegistration extends StatefulWidget {
  const MemberRegistration({super.key});

  @override
  State<MemberRegistration> createState() => _MemberRegistrationState();
}

class _MemberRegistrationState extends State<MemberRegistration> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController txtAddress = TextEditingController();
  TextEditingController txtContactNumber = TextEditingController();
  TextEditingController txtEmail = TextEditingController();

  bool isChecked = false;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context);
    final backendService = Api();
    String email = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    return SingleChildScrollView(
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
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuthTextField(
                    placeholder: 'Address',
                    controller: txtAddress,
                    onValidate: (value) => TextFieldValidation.address(value!),
                  ),
                  ExpansionTile(
                    title: Text('Select an Overseer'),
                    children: [
                      ListTile(
                        title: Text('OS Hadebe'),
                        onTap: () {
                          // Handle Overseer 1 selection
                        },
                      ),
                      ListTile(
                        title: Text('Father Mfeka'),
                        onTap: () {
                          // Handle Overseer 2 selection
                        },
                      ),
                      ListTile(
                        title: Text('Father Mfeka'),
                        onTap: () {
                          // Handle Overseer 2 selection
                        },
                      ),
                    ],
                  ),
                  ExpansionTile(
                    title: Text('Student/Member'),
                    children: [
                      ListTile(
                        title: Text('Student'),
                        onTap: () {
                          // Handle Student selection
                        },
                      ),
                      ListTile(
                        title: Text('Member'),
                        onTap: () {
                          // Handle Member selection
                        },
                      ),
                    ],
                  ),
                  AuthTextField(
                    placeholder: 'Email',
                    controller: txtEmail,
                    onValidate: (value) => TextFieldValidation.email(value!),
                  ),
                  AuthTextField(
                    placeholder: 'Contact Number',
                    controller: txtContactNumber,
                    onValidate: (value) => TextFieldValidation.phone(value!),
                  ),

                  SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) {
                          setState(() {
                            isChecked = value!;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          "I agree to the terms and conditions",
                          style: TextStyle(color: colorScheme.hintColor),
                        ),
                      ),
                    ],
                  ),
                  Custom_Button(
                    onPressed: () {},
                    text: 'Register',
                    backgroundColor: colorScheme.primaryColor,
                    foregroundColor: colorScheme.hintColor,
                    minWidth: double.infinity, 
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
