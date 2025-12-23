// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; // REQUIRED for session persistence
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'package:ttact/Pages/Admin/AuditPage.dart';
import 'package:ttact/Pages/Overseer/OverseerAuditPage.dart';
import 'package:ttact/Pages/Overseer/Supscription_Info.dart';
import 'package:url_launcher/url_launcher.dart';

// --- Local Components & Pages ---
import 'package:ttact/Components/paystack_service.dart';
import 'package:ttact/Components/PaystackWebView.dart';
import 'package:ttact/Pages/Overseer/payment_opened_dialog.dart';
import 'package:ttact/Pages/Overseer/subscribtion_screen.dart';

// --- The Tabs ---
import 'package:ttact/Pages/Overseer/Add_COmmittee_Member.dart';
import 'dashboard_tab.dart';
import 'add_member_tab.dart';
import 'all_members_tab.dart';
import 'add_officer_tab.dart';
import 'reports_tab.dart';

const double _desktopBreakpoint = 1100.0;

class OverseerPage extends StatefulWidget {
  // Parameters passed from FaceVerificationScreen
  final String? loggedMemberName;
  final String? loggedMemberRole;
  final String? faceUrl; // Critical for identifying the user

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

  // --- PROFILE STATE ---
  String _displayName = "Loading...";
  String _displayRole = "Overseer";
  String? faceUrl;
  bool _isLoadingProfile = true;

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

