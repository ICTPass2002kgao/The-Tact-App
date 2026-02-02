// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Pages/Overseer/OverseerAuditPage.dart';
import 'package:ttact/Pages/Overseer/Supscription_Info.dart';
import 'package:ttact/Components/paystack_service.dart';
import 'package:ttact/Components/PaystackWebView.dart';
import 'package:ttact/Pages/Overseer/payment_opened_dialog.dart';
import 'package:ttact/Pages/Overseer/subscribtion_screen.dart';
import 'package:ttact/Pages/Overseer/Add_COmmittee_Member.dart';

import 'dashboard_tab.dart';
import 'add_member_tab.dart';
import 'all_members_tab.dart';
import 'add_officer_tab.dart';
import 'reports_tab.dart';

const double _desktopBreakpoint = 1100.0;
const Color _neumorphicBaseColor = Color(0xFFF0F2F5);

class OverseerPage extends StatefulWidget {
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl;

  const OverseerPage({
    super.key,
    this.loggedMemberName,
    this.loggedMemberRole,
    this.faceUrl,
  });

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _OverseerPageState extends State<OverseerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;
  Uint8List? _logoBytes;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _displayName = "Loading...";
  String _displayRole = "Overseer";
  String? faceUrl;
  bool _isLoadingProfile = true;

