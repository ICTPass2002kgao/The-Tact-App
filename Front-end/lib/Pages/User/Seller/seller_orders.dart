import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerOrdersTab extends StatefulWidget {
  final String userId;
  final bool isVerified;

  const SellerOrdersTab({super.key, required this.userId, required this.isVerified});

  @override
  State<SellerOrdersTab> createState() => _SellerOrdersTabState();
}

class _SellerOrdersTabState extends State<SellerOrdersTab> {
  final List<String> orderStatuses = ['pending', 'processing', 'ready_for_pickup', 'dispatched', 'completed', 'cancelled'];

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    if (!widget.isVerified) return;
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': newStatus});
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final orders = snapshot.data!.docs.where((doc) {
          final prods = doc['products'] as List? ?? [];
          return prods.any((p) => p['sellerId'] == widget.userId);
        }).toList();

        if (orders.isEmpty) return const Center(child: Text("No Orders Yet"));

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isDesktop
                ? GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // 2 Columns on desktop for orders (they need space)
                      childAspectRatio: 2.0,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => _buildOrderCard(orders[index], index),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => _buildOrderCard(orders[index], index),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildOrderCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final orderId = doc.id;
    final status = data['status'] ?? 'pending';
    final accentColor = NeumorphicUtils.getAccentColor(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: NeumorphicUtils.decoration(
        context: context,
        isDark: Theme.of(context).brightness == Brightness.dark,
        radius: 12,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  title: Text(
                    "Order #${data['orderReference'] ?? orderId.toString().substring(0, 6)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    status.toString().toUpperCase(),
                    style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(height: 20, color: Colors.grey.withOpacity(0.2)),
                          _buildDetailRow("Customer", data['customerEmail'] ?? 'N/A'),
                          _buildDetailRow("Address", data['address'] ?? 'N/A'),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: () => _showStatusDialog(orderId, status),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: NeumorphicUtils.decoration(context: context, isPressed: true, radius: 8),
                              child: Text("Update Status", style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  void _showStatusDialog(String orderId, String current) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Update Status", style: TextStyle(fontSize: 16)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        children: orderStatuses.map((s) => SimpleDialogOption(
          onPressed: () {
            updateOrderStatus(orderId, s);
            Navigator.pop(context);
          },
          child: Text(s.toUpperCase(), style: TextStyle(
            color: s == current ? Theme.of(context).primaryColor : null,
            fontWeight: s == current ? FontWeight.bold : FontWeight.normal
          )),
        )).toList(),
      ),
    );
  }
}