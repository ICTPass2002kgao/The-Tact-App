// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Share_Career_Card.dart';
import 'package:ttact/Pages/Login.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
// --------------------------

class CareerOpportunities extends StatefulWidget {
  const CareerOpportunities({super.key});

  @override
  State<CareerOpportunities> createState() => _CareerOpportunitiesState();
}

class _CareerOpportunitiesState extends State<CareerOpportunities> {
  // Categories for Tabs
  final List<String> _tabs = [
    'All',
    'Bursary',
    'Scholarship',
    'Internship',
    'Job',
    'Learnership',
  ];

  int _selectedIndex = 0; // Tracks the active tab

  // --- DESKTOP SPLIT VIEW STATE ---
  Map<String, dynamic>? _selectedOpportunity;
  String? _selectedDocId;
  bool _isDetailsPanelVisible = false;

  // Fetch data once
  late Future<QuerySnapshot> _usersStream;

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance
        .collection('career_opportunities')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
  }

  // --- 1. Helper: Get Dynamic Email Body ---
  String _getCategorySpecificBody(
    String category,
    String userName,
    String jobTitle,
  ) {
    String cat = category.trim().toLowerCase();
    String titleUpper = jobTitle.toUpperCase();

    if (cat == 'job') {
      return """Dear Hiring Manager,

I hope you are well.

My name is $userName, and I would like to formally apply for the $titleUpper position. I am in need of this opportunity, as it would greatly support me in advancing my career and improving my personal stability.

Sincerely,
$userName""";
    } else {
      return """Dear Hiring Team,

I hope you are doing well.

My name is $userName, and I am writing to apply for the $titleUpper ($cat) opportunity.

Kind regards,
$userName""";
    }
  }

  // --- 2. Show Share Sheet Function ---
  void _showShareSheet(Map<String, dynamic> data, String docId) {
    String title = data['title'] ?? 'Opportunity';
    String category = data['category'] ?? 'General';
    String link = data['link'] ?? '';

    if (link.isEmpty) {
      link = "https://tact-3c612.web.app";
    }

    Timestamp? expiryTs = data['expiryDate'];
    String dateStr = expiryTs != null
        ? DateFormat('dd MMM yyyy').format(expiryTs.toDate())
        : 'Open / Ongoing';

    showModalBottomSheet(
      constraints: BoxConstraints(minWidth: double.infinity),
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CareerShareSheet(
        title: title,
        category: category,
        expiryDate: dateStr,
        docId: docId,
        theme: Theme.of(context),
      ),
    );
  }

  // --- 3. REUSABLE DETAILS CONTENT ---
  // Extracted this so it can be used in both the BottomSheet (Mobile) and SidePanel (Desktop)
  Widget _buildDetailsContent({
    required Map<String, dynamic> data,
    required String docId,
    required bool isScrollableSheet,
    ScrollController? scrollController,
    required VoidCallback onClose,
  }) {
    String title = data['title'] ?? 'Opportunity';
    String oldDescription = data['description'] ?? '';
    List<dynamic> docs = data['requiredDocuments'] ?? [];
    String email = data['applicationEmail'] ?? '';

    Map<String, dynamic> details = data['details'] ?? {};
    String subtitle = details['subtitle'] ?? '';
    String address = details['address'] ?? '';
    String contactNum = details['contactNumber'] ?? '';

    List<dynamic> requirementsList = details['requirementsList'] ?? [];
    List<dynamic> dutiesList = details['dutiesList'] ?? [];

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView(
        // IMPORTANT: On mobile sheet, we MUST use the provided scrollController
        controller: scrollController,
        shrinkWrap:
            !isScrollableSheet, // If in side panel, don't shrink wrap excessively
        children: [
          if (isScrollableSheet) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),
          ] else ...[
            // Close button for Desktop Side Panel
            Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: Icon(Icons.close), onPressed: onClose),
            ),
          ],

          Row(
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showShareSheet(data, docId),
                icon: Icon(
                  isIOSPlatform
                      ? Icons.ios_share_outlined
                      : Icons.share_outlined,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Contact & Submission Section
          if (address.isNotEmpty ||
              contactNum.isNotEmpty ||
              email.isNotEmpty) ...[
            Text(
              "Contact & Submission:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            // Email
            if (email.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.email, size: 20, color: Colors.blueAccent),
                title: Text(
                  "Email",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  email,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.send, size: 20),
                  onPressed: () {
                    AdManager().loadRewardedInterstitialAd();
                    _sendEmail(email, title, data['category'] ?? '');
                  },
                ),
              ),
            // Address
            if (address.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.map, size: 20, color: Colors.redAccent),
                title: Text(
                  "Address",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  address,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.open_in_new, size: 20),
                  onPressed: () => _launchMap(address),
                ),
              ),
            // Phone
            if (contactNum.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(Icons.phone, size: 20, color: Colors.green),
                title: Text(
                  "Phone",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  contactNum,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.call, size: 20),
                  onPressed: () => _launchCall(contactNum),
                ),
              ),
            Divider(),
          ],

          // Requirements List
          if (requirementsList.isNotEmpty) ...[
            Text(
              "Requirements:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            ...requirementsList.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(r.toString())),
                  ],
                ),
              ),
            ),
            Divider(height: 30),
          ],

          // Duties/Modules/Description
          if (dutiesList.isNotEmpty) ...[
            Text(
              "Duties / Modules:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            ...dutiesList.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("• ", style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(d.toString())),
                  ],
                ),
              ),
            ),
            Divider(height: 30),
          ] else if (oldDescription.isNotEmpty) ...[
            Text(
              "Description:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 8),
            Text(oldDescription, style: TextStyle(fontSize: 14, height: 1.5)),
            Divider(height: 30),
          ],

          // Documents
          Text(
            "Required Documents:",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          SizedBox(height: 10),
          if (docs.isEmpty)
            Text(
              "• CV & ID (Standard Requirement)",
              style: TextStyle(fontStyle: FontStyle.italic),
            )
          else
            ...docs.map(
              (doc) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_box_outlined,
                      size: 18,
                      color: Colors.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doc.toString(),
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                if (isScrollableSheet) Navigator.pop(context);
                _checkAuthAndApply(data);
              },
              child: Text(
                "I Understand, Proceed to Apply",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. Logic: Handle Product Click (Mobile vs Desktop) ---
  void _handleOpportunityClick(Map<String, dynamic> data, String docId) {
    if (isLargeScreen(context)) {
      // Desktop: Show Side Panel
      setState(() {
        _selectedOpportunity = data;
        _selectedDocId = docId;
        _isDetailsPanelVisible = true;
      });
    } else {
      // Mobile: Show Bottom Sheet
      _showDetailsBottomSheet(data, docId);
    }
  }

  // --- 5. Show Details Bottom Sheet (Mobile Only) ---
  void _showDetailsBottomSheet(Map<String, dynamic> data, String docId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _buildDetailsContent(
              data: data,
              docId: docId,
              isScrollableSheet: true,
              scrollController: scrollController,
              onClose: () => Navigator.pop(context),
            );
          },
        );
      },
    );
  }

  // --- 6. Auth Check Logic ---
  void _checkAuthAndApply(Map<String, dynamic> data) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginBottomSheet();
    } else {
      _handleApplicationLogic(data);
    }
  }

  void _showLoginBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(24),
          height: 300,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: Colors.orange),
              SizedBox(height: 16),
              Text(
                "Login Required",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                "To apply for this opportunity and auto-fill your details, you need to be logged in.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => Login_Page()),
                    );
                  },
                  child: Text(
                    "Login / Register",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 7. Application Routing Logic ---
  Future<void> _handleApplicationLogic(Map<String, dynamic> data) async {
    final String webLink = data['link'] ?? '';
    final String email = data['applicationEmail'] ?? '';
    final String title = data['title'] ?? 'Opportunity';
    final String category = data['category'] ?? 'General';
    final Map<String, dynamic> details = data['details'] ?? {};
    final String address = details['address'] ?? '';

    bool hasEmail = email.isNotEmpty;
    bool hasLink = webLink.isNotEmpty;
    bool hasAddress = address.isNotEmpty;

    if (hasEmail || hasLink) {
      if (hasEmail && hasLink) {
        _showDualOptionDialog(webLink, email, title, category);
      } else if (hasEmail) {
        _sendEmail(email, title, category);
      } else if (hasLink) {
        _launchWebURL(webLink);
      }
    } else if (hasAddress) {
      // Fallback for physical submission only
      _launchMap(address);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No application method available.')),
      );
    }
  }

  void _showDualOptionDialog(
    String webLink,
    String email,
    String title,
    String category,
  ) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    if (isIos) {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text("Choose Application Method"),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _launchWebURL(webLink);
              },
              child: Text("Apply via Website"),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx);
                _sendEmail(email, title, category);
              },
              child: Text("Apply via Email"),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel"),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Application Method",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Icon(Icons.language, color: Colors.blue),
                title: Text("Apply via Website"),
                onTap: () {
                  Navigator.pop(ctx);
                  _launchWebURL(webLink);
                },
              ),
              ListTile(
                leading: Icon(Icons.email_outlined, color: Colors.orange),
                title: Text("Apply via Email"),
                onTap: () {
                  Navigator.pop(ctx);
                  _sendEmail(email, title, category);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _launchWebURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch website')));
      }
    }
  }

  Future<void> _launchMap(String address) async {
    final Uri url = Uri.parse("geo:0,0?q=${Uri.encodeComponent(address)}");
    if (!await launchUrl(url)) {
      await launchUrl(
        Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}",
        ),
      );
    }
  }

  Future<void> _launchCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Could not launch dialer")));
    }
  }

  Future<void> _sendEmail(
    String email,
    String jobTitle,
    String category,
  ) async {
    User? user = FirebaseAuth.instance.currentUser;
    String userName = "Applicant";

    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          String name = userData['name'] ?? '';
          String surname = userData['surname'] ?? '';
          if (name.isNotEmpty || surname.isNotEmpty) {
            userName = "$name $surname".trim();
          } else {
            userName = user.displayName ?? "Applicant";
          }
        } else {
          userName = user.displayName ?? "Applicant";
        }
      } catch (e) {
        userName = user.displayName ?? "Applicant";
      }
    }

    String body = _getCategorySpecificBody(category, userName, jobTitle);
    String subject = "Application for ${jobTitle.toUpperCase()} - $userName";

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: _encodeQueryParameters(<String, String>{
        'subject': subject,
        'body': body,
      }),
    );

    if (!await launchUrl(emailLaunchUri)) {
      if (mounted) {
        Api().showMessage(
          context,
          "Could not open email app.",
          "Error",
          Colors.red,
        );
      }
    }
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  // --- 8. BUILD METHOD (Desktop vs Mobile) ---
  @override
  Widget build(BuildContext context) {
    final isIos = Theme.of(context).platform == TargetPlatform.iOS;
    final primaryColor = Theme.of(context).primaryColor;
    final bool isDesktop = isLargeScreen(context);

    // The Main List Content
    Widget mainContent = Column(
      children: [
        // --- CUSTOM ROUNDED TABS ---
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _tabs.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                    // Reset Desktop selection on category change
                    _selectedOpportunity = null;
                    _isDetailsPanelVisible = false;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(right: 12),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor
                        : primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1,
                          ),
                  ),
                  child: Center(
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        color: isSelected ? Colors.white : primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        SizedBox(height: 16),

        // --- LIST CONTENT ---
        Expanded(
          child: FutureBuilder<QuerySnapshot>(
            future: _usersStream,
            builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Something went wrong.'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator.adaptive());
              }

              // 1. Initial Filter: Expired + Active
              final List<QueryDocumentSnapshot> allDocs = snapshot.data!.docs
                  .where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? expiryTs = data['expiryDate'];
                    // Allow null (Open/Ongoing)
                    if (expiryTs == null) return true;
                    DateTime date = expiryTs.toDate();
                    DateTime endOfDay = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      23,
                      59,
                      59,
                    );
                    return DateTime.now().isBefore(endOfDay);
                  })
                  .toList();

              // 2. Tab Filter: Category
              final currentTab = _tabs[_selectedIndex];
              final filteredDocs = currentTab == "All"
                  ? allDocs
                  : allDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      String cat = data['category'] ?? '';
                      return cat.toLowerCase() == currentTab.toLowerCase();
                    }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.work_off_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 12),
                      Text(
                        "No active ${currentTab == 'All' ? 'opportunities' : currentTab.toLowerCase() + 's'} found.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  Map<String, dynamic> data =
                      doc.data()! as Map<String, dynamic>;

                  // Highlight selected item on desktop
                  bool isSelected =
                      isDesktop &&
                      _selectedDocId == doc.id &&
                      _isDetailsPanelVisible;

                  return Container(
                    decoration: isSelected
                        ? BoxDecoration(
                            border: Border.all(color: primaryColor, width: 2),
                            borderRadius: BorderRadius.circular(18),
                          )
                        : null,
                    child: _buildHorizontalCard(data, doc.id, isIos),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    // --- FINAL STRUCTURE (SPLIT OR SINGLE) ---
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: List (Flex 2)
                Expanded(flex: 2, child: mainContent),
                // Right: Details (Flex 1)
                if (_isDetailsPanelVisible && _selectedOpportunity != null)
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildDetailsContent(
                        data: _selectedOpportunity!,
                        docId: _selectedDocId!,
                        isScrollableSheet: false,
                        onClose: () {
                          setState(() {
                            _isDetailsPanelVisible = false;
                            _selectedOpportunity = null;
                          });
                        },
                      ),
                    ),
                  ),
              ],
            )
          : mainContent,
    );
  }

  // --- CARD: Horizontal Layout ---
  Widget _buildHorizontalCard(
    Map<String, dynamic> data,
    String docId,
    bool isIos,
  ) {
    String title = data['title'] ?? 'Untitled';
    String category = data['category'] ?? 'General';
    String imageUrl = data['imageUrl'] ?? '';

    bool hasEmail = (data['applicationEmail'] ?? '').toString().isNotEmpty;
    bool hasLink = (data['link'] ?? '').toString().isNotEmpty;

    Timestamp? expiryTs = data['expiryDate'];
    DateTime? expiryDate = expiryTs?.toDate();
    String formattedDate = expiryDate != null
        ? DateFormat('dd MMM yyyy').format(expiryDate)
        : 'Open / Ongoing';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).primaryColor, width: 1),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. IMAGE (Left Side)
              SizedBox(
                width: 110,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Image.asset(
                          "assets/dankie_logo.PNG",
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset("assets/dankie_logo.PNG", fit: BoxFit.cover),
              ),

              // 2. CONTENT (Right Side)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category & Share Icon Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).primaryColor,
                                width: 1,
                              ),
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          // SHARE BUTTON
                          GestureDetector(
                            onTap: () => _showShareSheet(data, docId),
                            child: Icon(
                              isIos ? Icons.ios_share_outlined : Icons.share,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),

                      // Title
                      Text(
                        title.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      SizedBox(height: 6),

                      // Expiry
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: expiryDate == null
                                ? Colors.blue
                                : const Color.fromARGB(255, 39, 163, 17),
                          ),
                          SizedBox(width: 4),
                          Text(
                            expiryDate == null
                                ? formattedDate
                                : "Closes: $formattedDate",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: 10),

                      // Apply Button
                      SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            AdManager().loadRewardedInterstitialAd();
                            // Changed to use the new responsive handler
                            _handleOpportunityClick(data, docId);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Apply Now", style: TextStyle(fontSize: 12)),
                              SizedBox(width: 4),
                              if (hasEmail && hasLink)
                                Icon(Icons.swap_vert, size: 14)
                              else
                                Icon(
                                  hasEmail ? Icons.email : Icons.open_in_new,
                                  size: 12,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
