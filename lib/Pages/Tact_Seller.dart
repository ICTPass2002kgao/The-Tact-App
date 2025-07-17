import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class SellerProductPage extends StatefulWidget {
  @override
  _SellerProductPageState createState() => _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final priceController = TextEditingController();
  final locationController = TextEditingController();
  final quantityController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  final List<String> orderStatuses = [
    'pending',
    'processing',
    'ready_for_pickup',
    'dispatched',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    _tabController = TabController(
      length: 4,
      vsync: this,
    ); // Increased tab length to 4 for Dashboard
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    priceController.dispose();
    locationController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> addSellerProduct(
    String productId,
    String name,
    String descrip,
    int quantity,
    dynamic imageUrl,
  ) async {
    if (user == null ||
        priceController.text.isEmpty ||
        locationController.text.isEmpty ||
        quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill all fields correctly, including a valid quantity.',
          ),
        ),
      );
      return;
    }

    final existingProduct = await FirebaseFirestore.instance
        .collection('seller_products')
        .where('productId', isEqualTo: productId)
        .where('sellerId', isEqualTo: user!.uid)
        .get();

    if (existingProduct.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You have already listed this product. Consider updating it in "My Products" tab.',
          ),
        ),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('seller_products').add({
      'productId': productId,
      'sellerId': user!.uid,
      'price': double.parse(priceController.text),
      'location': locationController.text,
      'quantity': quantity,
      'createdAt': FieldValue.serverTimestamp(),
      'productName': name,
      'productDescription': descrip,
      'imageUrl': (imageUrl is List) ? imageUrl[0] : imageUrl,
      'views': 0, // Initialize views for new products
    });

    priceController.clear();
    locationController.clear();
    quantityController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Product added successfully!')));
    Navigator.pop(context);
  }

  Future<void> updateSellerProductPrice(String docId, double newPrice) async {
    final color = Theme.of(context);
    try {
      await FirebaseFirestore.instance
          .collection('seller_products')
          .doc(docId)
          .update({'price': newPrice});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Price updated successfully!'),
          backgroundColor: color.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating price: $e'),
          backgroundColor: color.primaryColorDark,
        ),
      );
      print('Error updating seller product price: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final color = Theme.of(context);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(
        {'status': newStatus},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Order status updated to "${newStatus.toUpperCase().replaceAll('_', ' ')}"!',
          ),
          backgroundColor: color.primaryColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order status: $e'),
          backgroundColor: color.primaryColorDark,
        ),
      );
      print('Error updating order status: $e');
    }
  }

  // Helper function for status colors
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.purple;
      case 'dispatched':
        return Colors.lightBlue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // --- Dashboard Tab Widget ---
  Widget dashboardTab() {
    final currentSellerId = user?.uid;
    if (currentSellerId == null) {
      return Center(child: Text("Please log in to view your dashboard."));
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
          SizedBox(height: 20),

          // Total Products Listed Card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('seller_products')
                .where('sellerId', isEqualTo: currentSellerId)
                .snapshots(),
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
          SizedBox(height: 15),

          // Total Orders Received & Total Revenue Card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('orders').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Column(
                  children: [
                    _buildDashboardCard(
                      "Total Orders Received",
                      "Loading...",
                      Icons.shopping_bag,
                    ),
                    SizedBox(height: 15),
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
                    SizedBox(height: 15),
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
                  SizedBox(height: 15),
                  _buildDashboardCard(
                    "Total Revenue (Your Products)",
                    "R${totalRevenueForSeller.toStringAsFixed(2)}",
                    Icons.attach_money,
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 15),

          // Total Product Views Card
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('seller_products')
                .where('sellerId', isEqualTo: currentSellerId)
                .snapshots(),
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
          SizedBox(height: 20),
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
            SizedBox(width: 15),
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
                SizedBox(height: 5),
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

  Widget myProductsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('seller_products')
          .where('sellerId', isEqualTo: user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No products added yet."));
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
            final quantity = data['quantity'] ?? 0;
            final currentPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
            final productViews = (data['views'] as int?) ?? 0; // Get views

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            Icon(Icons.broken_image),
                      )
                    : Icon(Icons.image_not_supported),
                title: Text(productName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Price: R${currentPrice.toStringAsFixed(2)} • Quantity: ${quantity}",
                    ),
                    Text(
                      "Location: ${data['location'] ?? 'N/A'}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Views: $productViews", // Display views here
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
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: "New Price (R)",
                              hintText: "e.g., 175.50",
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text("Cancel"),
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
                                  Navigator.pop(context);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Please enter a valid positive number for price.',
                                      ),
                                    ),
                                  );
                                }
                              },
                              child: Text("Update"),
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

  Widget addProductTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('products').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No products available to add."));
        }

        final products = snapshot.data!.docs;

        return ListView.builder(
          itemCount: products.length,
          itemBuilder: (context, index) {
            final prod = products[index];
            final String adminProductName =
                prod['name'] ?? 'Unnamed Product (Admin)';
            final String adminProductDescription =
                prod['description'] ?? 'No description (Admin)';
            final dynamic adminProductImageUrl = prod['imageUrl'];

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            Icon(Icons.broken_image),
                      )
                    : Icon(Icons.image_not_supported),
                title: Text(adminProductName),
                subtitle: Text(adminProductDescription),
                onTap: () {
                  priceController.clear();
                  locationController.clear();
                  quantityController.clear();

                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        "Add Your Price, Quantity & Location for: ${adminProductName}",
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              "Product: ${adminProductName}",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Price (R)",
                              hintText: "e.g., 150.00",
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: quantityController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Quantity in Stock",
                              hintText: "e.g., 100",
                            ),
                          ),
                          SizedBox(height: 10),
                          TextField(
                            controller: locationController,
                            decoration: InputDecoration(
                              labelText: "Location (e.g., Shop A12, Market St)",
                              hintText: "e.g., My Store Front, City",
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            if (priceController.text.isEmpty ||
                                locationController.text.isEmpty ||
                                quantityController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please fill in all fields: price, quantity, and location.',
                                  ),
                                ),
                              );
                              return;
                            }

                            final int? quantity = int.tryParse(
                              quantityController.text,
                            );
                            if (quantity == null || quantity <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Please enter a valid positive number for quantity.',
                                  ),
                                ),
                              );
                              return;
                            }

                            try {
                              await addSellerProduct(
                                prod.id,
                                adminProductName,
                                adminProductDescription,
                                quantity,
                                adminProductImageUrl,
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding product: $e'),
                                ),
                              );
                            }
                          },
                          child: Text("Submit"),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget ordersTab() {
    final currentSellerId = user?.uid;

    if (currentSellerId == null) {
      return Center(child: Text("Please log in to view orders."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No orders found."));
        }

        final allOrders = snapshot.data!.docs;
        List<DocumentSnapshot> relevantOrders = [];

        for (var orderDoc in allOrders) {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          final List<dynamic> productsInOrder = orderData['products'] ?? [];

          bool containsSellerProduct = false;
          for (var productItem in productsInOrder) {
            if (productItem is Map<String, dynamic> &&
                productItem['sellerId'] == currentSellerId) {
              containsSellerProduct = true;
              break;
            }
          }
          if (containsSellerProduct) {
            relevantOrders.add(orderDoc);
          }
        }

        if (relevantOrders.isEmpty) {
          return Center(child: Text("No orders found for your products."));
        }

        return ListView.builder(
          itemCount: relevantOrders.length,
          itemBuilder: (context, index) {
            final orderDoc = relevantOrders[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id;

            final orderProducts = orderData['products'] as List<dynamic>? ?? [];
            final orderDate = (orderData['createdAt'] as Timestamp?)?.toDate();
            final formattedDate = orderDate != null
                ? DateFormat('dd MMM yyyy HH:mm').format(orderDate)
                : 'N/A';
            final customerName =
                orderData['customerName'] ?? 'Unknown Customer';
            final totalPaid =
                (orderData['totalPaidAmount'] as num?)?.toDouble() ?? 0.0;
            final deliveryNeeded = orderData['needsDelivery'] ?? false;
            final deliveryAddress = orderData['address'] ?? 'Not provided';
            final orderRef =
                orderData['orderReference'] ??
                orderId.substring(0, 8).toUpperCase();
            final currentStatus = orderData['status'] ?? 'pending';

            final sellerSpecificProducts = orderProducts
                .where(
                  (p) =>
                      p is Map<String, dynamic> &&
                      p['sellerId'] == currentSellerId,
                )
                .toList();

            if (sellerSpecificProducts.isEmpty) {
              return SizedBox.shrink();
            }

            double sellerProductsTotal = 0.0;
            for (var prod in sellerSpecificProducts) {
              sellerProductsTotal +=
                  (prod['itemTotalPrice'] as num?)?.toDouble() ?? 0.0;
            }

            return Card(
              margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              elevation: 2,
              child: ExpansionTile(
                title: Text(
                  'Order #${orderRef}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customer: ${customerName}'),
                    Text('Date: ${formattedDate}'),
                    Chip(
                      label: Text(
                        'Status: ${currentStatus.toUpperCase().replaceAll('_', ' ')}',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _getStatusColor(currentStatus),
                    ),
                    Text(
                      'Your Products Total: R${sellerProductsTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Order ID: $orderId',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Customer Email: ${orderData['customerEmail'] ?? 'N/A'}',
                        ),
                        Text(
                          'Payment Method: ${orderData['paymentMethod'] ?? 'N/A'}',
                        ),
                        Text(
                          'Total Paid by Customer (Full Order): R${totalPaid.toStringAsFixed(2)}',
                        ),
                        if (deliveryNeeded) ...[
                          Text('Delivery Needed: Yes'),
                          Text('Delivery Address: ${deliveryAddress}'),
                          Text(
                            'Delivery Charge: R${(orderData['deliveryCharge'] as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'}',
                          ),
                        ] else ...[
                          Text('Delivery Needed: No (Collection)'),
                        ],
                        SizedBox(height: 10),
                        Text(
                          'Your Products in this Order:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sellerSpecificProducts.map<Widget>((
                            product,
                          ) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 8.0,
                                top: 4.0,
                              ),
                              child: Text(
                                '- ${product['productName']} (x${product['quantity']}) @ R${(product['price'] as num?)?.toDouble().toStringAsFixed(2)} each = R${(product['itemTotalPrice'] as num?)?.toDouble().toStringAsFixed(2)}',
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 10),
                        Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    // **Crucial Fix:**
                                    // Declare tempSelectedStatus here, inside the builder,
                                    // so it maintains its state across setDialogState calls.
                                    String? tempSelectedStatus = currentStatus;
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        return AlertDialog(
                                          title: Text("Update Order Status"),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: orderStatuses.map((
                                                status,
                                              ) {
                                                return RadioListTile<String>(
                                                  title: Text(
                                                    status
                                                        .toUpperCase()
                                                        .replaceAll('_', ' '),
                                                  ),
                                                  value: status,
                                                  groupValue:
                                                      tempSelectedStatus, // Use the state variable
                                                  onChanged: (value) {
                                                    setDialogState(() {
                                                      tempSelectedStatus =
                                                          value; // Update state and rebuild dialog
                                                    });
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                              },
                                              child: Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                if (tempSelectedStatus !=
                                                        null &&
                                                    tempSelectedStatus !=
                                                        currentStatus) {
                                                  await updateOrderStatus(
                                                    orderId,
                                                    tempSelectedStatus!,
                                                  );
                                                  Navigator.pop(context);
                                                } else {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'No status selected or no change.',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Text("Confirm Update"),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                              icon: Icon(Icons.update),
                              label: Text('Update Status'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Expanded(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: color.primaryColor,
              unselectedLabelColor: color.hintColor,
              indicatorColor: color.primaryColor,
              tabs: [
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
                  addProductTab(),
                  ordersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