    // Trigger the robust profile loader (handles login + refresh)
    _initializeProfileData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndEnforceSubscription();
    });

      OverseerAuditLogs.logAction(action: "LOGGED_IN", details: "$committeeMemberName Logged in",   committeeMemberName: committeeMemberName, committeeMemberRole: committeeMemberRole, universityCommitteeFace: widget.faceUrl);
  }

  // ===========================================================================
  // === 1. ROBUST PROFILE LOGIC (Fixes the "Wrong User" Bug) ===
  // ===========================================================================
  String committeeMemberName = '';
  String committeeMemberRole = '';

  Future<void> _initializeProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // STEP 1: Find the Main Overseer Doc (Account Owner)
      // We use .where('uid') because the doc ID is random
      final overseerQuery = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (overseerQuery.docs.isEmpty) {
        print("⚠️ No overseer profile found for this user.");
        return;
      }

      final overseerDoc = overseerQuery.docs.first;
      final overseerData = overseerDoc.data();

      // STEP 2: Determine who is logging in
      // Priority A: Passed faceUrl (Fresh Login from Camera)
      // Priority B: Saved Session in SharedPreferences (Browser Refresh)

      String? faceUrlToCheck =
          widget.faceUrl ?? prefs.getString('session_faceUrl');

      if (faceUrlToCheck != null) {
        print("🔍 Checking identity for FaceURL: $faceUrlToCheck");

        // Search inside the 'committee_members' sub-collection of this Overseer
        final committeeQuery = await overseerDoc.reference
            .collection('committee_members')
            .where('faceUrl', isEqualTo: faceUrlToCheck)
            .limit(1)
            .get();

        if (committeeQuery.docs.isNotEmpty) {
          // --- FOUND COMMITTEE MEMBER (e.g., Kgaogelo) ---
          final memberData = committeeQuery.docs.first.data();

          final name = memberData['name'] ?? "Committee Member";
          // Prefer 'portfolio', fallback to 'role'
          final role =
              memberData['portfolio'] ?? memberData['role'] ?? "Committee";

          // Save to Prefs so it persists if the user hits refresh
          await prefs.setString('session_faceUrl', faceUrlToCheck);
          await prefs.setString('session_name', name);
          await prefs.setString('session_role', role);
          setState(() {
            committeeMemberName = name;
            committeeMemberRole = role;
            faceUrl = faceUrlToCheck;
          });

          if (mounted) {
            setState(() {
              _displayName = name;
              _displayRole = role;
              faceUrl = faceUrlToCheck;
              _isLoadingProfile = false;
            });
          }
          return; // STOP HERE: We found the specific member
        } else {
          print(
            "⚠️ Face URL exists but no matching committee member found. Checking Main User...",
          );
        }
      }

      // STEP 3: Fallback to Main Overseer (Hadebe)
      // If no face passed, or face not found in committee list -> It's the Boss.

      // Clear specific committee session data just in case
      await prefs.remove('session_faceUrl');
      await prefs.remove('session_name');
      await prefs.remove('session_role');

      if (mounted) {
        setState(() {
          _displayName =
              overseerData['overseerInitialsAndSurname'] ?? "Main Overseer";
          _displayRole = "Main Overseer";

          // Use the passed face, or the first authorized face, or default null
          if (widget.faceUrl != null) {
            faceUrl = widget.faceUrl;
          } else {
            List faces = overseerData['authorizedUserFaceUrls'] ?? [];
            if (faces.isNotEmpty) faceUrl = faces.first;
          }
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print("❌ Error initializing profile: $e");
      setState(() => _isLoadingProfile = false);
    }
  }

  // --- LOGOUT HELPER ---
  Future<void> _handleLogout() async {
    // Clear session data on logout so next login is clean
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // --- LOGO LOGIC ---
  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() => _logoBytes = bytes.buffer.asUint8List());
    } catch (e) {
      print("Error loading logo: $e");
    }
  }

  // --- SUBSCRIPTION LOGIC ---
  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('overseerUid', isEqualTo: uid)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<void> _checkAndEnforceSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    int memberCount = await _getTotalOverseerMemberCount();
    String? requiredPlan = PaystackService.getRequiredPlan(memberCount);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('overseers')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) return;

    final userDoc = querySnapshot.docs.first;
    String? currentPlan = userDoc.data()['currentPlan'];
    String status = userDoc.data()['subscriptionStatus'] ?? 'inactive';

    if (requiredPlan == null) {
      if (status != 'active' || currentPlan != 'free_tier') {
        await userDoc.reference.set({
          'subscriptionStatus': 'active',
          'currentPlan': 'free_tier',
        }, SetOptions(merge: true));
      }
      return;
    }

    if (status != 'active' || currentPlan != requiredPlan) {
      if (mounted) {
        _showSubscriptionLockedScreen(context, requiredPlan, memberCount);
      }
    }
  }

  void _showSubscriptionLockedScreen(
    BuildContext context,
    String planCode,
    int count,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SubscriptionPlansScreen(
        requiredPlanCode: planCode,
        onSubscribe: (selectedPlanCode) async {
          Navigator.pop(context);
          await _startPaystackPayment(selectedPlanCode, count);
        },
      ),
    );
  }

  Future<void> _startPaystackPayment(String planCode, int count) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    String? authUrl = await PaystackService.initializeSubscription(
      email: user.email!,
      planCode: planCode,
      memberCount: count,
    );

    if (authUrl != null && mounted) {
      if (kIsWeb) {
        final Uri url = Uri.parse(authUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PaymentOpenedDialog(
              onPaid: () {
                Navigator.pop(ctx);
                _checkAndEnforceSubscription();
              },
            ),
          );
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackWebView(
              authUrl: authUrl,
              onSuccess: () async {
                final querySnapshot = await FirebaseFirestore.instance
                    .collection('overseers')
                    .where('uid', isEqualTo: user.uid)
                    .limit(1)
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  await querySnapshot.docs.first.reference.set({
                    'subscriptionStatus': 'active',
                    'currentPlan': planCode,
                    'lastPaymentDate': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                }
                _checkAndEnforceSubscription();
              },
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to initialize payment. Please try again."),
        ),
      );
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width >= _desktopBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: !isLargeScreen
          ? AppBar(
              title: const Text('Overseer Dashboard'),
              centerTitle: true,
              foregroundColor: Colors.white,
              backgroundColor: Theme.of(context).primaryColor,
              bottom: TabBar(
                isScrollable: true,
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'Add Member'),
                  Tab(text: 'All Members'),
                  Tab(text: 'Add Committee'),
                  Tab(text: 'Add Officer'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Audit'),
                  Tab(text: 'Billing & Subscription'),
                ],
              ),
            )
          : null,
      drawer: !isLargeScreen ? _buildMobileDrawer(context) : null,
      body: isLargeScreen
          ? Row(
              children: [
                _buildSidebar(context),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: _buildBodyContent(isLargeScreen),
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: [
                DashboardTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: faceUrl,
                ),
                AddMemberTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: faceUrl,
                ),
                AllMembersTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: faceUrl,
                ),

                // === PASS THE CALCULATED USER INFO HERE (MOBILE) ===
                AddCommitteeMemberTab(
                  isLargeScreen: false,
                  currentUserName: committeeMemberName,
                  currentUserPortfolio: committeeMemberRole,

                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: faceUrl,
                ),

                // ===================================================
                AddOfficerTab(
                  isLargeScreen: false,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: faceUrl,
                ),
                ReportsTab(
                  isLargeScreen: false,
                  logoBytes: _logoBytes,
                  committeeMemberName: committeeMemberName,
                  committeeMemberRole: committeeMemberRole,
                  faceUrl: faceUrl,
                ),
                OverseerAuditpage(),
                SubscriptionInfo(),
              ],
            ),
    );
  }

  Widget _buildBodyContent(bool isLargeScreen) {
    switch (_selectedIndex) {
      case 0:
        return DashboardTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: faceUrl,
        );
      case 1:
        return AddMemberTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: faceUrl,
        );
      case 2:
        return AllMembersTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: faceUrl,
        );
      case 3:
        // === PASS THE CALCULATED USER INFO HERE (DESKTOP) ===
        return AddCommitteeMemberTab(
          isLargeScreen: isLargeScreen,
          currentUserName: committeeMemberName,
          currentUserPortfolio: committeeMemberRole,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: faceUrl,
        );
      // ===================================================
      case 4:
        return AddOfficerTab(
          isLargeScreen: isLargeScreen,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: faceUrl,
        );
      case 5:
        return ReportsTab(
          isLargeScreen: isLargeScreen,
          logoBytes: _logoBytes,
          committeeMemberName: committeeMemberName,
          committeeMemberRole: committeeMemberRole,
          faceUrl: faceUrl,
        );
      case 6:
        return OverseerAuditpage();
      case 7:
        return SubscriptionInfo();
      default:
        return const Center(child: Text("Tab not found"));
    }
  }

  // --- SIDEBAR (Desktop) ---
  Widget _buildSidebar(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          // Sidebar Header: Displays Face & Name
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Profile Image
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    backgroundImage: faceUrl != null
                        ? NetworkImage(faceUrl!)
                        : null,
                    child: faceUrl == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Name
                _isLoadingProfile
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                // Role Badge (Portfolio)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _displayRole.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Sidebar Menu Items
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
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "Logout",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _handleLogout, // Use the proper logout handler
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? primaryColor : Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? primaryColor : Colors.grey[800],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() {
          _selectedIndex = index;
          _tabController.index = index;
        }),
      ),
    );
  }

  // --- MOBILE DRAWER (Mobile) ---
  Widget _buildMobileDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            accountName: Text(
              _displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(_displayRole.toUpperCase()),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              backgroundImage: faceUrl != null ? NetworkImage(faceUrl!) : null,
              child: faceUrl == null
                  ? Icon(Icons.person, color: Theme.of(context).primaryColor)
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text("Logout"),
            onTap: _handleLogout, // Use the proper logout handler
          ),
        ],
      ),
    );
  }
}
