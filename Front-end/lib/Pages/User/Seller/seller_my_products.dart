import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/NeumorphicUtils.dart';

class SellerMyProductsTab extends StatefulWidget {
  final String userId;
  final Color baseColor;

  const SellerMyProductsTab({
    super.key,
    required this.userId,
    required this.baseColor,
  });

  @override
  State<SellerMyProductsTab> createState() => _SellerMyProductsTabState();
}

class _SellerMyProductsTabState extends State<SellerMyProductsTab> {
  void _showUpdatePriceDialog(String docId, String name, double currentPrice) {
    final controller = TextEditingController(text: currentPrice.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text("Update Price for $name", style: TextStyle(fontSize: 16)),
        content: NeumorphicUtils.buildTextField(
          controller: controller,
          placeholder: "New Price",
          context: context,
          keyboardType: TextInputType.number,
          prefixIcon: Icons.attach_money,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('seller_products')
                  .doc(docId)
                  .update({'price': double.tryParse(controller.text) ?? currentPrice});
              Navigator.pop(context);
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('seller_products')
          .where('sellerId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No products."));

        final docs = snapshot.data!.docs;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: isDesktop
                ? GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.2, // Wide cards for grid
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _buildProductCard(docs[index], index),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => _buildProductCard(docs[index], index),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildProductCard(DocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final accentColor = NeumorphicUtils.getAccentColor(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 15), // Margin for list view
      decoration: NeumorphicUtils.decoration(
        context: context,
        isDark: Theme.of(context).brightness == Brightness.dark,
        radius: 12,
      ),
      child: IntrinsicHeight( // Ensures the vertical line fills height
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full Height Colored Line
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            
            // Image
            Container(
              width: 70,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey[200],
                image: DecorationImage(
                  image: NetworkImage(data['imageUrl'] ?? ''),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      data['productName'] ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "R${data['price']}",
                      style: TextStyle(
                        color: accentColor, // Match text to line color
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Views: ${data['views'] ?? 0}",
                      style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
            ),
            
            // Edit Action
            IconButton(
              icon: Icon(Icons.edit, size: 18, color: Theme.of(context).hintColor),
              onPressed: () => _showUpdatePriceDialog(doc.id, data['productName'], (data['price'] as num).toDouble()),
            )
          ],
        ),
      ),
    );
  }
}