  String committeeMemberName = '';
  String committeeMemberRole = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedIndex = _tabController.index);
      }
    });

    _loadLogoBytes();
    _initializeProfileData();
  }

  // ⭐️ HELPER: Convert Encrypted URL to Decrypted Django Proxy URL
  String _getSecureImageUrl(String originalUrl) {
    if (originalUrl.isEmpty) return "";
    // If it's already a local asset or plain HTTP, leave it.
    // Otherwise, route through Django.
    return '${Api().BACKEND_BASE_URL_DEBUG}/serve_image/?url=${Uri.encodeComponent(originalUrl)}';
  }

  Future<void> _initializeProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      final identifier = user.email ?? "";
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=$identifier',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final List<dynamic> results = json.decode(response.body);
      if (results.isEmpty) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final overseerData = results[0];
      final overseerId = overseerData['id'];

      String? faceUrlToCheck =
          widget.faceUrl ?? prefs.getString('session_faceUrl');

      bool isCommitteeMember = false;

      if (faceUrlToCheck != null) {
        final committeeUrl = Uri.parse(
          '${Api().BACKEND_BASE_URL_DEBUG}/committee_members/?overseer=$overseerId&face_url=$faceUrlToCheck',
        );

        final commResponse = await http.get(committeeUrl);

        if (commResponse.statusCode == 200) {
          final List<dynamic> commResults = json.decode(commResponse.body);

          if (commResults.isNotEmpty) {
            isCommitteeMember = true;
            final memberData = commResults[0];

            final name = memberData['name'] ?? "Committee Member";
            final role =
                memberData['portfolio'] ?? memberData['role'] ?? "Committee";

            await prefs.setString('session_faceUrl', faceUrlToCheck);
            await prefs.setString('session_name', name);
            await prefs.setString('session_role', role);

            if (mounted) {
              setState(() {
                _displayName = name;
                _displayRole = role;
                faceUrl = faceUrlToCheck;
                committeeMemberName = name;
                committeeMemberRole = role;
                _isLoadingProfile = false;
              });
            }
          }
        }
      }

      if (!isCommitteeMember) {
        await prefs.remove('session_faceUrl');
        await prefs.remove('session_name');
        await prefs.remove('session_role');

        String mainName =
            overseerData['overseer_initials_surname'] ?? "Main Overseer";
        String mainRole = "Main Overseer";
        String? mainFaceUrl;

        if (widget.faceUrl != null) {
          mainFaceUrl = widget.faceUrl;
        } else {
          mainFaceUrl =
              overseerData['chairperson_face_url'] ??
              overseerData['secretary_face_url'];
        }

        if (mounted) {
          setState(() {
            _displayName = mainName;
            _displayRole = mainRole;
            faceUrl = mainFaceUrl;
            committeeMemberName = mainName;
            committeeMemberRole = mainRole;
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print("❌ Error initializing profile: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() => _logoBytes = bytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= _desktopBreakpoint;

    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: _neumorphicBaseColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Loading Profile Data..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _neumorphicBaseColor,
      drawer: !isLargeScreen ? _buildMobileDrawer(context) : null,
      body: SafeArea(
        child: isLargeScreen
            ? _buildDesktopLayout(context)
            : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        _buildSidebar(context),
        Expanded(
          child: Container(
            color: _neumorphicBaseColor,
            padding: const EdgeInsets.all(24),
            child: _buildBodyContent(true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    // ⭐️ Use the Helper Method for the secure URL
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: NeumorphicContainer(
                  padding: const EdgeInsets.all(10),
                  borderRadius: 12,
                  child: Icon(Icons.menu, color: Colors.grey[700]),
                ),
              ),
              Text(
                'Overseer Dashboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              NeumorphicContainer(
                padding: const EdgeInsets.all(4),
                borderRadius: 30,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: _neumorphicBaseColor,
                  // ⭐️ UPDATED: Uses secureFaceUrl
                  backgroundImage: secureFaceUrl != null
                      ? NetworkImage(secureFaceUrl)
                      : null,
                  child: secureFaceUrl == null
                      ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                      : null,
                ),
              ),
            ],
          ),
        ),

        // ... Tabs logic remains unchanged ...
        Container(
          height: 60,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildMobileTabItem(0, "Dashboard"),
              _buildMobileTabItem(1, "Add Member"),
              _buildMobileTabItem(2, "All Members"),
              _buildMobileTabItem(3, "Add Committee"),
              _buildMobileTabItem(4, "Add Officer"),
              _buildMobileTabItem(5, "Reports"),
              _buildMobileTabItem(6, "Audit"),
              _buildMobileTabItem(7, "Billing"),
            ],
          ),
        ),

        Expanded(
          child: Container(
            color: _neumorphicBaseColor,
            child: TabBarView(
              controller: _tabController,
              children: [
                DashboardTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  // ⭐️ Pass the secure URL to children
                  faceUrl: secureFaceUrl,
                ),
                AddMemberTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: secureFaceUrl,
                ),
                AllMembersTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: secureFaceUrl,
                ),
                AddCommitteeMemberTab(
                  isLargeScreen: false,
                  currentUserName: committeeMemberName,
                  currentUserPortfolio: committeeMemberRole,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: secureFaceUrl,
                ),
                AddOfficerTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: secureFaceUrl,
                ),
                ReportsTab(
                  isLargeScreen: false,
                  logoBytes: _logoBytes,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: secureFaceUrl,
                ),
                OverseerAuditpage(),
                SubscriptionInfo(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ... (Mobile Tab Item Helper remains unchanged) ...
  Widget _buildMobileTabItem(int index, String title) {
    final bool isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _tabController.animateTo(index);
          });
        },
        child: NeumorphicContainer(
          isPressed: isSelected,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          borderRadius: 20,
          color: _neumorphicBaseColor,
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(bool isLargeScreen) {
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;

    switch (_selectedIndex) {
      case 0:
        return DashboardTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        );
      // ... Repeat for all other tabs using secureFaceUrl ...
      case 1:
        return AddMemberTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        );
      // [Abbreviated for length: Use secureFaceUrl for all other tabs]
      case 2:
        return AllMembersTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        );
      case 3:
        return AddCommitteeMemberTab(
          isLargeScreen: isLargeScreen,
          currentUserName: committeeMemberName,
          currentUserPortfolio: committeeMemberRole,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        );
      case 4:
        return AddOfficerTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        );
      case 5:
        return ReportsTab(
          isLargeScreen: isLargeScreen,
          logoBytes: _logoBytes,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: secureFaceUrl,
        );
      case 6:
        return OverseerAuditpage();
      case 7:
        return SubscriptionInfo();
      default:
        return const Center(child: Text("Tab not found"));
    }
  }

  Widget _buildSidebar(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    // ⭐️ SECURE URL
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;

    return Container(
      width: 280,
      color: _neumorphicBaseColor,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 20.0,
            ),
            child: NeumorphicContainer(
              isPressed: false,
              padding: const EdgeInsets.all(20),
              borderRadius: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white, primaryColor.withOpacity(0.1)],
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: _neumorphicBaseColor,
                      // ⭐️ USE SECURE URL
                      backgroundImage: secureFaceUrl != null
                          ? NetworkImage(secureFaceUrl)
                          : null,
                      child: secureFaceUrl == null
                          ? Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.grey[600],
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _displayRole.toUpperCase(),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ... Sidebar items remain unchanged ...
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                _buildSidebarItem(0, Icons.dashboard, "Dashboard"),
                _buildSidebarItem(1, Icons.person_add, "Add Member"),
                _buildSidebarItem(2, Icons.people, "All Members"),
                _buildSidebarItem(3, Icons.groups, "Add Committee"),
                _buildSidebarItem(4, Icons.admin_panel_settings, "Add Officer"),
                _buildSidebarItem(5, Icons.receipt_long, "Reports"),
                _buildSidebarItem(6, Icons.receipt_long, "Audit Logs"),
                _buildSidebarItem(
                  7,
                  Icons.subscriptions_outlined,
                  "Billing & Subscription",
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: NeumorphicContainer(
                    isPressed: false,
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: _handleLogout,
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

  // ... (Sidebar Item and Mobile Drawer Helpers remain unchanged) ...
  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _selectedIndex = index;
          _tabController.index = index;
        }),
        child: NeumorphicContainer(
          isPressed: isSelected,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 12,
          color: isSelected ? _neumorphicBaseColor : _neumorphicBaseColor,
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryColor : Colors.grey[600],
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? primaryColor : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    String? secureFaceUrl = faceUrl != null
        ? _getSecureImageUrl(faceUrl!)
        : null;
    return Drawer(
      backgroundColor: _neumorphicBaseColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          NeumorphicContainer(
            child: UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              accountName: Text(
                _displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(_displayRole.toUpperCase()),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: secureFaceUrl != null
                    ? NetworkImage(secureFaceUrl)
                    : null,
                child: secureFaceUrl == null
                    ? Icon(Icons.person, color: Theme.of(context).primaryColor)
                    : null,
              ),
            ),
          ),
          NeumorphicContainer(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: _handleLogout,
            ),
          ),
        ],
      ),
    );
  }
}
