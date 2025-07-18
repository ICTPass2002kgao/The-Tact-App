import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

class AdminAddOverseer extends StatefulWidget {
  const AdminAddOverseer({super.key});

  @override
  State<AdminAddOverseer> createState() => _AdminAddOverseerState();
}

class _AdminAddOverseerState extends State<AdminAddOverseer> {
  final TextEditingController overseerNameController = TextEditingController();
  final TextEditingController overseerEmailController = TextEditingController();
  final TextEditingController overseerSurnameController =
      TextEditingController();
  final TextEditingController overseerPasswordController =
      TextEditingController();
  //addressController, phoneController, passwordController;
  final TextEditingController overseerAddressController =
      TextEditingController();
  List<String> provinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];
  String? selectedProvince;
  bool isPasswordVisible = false;
  Future<void> addOverseer() async {
    Api().showLoading(context);
    FirebaseAuth auth = await FirebaseAuth.instance;
    if (overseerNameController.text.isEmpty ||
        overseerSurnameController.text.isEmpty ||
        overseerEmailController.text.isEmpty ||
        overseerPasswordController.text.isEmpty ||
        selectedProvince == null) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Please fill in all fields',
        'Error',
        Theme.of(context).primaryColorDark,
      );
      return;
    } 
    await auth
        .createUserWithEmailAndPassword(
          email: overseerEmailController.text,
          password: overseerPasswordController.text,
        )
        .then((userCredential) {
          // User created successfully, you can now add the overseer to Firestore

          FirebaseFirestore firestore = FirebaseFirestore.instance;
          firestore.collection('overseers').add({
            'name': overseerNameController.text,
            'surname': overseerSurnameController.text,
            'email': overseerEmailController.text,
            'province': selectedProvince,
            'uid': userCredential.user?.uid,
            'role': 'overseer',
          });
          Navigator.pop(context);
          Api().showMessage(
            context,
            'Overseer added successfully',
            'Success',
            Theme.of(context).splashColor,
          );
          overseerNameController.clear();
          overseerSurnameController.clear();
          overseerEmailController.clear();
          overseerPasswordController.clear();
          selectedProvince = null;
          setState(() {
            isPasswordVisible = false;
          });
        })
        .catchError((error) {
          Navigator.pop(context);
          Api().showMessage(
            context,
            'Failed to create overseer: $error',
            'Error',
            Theme.of(context).primaryColorDark,
          );
          return;
        });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Admin Add Overseer Page',
              style: TextStyle(
                fontSize: 24,
                color: Theme.of(context).primaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            controller: overseerNameController,
            placeholder: 'Enter Overseer Name',
            padding: EdgeInsets.all(16.0),
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            controller: overseerSurnameController,
            placeholder: 'Enter Overseer Surname',
            padding: EdgeInsets.all(16.0),
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            controller: overseerEmailController,
            placeholder: 'Enter Overseer Email',
            padding: EdgeInsets.all(16.0),
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          CupertinoTextField(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18.0),
              border: Border.all(color: color.primaryColor),
            ),
            suffix: IconButton(
              onPressed: () {
                setState(() {
                  isPasswordVisible = !isPasswordVisible;
                });
              },
              icon: Icon(
                isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
            ),
            controller: overseerPasswordController,
            placeholder: 'Enter Overseer Password',
            padding: EdgeInsets.all(16.0),
            obscureText: isPasswordVisible,
            style: TextStyle(fontSize: 18),
          ),
          SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(8.0),
              focusColor: color.scaffoldBackgroundColor,
              decoration: InputDecoration(
                labelText: 'Select Overseer Province',
                border: OutlineInputBorder(),
              ),
              items: provinces.map((String province) {
                return DropdownMenuItem<String>(
                  value: province,
                  child: Text(province),
                );
              }).toList(),
              onChanged: (String? newValue) {
                // Handle province selection
                setState(() {
                  selectedProvince = newValue;
                });
              },
            ),
          ),
          SizedBox(height: 20),
          CustomOutlinedButton(
            onPressed: addOverseer,
            text: 'Add Overseer',
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: color.scaffoldBackgroundColor,
            width: double.infinity,
          ),
        ],
      ),
    );
  }
}
