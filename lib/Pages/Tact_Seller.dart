import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SellerProductPage extends StatefulWidget {
  @override
  _SellerProductPageState createState() => _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final priceController = TextEditingController();
  final locationController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  Future<void> addSellerProduct(String productId, String name,String descrip) async {
    if (user == null ||
        priceController.text.isEmpty ||
        locationController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('seller_products').add({
      'productId': productId,
      'sellerId': user!.uid,
      'price': double.parse(priceController.text),
      'description':descrip,
      'location': locationController.text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    priceController.clear();
    locationController.clear();
  }

  Widget myProductsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('seller_products')
          .where('sellerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final sellerProds = snapshot.data!.docs;

        if (sellerProds.isEmpty) {
          return Center(child: Text("No products added yet."));
        }

        return ListView.builder(
          itemCount: sellerProds.length,
          itemBuilder: (context, index) {
            final data = sellerProds[index].data() as Map<String, dynamic>;
            final productId = data['productId'];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('products')
                  .doc(productId)
                  .get(),
              builder: (context, productSnap) {
                if (!productSnap.hasData) return ListTile(title: Text("Loading..."));

                final productData =
                    productSnap.data!.data() as Map<String, dynamic>;

                return ListTile(
                  leading: Image.network(productData['imageUrl'], height: 50, width: 50),
                  title: Text(productData['name']),
                  subtitle: Text(
                      "Price: R${data['price']} • Location: ${data['location']}"),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget addProductTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

        final products = snapshot.data!.docs;

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final prod = products[index];
            return ListTile(
              leading: Image.network(prod['imageUrl'], height: 50, width: 50),
              title: Text(prod['name']),
              subtitle: Text(prod['description']),
              onTap: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("Add Your Price"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Product: ${prod['name']}"),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: "Price"),
                      ),
                      TextField(
                        controller: locationController,
                        decoration: InputDecoration(labelText: "Location"),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await addSellerProduct(prod.id, prod['name'],prod['description']);
                        Navigator.pop(context);
                      },
                      child: Text("Submit"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    priceController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Seller Products"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "My Products"),
            Tab(text: "Add Product"),
          ],
        ),
      ),
      backgroundColor: color.scaffoldBackgroundColor,
      body: TabBarView(
        controller: _tabController,
        children: [
          myProductsTab(),
          addProductTab(),
        ],
      ),
    );
  }
}
