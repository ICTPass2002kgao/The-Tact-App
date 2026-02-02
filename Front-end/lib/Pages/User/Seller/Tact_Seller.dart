// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';
import 'package:ttact/Pages/User/Seller/dashboard.dart';
import 'package:ttact/Pages/User/Seller/seller_add_products.dart';
import 'package:ttact/Pages/User/Seller/seller_my_products.dart';
import 'package:ttact/Pages/User/Seller/seller_orders.dart';

const double _desktopBreakpoint = 900.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

class SellerProductPage extends StatefulWidget {
  const SellerProductPage({super.key});

  @override
  _SellerProductPageState createState() => _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  final user = FirebaseAuth.instance.currentUser;
  bool isVerified = false;
  Map<String, dynamic> userData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentIndex) {
        setState(() => _currentIndex = _tabController.index);
      }
    });
    fetchCurrentUser();
  }

  Future<void> fetchCurrentUser() async {
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (doc.exists && doc.data() != null) {
      setState(() {
        userData = doc.data()!;
        isVerified = userData['accountVerified'] ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (user == null) {
      return Scaffold(
        backgroundColor: baseColor,
        body: const Center(child: Text("Please Log In")),
      );
    }

    return Scaffold(
      backgroundColor: baseColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Centered Tab Bar with constrained width for Web
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: _buildNeumorphicTabSwitcher(theme, baseColor),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SellerDashboardTab(userId: user!.uid, baseColor: baseColor),
                  SellerMyProductsTab(userId: user!.uid, baseColor: baseColor),
                  SellerAddProductTab(
                    userId: user!.uid,
                    isVerified: isVerified,
                    userData: userData,
                  ),
                  SellerOrdersTab(userId: user!.uid, isVerified: isVerified),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNeumorphicTabSwitcher(ThemeData theme, Color baseColor) {
    final tabs = [
      {'icon': Icons.grid_view_rounded, 'label': 'Dash'},
      {'icon': Icons.inventory_2_rounded, 'label': 'Items'},
      {'icon': Icons.add_circle_rounded, 'label': 'Add'},
      {'icon': Icons.receipt_long_rounded, 'label': 'Sales'},
    ];

    return Container(
      height: 60, // Reduced height for cleaner look
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(tabs.length, (index) {
          final isSelected = _currentIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _currentIndex = index);
                _tabController.animateTo(index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.symmetric(horizontal: 4),
                decoration: NeumorphicUtils.decoration(
                  context: context,
                  radius: 12,
                  isPressed: isSelected,
                  isDark: theme.brightness == Brightness.dark,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      color: isSelected ? theme.primaryColor : theme.hintColor,
                      size: 20, // Smaller icon
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tabs[index]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.normal,
                        color: isSelected
                            ? theme.primaryColor
                            : theme.hintColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
