// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:ttact/Pages/MyProfile.dart';
import 'package:ttact/Pages/Rate.dart';
// These imports will need to be correctly resolved based on your project structure
import 'package:ttact/Pages/ShoppingPage.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/orders.dart'; // Ensure correct import for OrdersPage
import 'Events.dart';
import 'HistoryPage.dart';
import 'HomePage.dart'; // Ensure this is imported correctly

class MotherPage extends StatefulWidget {
  // NEW: Add onToggleTheme callback
  final Function(bool) onToggleTheme;
  const MotherPage({super.key, required this.onToggleTheme});

  @override
  State<MotherPage> createState() => _MotherPageState();
}

class _MotherPageState extends State<MotherPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  // Removed _isDarkMode state from here as it's now managed in MyApp

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  final userId = FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic> _userData = {};
  void fetchUserData() async {
    final shapshots = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = shapshots.data();

    if (data != null) {
      setState(() {
        _userData = data;
        if (_userData['role'] == 'Seller') {
          // If the user is a seller, set initial index to My Shop (now at index 4)
          _currentIndex = 4;
        } else {
          _currentIndex = 0;
        }
      });
    }
  }

  // Function to show the help/issue dialog
  void _showHelpDialog() {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report an Issue / Get Help'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject',
                    hintText: 'e.g., App Crash, Order Problem',
                  ),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Describe your issue',
                    hintText: 'Provide as much detail as possible...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (subjectController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('UserHelp').add({
                    'userId': userId,
                    'userEmail':
                        FirebaseAuth.instance.currentUser?.email ?? 'N/A',
                    'subject': subjectController.text,
                    'description': descriptionController.text,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'open', // e.g., 'open', 'in_progress', 'resolved'
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Your issue has been submitted. We will get back to you!',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please fill in both subject and description.',
                      ),
                    ),
                  );
                }
              },
              child: Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    List pages = [
      HomePage(),
      EventsPage(),
      ShoppingPage(),
      HistoryPage(),
      if (_userData['role'] == 'Seller') SellerProductPage(),
    ];

    final color = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: Text('W E L C O M E'),
        actions: [
          if (_userData['role'] != 'Seller' && userId != null)
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrdersPage()),
                );
              },
              icon: Icon(Icons.delivery_dining_outlined),
            ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: color.primaryColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                SizedBox(height: 30),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/tact_logo.PNG',
                    height: 150,
                    width: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                Divider(color: color.scaffoldBackgroundColor),

                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProfile()),
                    );
                  },
                  textColor: color.scaffoldBackgroundColor,
                  title: Text('Profile'),
                  leading: Icon(
                    Ionicons.person_outline,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
                Divider(),
                // Dark/Light Mode Switch
                SwitchListTile(
                  title: Text(
                    'Light/Dark Mode',
                    style: TextStyle(color: color.scaffoldBackgroundColor),
                  ),
                  secondary: Icon(
                    Icons.brightness_2,
                    color: color.scaffoldBackgroundColor,
                  ),
                  value:
                      Theme.of(context).brightness ==
                      Brightness.dark, // Get current theme brightness
                  onChanged: (value) {
                    widget.onToggleTheme(value); // Call the callback from MyApp
                  },
                  activeColor: color.colorScheme.secondary,
                  inactiveThumbColor: color.hintColor,
                  inactiveTrackColor: color.hintColor.withOpacity(0.5),
                ),
                Divider(color: color.scaffoldBackgroundColor),
                ListTile(
                  onTap: () {},
                  textColor: color.scaffoldBackgroundColor,
                  tileColor: Colors.transparent,
                  iconColor: color.scaffoldBackgroundColor,
                  title: Text('About'),
                  leading: Icon(Icons.info_outline),
                ),
                Divider(color: color.scaffoldBackgroundColor),
                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RateUsDialog()),
                    );
                  },
                  textColor: color.scaffoldBackgroundColor,
                  tileColor: Colors.transparent,
                  iconColor: color.scaffoldBackgroundColor,
                  title: Text('Rate the App'),
                  leading: Icon(Icons.star_rate_outlined),
                ),
                Divider(color: color.scaffoldBackgroundColor),
                ListTile(
                  onTap: _showHelpDialog,
                  textColor: color.scaffoldBackgroundColor,
                  tileColor: Colors.transparent,
                  iconColor: color.scaffoldBackgroundColor,
                  title: Text('Help / Report Issue'),
                  leading: Icon(Icons.help_outline),
                ),
                Divider(color: color.scaffoldBackgroundColor),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: ListTile(
                onTap: () {
                  if (FirebaseAuth.instance.currentUser?.uid == null) {
                    FirebaseAuth.instance.signOut();
                    Navigator.pushNamed(context, '/login');
                  } else {
                    FirebaseAuth.instance.signOut();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                },
                textColor: color.scaffoldBackgroundColor,
                tileColor: Colors.transparent,
                iconColor: color.scaffoldBackgroundColor,
                title: Text(
                  FirebaseAuth.instance.currentUser?.uid == null
                      ? 'Login'
                      : 'Logout',
                ),
                leading: Icon(Icons.logout),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SalomonBottomBar(
        backgroundColor: color.primaryColor,
        selectedItemColor: color.scaffoldBackgroundColor,
        unselectedItemColor: color.hintColor,
        currentIndex: _currentIndex,
        onTap: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
        items: [
          SalomonBottomBarItem(
            icon: Icon(Ionicons.home_outline),
            title: Text('Home'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Ionicons.calendar_outline),
            title: Text('Events'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.local_mall_outlined),
            title: Text('Shopping'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.history_outlined),
            title: Text('History'),
          ),
          if (_userData['role'] == 'Seller')
            SalomonBottomBarItem(
              icon: Icon(Ionicons.person_outline),
              title: Text('My Shop'),
            ),
        ],
      ),
      body: pages[_currentIndex],
    );
  }
}
