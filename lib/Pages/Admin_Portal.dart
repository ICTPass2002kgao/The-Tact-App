import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Pages/Add_Tactso_Branch.dart';
import 'package:ttact/Pages/AddMusic.dart';
import 'package:ttact/Pages/Admin_Add_Overseer.dart';
import 'package:ttact/Pages/Admin_Home_Page.dart';
import 'package:ttact/Pages/Admin_Add_Product.dart';
import 'package:ttact/Pages/Portal_Add_Feed.dart';
import 'package:flutter/foundation.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 800.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

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
    Api().showLoading(context);
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pop(context); // Dismiss loading
      Navigator.pushNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    return isDesktop
        ? _buildDesktopLayout(context, color)
        : _buildMobileLayout(context, color);
  }

  // --- MOBILE / SMALL SCREEN LAYOUT (Uses BottomNavigationBar) ---
  Widget _buildMobileLayout(BuildContext context, ThemeData color) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Portal"),
        elevation: 0,
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
      ),
      backgroundColor: color.scaffoldBackgroundColor,

      body: _currentPage, // Displays the selected page

      bottomNavigationBar: BottomNavigationBar(
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

      // Drawer remains for logout/extra menu on mobile
      drawer: _buildDrawer(context, color),
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
          // FIX: Add Logout Icon for Desktop AppBar
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

  // --- Shared Drawer Content ---
  Widget _buildDrawer(BuildContext context, ThemeData color) {
    return Drawer(
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
              // Use the defined list for menu items
              ..._adminNavItems
                  .map(
                    (item) => ListTile(
                      onTap: () {
                        setState(() {
                          _currentIndex = _adminNavItems.indexOf(item);
                        });
                        Navigator.pop(context);
                      },
                      textColor: color.scaffoldBackgroundColor,
                      title: Text(item['label']),
                      leading: Icon(
                        item['icon'],
                        color: color.scaffoldBackgroundColor,
                      ),
                    ),
                  )
                  .toList(),
            ],
          ),

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
}
