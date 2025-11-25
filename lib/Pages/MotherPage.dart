// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // Import for Cupertino widgets
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

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// ------------------------

// --- COPIED HELPERS (Platform Aware Message) ---
void _showPlatformMessage(
  BuildContext context,
  String title,
  String message,
  Color backgroundColor,
) {
  Api().showMessage(context, message, title, backgroundColor);
}
// --- END COPIED HELPERS ---

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
    if (uri != null) {
      _handleDeepLink(uri);
    }
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.path.contains('/song')) {
      final songUrl = uri.queryParameters['url'];
      if (songUrl != null) {
        setState(() {
          _currentIndex = 0;
        });
        Future.delayed(Duration(milliseconds: 100), () {
          MotherPage.deepLinkSongIdNotifier.value = songUrl;
        });
      }
    }
  }

  final userId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic> _userData = {};

  void fetchUserData() async {
    if (userId == null) {
      setState(() {
        _isSeller = false;
      });
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

  // ⭐️ UPDATED: Logic for submitting the help form
  Future<void> _submitHelpForm(
    BuildContext context,
    TextEditingController subjectController,
    TextEditingController descriptionController,
  ) async {
    if (subjectController.text.isNotEmpty &&
        descriptionController.text.isNotEmpty) {
      // Close the Bottom Sheet first
      Navigator.pop(context);

      Api().sendEmail(
        'kgaogelodeveloper@gmail.com',
        '${subjectController.text}',
        """
      <p>Gooday admin</p>
      
      <p>You have received issue from a user</p>
       
      
      <hr />
      <p><strong>Message:</strong></p>
      <blockquote style="background: #f9f9f9; border-left: 5px solid #ccc; margin: 1.5em 10px; padding: 0.5em 10px;">
        ${descriptionController.text}
      </blockquote>
      <hr />
      
      <p>Please respond to the user as soon as possible.</p>
      
      <br>
      <p>Regards,<br>
      Dankie Mobile Support System</p>
      """,
        context,
      );

      await FirebaseFirestore.instance.collection('UserHelp').add({
        'userId': userId ?? 'guest',
        'userEmail': FirebaseAuth.instance.currentUser?.email ?? 'N/A',
        'subject': subjectController.text,
        'description': descriptionController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'open',
      });

      _showPlatformMessage(
        context,
        'Success',
        'Your issue has been submitted. We will get back to you!',
        Theme.of(context).splashColor,
      );
    } else {
      _showPlatformMessage(
        context,
        'Error',
        'Please fill in both subject and description.',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  // ⭐️ UPDATED: Beautiful Platform-Aware Bottom Sheet
  void _showHelpBottomSheet() {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final theme = Theme.of(context);

    // Helper to build the content so we don't duplicate code for both platforms
    Widget buildSheetContent(BuildContext context) {
      return Padding(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          // Critical: Moves sheet up when keyboard opens
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isIOSPlatform
                      ? CupertinoColors.systemGrey4
                      : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Title
            Text(
              'Report an Issue',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isIOSPlatform
                    ? CupertinoColors.label.resolveFrom(context)
                    : theme.primaryColor,
                decoration: TextDecoration.none,
              ),
            ),
            SizedBox(height: 20),

            // Subject Input
            if (isIOSPlatform)
              CupertinoTextField(
                controller: subjectController,
                placeholder: 'Subject (e.g., App Crash)',
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            else
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., App Crash',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            SizedBox(height: 15),

            // Description Input
            if (isIOSPlatform)
              CupertinoTextField(
                controller: descriptionController,
                placeholder: 'Describe your issue...',
                maxLines: 4,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            else
              TextField(
                controller: descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your issue...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignLabelWithHint: true,
                ),
              ),

            SizedBox(height: 25),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: isIOSPlatform
                  ? CupertinoButton.filled(
                      color: theme.primaryColor,
                      child: Text('Submit'),
                      onPressed: () => _submitHelpForm(
                        context,
                        subjectController,
                        descriptionController,
                      ),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: theme.scaffoldBackgroundColor,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _submitHelpForm(
                        context,
                        subjectController,
                        descriptionController,
                      ),
                      child: Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(top: false, child: buildSheetContent(context)),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => buildSheetContent(context),
      );
    }
  }

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

  bool _isMobileWeb(BuildContext context) {
    return kIsWeb && !isLargeScreen(context);
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);
    final isMobileWeb = _isMobileWeb(context);

    List<Widget> pages = [
      HomePage(),
      EventsPage(),
      ShoppingPage(),
      HistoryPage(),
      if (_isSeller) SellerProductPage(),
    ];

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildNavigationRail(color),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: color.dividerColor.withOpacity(0.5),
            ),
            Expanded(
              child: Column(
                children: [
                  _buildAppBar(color),
                  Expanded(child: pages[_currentIndex]),
                  AdManager().bannerAdWidget(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: _buildAppBar(color),
        drawer: _buildDrawer(color, isMobileWeb: isMobileWeb),
        body: pages[_currentIndex],
        bottomNavigationBar: isMobileWeb ? null : _buildSalomonBottomBar(color),
      );
    }
  }

  PreferredSizeWidget _buildAppBar(ThemeData color) {
    return AppBar(
      centerTitle: true,
      automaticallyImplyLeading:
          kIsWeb && MediaQuery.of(context).size.width > 1000 ? false : true,
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
        if (isLargeScreen(context))
          Switch(
            value: Theme.of(context).brightness == Brightness.dark,
            onChanged: _handleThemeChange,
            activeColor: color.colorScheme.secondary,
          ),
      ],
    );
  }

  Widget _buildDrawer(ThemeData color, {bool isMobileWeb = false}) {
    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
      ),
      width: MediaQuery.of(context).size.width > 350 ? 350 : null,
      backgroundColor: color.primaryColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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

                  if (isMobileWeb) ...[
                    ..._buildBottomBarItems(color).asMap().entries.map((entry) {
                      int index = entry.key;
                      SalomonBottomBarItem item = entry.value;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDrawerListTile(
                            color,
                            item.title is Text
                                ? (item.title as Text).data ?? ''
                                : 'Item',
                            item.icon is Icon
                                ? (item.icon as Icon).icon!
                                : Icons.circle_outlined,
                            () {
                              setState(() {
                                _currentIndex = index;
                              });
                              Navigator.pop(context);
                            },
                            isSelected: _currentIndex == index,
                          ),
                          Divider(color: color.scaffoldBackgroundColor),
                        ],
                      );
                    }).toList(),
                  ],

                  _buildDrawerListTile(
                    color,
                    'Profile',
                    Ionicons.person_outline,
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyProfile()),
                      );
                    },
                  ),
                  Divider(color: color.scaffoldBackgroundColor),

                  isIOSPlatform
                      ? CupertinoListTile(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18.0,
                            vertical: 8.0,
                          ),
                          leading: Icon(
                            CupertinoIcons.brightness,
                            color: color.scaffoldBackgroundColor,
                          ),
                          title: Text(
                            'Light/Dark Mode',
                            style: TextStyle(
                              color: color.scaffoldBackgroundColor,
                            ),
                          ),
                          trailing: CupertinoSwitch(
                            value:
                                Theme.of(context).brightness == Brightness.dark,
                            onChanged: _handleThemeChange,
                            activeColor: color.colorScheme.secondary,
                          ),
                        )
                      : SwitchListTile(
                          title: Text(
                            'Light/Dark Mode',
                            style: TextStyle(
                              color: color.scaffoldBackgroundColor,
                            ),
                          ),
                          secondary: Icon(
                            Icons.brightness_2,
                            color: color.scaffoldBackgroundColor,
                          ),
                          value:
                              Theme.of(context).brightness == Brightness.dark,
                          onChanged: _handleThemeChange,
                          activeColor: color.colorScheme.secondary,
                          inactiveThumbColor: color.hintColor,
                          inactiveTrackColor: color.hintColor.withOpacity(0.5),
                        ),
                  Divider(color: color.scaffoldBackgroundColor),

                  // ⭐️ UPDATED: Calls the new bottom sheet method
                  _buildDrawerListTile(
                    color,
                    'Help / Report Issue',
                    Icons.help_outline,
                    () {
                      Navigator.pop(context);
                      _showHelpBottomSheet(); // <-- CHANGED
                    },
                  ),
                  Divider(color: color.scaffoldBackgroundColor),
                ],
              ),
            ),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AdManager().bannerAdWidget(),
              Padding(
                padding: const EdgeInsets.all(18.0),
                child: _buildDrawerListTile(
                  color,
                  userId == null ? 'Login' : 'Logout',
                  isIOSPlatform
                      ? CupertinoIcons.square_arrow_right
                      : Icons.logout,
                  () async {
                    final isGuest =
                        FirebaseAuth.instance.currentUser?.uid == null;
                    if (isGuest) {
                      Navigator.pushNamed(context, '/login');
                    } else {
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('authToken');
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/login',
                        (route) => false,
                      );
                    }
                  },
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
    VoidCallback onTap, {
    bool isSelected = false,
  }) {
    final itemColor = isSelected
        ? color.colorScheme.secondary
        : color.scaffoldBackgroundColor;

    if (isIOSPlatform) {
      return CupertinoListTile(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8.0),
        leading: Icon(icon, color: itemColor),
        title: Text(
          title,
          style: TextStyle(
            color: itemColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        backgroundColor: isSelected
            ? color.primaryColor.withOpacity(0.5)
            : null,
      );
    } else {
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
        selected: isSelected,
        selectedTileColor: color.primaryColor.withOpacity(0.5),
      );
    }
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
    final destinations = _buildBottomBarItems(color)
        .map(
          (item) =>
              NavigationRailDestination(icon: item.icon, label: item.title),
        )
        .toList();

    return Container(
      color: color.primaryColor,
      child: Column(
        children: [
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

          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                // ⭐️ UPDATED: Calls the new bottom sheet method
                IconButton(
                  icon: Icon(
                    Icons.help_outline,
                    color: color.scaffoldBackgroundColor,
                  ),
                  tooltip: 'Help / Report Issue',
                  onPressed: _showHelpBottomSheet, // <-- CHANGED
                ),
                IconButton(
                  icon: Icon(
                    Icons.logout,
                    color: color.scaffoldBackgroundColor,
                  ),
                  tooltip: userId == null ? 'Login' : 'Logout',
                  onPressed: () async {
                    final isGuest =
                        FirebaseAuth.instance.currentUser?.uid == null;
                    if (isGuest) {
                      Navigator.pushNamed(context, '/login');
                    } else {
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('authToken');
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
