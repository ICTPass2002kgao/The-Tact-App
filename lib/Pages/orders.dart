import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;

  // Define your order statuses here. This sequence is important for the tracker.
  // Make sure these match the 'status' values you use in Firestore.
  final List<String> _orderStatuses = [
    'pending_payment', // Initial status after creating payment link
    'paid', // After successful payment (webhook)
    'processing', // Seller starts preparing the order
    'ready_for_pickup', // For collection orders
    'shipped', // For delivery orders
    'delivered', // Final stage
    // 'cancelled' is a terminal, non-sequential status.
    // We'll handle it separately in the UI.
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    // Consider adding a FirebaseAuth.instance.authStateChanges().listen()
    // if you want this page to react live to login/logout.
  }

  // Helper function to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.blueAccent; // Distinct color for paid
      case 'processing':
        return Colors.blue;
      case 'ready_for_pickup':
        return Colors.teal; // For pickup specific
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

  // Helper function to get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending_payment':
      case 'pending':
        return Icons.access_time;
      case 'paid':
        return Icons.payment; // Icon for paid
      case 'processing':
        return Icons.autorenew;
      case 'ready_for_pickup':
        return Icons.storefront; // Icon for pickup
      case 'shipped':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context);

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Orders'),
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: colorScheme.scaffoldBackgroundColor,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 100,
                  color: colorScheme.primaryColor.withOpacity(0.6),
                ),
                const SizedBox(height: 20),
                Text(
                  'Please log in to view your orders.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.hintColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'You need to be logged in to see your order history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.hintColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to your login page
                    Navigator.pushNamed(
                      context,
                      '/login',
                    ); // Adjust route as needed
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Log In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryColor,
                    foregroundColor: colorScheme.scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Orders'),
        backgroundColor: colorScheme.primaryColor,
        foregroundColor: colorScheme.scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Listen to orders for the current user, ordered by creation time
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where(
              'userId',
              isEqualTo:
                  '${_currentUser!.uid}', // Adjust this to your user ID logic
            ) // Adjust this to your sellerId logic
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error);
            return Center(
              child: Text(
                'Error loading orders: ${snapshot.error}',
                style: TextStyle(color: colorScheme.primaryColorDark),
                textAlign: TextAlign.center,
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 100,
                      color: colorScheme.primaryColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No orders yet!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primaryColorDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Looks like you haven\'t placed any orders. Start shopping now!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.primaryColorDark.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Go back to shopping page
                      },
                      icon: const Icon(Icons.storefront),
                      label: const Text('Explore Products'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primaryColor,
                        foregroundColor: colorScheme.scaffoldBackgroundColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final order =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final orderId = snapshot.data!.docs[index].id;
              final List<dynamic> products = order['products'] ?? [];
              final String status = order['status'] ?? 'unknown';
              final Timestamp? createdAt = order['createdAt'] as Timestamp?;
              final double totalAmount =
                  (order['amount'] as num?)?.toDouble() ?? 0.0; // Use amount
              final String address = order['address'] ?? 'N/A';
              final bool needsDelivery = order['needsDelivery'] ?? false;
              final double deliveryCharge =
                  (order['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
              final String paymentMethod = order['paymentMethod'] ?? 'N/A';
              final String orderReference =
                  order['orderReference'] ??
                  orderId.substring(0, 8).toUpperCase();

              return Card(
                color: colorScheme.scaffoldBackgroundColor.withOpacity(0.7),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Order ID: #${orderReference}', // Use orderReference
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize
                                  .min, // Make sure it only takes necessary space
                              children: [
                                Icon(
                                  _getStatusIcon(status),
                                  color: _getStatusColor(status),
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    status.toUpperCase().replaceAll(
                                      '_',
                                      ' ',
                                    ), // Format status for display
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Order Date: ${createdAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt.toDate()) : 'N/A'}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const Divider(height: 20),

                      // --- Order Status Tracker ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: OrderStatusTracker(
                          currentStatus: status,
                          allStatuses: _orderStatuses,
                          needsDelivery: needsDelivery,
                          getStatusIcon: _getStatusIcon,
                          getStatusColor: _getStatusColor,
                        ),
                      ),
                      const Divider(height: 20),

                      Text(
                        'Items:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // List of Products
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        itemBuilder: (context, prodIndex) {
                          final product = products[prodIndex];
                          final String prodName =
                              product['productName'] ?? 'Unknown Product';
                          final double prodPrice =
                              (product['price'] as num?)?.toDouble() ?? 0.0;
                          final int prodQuantity =
                              (product['quantity'] as int?) ?? 1;
                          final String prodImageUrl =
                              product['imageUrl']?.toString() ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Product Image
                                if (prodImageUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4.0),
                                    child: Image.network(
                                      prodImageUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 40,
                                              height: 40,
                                              color: Colors.grey[200],
                                              child: Icon(
                                                Icons.image_not_supported,
                                                color: Colors.grey[400],
                                                size: 20,
                                              ),
                                            );
                                          },
                                    ),
                                  )
                                else
                                  Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                // Product Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        prodName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'R${prodPrice.toStringAsFixed(2)} x ${prodQuantity}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'R${(prodPrice * prodQuantity).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(height: 20),
                      // Delivery and Payment Info
                      _buildInfoRow(
                        'Delivery Type:',
                        needsDelivery
                            ? 'Delivery (R${deliveryCharge.toStringAsFixed(2)})'
                            : 'Collection',
                        Icons.delivery_dining,
                      ),
                      _buildInfoRow('Address:', address, Icons.home),
                      _buildInfoRow(
                        'Payment Method:',
                        paymentMethod,
                        Icons.payment,
                      ),
                      const Divider(height: 20),
                      // Total Amount
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'R${totalAmount.toStringAsFixed(2)}', // Use amount for consistency
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Optional: Add action buttons like "Contact Seller", "Track Order" etc.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Implement contact seller/support logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Contact Support functionality goes here!',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.support_agent),
                          label: const Text('Contact Support'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colorScheme.primaryColor,
                            side: BorderSide(color: colorScheme.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper widget for consistent info rows
  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW: OrderStatusTracker Widget ---
class OrderStatusTracker extends StatelessWidget {
  final String currentStatus;
  final List<String> allStatuses;
  final bool needsDelivery;
  final Function(String) getStatusIcon;
  final Function(String) getStatusColor;

  const OrderStatusTracker({
    super.key,
    required this.currentStatus,
    required this.allStatuses,
    required this.needsDelivery,
    required this.getStatusIcon,
    required this.getStatusColor,
  });

  @override
  Widget build(BuildContext context) { 
    // Handle 'cancelled' status specifically. It's a terminal state outside the linear flow.
    if (currentStatus.toLowerCase() == 'cancelled') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              Icon(Icons.cancel_outlined, size: 40, color: Colors.red),
              SizedBox(height: 8),
              Text(
                'ORDER CANCELLED',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Filter statuses based on whether delivery is needed
    List<String> displayStatuses = allStatuses.where((status) {
      if (needsDelivery) {
        return status !=
            'ready_for_pickup'; // Exclude pickup status for delivery orders
      } else {
        return status != 'shipped' &&
            status !=
                'delivered'; // Exclude shipping/delivery for pickup orders
      }
    }).toList();

    // Adjust currentStatusIndex for the filtered list
    final int displayCurrentStatusIndex = displayStatuses.indexOf(
      currentStatus.toLowerCase(),
    );

    return Column(
      children: List.generate(displayStatuses.length, (index) {
        final status = displayStatuses[index];
        final bool isActive = index <= displayCurrentStatusIndex;
        final bool isCurrent = index == displayCurrentStatusIndex;

        return Column(
          children: [
            Row(
              children: [
                // Step Indicator (Circle with Icon)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? getStatusColor(status)
                            : Colors.grey[300],
                        border:
                            isCurrent &&
                                !isActive // Only border if it's current but somehow not active (shouldn't happen with logic above)
                            ? Border.all(
                                color: getStatusColor(status),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Icon(
                        getStatusIcon(status),
                        color: isActive ? Colors.white : Colors.grey[700],
                        size: 18,
                      ),
                    ),
                    if (isActive && !isCurrent) // Checkmark for completed steps
                      Positioned.fill(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 30, // Covers the background circle nicely
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                // Status Text
                Expanded(
                  child: Text(
                    status.toUpperCase().replaceAll('_', ' '),
                    style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? getStatusColor(status)
                          : Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            // Connector Line (only if not the last step)
            if (index < displayStatuses.length - 1)
              Padding(
                padding: const EdgeInsets.only(
                  left: 14.0,
                ), // Align with center of circle
                child: Container(
                  height: 30, // Length of the line
                  width: 2, // Thickness of the line
                  color: isActive
                      ? getStatusColor(
                          displayStatuses[index + 1],
                        ).withOpacity(0.5)
                      : Colors.grey[300],
                ),
              ),
          ],
        );
      }),
    );
  }
}
