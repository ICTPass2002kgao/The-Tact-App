import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;
// --------------------------

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _currentUser;
  String _userRole = 'customer'; // Default role

  final List<String> _orderStatuses = [
    'pending_payment',
    'paid',
    'processing', 
    'shipped',
    'delivered',
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      _fetchUserRole();
    }
  }

  Future<void> _fetchUserRole() async {
    if (_currentUser != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'] ?? 'customer';
        });
      }
    }
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
      case 'shipped':
        return Colors.purple;
      case 'delivered':
        return Colors.green; 
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
          // Constrain the 'Log In' prompt on desktop
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 450),
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
                      Navigator.pushNamed(context, '/login');
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
        ),
      );
    }

    // Determine which list view to build based on user role
    return _userRole == 'Seller' ? _buildSellerOrdersList() : _buildCustomerOrdersList();
  }

  Widget _buildCustomerOrdersList() {
    final colorScheme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Orders'),
        backgroundColor: colorScheme.primaryColor,
        foregroundColor: colorScheme.scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: Center(
        // FIX: Constrain the list view for desktop
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: FutureBuilder<QuerySnapshot>(
            future: _firestore
                .collection('orders')
                .where('userId', isEqualTo: _currentUser!.uid)
                .orderBy('createdAt', descending: true)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading orders: ${snapshot.error}',
                    style: TextStyle(color: colorScheme.primaryColorDark),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(
                  'No orders yet!',
                  'Looks like you haven\'t placed any orders. Start shopping now!',
                  Icons.shopping_bag_outlined,
                  'Explore Products',
                  // Assuming '/main-menu' is the route to MotherPage which contains ShoppingPage
                  () => Navigator.pushNamed(context, '/main-menu'), 
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final order =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return _buildOrderExpansionTile(context, order);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSellerOrdersList() {
    final colorScheme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Sales'),
        backgroundColor: colorScheme.primaryColor,
        foregroundColor: colorScheme.scaffoldBackgroundColor,
        centerTitle: true,
      ),
      body: Center(
        // FIX: Constrain the list view for desktop
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: FutureBuilder<QuerySnapshot>(
            // NOTE: This query pattern can be very slow and expensive in Firestore
            // A better query would be to use a collection group query on 'seller_orders'
            // or a more specific array-contains query if possible.
            future: _firestore
                .collection('orders')
                // This query requires a Firestore index: products.sellerId arrayContains
                .where('products.sellerId', arrayContains: _currentUser!.uid) 
                .orderBy('createdAt', descending: true)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading sales: ${snapshot.error}',
                    style: TextStyle(color: colorScheme.primaryColorDark),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(
                  'No sales yet!',
                  'Your products will appear here once a customer places an order.',
                  Icons.storefront,
                  'Manage Products',
                  () {
                    // Navigate to the Seller Product Page (My Shop tab in MotherPage)
                    Navigator.pushNamed(context, '/main-menu', arguments: {'initialTab': 'seller'}); 
                  },
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final order =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final sellerProducts = (order['products'] as List<dynamic>?)
                      ?.where((p) => p['sellerId'] == _currentUser!.uid)
                      .toList();

                  if (sellerProducts == null || sellerProducts.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final sellerOrder = Map<String, dynamic>.from(order);
                  sellerOrder['products'] = sellerProducts;

                  return _buildOrderExpansionTile(context, sellerOrder);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildOrderExpansionTile(
    BuildContext context,
    Map<String, dynamic> order,
  ) {
    final colorScheme = Theme.of(context);
    final String status = order['status'] ?? 'unknown';
    final String orderReference =
        order['orderReference'] ??
        order['orderId']?.toString().substring(0, 8).toUpperCase() ??
        'N/A';
    final Timestamp? createdAt = order['createdAt'] as Timestamp?;

    return Card(
      color: colorScheme.scaffoldBackgroundColor.withOpacity(0.9), // Slightly opaque card
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16.0),
        title: _buildOrderSummary(
          orderReference: orderReference,
          createdAt: createdAt,
          status: status,
        ),
        children: [_buildOrderDetails(context, order)],
      ),
    );
  }

  Widget _buildOrderSummary({
    required String orderReference,
    required Timestamp? createdAt,
    required String status,
  }) { 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Order ID: #${orderReference}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      status.toUpperCase().replaceAll('_', ' '),
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
      ],
    );
  }

  Widget _buildOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final colorScheme = Theme.of(context);
    final List<dynamic> products = order['products'] ?? [];
    final String status = order['status'] ?? 'unknown';
    final double totalAmount =
        (order['totalPaidAmount'] as num?)?.toDouble() ?? 0.0;
    final String address = order['address'] ?? 'N/A';
    final bool needsDelivery = order['needsDelivery'] ?? false;
    final double deliveryCharge =
        (order['deliveryCharge'] as num?)?.toDouble() ?? 0.0;
    final String paymentMethod = order['paymentMethod'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 20),
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
              final int prodQuantity = (product['quantity'] as int?) ?? 1;
              final String prodImageUrl = product['imageUrl']?.toString() ?? '';
              final String selectedColor = product['selectedColor'] ?? 'N/A';
              final String selectedSize = product['selectedSize'] ?? 'N/A';


              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Product Image (40x40)
                    if (prodImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          prodImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            'Variant: ${selectedColor} / ${selectedSize}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
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

          _buildInfoRow(
            'Delivery Type:',
            needsDelivery ? 'Delivery' : 'Collection',
            Icons.delivery_dining,
          ),
          if (needsDelivery)
            _buildInfoRow(
              'Delivery Charge:',
              'R${deliveryCharge.toStringAsFixed(2)}',
              Icons.payments,
            ),
          _buildInfoRow('Address:', address, Icons.home),
          _buildInfoRow('Payment Method:', paymentMethod, Icons.payment),
          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'R${totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact Support functionality goes here!'),
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
    );
  }

  Widget _buildEmptyState(
    String title,
    String subtitle,
    IconData icon,
    String buttonText,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 100,
                color: colorScheme.primaryColor.withOpacity(0.6),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primaryColorDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.primaryColorDark.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(buttonText),
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

    List<String> displayStatuses = allStatuses.where((status) {
      if (needsDelivery) {
        return status != 'ready_for_pickup';
      } else {
        return status != 'shipped' && status != 'delivered';
      }
    }).toList();

    final int displayCurrentStatusIndex = displayStatuses.indexOf(
      currentStatus.toLowerCase(),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(displayStatuses.length, (index) {
        final status = displayStatuses[index];
        final bool isActive = index <= displayCurrentStatusIndex;
        final bool isCurrent = index == displayCurrentStatusIndex;
        final Color iconColor = isActive ? Colors.white : Colors.grey[700]!;
        final Color boxColor = isActive
            ? getStatusColor(status)
            : Colors.grey[300]!;
        final String statusName = status.toUpperCase().replaceAll('_', ' ');

        return Expanded(
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: boxColor,
                      border: isCurrent && !isActive
                          ? Border.all(color: getStatusColor(status), width: 2)
                          : null,
                    ),
                    child: Icon(
                      getStatusIcon(status),
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                statusName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isActive ? getStatusColor(status) : Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}