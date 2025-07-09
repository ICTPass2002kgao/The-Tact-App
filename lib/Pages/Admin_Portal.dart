import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Add_Tactso_Branch.dart';
import 'package:ttact/Pages/Admin_Add_Officers.dart';
import 'package:ttact/Pages/Admin_Home_Page.dart';
import 'package:ttact/Pages/Admin_portal_home.dart';
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
    PortalAddFeed(),
  ];
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text("Admin Portal"), elevation: 0),
      backgroundColor: color.scaffoldBackgroundColor.withOpacity(1),
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
          SalomonBottomBarItem(icon: Icon(Ionicons.home), title: Text('Home')),

          SalomonBottomBarItem(
            icon: Icon(Icons.add_shopping_cart_outlined),
            title: Text('Add Products'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Ionicons.musical_notes_outline),
            title: Text('Add Tact Songs'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.location_city_outlined),
            title: Text('Add Tactso Branch'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.add_card_outlined),
            title: Text('Add feeds'),
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
