import 'dart:math'; // For random number generation
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart'; // Import for date formatting

class SellerProductPage extends StatefulWidget {
  @override
  _SellerProductPageState createState() => _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final priceController = TextEditingController();
  final locationController = TextEditingController();
  // Removed: quantityController
  final user = FirebaseAuth.instance.currentUser;

  // NEW: Controller for adding individual colors
  final singleColorController = TextEditingController();
  // NEW: List to temporarily hold colors as they are added in the bottom sheet
  List<String> _tempColors = [];

  final List<String> orderStatuses = [
    'pending',
    'processing',
    'ready_for_pickup',
    'dispatched',
    'completed',
    'cancelled',
  ];

  late int _randomDisplayPercentage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4, // 4 tabs: Dashboard, My Products, Add Product, Orders
      vsync: this,
    );
    _generateRandomDisplayDiscount();
  }

  void _generateRandomDisplayDiscount() {
    final random = Random();
    _randomDisplayPercentage = 13 + random.nextInt(44 - 13 + 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    priceController.dispose();
    locationController.dispose();
    // Removed: quantityController.dispose();
    singleColorController.dispose(); // NEW: Dispose singleColorController
    super.dispose();
  }

  // --- UPDATED: addSellerProduct Function ---
  // Quantity parameter removed, colors list updated.
  Future<void> addSellerProduct(
    String productId, // ID from the 'products' collection
    String name,
    String descrip,
    // Removed: int quantity,
    dynamic imageUrl, // Could be String or List<String>
    List<String> colors, // List of available colors
  ) async {
    // Basic validation
    if (user == null ||
        priceController.text.isEmpty ||
        locationController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill all required fields: price and location.',
            ),
          ),
        );
      }
      return;
    }

    final existingProduct = await FirebaseFirestore.instance
        .collection('seller_products')
        .where('productId', isEqualTo: productId)
        .where('sellerId', isEqualTo: user!.uid)
        .get();

    if (existingProduct.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have already listed this product. Consider updating it in "My Products" tab.',
            ),
          ),
        );
      }
      return;
    }

    _generateRandomDisplayDiscount();

    try {
      // Fetch seller's Paystack subaccount code from 'users' collection
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      final subaccountCode = sellerDoc.data()?['sellerPaystackAccount'] ?? '';

      await FirebaseFirestore.instance.collection('seller_products').add({
        'productId': productId,
        'sellerId': user!.uid,
        'price': double.parse(priceController.text),
        'location': locationController.text,
        // Removed: 'quantity': quantity,
        'createdAt': FieldValue.serverTimestamp(),
        'productName': name,
        'productDescription': descrip,
        'discountPercentage': _randomDisplayPercentage,
        'imageUrl': (imageUrl is List) ? imageUrl[0] : imageUrl,
        'views': 0,
        'availableColors': colors,
        'subaccountCode': subaccountCode, // ✅ Added subaccount code
      });

      // Clear controllers and provide success feedback
      priceController.clear();
      locationController.clear();
      singleColorController.clear(); // Clear single color controller
      _tempColors.clear(); // Clear temporary colors list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
        Navigator.pop(context); // Close the bottom sheet
      }

      setState(
        () {},
      ); // Rebuild to refresh the filtered list of available products
    } catch (e) {
      print("Error adding seller product: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding product: $e')));
      }
    }
  }

  // --- EXISTING: updateSellerProductPrice ---
  Future<void> updateSellerProductPrice(String docId, double newPrice) async {
    final color = Theme.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('seller_products')
          .doc(docId)
          .update({'price': newPrice});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Price updated successfully!'),
            backgroundColor: color.primaryColor,
          ),
        );
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating price: $e'),
            backgroundColor: color.primaryColorDark,
          ),
        );
      }
      print('Error updating seller product price: $e');
    }
  }

  // --- EXISTING: updateOrderStatus ---
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final color = Theme.of(context);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': newStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Order status updated to "${newStatus.toUpperCase().replaceAll('_', ' ')}!"',
            ),
            backgroundColor: color.primaryColor,
          ),
        );
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order status: $e'),
            backgroundColor: color.primaryColorDark,
          ),
        );
      }
      print('Error updating order status: $e');
    }
  }

  // --- Dashboard Tab Widget ---
  Widget dashboardTab() {
    final currentSellerId = user?.uid;
    if (currentSellerId == null) {
      return const Center(child: Text("Please log in to view your dashboard."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Shop Performance Overview",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 20),

          // Total Products Listed Card
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('seller_products')
                .where('sellerId', isEqualTo: currentSellerId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildDashboardCard(
                  "Total Products Listed",
                  "Loading...",
                  Icons.storage,
                );
              }
              final totalProducts = snapshot.data?.docs.length ?? 0;
              return _buildDashboardCard(
                "Total Products Listed",
                totalProducts.toString(),
                Icons.storage,
              );
            },
          ),
          const SizedBox(height: 15),

          // Total Orders Received & Total Revenue Card
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('orders').get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: [
                    _buildDashboardCard(
                      "Total Orders Received",
                      "Loading...",
                      Icons.shopping_bag,
                    ),
                    const SizedBox(height: 15),
                    _buildDashboardCard(
                      "Total Revenue (Your Products)",
                      "Loading...",
                      Icons.attach_money,
                    ),
                  ],
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    _buildDashboardCard(
                      "Total Orders Received",
                      "Error",
                      Icons.error,
                    ),
                    const SizedBox(height: 15),
                    _buildDashboardCard(
                      "Total Revenue (Your Products)",
                      "Error",
                      Icons.error,
                    ),
                  ],
                );
              }

              int totalOrdersForSeller = 0;
              double totalRevenueForSeller = 0.0;
              final allOrders = snapshot.data?.docs ?? [];

              for (var orderDoc in allOrders) {
                final orderData = orderDoc.data() as Map<String, dynamic>;
                final List<dynamic> productsInOrder =
                    orderData['products'] ?? [];

                bool containsSellerProduct = false;
                double orderRevenueFromSeller = 0.0;

                for (var productItem in productsInOrder) {
                  if (productItem is Map<String, dynamic> &&
                      productItem['sellerId'] == currentSellerId) {
                    containsSellerProduct = true;
                    orderRevenueFromSeller +=
                        (productItem['itemTotalPrice'] as num?)?.toDouble() ??
                        0.0;
                  }
                }

                if (containsSellerProduct) {
                  totalOrdersForSeller++;
                  totalRevenueForSeller += orderRevenueFromSeller;
                }
              }

              return Column(
                children: [
                  _buildDashboardCard(
                    "Total Orders Received",
                    totalOrdersForSeller.toString(),
                    Icons.shopping_bag,
                  ),
                  const SizedBox(height: 15),
                  _buildDashboardCard(
                    "Total Revenue (Your Products)",
                    "R${totalRevenueForSeller.toStringAsFixed(2)}",
                    Icons.attach_money,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 15),

          // Total Product Views Card
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('seller_products')
                .where('sellerId', isEqualTo: currentSellerId)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildDashboardCard(
                  "Total Product Views",
                  "Loading...",
                  Icons.visibility,
                );
              }
              if (snapshot.hasError) {
                return _buildDashboardCard(
                  "Total Product Views",
                  "Error",
                  Icons.error,
                );
              }

              int totalViews = 0;
              final sellerProducts = snapshot.data?.docs ?? [];
              for (var doc in sellerProducts) {
                final data = doc.data() as Map<String, dynamic>;
                totalViews += (data['views'] as int?) ?? 0;
              }
              return _buildDashboardCard(
                "Total Product Views",
                totalViews.toString(),
                Icons.visibility,
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            "Note: Product views are incremented when customers interact with your products on the shopping page.",
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for dashboard cards
  Widget _buildDashboardCard(String title, String value, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- My Products Tab Widget ---
  Widget myProductsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('seller_products')
          .where('sellerId', isEqualTo: user?.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No products added yet."));
        }

        final sellerProds = snapshot.data!.docs;

        return ListView.builder(
          itemCount: sellerProds.length,
          itemBuilder: (context, index) {
            final doc = sellerProds[index];
            final data = doc.data() as Map<String, dynamic>;
            final String docId = doc.id;

            final productName = data['productName'] ?? 'Unnamed Product';
            final imageUrl = data['imageUrl'];
            // Removed: final quantity = data['quantity'] ?? 0;
            final currentPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
            final productViews = (data['views'] as int?) ?? 0; // Get views
            final List<dynamic> availableColorsDynamic =
                data['availableColors'] ?? []; // Retrieve colors
            final List<String> availableColors = availableColorsDynamic
                .map((c) => c.toString())
                .toList();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading:
                    imageUrl != null &&
                        (imageUrl is String && imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        height: 50,
                        width: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image),
                      )
                    : const Icon(Icons.image_not_supported),
                title: Text(productName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Price: R${currentPrice.toStringAsFixed(2)}", // Quantity removed here
                    ),
                    Text(
                      "Location: ${data['location'] ?? 'N/A'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Views: $productViews",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (availableColors.isNotEmpty)
                      Text(
                        "Colors: ${availableColors.join(', ')}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(Icons.edit, color: Theme.of(context).primaryColor),
                  onPressed: () {
                    final TextEditingController newPriceController =
                        TextEditingController(
                          text: currentPrice.toStringAsFixed(2),
                        );
                    showDialog(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text("Update Price for $productName"),
                          content: TextField(
                            controller: newPriceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: "New Price (R)",
                              hintText: "e.g., 175.50",
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Cancel"),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final double? updatedPrice = double.tryParse(
                                  newPriceController.text,
                                );
                                if (updatedPrice != null && updatedPrice >= 0) {
                                  await updateSellerProductPrice(
                                    docId,
                                    updatedPrice,
                                  );
                                  if (mounted) {
                                    Navigator.pop(context);
                                  }
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Please enter a valid positive number for price.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text("Update"),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- UPDATED: addProductTab Widget (with filtering, dynamic colors, and BottomSheet) ---
  Widget addProductTab() {
    if (user == null) {
      return const Center(child: Text("Please log in to add products."));
    }

    final String sellerId = user!.uid;

    return FutureBuilder<List<String>>(
      future: FirebaseFirestore.instance
          .collection('seller_products')
          .where('sellerId', isEqualTo: sellerId)
          .get()
          .then(
            (snapshot) =>
                snapshot.docs.map((doc) => doc['productId'] as String).toList(),
          ),
      builder: (context, existingProductIdsSnapshot) {
        if (existingProductIdsSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (existingProductIdsSnapshot.hasError) {
          return Center(
            child: Text(
              "Error fetching existing products: ${existingProductIdsSnapshot.error}",
            ),
          );
        }

        final List<String> existingProductIds =
            existingProductIdsSnapshot.data ?? [];

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance.collection('products').get(),
          builder: (context, allProductsSnapshot) {
            if (allProductsSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (allProductsSnapshot.hasError) {
              return Center(child: Text("Error: ${allProductsSnapshot.error}"));
            }
            if (!allProductsSnapshot.hasData ||
                allProductsSnapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text("No base products available to add."),
              );
            }

            final availableProducts = allProductsSnapshot.data!.docs.where((
              prod,
            ) {
              return !existingProductIds.contains(prod.id);
            }).toList();

            if (availableProducts.isEmpty) {
              return const Center(
                child: Text("You have added all available products."),
              );
            }

            return ListView.builder(
              itemCount: availableProducts.length,
              itemBuilder: (context, index) {
                final prod = availableProducts[index];
                final String adminProductName =
                    prod['name'] ?? 'Unnamed Product (Admin)';
                final String adminProductDescription =
                    prod['description'] ?? 'No description (Admin)';
                final dynamic adminProductImageUrl = prod['imageUrl'];

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading:
                        adminProductImageUrl != null &&
                            (adminProductImageUrl is String ||
                                (adminProductImageUrl is List &&
                                    adminProductImageUrl.isNotEmpty))
                        ? Image.network(
                            (adminProductImageUrl is List)
                                ? adminProductImageUrl[0]
                                : adminProductImageUrl,
                            height: 50,
                            width: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                          )
                        : const Icon(Icons.image_not_supported),
                    title: Text(
                      adminProductName,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      adminProductDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      // Clear controllers and temp colors when opening the bottom sheet
                      priceController.clear();
                      locationController.clear();
                      singleColorController.clear();
                      setState(() {
                        _tempColors
                            .clear(); // Clear temp colors for new product
                      });

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) {
                          return StatefulBuilder(
                            // Use StatefulBuilder to update sheet content
                            builder: (BuildContext context, StateSetter setModalState) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(
                                    context,
                                  ).viewInsets.bottom,
                                  top: 20,
                                  left: 20,
                                  right: 20,
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Text(
                                          "Add Your Price, Location & Colors for:",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16.0,
                                          ),
                                          child: Text(
                                            adminProductName,
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      TextField(
                                        controller: priceController,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: "Price (R)",
                                          hintText: "e.g., 150.00",
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Removed: Quantity TextField
                                      FutureBuilder(
                                        future: FirebaseFirestore.instance
                                            .collection('users')
                                            .where('role', isEqualTo: 'Seller')
                                            .where(
                                              'email',
                                              isEqualTo: FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .email,
                                            )
                                            .get(),

                                        builder: (context, asyncSnapshot) {
                                          if (asyncSnapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          var data =
                                              asyncSnapshot.data!.docs.first;
                                          locationController.text =
                                              data['address'];
                                          return TextField(
                                            controller: locationController,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  "Location (e.g., Shop A12, Market St)",
                                              hintText:
                                                  "e.g., My Store Front, City",
                                              border: OutlineInputBorder(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 10),
                                      // NEW: Color Input with Add Button
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: singleColorController,
                                              decoration: const InputDecoration(
                                                labelText: "Add a Color",
                                                hintText: "e.g., Red",
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () {
                                              final String color =
                                                  singleColorController.text
                                                      .trim();
                                              if (color.isNotEmpty &&
                                                  !_tempColors.contains(
                                                    color,
                                                  )) {
                                                setModalState(() {
                                                  _tempColors.add(color);
                                                  singleColorController.clear();
                                                });
                                              } else if (_tempColors.contains(
                                                color,
                                              )) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Color already added!',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 15,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text("Add"),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      // Display Added Colors
                                      if (_tempColors.isNotEmpty)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Colors Added:",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Wrap(
                                              spacing: 8.0,
                                              runSpacing: 4.0,
                                              children: _tempColors.map((
                                                color,
                                              ) {
                                                return Chip(
                                                  label: Text(color),
                                                  deleteIcon: const Icon(
                                                    Icons.close,
                                                  ),
                                                  onDeleted: () {
                                                    setModalState(() {
                                                      _tempColors.remove(color);
                                                    });
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        )
                                      else
                                        const Text(
                                          "No colors added yet.",
                                          style: TextStyle(color: Colors.grey),
                                        ),

                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              Navigator.pop(context);
                                            },
                                            child: const Text("Cancel"),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () async {
                                              if (priceController
                                                      .text
                                                      .isEmpty ||
                                                  locationController
                                                      .text
                                                      .isEmpty) {
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Please fill in all fields: price and location.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                                return;
                                              }

                                              try {
                                                Api().showLoading(context);
                                                await addSellerProduct(
                                                  prod.id,
                                                  adminProductName,
                                                  adminProductDescription,
                                                  // Removed: quantity,
                                                  adminProductImageUrl,
                                                  _tempColors, // Pass the dynamically built list of colors
                                                );
                                                Navigator.pop(context);
                                              } catch (e) {
                                                Navigator.pop(context);
                                                if (mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'Error adding product: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text("Submit"),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blueAccent;
      case 'processing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.teal;
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Icons.access_time;
      case 'paid':
        return Icons.payment;
      case 'processing':
        return Icons.autorenew; 
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle_outline;
       
      default:
        return Icons.info_outline;
    }
  }

  // Your updated widget
  Widget ordersTab(
    User? user,
    BuildContext context,
    Function(String, String) updateOrderStatus,
    List<String> orderStatuses,
  ) {
    final currentSellerId = user?.uid;

    if (currentSellerId == null) {
      return const Center(child: Text("Please log in to view your sales."));
    }

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No orders found."));
        }

        final relevantOrders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: relevantOrders.length,
          itemBuilder: (context, index) {
            final orderDoc = relevantOrders[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id;
            final customerId = orderData['userId'] as String;

            final orderRef =
                orderData['orderReference'] ??
                orderId.substring(0, 8).toUpperCase();
            final currentStatus = orderData['status'] ?? 'pending';
            final orderDate = (orderData['createdAt'] as Timestamp?)?.toDate();

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(customerId)
                  .get(),
              builder: (context, customerSnapshot) {
                String customerName = 'Unknown Customer';
                if (customerSnapshot.connectionState == ConnectionState.done &&
                    customerSnapshot.hasData) {
                  final customerData =
                      customerSnapshot.data!.data() as Map<String, dynamic>?;
                  if (customerData != null &&
                      customerData.containsKey('name')) {
                    customerName = customerData['name'] ?? 'Unknown Customer';
                  }
                }

                return Card(
                  color: Colors.grey[50],
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: _buildOrderSummary(
                      orderRef: orderRef,
                      customerName: customerName,
                      orderDate: orderDate,
                      currentStatus: currentStatus,
                      context: context,
                    ),
                    children: [
                      _buildOrderDetails(
                        context,
                        orderData,
                        orderId,
                        currentSellerId,
                        orderStatuses,
                        updateOrderStatus,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // Helper widget for the collapsed order view
  Widget _buildOrderSummary({
    required String orderRef,
    required String customerName,
    required DateTime? orderDate,
    required String currentStatus,
    required BuildContext context,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Order #${orderRef}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(currentStatus).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(currentStatus),
                    color: _getStatusColor(currentStatus),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      currentStatus.toUpperCase().replaceAll('_', ' '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(currentStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Customer: $customerName',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 4),
        Text(
          'Date: ${orderDate != null ? DateFormat('dd MMM yyyy HH:mm').format(orderDate) : 'N/A'}',
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }

  // Helper widget for the expanded order view
  Widget _buildOrderDetails(
    BuildContext context,
    Map<String, dynamic> orderData,
    String orderId,
    String currentSellerId,
    List<String> orderStatuses,
    Function(String, String) updateOrderStatus,
  ) {
    final orderProducts = orderData['products'] as List<dynamic>? ?? [];
    final sellerSpecificProducts = orderProducts
        .where(
          (p) => p is Map<String, dynamic> && p['sellerId'] == currentSellerId,
        )
        .toList();

    double sellerProductsTotal = 0.0;
    for (var prod in sellerSpecificProducts) {
      sellerProductsTotal +=
          (prod['itemTotalPrice'] as num?)?.toDouble() ?? 0.0;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Products Total: R${sellerProductsTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.green,
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Total Paid by Customer (Full Order): R${(orderData['totalPaidAmount'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            'Payment Method: ${orderData['paymentMethod'] ?? 'N/A'}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Delivery: ${orderData['needsDelivery'] ? 'Needed' : 'Collection'}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (orderData['needsDelivery'])
            Text(
              'Delivery Address: ${orderData['address'] ?? 'Not provided'}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          const SizedBox(height: 16),
          const Text(
            'Items in this Order:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...sellerSpecificProducts.map<Widget>((product) {
            final prodName = product['productName'] ?? 'Unknown Product';
            final prodQty = product['quantity'] ?? 1;
            final prodPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
            final prodTotal =
                (product['itemTotalPrice'] as num?)?.toDouble() ?? 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$prodName (x$prodQty) @ R${prodPrice.toStringAsFixed(2)} each = R${prodTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  _showStatusUpdateDialog(
                    context,
                    orderId,
                    orderData['status'] ?? 'pending',
                    orderStatuses,
                    updateOrderStatus,
                  );
                },
                icon: const Icon(Icons.edit),
                label: const Text("Update Status"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(
    BuildContext context,
    String orderId,
    String currentStatus,
    List<String> orderStatuses,
    Function(String, String) updateOrderStatus,
  ) {
    String? tempSelectedStatus = currentStatus;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Update Order Status"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: orderStatuses.map((status) {
                    return RadioListTile<String>(
                      title: Text(status.toUpperCase().replaceAll('_', ' ')),
                      value: status,
                      groupValue: tempSelectedStatus,
                      onChanged: (value) {
                        setDialogState(() {
                          tempSelectedStatus = value;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (tempSelectedStatus != null &&
                        tempSelectedStatus != currentStatus) {
                      await updateOrderStatus(orderId, tempSelectedStatus!);
                      if (context.mounted) Navigator.pop(context);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No status selected or no change.'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    }
                  },
                  icon: const Icon(Icons.update),
                  label: const Text("Confirm Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: color.primaryColor,
            unselectedLabelColor: color.hintColor,
            indicatorColor: color.primaryColor,
            tabs: const [
              Tab(text: "Dashboard", icon: Icon(Icons.dashboard)),
              Tab(text: "My Products", icon: Icon(Icons.inventory)),
              Tab(text: "Add Product", icon: Icon(Icons.add_shopping_cart)),
              Tab(text: "Orders", icon: Icon(Icons.local_shipping)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                dashboardTab(),
                myProductsTab(),
                addProductTab(), // This is now the updated addProductTab
                ordersTab(user, context, updateOrderStatus, orderStatuses),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
