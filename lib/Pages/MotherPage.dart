// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:ttact/Pages/ShoppingPage.dart';
import 'Events.dart';
import 'HistoryPage.dart';
import 'HomePage.dart'; 

class MotherPage extends StatefulWidget {
  const MotherPage({super.key});

  @override
  State<MotherPage> createState() => _MotherPageState();
}

class _MotherPageState extends State<MotherPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  List pages = [HomePage(), EventsPage(), ShoppingPage(), HistoryPage()];
 
  @override
  void initState() {
    super.initState(); 
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: Text('W E L C O M E'),
      ),
      drawer: Drawer(
        backgroundColor: color.primaryColor,
        child: Column(
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
            Divider(),
            ListTile(
              onTap: () {},
              textColor: color.scaffoldBackgroundColor,
              tileColor: Colors.transparent,
              iconColor: color.scaffoldBackgroundColor,
              title: Text('About'),
              leading: Icon(Icons.live_help_outlined),
            ),
            Divider(),
            ListTile(
              onTap: () {},
              textColor: color.scaffoldBackgroundColor,
              tileColor: Colors.transparent,
              iconColor: color.scaffoldBackgroundColor,
              title: Text('Services'),
              leading: Icon(Icons.settings_suggest_outlined),
            ),
            Divider(),
            ListTile(
              onTap: () {},
              textColor: color.scaffoldBackgroundColor,
              tileColor: Colors.transparent,
              iconColor: color.scaffoldBackgroundColor,
              title: Text('Help'),
              leading: Icon(Icons.live_help_outlined),
            ),
            Divider(),
            ListTile(
              onTap: () {},
              textColor: color.scaffoldBackgroundColor,
              tileColor: Colors.transparent,
              iconColor: color.scaffoldBackgroundColor,
              title: Text('Logout'),
              leading: Icon(Icons.logout),
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
          SalomonBottomBarItem(icon: Icon(Ionicons.home), title: Text('Home')),
          SalomonBottomBarItem(
            icon: Icon(Ionicons.calendar_outline),
            title: Text('Events'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.shopping_basket),
            title: Text('Shopping'),
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.history),
            title: Text('History'),
          ),
        ],
      ),
      body: pages[_currentIndex],
    );
  }
}
