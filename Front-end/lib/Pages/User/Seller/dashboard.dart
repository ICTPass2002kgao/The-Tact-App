import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerDashboardTab extends StatelessWidget {
  final String userId;
  final Color baseColor;

  const SellerDashboardTab({
    super.key,
    required this.userId,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Overview",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 15),
              _buildMetricsGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('orders').get(),
      builder: (context, ordersSnapshot) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('seller_products')
              .where('sellerId', isEqualTo: userId)
              .get(),
          builder: (context, productsSnapshot) {
            if (!productsSnapshot.hasData) return const LinearProgressIndicator();

            int totalProducts = productsSnapshot.data?.docs.length ?? 0;
            int totalViews = 0;
            for (var doc in productsSnapshot.data!.docs) {
              totalViews += (doc['views'] as int?) ?? 0;
            }

            int totalOrders = 0;
            double totalRevenue = 0.0;
            if (ordersSnapshot.hasData) {
              for (var orderDoc in ordersSnapshot.data!.docs) {
                final prods = orderDoc['products'] as List? ?? [];
                for (var p in prods) {
                  if (p['sellerId'] == userId) {
                    totalOrders++;
                    totalRevenue += (p['itemTotalPrice'] as num?)?.toDouble() ?? 0.0;
                  }
                }
              }
            }

            // Using Wrap for responsive layout
            return Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                _buildMetricCard(context, "Revenue", "R${totalRevenue.toStringAsFixed(0)}", Icons.attach_money, 0),
                _buildMetricCard(context, "Sales", "$totalOrders", Icons.shopping_bag_outlined, 1),
                _buildMetricCard(context, "Products", "$totalProducts", Icons.inventory_2_outlined, 2),
                _buildMetricCard(context, "Views", "$totalViews", Icons.visibility_outlined, 3),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, int index) {
    double width = (MediaQuery.of(context).size.width > 800)
        ? 220 // Fixed small size on desktop
        : (MediaQuery.of(context).size.width - 55) / 2; // Split 2 on mobile

    return Container(
      width: width,
      height: 100, // Compact height
      decoration: NeumorphicUtils.decoration(
        context: context,
        isDark: Theme.of(context).brightness == Brightness.dark,
        radius: 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Vertical Color Strip (Full Height)
            Container(
              width: 5,
              height: double.infinity,
              color: NeumorphicUtils.getAccentColor(index),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Theme.of(context).primaryColor.withOpacity(0.7), size: 20),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    title,
                    style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}