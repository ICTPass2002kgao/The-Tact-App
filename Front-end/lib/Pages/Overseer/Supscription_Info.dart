// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http; // Added for Django
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:ttact/Components/PaystackWebView.dart';
import 'package:ttact/Components/paystack_service.dart';
// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

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
  int? _overseerId; // Store ID for updates

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionDetails();
  }

  // --- 1. FETCH DETAILS (DJANGO) ---
  Future<void> _fetchSubscriptionDetails() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final memberCount = await _getTotalOverseerMemberCount();

      // Fetch Overseer Profile via Email
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/?email=${user.email}',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);

        if (results.isNotEmpty) {
          final data = results[0];

          setState(() {
            _memberCount = memberCount;
            _overseerId = data['id']; // Needed for PATCH later
            // Django keys (snake_case)
            _currentPlan =
                data['current_plan'] ?? data['currentPlan'] ?? 'free_tier';
            _status =
                data['subscription_status'] ??
                data['subscriptionStatus'] ??
                'inactive';
            _requiredPlan = PaystackService.getRequiredPlan(memberCount);

            String? paymentDateStr =
                data['last_payment_date'] ?? data['lastPaymentDate'];
            if (paymentDateStr != null) {
              try {
                _lastPaymentDate = DateTime.parse(paymentDateStr);
              } catch (e) {
                /* ignore parse error */
              }
            }
            _isLoading = false;
          });
        } else {
          // No profile found, default to free
          _setDefaults(memberCount);
        }
      } else {
        _setDefaults(memberCount);
      }
    } catch (e) {
      debugPrint("Error loading subscription info: $e");
      setState(() => _isLoading = false);
    }
  }

  void _setDefaults(int count) {
    setState(() {
      _memberCount = count;
      _currentPlan = 'free_tier';
      _status = 'inactive';
      _requiredPlan = PaystackService.getRequiredPlan(count);
      _isLoading = false;
    });
  }

  // --- 2. FETCH MEMBER COUNT (DJANGO) ---
  Future<int> _getTotalOverseerMemberCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    try {
      // URL: /api/users/?overseer_uid=UID
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/users/?overseer_uid=$uid',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return (json.decode(response.body) as List).length;
      }
    } catch (e) {
      print(e);
    }
    return 0;
  }

  // --- PAYMENT LOGIC (UNCHANGED, only success handler changed) ---
  Future<void> _startPaystackPayment(String planCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;

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

    if (mounted) Navigator.pop(context);

    if (authUrl != null && mounted) {
      if (kIsWeb) {
        final Uri url = Uri.parse(authUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
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
                    _handlePaymentSuccess(planCode);
                  },
                  child: const Text("Done"),
                ),
              ],
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
                await _handlePaymentSuccess(planCode);
                if (mounted) Navigator.pop(context);
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

  // --- 3. HANDLE SUCCESS (DJANGO PATCH) ---
  Future<void> _handlePaymentSuccess(String planCode) async {
    if (_overseerId == null) return;

    try {
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/overseers/$_overseerId/',
      );

      final response = await http.patch(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          'subscription_status': 'active',
          'current_plan': planCode,
          'last_payment_date': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        _fetchSubscriptionDetails(); // Refresh UI
      } else {
        print("Update Failed: ${response.body}");
      }
    } catch (e) {
      print("Network Error: $e");
    }
  }

  // --- UI HELPERS ---

  bool get _needsUpgrade {
    if (_requiredPlan == null) return false;
    return _currentPlan != _requiredPlan || _status != 'active';
  }

  Color get _statusColor {
    if (_status == 'active' && !_needsUpgrade) return Colors.green;
    return Colors.red;
  }

  // --- MAIN BUILD (UNCHANGED UI) ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;
    final primaryColor = theme.primaryColor;

    final isFreeTierActive = _requiredPlan == null;

    return Scaffold(
      backgroundColor: baseColor,
      appBar: AppBar(
        title: Text(
          "Subscription Management",
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryColor),
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
                  ? const CupertinoActivityIndicator()
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _fetchSubscriptionDetails,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATUS DASHBOARD
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
                        const SizedBox(width: 16),
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
                    const SizedBox(height: 16),

                    // METRICS CARD
                    NeumorphicContainer(
                      borderRadius: 16,
                      padding: const EdgeInsets.all(20),
                      color: baseColor,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Total Members:",
                                style: TextStyle(color: theme.hintColor),
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
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Divider(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Required Plan:",
                                style: TextStyle(color: theme.hintColor),
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

                    // PLANS GRID
                    Text(
                      'Available Plans',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _requiredPlan != null
                          ? 'Limit exceeded. Please upgrade.'
                          : 'Select a plan based on member count.',
                      style: TextStyle(fontSize: 14, color: theme.hintColor),
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildPlanCard(
                            planCode: 'free_tier',
                            title: 'Free Tier',
                            memberRange: '0 - 49 Members',
                            price: 'Free',
                            features: [
                              'Standard generation of balance sheet (Max 49)',
                            ],
                            isRecommended: isFreeTierActive,
                            isDisabled: !isFreeTierActive,
                            accentColor: Colors.grey,
                          ),
                          _buildPlanCard(
                            planCode: PaystackService.planTier1,
                            title: 'Tier 1',
                            memberRange: '50 - 299 Members',
                            price: 'R189',
                            features: ['Balance sheet for 50-299 members'],
                            isRecommended:
                                _requiredPlan == PaystackService.planTier1,
                            accentColor: const Color(0xFF00C853),
                          ),
                          _buildPlanCard(
                            planCode: PaystackService.planTier2,
                            title: 'Tier 2',
                            memberRange: '300 - 499 Members',
                            price: 'R349',
                            features: ['Balance sheet for 300-499 members'],
                            isRecommended:
                                _requiredPlan == PaystackService.planTier2,
                            accentColor: const Color(0xFF2962FF),
                          ),
                          _buildPlanCard(
                            planCode: PaystackService.planTier3,
                            title: 'Tier 3',
                            memberRange: '500+ Members',
                            price: 'R489',
                            features: ['Balance sheet for 500+ members'],
                            isRecommended:
                                _requiredPlan == PaystackService.planTier3,
                            accentColor: const Color(0xFF6200EA),
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
    final theme = Theme.of(context);
    return NeumorphicContainer(
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NeumorphicContainer(
                isPressed: true,
                borderRadius: 30,
                padding: const EdgeInsets.all(8),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
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
    required Color accentColor,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);
    final baseColor = theme.scaffoldBackgroundColor;

    String buttonText = 'Choose Plan';
    if (planCode == 'free_tier') {
      buttonText = isRecommended ? 'Current Plan' : 'Limit Exceeded';
    } else if (isRecommended) {
      buttonText = 'Subscribe Now';
    } else if (_currentPlan == planCode) {
      buttonText = 'Active Plan';
    }

    final bool isActionable =
        !isDisabled && planCode != 'free_tier' && _currentPlan != planCode;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        NeumorphicContainer(
          borderRadius: 20,
          padding: const EdgeInsets.all(24.0),
          isPressed: isDisabled,
          color: baseColor,
          child: SizedBox(
            width: 300,
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    memberRange,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  NeumorphicContainer(
                    isPressed: true,
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (price != 'Free')
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              '/mo',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.hintColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 24),
                  ...features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: isDisabled ? Colors.grey : accentColor,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  GestureDetector(
                    onTap: isActionable
                        ? () => _startPaystackPayment(planCode)
                        : null,
                    child: NeumorphicContainer(
                      isPressed: false,
                      borderRadius: 12,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      color: baseColor,
                      child: Center(
                        child: Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isActionable
                                ? accentColor
                                : (isRecommended ? Colors.green : Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isRecommended)
          Positioned(
            top: -10,
            right: 20,
            child: NeumorphicContainer(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: accentColor,
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
