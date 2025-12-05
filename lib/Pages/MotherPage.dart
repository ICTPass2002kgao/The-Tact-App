// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:ionicons/ionicons.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Pages/MyProfile.dart';
import 'package:ttact/Pages/Rate.dart';
import 'package:ttact/Pages/ShoppingPage.dart';
import 'package:ttact/Pages/Tact_Seller.dart';
import 'package:ttact/Pages/orders.dart';
import 'Events.dart';
import 'HistoryPage.dart';
import 'HomePage.dart';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;

bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class MotherPage extends StatefulWidget {
  final Function(bool) onToggleTheme;
  final int initialIndex;

  const MotherPage({
    super.key,
    required this.onToggleTheme,
    this.initialIndex = 0,
  });

  static final ValueNotifier<String?> deepLinkSongIdNotifier =
      ValueNotifier<String?>(null);

  @override
  State<MotherPage> createState() => _MotherPageState();
}

class _MotherPageState extends State<MotherPage>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  bool _isSeller = false;
  late AppLinks _appLinks;
  final userId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic> _userData = {};

  // ⭐️ HELPER: Detect Mobile Web ⭐️
  bool get _isMobileWeb => kIsWeb && !isLargeScreen(context);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    fetchUserData();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    final uri = await _appLinks.getInitialLink();
    if (uri != null) _handleDeepLink(uri);
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('/song')) {
      final songUrl = uri.queryParameters['url'];
      if (songUrl != null) {
        setState(() => _currentIndex = 0);
        Future.delayed(Duration(milliseconds: 100), () {
          MotherPage.deepLinkSongIdNotifier.value = songUrl;
        });
      }
    }
  }

  void fetchUserData() async {
    if (userId == null) {
      setState(() => _isSeller = false);
      return;
    }
    final snapshots = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final data = snapshots.data();

    if (data != null) {
      setState(() {
        _userData = data;
        _isSeller = _userData['role'] == 'Seller';
        if (_isSeller) {
          if (_currentIndex > 4) _currentIndex = 4;
        } else {
          if (_currentIndex > 3) _currentIndex = 0;
        }
      });
    } else {
      setState(() {
        _isSeller = false;
        _currentIndex = 0;
      });
    }
  }

  void _handleThemeChange(bool isDark) async {
    widget.onToggleTheme(isDark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDark);
    } catch (e) {
      print("Error saving theme preference: $e");
    }
  }

  // --- HELPER: Navigation Items List ---
  List<Map<String, dynamic>> _getNavItems() {
    List<Map<String, dynamic>> items = [
      {'icon': Ionicons.home_outline, 'label': 'Home'},
      {'icon': Ionicons.calendar_outline, 'label': 'Events'},
      {'icon': Icons.local_mall_outlined, 'label': 'Shopping'},
      {'icon': Icons.history_outlined, 'label': 'History'},
    ];

    // On Mobile/Tablet native, Profile is in Drawer, so we don't add it to bottom bar list usually.
    // But for sidebar/mobile-web-drawer navigation we need it.

    if (_isSeller) {
      items.add({'icon': Ionicons.storefront_outline, 'label': 'My Shop'});
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    List<Widget> pages = [
      HomePage(),
      EventsPage(),
      ShoppingPage(),
      HistoryPage(),
      if (_isSeller) SellerProductPage(),
    ];

    if (_currentIndex >= pages.length) _currentIndex = 0;

    if (isDesktop) {
      return _buildDesktopLayout(theme, pages[_currentIndex]);
    } else {
      return _buildMobileLayout(theme, pages[_currentIndex]);
    }
  }

  // ===========================================================================
  // 🖥️ DESKTOP LAYOUT (Sidebar + Content Area)
  // ===========================================================================
  Widget _buildDesktopLayout(ThemeData theme, Widget content) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          _buildNavigationRail(theme),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 70,
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  color: theme.scaffoldBackgroundColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getNavItems()[_currentIndex]['label'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _handleThemeChange(
                              theme.brightness == Brightness.light,
                            ),
                            icon: Icon(
                              theme.brightness == Brightness.light
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                              color: theme.hintColor,
                            ),
                          ),
                          SizedBox(width: 10),
                          if (userId != null)
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: theme.primaryColor,
                              child: Text(
                                (_userData['name'] ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(30, 0, 30, 30),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Scaffold(body: content),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    return Container(
      width: 250,
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.hintColor.withOpacity(0.2)),
                  ),
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/dankie_logo.PNG'),
                    backgroundColor: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Dankie Mobile Portal",
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: 15),
              children: _getNavItems().asMap().entries.map((entry) {
                int idx = entry.key;
                var item = entry.value;
                bool isSelected = _currentIndex == idx;

                return Container(
                  margin: EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item['icon'],
                      color: isSelected ? Colors.white : theme.hintColor,
                    ),
                    title: Text(
                      item['label'],
                      style: TextStyle(
                        color: isSelected ? Colors.white : theme.hintColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => setState(() => _currentIndex = idx),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person_outline, color: theme.hintColor),
                  title: Text(
                    "Profile",
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyProfile()),
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.help_outline, color: theme.hintColor),
                  title: Text(
                    "Support",
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: _showHelpBottomSheet,
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Colors.redAccent),
                  title: Text(
                    "Logout",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📱 MOBILE LAYOUT
  // Logic: If Mobile Web -> No BottomBar, Use Drawer.
  //        If Native App -> Use BottomBar.
  // ===========================================================================
  Widget _buildMobileLayout(ThemeData theme, Widget content) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.primaryColor, // Blue
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(_getNavItems()[_currentIndex]['label']),
        actions: [
          if (!_isSeller && userId != null)
            IconButton(
              icon: Icon(Icons.delivery_dining_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => OrdersPage()),
              ),
            ),
        ],
      ),

      drawer: _buildMobileDrawer(theme),

      body: Column(
        children: [
          Expanded(child: content),
          AdManager().bannerAdWidget(),
        ],
      ),

      // ⭐️ CONDITIONAL BOTTOM BAR ⭐️
      // If it is Mobile Web (_isMobileWeb is true), return null (hide bar).
      // Otherwise (Native App), return SalomonBottomBar.
      bottomNavigationBar: _isMobileWeb
          ? null
          : SalomonBottomBar(
              backgroundColor: theme.primaryColor,
              currentIndex: _currentIndex,
              onTap: (i) => setState(() => _currentIndex = i),
              selectedItemColor: theme.scaffoldBackgroundColor,
              unselectedItemColor: theme.scaffoldBackgroundColor,
              items: [
                SalomonBottomBarItem(
                  icon: Icon(Ionicons.home_outline),
                  title: Text("Home"),
                ),
                SalomonBottomBarItem(
                  icon: Icon(Ionicons.calendar_outline),
                  title: Text("Events"),
                ),
                SalomonBottomBarItem(
                  icon: Icon(Icons.local_mall_outlined),
                  title: Text("Shop"),
                ),
                SalomonBottomBarItem(
                  icon: Icon(Icons.history_outlined),
                  title: Text("History"),
                ),
                if (_isSeller)
                  SalomonBottomBarItem(
                    icon: Icon(Ionicons.storefront_outline),
                    title: Text("My Shop"),
                  ),
              ],
            ),
    );
  }

  Widget _buildMobileDrawer(ThemeData theme) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.primaryColor),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: AssetImage('assets/dankie_logo.PNG'),
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Dankie Mobile",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ⭐️ CONDITIONAL DRAWER ITEMS FOR MOBILE WEB ⭐️
                // If we hid the bottom bar, we MUST show those items here in the drawer
                if (_isMobileWeb) ...[
                  ..._getNavItems().asMap().entries.map((entry) {
                    int idx = entry.key;
                    var item = entry.value;
                    bool isSelected = _currentIndex == idx;
                    return ListTile(
                      leading: Icon(
                        item['icon'],
                        color: isSelected
                            ? theme.primaryColor
                            : theme.hintColor,
                      ),
                      title: Text(
                        item['label'],
                        style: TextStyle(
                          color: isSelected
                              ? theme.primaryColor
                              : theme.hintColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      tileColor: isSelected
                          ? theme.primaryColor.withOpacity(0.1)
                          : null,
                      onTap: () {
                        setState(() => _currentIndex = idx);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                  Divider(),
                ],

                ListTile(
                  leading: Icon(
                    Ionicons.person_outline,
                    color: theme.hintColor,
                  ),
                  title: Text(
                    "Profile",
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyProfile()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.brightness_6, color: theme.hintColor),
                  title: Text(
                    "Switch Theme",
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () =>
                      _handleThemeChange(theme.brightness == Brightness.light),
                ),
                ListTile(
                  leading: Icon(Icons.help_outline, color: theme.hintColor),
                  title: Text(
                    "Report Issue",
                    style: TextStyle(color: theme.hintColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showHelpBottomSheet();
                  },
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.redAccent),
            title: Text("Logout", style: TextStyle(color: Colors.redAccent)),
            onTap: () => _logout(context),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- SHARED FUNCTIONS ---

  Future<void> _logout(BuildContext context) async {
    final isGuest = FirebaseAuth.instance.currentUser?.uid == null;
    if (isGuest) {
      Navigator.pushNamed(context, '/login');
    } else {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('authToken');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _showHelpBottomSheet() {
    final subjectController = TextEditingController();
    final descriptionController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Report an Issue',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: theme.hintColor),
              ),
            ),
            SizedBox(height: 15),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(color: theme.hintColor),
              ),
            ),
            SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Api().showMessage(
                    context,
                    "Submitted",
                    "We received your report.",
                    Colors.green,
                  );
                },
                child: Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
