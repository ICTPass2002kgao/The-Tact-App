import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}
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
  String _userRole = 'customer';

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
        return isIOSPlatform ? CupertinoIcons.time : Icons.access_time;
      case 'paid':
        return isIOSPlatform
            ? CupertinoIcons.check_mark_circled
            : Icons.payment;
      case 'processing':
        return isIOSPlatform
            ? CupertinoIcons.arrow_2_circlepath
            : Icons.autorenew;
      case 'shipped':
        return isIOSPlatform ? CupertinoIcons.bus : Icons.local_shipping;
      case 'delivered':
        return isIOSPlatform
            ? CupertinoIcons.check_mark_circled
            : Icons.check_circle_outline;
      default:
        return isIOSPlatform ? CupertinoIcons.info : Icons.info_outline;
    }
  }

  // ⭐️ NEW: Method to show BOTTOM SHEET and send email
  void _handleContactSupport(
    BuildContext context,
    String sellerEmail,
    String orderId,
    String sellerName,
  ) {
    final TextEditingController messageController = TextEditingController();
    final theme = Theme.of(context);

    // Using showModalBottomSheet instead of showDialog
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Important for keyboard handling
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          // This padding ensures the sheet moves up when keyboard appears
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. Title
                Text(
                  "Contact Seller",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Enter your message below:"),
                const SizedBox(height: 15),

                // 3. Input Field (Platform Adaptive)
                if (isIOSPlatform)
                  CupertinoTextField(
                    controller: messageController,
                    placeholder: "Type your message here...",
                    maxLines: 4,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                else
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: "Type your message here...",
                      border: OutlineInputBorder(),
                    ),
                  ),

                const SizedBox(height: 20),

                // 4. Action Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: isIOSPlatform
                          ? CupertinoButton(
                              child: const Text("Cancel"),
                              onPressed: () => Navigator.pop(context),
                            )
                          : TextButton(
                              child: const Text("Cancel"),
                              onPressed: () => Navigator.pop(context),
                            ),
                    ),
                    const SizedBox(width: 10),
                    // Send Button
                    Expanded(
                      child: isIOSPlatform
                          ? CupertinoButton.filled(
                              child: const Text("Send Email"),
                              onPressed: () {
                                _sendSupportEmail(
                                  sellerEmail,
                                  orderId,
                                  messageController.text,
                                  sellerName,
                                );
                                Navigator.pop(context);
                              },
                            )
                          : ElevatedButton.icon(
                              icon: const Icon(Icons.send),
                              label: const Text("Send Email"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryColor,
                                foregroundColor: theme.scaffoldBackgroundColor,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                _sendSupportEmail(
                                  sellerEmail,
                                  orderId,
                                  messageController.text,
                                  sellerName,
                                );
                                Navigator.pop(context);
                              },
                            ),
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
  }

  // ⭐️ LOGIC to actually send the email
  void _sendSupportEmail(
    String sellerEmail,
    String orderId,
    String message,
    String sellerName,
  ) {
    if (message.trim().isEmpty) {
      Api().showMessage(
        context,
        "Message cannot be empty",
        "Error",
        Colors.red,
      );
      return;
    }

    final recipient = (sellerEmail.isNotEmpty)
        ? sellerEmail
        : "support@dankie.com";
    final buyerEmail = _currentUser?.email ?? "Unknown User";
    final buyerName = _currentUser?.displayName ?? "A Customer";

    Api().sendEmail(recipient, 'Inquiry regarding Order #$orderId', """
      <p>Hello $sellerName,</p>
      
      <p>You have received a new inquiry from a customer regarding <strong>Order #$orderId</strong>.</p>
      
      <p><strong>Customer:</strong> $buyerName ($buyerEmail)</p>
      
      <hr />
      <p><strong>Message:</strong></p>
      <blockquote style="background: #f9f9f9; border-left: 5px solid #ccc; margin: 1.5em 10px; padding: 0.5em 10px;">
        $message
      </blockquote>
      <hr />
      
      <p>Please respond to the customer as soon as possible.</p>
      
      <br>
      <p>Regards,<br>
      Dankie Mobile Support System</p>
      """, context);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return _buildLoggedOutPage();
    }
    return _userRole == 'Seller'
        ? _buildSellerOrdersList()
        : _buildCustomerOrdersList();
  }

  Widget _buildLoggedOutPage() {
    final colorScheme = Theme.of(context);
    final bodyContent = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isIOSPlatform
                    ? CupertinoIcons.person_badge_minus
                    : Icons.person_off_outlined,
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
              const SizedBox(height: 30),
              if (isIOSPlatform)
                CupertinoButton.filled(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  child: const Text('Log In'),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Log In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primaryColor,
                    foregroundColor: colorScheme.scaffoldBackgroundColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (isIOSPlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Your Orders'),
          backgroundColor: colorScheme.primaryColor,
        ),
        child: Material(child: bodyContent),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Orders'),
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: colorScheme.scaffoldBackgroundColor,
        ),
        body: bodyContent,
      );
    }
  }

  Widget _buildCustomerOrdersList() {
    final colorScheme = Theme.of(context);
    final body = Center(
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
              return Center(
                child: isIOSPlatform
                    ? const CupertinoActivityIndicator()
                    : const CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading orders: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                'No orders yet!',
                'Start shopping now!',
                isIOSPlatform
                    ? CupertinoIcons.bag
                    : Icons.shopping_bag_outlined,
                'Explore Products',
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
    );

    if (isIOSPlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Your Orders'),
          backgroundColor: colorScheme.primaryColor,
          leading: CupertinoNavigationBarBackButton(
            color: Colors.white,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        child: Material(type: MaterialType.transparency, child: body),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Your Orders'),
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: colorScheme.scaffoldBackgroundColor,
          centerTitle: true,
        ),
        body: body,
      );
    }
  }

  Widget _buildSellerOrdersList() {
    final colorScheme = Theme.of(context);
    final body = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('orders')
              .where('products.sellerId', arrayContains: _currentUser!.uid)
              .orderBy('createdAt', descending: true)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: isIOSPlatform
                    ? const CupertinoActivityIndicator()
                    : const CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading sales: ${snapshot.error}'),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(
                'No sales yet!',
                'Your products will appear here.',
                isIOSPlatform ? CupertinoIcons.shopping_cart : Icons.storefront,
                'Manage Products',
                () {
                  Navigator.pushNamed(
                    context,
                    '/main-menu',
                    arguments: {'initialTab': 'seller'},
                  );
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
    );

    if (isIOSPlatform) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('My Sales'),
          backgroundColor: colorScheme.primaryColor,
          leading: CupertinoNavigationBarBackButton(
            color: Colors.white,
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        child: Material(type: MaterialType.transparency, child: body),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Sales'),
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: colorScheme.scaffoldBackgroundColor,
          centerTitle: true,
        ),
        body: body,
      );
    }
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
      color: colorScheme.scaffoldBackgroundColor.withOpacity(0.9),
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
        children: [_buildOrderDetails(context, order, orderReference)],
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
                'Order ID: #$orderReference',
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

  Widget _buildOrderDetails(
    BuildContext context,
    Map<String, dynamic> order,
    String orderReference,
  ) {
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

    // Extract Seller Info for Contact Button
    String sellerEmail = '';
    String sellerName = 'Seller';
    if (products.isNotEmpty) {
      sellerEmail = products[0]['sellerEmail'] ?? '';
      sellerName = products[0]['sellerName'] ?? 'Seller';
    }

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
                    if (prodImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.0),
                        child: Image.network(
                          prodImageUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey[400],
                                ),
                              ),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 40,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
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
                            'Variant: $selectedColor / $selectedSize',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          Text(
                            'R${prodPrice.toStringAsFixed(2)} x $prodQuantity',
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
            isIOSPlatform ? CupertinoIcons.cube_box : Icons.delivery_dining,
          ),
          if (needsDelivery)
            _buildInfoRow(
              'Delivery Charge:',
              'R${deliveryCharge.toStringAsFixed(2)}',
              isIOSPlatform ? CupertinoIcons.money_dollar : Icons.payments,
            ),
          _buildInfoRow(
            'Address:',
            address,
            isIOSPlatform ? CupertinoIcons.home : Icons.home,
          ),
          _buildInfoRow(
            'Payment Method:',
            paymentMethod,
            isIOSPlatform ? CupertinoIcons.creditcard : Icons.payment,
          ),
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

          // ⭐️ UPDATED BUTTON: CONTACT SELLER (Opens Bottom Sheet)
          SizedBox(
            width: double.infinity,
            child: isIOSPlatform
                ? CupertinoButton(
                    color: colorScheme.primaryColor,
                    onPressed: () {
                      _handleContactSupport(
                        context,
                        sellerEmail,
                        orderReference,
                        sellerName,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(CupertinoIcons.mail),
                        SizedBox(width: 8),
                        Text('Contact Seller'),
                      ],
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: () {
                      _handleContactSupport(
                        context,
                        sellerEmail,
                        orderReference,
                        sellerName,
                      );
                    },
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Contact Seller'),
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
              if (isIOSPlatform)
                CupertinoButton.filled(
                  onPressed: onPressed,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon),
                      const SizedBox(width: 8),
                      Text(buttonText),
                    ],
                  ),
                )
              else
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
              Icon(
                isIOSPlatform
                    ? CupertinoIcons.xmark_circle
                    : Icons.cancel_outlined,
                size: 40,
                color: Colors.red,
              ),
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
