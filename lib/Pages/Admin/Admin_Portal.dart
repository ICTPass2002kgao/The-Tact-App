// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; // REQUIRED: Add fl_chart to pubspec.yaml
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:ttact/Pages/Admin/Add_Career_Opportunities.dart';
import 'package:ttact/Pages/Admin/Add_Committee_Member.dart';

// --- IMPORT YOUR EXISTING PAGES HERE ---
import 'package:ttact/Pages/Admin/Add_Tactso_Branch.dart';
import 'package:ttact/Pages/Admin/AddMusic.dart';
import 'package:ttact/Pages/Admin/Admin_Add_Overseer.dart';
import 'package:ttact/Pages/Admin/Admin_Add_Product.dart';
import 'package:ttact/Pages/Admin/Admin_Dashboard.dart';
import 'package:ttact/Pages/Admin/Admin_Verify_Seller.dart';
import 'package:ttact/Pages/Admin/AuditPage.dart';
import 'package:ttact/Pages/Admin/Overseer_BalanceSheet_Global.dart';
import 'package:ttact/Pages/Admin/Staff_Members.dart';
import 'package:ttact/Pages/Portal_Add_Feed.dart';

// --- STYLING CONSTANTS ---
const Color kPrimaryColor = Color(0xFF1E1E2C); // Dark Navy for Sidebar
const Color kSecondaryColor = Color(0xFF2D2D44); // Lighter Navy
const Color kAccentColor = Color(0xFF5E72E4); // Bright Blue
const Color kBackgroundColor = Color(0xFFF4F6F9); // Light Grey Background
const double _desktopBreakpoint = 900.0;

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class AdminPortal extends StatefulWidget {
  final String? faceUrl;
  final String? fullName;
  final String? portfolio;
  final String? province; 
  
  const AdminPortal({super.key, this.faceUrl, this.fullName, this.portfolio, this.province});

  @override
  _AdminPortalState createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  int _currentIndex = 0;
  bool _isAuthorized = false;

  // Define navigation items
  late final List<Map<String, dynamic>> _adminNavItems = [
    {
      'label': 'Dashboard',
      'icon': Ionicons.grid_outline,
      'page': ProfessionalDashboard(),
    },
    {
      'label': 'Products',
      'icon': Icons.shopping_bag_outlined,
      'page': AdminAddProduct(),
    },
    {
      'label': 'Songs',
      'icon': Ionicons.musical_notes_outline,
      'page': AddMusic(),
    },
    {
      'label': 'Branches',
      'icon': Icons.business_outlined,
      'page': AddTactsoBranch(),
    },
    {
      'label': 'Overseers',
      'icon': Icons.people_outline,
      'page': AdminAddOverseer(),
    },
    {
      'label': 'Global Balance Sheets',
      'icon': Icons.history,
      'page': OverseerBalancesheetGlobal(),
    },
    {
      'label': 'Sellers',
      'icon': Icons.storefront_outlined,
      'page': AdminVerifySeller(),
    },
    {
      'label': 'Career And Opportunities',
      'icon': Icons.work_outline,
      'page': AddCareerOpportunities(),
    },
    {
      'label': 'Tactso Committees',
      'icon': Icons.person_add_alt,
      'page': AddCommitteeMember(),
    },
    {
      'label': 'Staff Members',
      'icon': Icons.person_3_outlined,
      'page': StaffMembers(

        faceUrl: faceUrl,
        name: fullName,
        portfolio: portfolio,
        province: province,
      ),
    },
    {
      'label': 'Audit Logs',
      'icon': Icons.receipt_long_outlined,
      'page': TactsoBranchAudit(),
    },
    {'label': 'Feeds', 'icon': Icons.rss_feed, 'page': PortalAddFeed()},
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _checkAuthorization);
  }

  String faceUrl = '';
  String fullName = '';
  String portfolio = '';
  String province = '';
  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('staff_members')
          .where('faceUrl', isEqualTo: widget.faceUrl)
          .get();
      final String role = userDoc.docs.first.data()['role'] ?? '';

      setState(() {
        faceUrl = userDoc.docs.first.data()['faceUrl'] ?? '';
        fullName = userDoc.docs.first.data()['fullName'] ?? '';
        portfolio = userDoc.docs.first.data()['portfolio'] ?? '';
        province = userDoc.docs.first.data()['province'] ?? '';
      });
      if (role == 'Admin') {
        setState(() => _isAuthorized = true);
      } else {
        if (mounted) Navigator.of(context).pushReplacementNamed('/main-menu');
      }
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  Future<void> _handleLogout() async {
    Api().showLoading(context);
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pop(context);
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        body: Api().isIOSPlatform
            ? CupertinoActivityIndicator()
            : Center(child: CircularProgressIndicator()),
      );
    }

    final isDesktop = isLargeScreen(context);

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: isDesktop
          ? null
          : AppBar(
              title: Text(_adminNavItems[_currentIndex]['label']),
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
      drawer: isDesktop ? null : _buildDrawer(),
      body: isDesktop
          ? _buildDesktopLayout()
          : _adminNavItems[_currentIndex]['page'],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // 1. Sidebar
        NavigationRail(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          extended: MediaQuery.of(context).size.width >= 1100,
          backgroundColor: const Color.fromARGB(255, 22, 22, 122),
          selectedIconTheme: IconThemeData(color: kAccentColor, size: 28),
          unselectedIconTheme: IconThemeData(color: Colors.white70, size: 24),
          selectedLabelTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelTextStyle: TextStyle(color: Colors.white70),
          leading: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  backgroundImage: faceUrl != null
                      ? NetworkImage(faceUrl)
                      : null,
                  child: faceUrl == null
                      ? Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
              ),
              SizedBox(height: 10),
              Text(
                fullName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 5),
              Text(
                '$portfolio | $province',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 20),
            ],
          ),
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: IconButton(
                  icon: Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: _handleLogout,
                ),
              ),
            ),
          ),
          destinations: _adminNavItems
              .map(
                (item) => NavigationRailDestination(
                  icon: Icon(item['icon']),
                  label: Text(item['label']),
                ),
              )
              .toList(),
        ),

        // 2. Content
        Expanded(
          child: Container(
            color: kBackgroundColor,
            padding: EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _adminNavItems[_currentIndex]['page'],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(0)),
      ),
      backgroundColor: kPrimaryColor,
      child: Column(
        children: [
          SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: faceUrl != null
                        ? NetworkImage(faceUrl)
                        : null,
                    child: faceUrl == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  fullName,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '$portfolio | $province',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 40),
                Divider(color: Colors.white10, height: 1),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: _adminNavItems.length,
              separatorBuilder: (ctx, i) =>
                  Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final item = _adminNavItems[index];
                final isSelected = _currentIndex == index;
                return ListTile(
                  leading: Icon(
                    item['icon'],
                    color: isSelected ? kAccentColor : Colors.white70,
                  ),
                  title: Text(
                    item['label'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  tileColor: isSelected ? kSecondaryColor : null,
                  onTap: () {
                    setState(() => _currentIndex = index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onTap: _handleLogout,
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
 