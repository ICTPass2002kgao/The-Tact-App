// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Add_Tactso_Branch.dart';
import 'package:ttact/Pages/AddMusic.dart';
import 'package:ttact/Pages/Admin_Add_Overseer.dart';
import 'package:ttact/Pages/Admin_Home_Page.dart';
import 'package:ttact/Pages/Admin_Add_Product.dart';
import 'package:ttact/Pages/Admin_Verify_Seller.dart';
import 'package:ttact/Pages/Portal_Add_Feed.dart';
import 'package:flutter/foundation.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 800.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

bool get isIOSPlatform { 
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
 
bool get isAndroidPlatform { 
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// Define navigation items once
final List<Map<String, dynamic>> _adminNavItems = [
  {'label': 'Home', 'icon': Ionicons.home, 'page': AdminHomePage()},
  {
    'label': 'Products',
    'icon': Icons.add_shopping_cart_outlined,
    'page': AdminAddProduct(),
  },
  {
    'label': 'Songs',
    'icon': Ionicons.musical_notes_outline,
    'page': AddMusic(),
  },
  {
    'label': 'Branches',
    'icon': Icons.location_city_outlined,
    'page': AddTactsoBranch(),
  },
  {
    'label': 'Overseers',
    'icon': Icons.person_add_alt_1_outlined,
    'page': AdminAddOverseer(),
  },
  {
    'label': 'Sellers',
    'icon': Icons.person_3_sharp,
    'page': AdminVerifySeller(),
  },
  {'label': 'Feeds', 'icon': Icons.add_card_outlined, 'page': PortalAddFeed()},
];
// --------------------------

class AdminPortal extends StatefulWidget {
  @override
  _AdminPortalState createState() => _AdminPortalState();
}

class _AdminPortalState extends State<AdminPortal> {
  int _currentIndex = 0;

  // Getter for the current page widget
  Widget get _currentPage => _adminNavItems[_currentIndex]['page'];

  // Shared Logout Functionality
  Future<void> _handleLogout() async {
    // Assuming Api().showLoading exists and handles the context correctly
    // If not, you might need to use a local loading indicator.
    Api().showLoading(context);
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pop(context); // Dismiss loading
      Navigator.pushNamed(context, '/login');
    }
  }

  // Helper to determine if we are in a 'mobile web' scenario
  bool _isMobileWeb(BuildContext context) {
    // It's web AND the screen is NOT considered large/desktop
    return kIsWeb && !isLargeScreen(context);
  }

  bool _isAuthorized = false;
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Future.delayed(Duration.zero, _checkAuthorization);
  }

  Future<void> _checkAuthorization() async {
    final user = FirebaseAuth.instance.currentUser;

    // --- 1. Authentication Check (Is the user logged in?) ---
    if (user == null) {
      if (mounted) {
        // Not logged in: Redirect to login
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // --- 2. Role Check (Does the user have the 'Admin' role?) ---
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final String role = userDoc.data()?['role'] ?? '';

      if (role == 'Admin') {
        // Access granted!
        setState(() {
          _isAuthorized = true;
        });
      } else if (role == 'Seller' || role == 'Member') {
        if (mounted) {
          // Logged in, but NOT an Admin: Redirect to their main menu
          Navigator.of(context).pushReplacementNamed('/main-menu');
        }
      }
    } catch (e) {
      // Error fetching role (e.g., Firestore issue): Log out and redirect
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //Please wait screen while checking auth/role

    if (FirebaseAuth.instance.currentUser == null) {
      return   Scaffold(body:isIOSPlatform?Center(child:CupertinoActivityIndicator() ,): Center(child: CircularProgressIndicator()));
    } else if (!_isAuthorized) {
      return  Scaffold(body:isIOSPlatform?Center(child:CupertinoActivityIndicator() ,): Center(child: CircularProgressIndicator()));
    }
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    return isDesktop
        ? _buildDesktopLayout(context, color)
        : _buildMobileLayout(context, color);
  }

  // --- MOBILE / SMALL SCREEN LAYOUT (Uses BottomNavigationBar) ---
  Widget _buildMobileLayout(BuildContext context, ThemeData color) {
    final isMobileWeb = _isMobileWeb(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Portal"),
        elevation: 0,
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
      ),
      backgroundColor: color.scaffoldBackgroundColor,

      body: _currentPage, // Displays the selected page
      // **CONDITIONAL CHANGE**: Hide BottomNavigationBar on mobile web
      bottomNavigationBar: isMobileWeb
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (value) {
                setState(() {
                  _currentIndex = value;
                });
              },
              type: BottomNavigationBarType.fixed,
              selectedItemColor: color.scaffoldBackgroundColor,
              unselectedItemColor: color.hintColor,
              backgroundColor: color.primaryColor,
              items: _adminNavItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item['icon']),
                      label: item['label'],
                    ),
                  )
                  .toList(),
            ),

      // Pass the flag to the Drawer so it knows when to show navigation items
      drawer: _buildDrawer(context, color, isMobileWeb: isMobileWeb),
    );
  }

  // --- DESKTOP / WIDE SCREEN LAYOUT (Uses NavigationRail) ---
  Widget _buildDesktopLayout(BuildContext context, ThemeData color) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Portal"),
        elevation: 0,
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        automaticallyImplyLeading: false,
        actions: [
          // Logout Icon for Desktop AppBar
          IconButton(
            icon: Icon(Icons.logout, color: color.scaffoldBackgroundColor),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          // 1. Permanent Side Navigation Rail
          NavigationRail(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: color.primaryColor,
            selectedIconTheme: IconThemeData(
              color: color.scaffoldBackgroundColor,
            ),
            unselectedIconTheme: IconThemeData(color: color.hintColor),
            selectedLabelTextStyle: TextStyle(
              color: color.scaffoldBackgroundColor,
              fontWeight: FontWeight.bold,
            ),
            unselectedLabelTextStyle: TextStyle(color: color.hintColor),

            destinations: _adminNavItems
                .map(
                  (item) => NavigationRailDestination(
                    icon: Icon(item['icon']),
                    label: Text(item['label']),
                  ),
                )
                .toList(),
          ),

          VerticalDivider(thickness: 1, width: 1),

          // 2. Main Content Area (Centered and Constrained)
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1000,
                ), // Max content width for readability
                child: _currentPage, // Displays the selected page
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Shared Drawer Content (Modified to accept isMobileWeb) ---
  Widget _buildDrawer(
    BuildContext context,
    ThemeData color, {
    required bool isMobileWeb,
  }) {
    return Drawer(
      backgroundColor: color.primaryColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DrawerHeader(
                    child: Image.asset(
                      'assets/tact_logo.PNG',
                      height: 100,
                      width: 100,
                    ),
                  ),

                  // **CONDITIONAL CHANGE**: Show navigation items in Drawer on mobile web
                  // If it's a mobile web, we rely on the drawer for navigation
                  if (isMobileWeb) ...[
                    ..._adminNavItems.asMap().entries.map((entry) {
                      final item = entry.value;
                      final index = entry.key;
                      final isSelected = _currentIndex == index;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDrawerListTile(
                            color: color,
                            title: item['label'],
                            icon: item['icon'],
                            onTap: () {
                              setState(() {
                                _currentIndex = index;
                              });
                              Navigator.pop(context); // Close drawer
                            },
                            isSelected: isSelected,
                          ),
                          Divider(
                            color: color.scaffoldBackgroundColor.withOpacity(
                              0.5,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                    Divider(color: color.scaffoldBackgroundColor),
                  ],
                  // If not mobile web, the drawer typically contains secondary items
                  // or the mobile layout uses BottomNavigationBar, so the items are optional here
                  // (Your original code was listing ALL items here, which is fine for redundancy, but I've kept
                  // the condition to only show them when the bottom bar is removed.)
                ],
              ),
            ),
          ),

          // Logout Button
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: ListTile(
              onTap: _handleLogout,
              textColor: color.scaffoldBackgroundColor,
              title: Text('Logout'),
              leading: Icon(Icons.logout, color: color.scaffoldBackgroundColor),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build list tiles with a selection state
  Widget _buildDrawerListTile({
    required ThemeData color,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final itemColor = isSelected
        ? color.colorScheme.secondary
        : color.scaffoldBackgroundColor;
    return ListTile(
      onTap: onTap,
      textColor: itemColor,
      iconColor: itemColor,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      leading: Icon(icon),
    );
  }
}
