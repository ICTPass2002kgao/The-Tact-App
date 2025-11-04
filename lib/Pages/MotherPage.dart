// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Pages/MyProfile.dart';
import 'package:ttact/Pages/Rate.dart';
import 'package:ttact/Pages/ShoppingPage.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/orders.dart';
import 'Events.dart';
import 'HistoryPage.dart';
import 'HomePage.dart';

// Import foundation for kIsWeb and defaultTargetPlatform checks
import 'package:flutter/foundation.dart';

// --- PLATFORM UTILITIES ---
// Define breakpoints and checks for responsiveness
const double _desktopBreakpoint = 1000.0;

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class MotherPage extends StatefulWidget {
  final Function(bool) onToggleTheme;
  const MotherPage({super.key, required this.onToggleTheme});

  @override
  State<MotherPage> createState() => _MotherPageState();
}

class _MotherPageState extends State<MotherPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isSeller = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  final userId = FirebaseAuth.instance.currentUser?.uid;

  Map<String, dynamic> _userData = {};
  void fetchUserData() async {
    final snapshots = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = snapshots.data();

    if (data != null) {
      setState(() {
        _userData = data;
        _isSeller = _userData['role'] == 'Seller';

        // Ensure index is valid after setting role
        if (_isSeller) {
          // Seller has 5 pages (index 0-4)
          if (_currentIndex > 4) {
            _currentIndex = 4; // Default to My Shop if index is out of bounds
          }
          // Optional: Set default to My Shop page for sellers
          // else if (_currentIndex == 0) {
          //     _currentIndex = 4;
          // }
        } else {
          // Standard user has 4 pages (index 0-3)
          if (_currentIndex > 3) {
            _currentIndex = 0; // Default to Home if index is out of bounds
          }
        }
      });
    }
  }

  void _showHelpDialog() {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // Use a constrained dialog width for desktop/web
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: AlertDialog(
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
                      await FirebaseFirestore.instance.collection('UserHelp').add(
                        {
                          'userId': userId,
                          'userEmail':
                              FirebaseAuth.instance.currentUser?.email ?? 'N/A',
                          'subject': subjectController.text,
                          'description': descriptionController.text,
                          'timestamp': FieldValue.serverTimestamp(),
                          'status':
                              'open', // e.g., 'open', 'in_progress', 'resolved'
                        },
                      );
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
            ),
          ),
        );
      },
    );
  }

  // Helper function to build the common navigation items
  List<SalomonBottomBarItem> _buildBottomBarItems(ThemeData theme) {
    return [
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
      if (_isSeller)
        SalomonBottomBarItem(
          icon: Icon(Ionicons.person_outline),
          title: Text('My Shop'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context); // Check screen size

    // Page list is defined here, based on role
    List<Widget> pages = [
      HomePage(),
      EventsPage(),
      ShoppingPage(),
      HistoryPage(),
      if (_isSeller) SellerProductPage(),
    ];

    if (isDesktop) {
      return Scaffold(
        // Desktop/Web Layout: NavigationRail (Sidebar)
        body: Row(
          children: [
            _buildNavigationRail(color),

            // Vertical Divider for separation
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: color.dividerColor.withOpacity(0.5),
            ),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Use AppBar for title/actions on desktop as well
                  _buildAppBar(color),

                  // Main page content
                  Expanded(child: pages[_currentIndex]),

                  // Optional: Ad Banner at the bottom of the content
                  AdManager().bannerAdWidget(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        // Mobile Layout: AppBar, Drawer, BottomBar
        appBar: _buildAppBar(color),
        drawer: _buildDrawer(color),
        body: pages[_currentIndex],
        bottomNavigationBar: _buildSalomonBottomBar(color),
      );
    }
  }

  // --- WIDGET BUILDERS ---

  AppBar _buildAppBar(ThemeData color) {
    return AppBar(
      centerTitle: true,
      automaticallyImplyLeading:
          kIsWeb && MediaQuery.of(context).size.width <350 ? false : true,
      backgroundColor: color.primaryColor,
      foregroundColor: color.scaffoldBackgroundColor,
      title: Text('W E L C O M E'),
      actions: [
        if (!_isSeller && userId != null)
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OrdersPage()),
              );
            },
            icon: Icon(Icons.delivery_dining_outlined),
          ),

        // Only show theme toggle button on AppBar for desktop view
        if (isLargeScreen(context))
          Switch(
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: (value) => widget.onToggleTheme(value),
            activeColor: color.colorScheme.secondary,
          ),
      ],
    );
  }

  Widget _buildDrawer(ThemeData color) {
    return Drawer(
      // Constrain drawer width for tablets/smaller desktops
      width: MediaQuery.of(context).size.width > 350 ? 350 : null,
      backgroundColor: color.primaryColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Section: Logo and Navigation Items
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 30),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/dankie_logo.PNG',
                      width: double.infinity,
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Divider(color: color.scaffoldBackgroundColor),

                  // Navigation Items
                  _buildDrawerListTile(
                    color,
                    'Profile',
                    Ionicons.person_outline,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProfile()),
                    ),
                  ),
                  Divider(color: color.scaffoldBackgroundColor),

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
                    value: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (value) => widget.onToggleTheme(value),
                    activeColor: color.colorScheme.secondary,
                    inactiveThumbColor: color.hintColor,
                    inactiveTrackColor: color.hintColor.withOpacity(0.5),
                  ),
                  Divider(color: color.scaffoldBackgroundColor),

                  _buildDrawerListTile(
                    color,
                    'About',
                    Icons.info_outline,
                    () {},
                  ),
                  Divider(color: color.scaffoldBackgroundColor),

                  _buildDrawerListTile(
                    color,
                    'Rate the App',
                    Icons.star_rate_outlined,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RateUsDialog()),
                    ),
                  ),
                  Divider(color: color.scaffoldBackgroundColor),

                  _buildDrawerListTile(
                    color,
                    'Help / Report Issue',
                    Icons.help_outline,
                    _showHelpDialog,
                  ),
                  Divider(color: color.scaffoldBackgroundColor),
                ],
              ),
            ),
          ),

          // Bottom Section: Ad Banner and Login/Logout
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdManager().bannerAdWidget(),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: ListTile(
                  onTap: () {
                    final isGuest =
                        FirebaseAuth.instance.currentUser?.uid == null;
                    if (isGuest) {
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
                  iconColor: color.scaffoldBackgroundColor,
                  title: Text(userId == null ? 'Login' : 'Logout'),
                  leading: Icon(Icons.logout),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerListTile(
    ThemeData color,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      textColor: color.scaffoldBackgroundColor,
      iconColor: color.scaffoldBackgroundColor,
      title: Text(title),
      leading: Icon(icon),
    );
  }

  Widget _buildSalomonBottomBar(ThemeData color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdManager().bannerAdWidget(),

        SalomonBottomBar(
          backgroundColor: color.primaryColor,
          selectedItemColor: color.scaffoldBackgroundColor,
          unselectedItemColor: color.hintColor,
          currentIndex: _currentIndex,
          onTap: (value) {
            setState(() {
              _currentIndex = value;
            });
          },
          items: _buildBottomBarItems(color),
        ),
      ],
    );
  }

  Widget _buildNavigationRail(ThemeData color) {
    // Determine which icons to display based on the user role
    final destinations = _buildBottomBarItems(color)
        .map(
          (item) =>
              NavigationRailDestination(icon: item.icon, label: item.title),
        )
        .toList();

    return Container(
      // Ensure the navigation area has a distinct background (e.g., primary color)
      color: color.primaryColor,
      child: Column(
        children: [
          // Logo or Header for the top of the sidebar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/dankie_logo.PNG',
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Main Navigation Rail
          Expanded(
            child: NavigationRail(
              backgroundColor: color.primaryColor,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: IconThemeData(
                color: color.scaffoldBackgroundColor,
              ),
              unselectedIconTheme: IconThemeData(color: color.hintColor),
              selectedLabelTextStyle: TextStyle(
                color: color.scaffoldBackgroundColor,
              ),
              unselectedLabelTextStyle: TextStyle(color: color.hintColor),
              destinations: destinations,
            ),
          ),

          // Utility/User Actions at the bottom of the sidebar
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    Ionicons.person_outline,
                    color: color.scaffoldBackgroundColor,
                  ),
                  tooltip: 'Profile',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyProfile()),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.help_outline,
                    color: color.scaffoldBackgroundColor,
                  ),
                  tooltip: 'Help / Report Issue',
                  onPressed: _showHelpDialog,
                ),
                IconButton(
                  icon: Icon(
                    Icons.logout,
                    color: color.scaffoldBackgroundColor,
                  ),
                  tooltip: userId == null ? 'Login' : 'Logout',
                  onPressed: () {
                    final isGuest =
                        FirebaseAuth.instance.currentUser?.uid == null;
                    if (isGuest) {
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
