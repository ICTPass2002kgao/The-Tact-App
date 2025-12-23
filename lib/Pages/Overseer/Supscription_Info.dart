import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ASSUMPTION: You have these imports in your project
import 'package:ttact/Components/PaystackWebView.dart';
import 'package:ttact/Components/paystack_service.dart';

class SubscriptionInfo extends StatefulWidget {
  const SubscriptionInfo({super.key});

  @override
  State<SubscriptionInfo> createState() => _SubscriptionInfoState();
}

class _SubscriptionInfoState extends State<SubscriptionInfo> {
  bool _isLoading = true;
  int _memberCount = 0;
  String _currentPlan = 'Loading...';
  String _status = 'Loading...';
  String? _requiredPlan;
  DateTime? _lastPaymentDate;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionDetails();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchSubscriptionDetails() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Get Member Count
      final memberCount = await _getTotalOverseerMemberCount();

      // 2. Get Firestore Data
      final querySnapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();

        setState(() {
          _memberCount = memberCount;
          _currentPlan = data['currentPlan'] ?? 'free_tier';
          _status = data['subscriptionStatus'] ?? 'inactive';
          // Check what plan is required based on the count
          _requiredPlan = PaystackService.getRequiredPlan(memberCount);

          if (data['lastPaymentDate'] != null) {
            _lastPaymentDate = (data['lastPaymentDate'] as Timestamp).toDate();
          }
          _isLoading = false;
        });
      } else {
        // Handle case where overseer doc doesn't exist yet
        setState(() {
          _memberCount = memberCount;
          _currentPlan = 'free_tier';
          _status = 'inactive';
          _requiredPlan = PaystackService.getRequiredPlan(memberCount);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading subscription info: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    // NOTE: Switched back to real logic.
    // If you want to test the "Upgrade" UI, uncomment "return 70;"

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('overseerUid', isEqualTo: uid)
        .count()
        .get();
    return snapshot.count ?? 0;

    // return 70; // Hardcoded for testing UI
  }

  // --- PAYMENT LOGIC ---
  Future<void> _startPaystackPayment(String planCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    String? authUrl = await PaystackService.initializeSubscription(
      email: user.email!,
      planCode: planCode,
      memberCount: _memberCount,
    );

    // Remove loading indicator
    if (mounted) Navigator.pop(context);

    if (authUrl != null && mounted) {
      if (kIsWeb) {
        final Uri url = Uri.parse(authUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          // Show dialog to confirm payment on web
          // ignore: use_build_context_synchronously
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Payment Processing"),
              content: const Text(
                "Please confirm in the new window. Click done when finished.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handlePaymentSuccess(user.uid, planCode);
                  },
                  child: const Text("Done"),
                ),
              ],
            ),
          );
        }
      } else {
        // Mobile WebView
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaystackWebView(
              authUrl: authUrl,
              onSuccess: () async {
                await _handlePaymentSuccess(user.uid, planCode);
                if (mounted) Navigator.pop(context); // Close WebView
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

  Future<void> _handlePaymentSuccess(String uid, String planCode) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('overseers')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.set({
        'subscriptionStatus': 'active',
        'currentPlan': planCode,
        'lastPaymentDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    // Refresh the UI
    _fetchSubscriptionDetails();
  }

  // --- UI HELPERS ---

  bool get _needsUpgrade {
    if (_requiredPlan == null) return false; // Free tier is fine
    // If the plan is different, OR the status is not active (expired/failed)
    return _currentPlan != _requiredPlan || _status != 'active';
  }

  Color get _statusColor {
    if (_status == 'active' && !_needsUpgrade) return Colors.green;
    return Colors.red;
  }

  // --- MAIN BUILD ---

  @override
  Widget build(BuildContext context) {
    // Check if free tier is active (no upgrade needed)
    final isFreeTierActive = _requiredPlan == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), // Light background for cards
      appBar: AppBar(
        title: const Text("Subscription Management"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.blue,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSubscriptionDetails,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Api().isIOSPlatform
                  ? CupertinoActivityIndicator()
                  : CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _fetchSubscriptionDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: CURRENT STATUS DASHBOARD ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildDashboardCard(
                            title: "Status",
                            value: _status.toUpperCase(),
                            icon: Icons.verified_user,
                            color: _statusColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDashboardCard(
                            title: "Current Plan",
                            value: _currentPlan
                                .replaceAll('_', ' ')
                                .toUpperCase(),
                            icon: Icons.layers,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Usage Metrics Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total Members:",
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                "$_memberCount",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Required Plan:",
                                style: TextStyle(color: Colors.grey),
                              ),
                              Text(
                                (_requiredPlan ?? "Free Tier")
                                    .replaceAll('_', ' ')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _needsUpgrade
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- SECTION 2: PLANS GRID ---
                    const Text(
                      'Available Plans',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3E50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _requiredPlan != null
                          ? 'You have exceeded the free tier limit. Please upgrade to continue.'
                          : 'Select a plan based on your member count.',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: [
                          // --- FREE TIER CARD ---
                          _buildPlanCard(
                            planCode: 'free_tier',
                            title: 'Free Tier',
                            memberRange: '0 - 49 Members',
                            price: 'Free',
                            features: [
                              'Standard generation of balance sheet for up to 49 members',
                            ],
                            // It is active if requiredPlan is null
                            isRecommended: isFreeTierActive,
                            // Disable if they need to upgrade
                            isDisabled: !isFreeTierActive,
                            buttonColor: Colors.grey,
                          ),

                          // --- TIER 1 ---
                          _buildPlanCard(
                            planCode: PaystackService.planTier1,
                            title: 'Tier 1',
                            memberRange: '50 - 299 Members',
                            price: 'R189',
                            features: [
                              'Generate a balance sheet of 50-299 members',
                            ],
                            isRecommended:
                                _requiredPlan == PaystackService.planTier1,
                            buttonColor: const Color(0xFF00C853), // Green
                          ),

                          // --- TIER 2 ---
                          _buildPlanCard(
                            planCode: PaystackService.planTier2,
                            title: 'Tier 2',
                            memberRange: '300 - 499 Members',
                            price: 'R349',
                            features: [
                              'Generate a balance sheet of 300-499 members',
                            ],
                            isRecommended:
                                _requiredPlan == PaystackService.planTier2,
                            buttonColor: const Color(0xFF2962FF), // Blue
                          ),

                          // --- TIER 3 ---
                          _buildPlanCard(
                            planCode: PaystackService.planTier3,
                            title: 'Tier 3',
                            memberRange: '500+ Members',
                            price: 'R489',
                            features: [
                              'Generate a balance sheet of 500+ members',
                            ],
                            isRecommended:
                                _requiredPlan == PaystackService.planTier3,
                            buttonColor: const Color(0xFF6200EA), // Purple
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String planCode,
    required String title,
    required String memberRange,
    required String price,
    required List<String> features,
    required bool isRecommended,
    required Color buttonColor,
    bool isDisabled = false,
  }) {
    // Logic for button text
    String buttonText = 'Choose Plan';
    if (planCode == 'free_tier') {
      buttonText = isRecommended ? 'Current Plan' : 'Limit Exceeded';
    } else if (isRecommended) {
      buttonText = 'Subscribe Now';
    } else if (_currentPlan == planCode) {
      buttonText = 'Active Plan';
    }

    // Logic for button action
    final bool isActionable =
        !isDisabled && planCode != 'free_tier' && _currentPlan != planCode;

    return Stack(
      children: [
        Container(
          width: 300,
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: isDisabled ? Colors.grey[50] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isRecommended
                ? Border.all(color: buttonColor, width: 2)
                : Border.all(color: Colors.grey.shade200),
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Opacity(
            opacity: isDisabled ? 0.6 : 1.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDisabled ? Colors.grey : buttonColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  memberRange,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF2D3E50),
                      ),
                    ),
                    if (price != 'Free')
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, left: 4.0),
                        child: Text(
                          '/month',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 24),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: isDisabled ? Colors.grey : buttonColor,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDisabled
                                  ? Colors.grey
                                  : const Color(0xFF455A64),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: isActionable
                        ? () => _startPaystackPayment(planCode)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      disabledBackgroundColor:
                          (planCode == 'free_tier' && isRecommended)
                          ? Colors.green.shade50
                          : Colors.grey.shade200,
                      foregroundColor: Colors.white,
                      disabledForegroundColor:
                          (planCode == 'free_tier' && isRecommended)
                          ? Colors.green
                          : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isRecommended)
          Positioned(
            top: 0,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: buttonColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                planCode == 'free_tier' ? 'Active' : 'Recommended',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
