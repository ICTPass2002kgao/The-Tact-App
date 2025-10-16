import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Add_Tactso_Branch.dart';
import 'package:ttact/Pages/AddMusic.dart';
import 'package:ttact/Pages/Admin_Add_Overseer.dart';
import 'package:ttact/Pages/Admin_Home_Page.dart';
import 'package:ttact/Pages/Admin_Add_Product.dart';
import 'package:ttact/Pages/Portal_Add_Feed.dart';

class AdminPortal extends StatefulWidget {
  @override
  _AdminPortalState createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  int _currentIndex = 0;
  List pages = [
    AdminHomePage(),
    AdminAddProduct(),
    AddMusic(),
    AddTactsoBranch(),
    AdminAddOverseer(),
    PortalAddFeed(),
  ];
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("Admin Portal"), elevation: 0),
      backgroundColor: color.scaffoldBackgroundColor,
      bottomNavigationBar: BottomNavigationBar(
        // <-- Switched to BottomNavigationBar
        currentIndex: _currentIndex,
        onTap: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
        type: BottomNavigationBarType.fixed, // Ensures all items are visible
        selectedItemColor: color.scaffoldBackgroundColor,
        unselectedItemColor: color.hintColor,
        backgroundColor: color.primaryColor,
        items: [
          BottomNavigationBarItem(icon: Icon(Ionicons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_shopping_cart_outlined),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Ionicons.musical_notes_outline),
            label: 'Songs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_city_outlined),
            label: 'Branches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_alt_1_outlined),
            label: 'Overseers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_card_outlined),
            label: 'Feeds',
          ),
        ],
      ),
      body: pages[_currentIndex],
      drawer: Drawer(
        backgroundColor: color.primaryColor,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                DrawerHeader(
                  child: Image.asset(
                    'assets/tact_logo.PNG',
                    height: 100,
                    width: 100,
                  ),
                ),
                ListTile(
                  textColor: color.scaffoldBackgroundColor,

                  title: Text('Manage Latest Updates'),
                  leading: Icon(
                    Icons.manage_accounts,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
                ListTile(
                  textColor: color.scaffoldBackgroundColor,
                  title: Text('Add Products'),
                  leading: Icon(
                    Icons.manage_accounts,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
                ListTile(
                  textColor: color.scaffoldBackgroundColor,
                  title: Text('Add Apostles'),
                  leading: Icon(
                    Icons.manage_accounts,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ListTile(
                onTap: () {
                  Api().showLoading(context);
                  FirebaseAuth.instance.signOut();
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/login');
                },
                textColor: color.scaffoldBackgroundColor,
                title: Text('Logout'),
                leading: Icon(
                  Icons.login_sharp,
                  color: color.scaffoldBackgroundColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
