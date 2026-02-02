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

  // --- COLORS & STYLING ---
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

  // --- EMAIL LOGIC ---
  void _handleContactSupport(
    BuildContext context,
    String sellerEmail,
    String orderId,
    String sellerName,
  ) {
    final TextEditingController messageController = TextEditingController();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Neumorphic Base Color calculation
    final Color neumoBase = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: neumoBase,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "Contact Seller",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textTheme.bodyLarge?.color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Send a message regarding Order #$orderId",
                  style: TextStyle(color: theme.hintColor),
                ),
                const SizedBox(height: 20),

                // Neumorphic Input Field
                Container(
                  decoration: BoxDecoration(
                    color: neumoBase,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      // Inner Shadow for "Pressed" look
                      BoxShadow(
                        color: isDark ? Colors.black : Colors.grey.shade400,
                        offset: Offset(4, 4),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: isDark ? Colors.grey.shade800 : Colors.white,
                        offset: Offset(-4, -4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: messageController,
                    maxLines: 4,
                    style: TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: "Type your message here...",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: _buildNeumorphicButton(
                        context,
                        label: "Cancel",
                        icon: Icons.close,
                        isPrimary: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildNeumorphicButton(
                        context,
                        label: "Send",
                        icon: Icons.send_rounded,
                        isPrimary: true,
                        onTap: () {
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
      <p>Regards,<br>Dankie Mobile Support System</p>
      """, context);
  }

  // --- NEUMORPHIC BUTTON WIDGET ---
  Widget _buildNeumorphicButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isPrimary
        ? theme.primaryColor
        : Color.alphaBlend(
            theme.primaryColor.withOpacity(0.08),
            theme.scaffoldBackgroundColor,
          );
    final textColor = isPrimary ? Colors.white : theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.4),
              offset: Offset(4, 4),
              blurRadius: 10,
            ),
            BoxShadow(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              offset: Offset(-4, -4),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Calculate global neumorphic color
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    if (_currentUser == null) {
      return _buildLoggedOutPage(theme, neumoBaseColor);
    }

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            // ⭐️ CUSTOM NEUMORPHIC APP BAR ⭐️
            _buildNeumorphicAppBar(context, theme, neumoBaseColor),

            Expanded(
              child: _userRole == 'Seller'
                  ? _buildSellerOrdersList(theme, neumoBaseColor)
                  : _buildCustomerOrdersList(theme, neumoBaseColor),
            ),
          ],
        ),
      ),
    );
  }

  // ⭐️ CUSTOM APP BAR WIDGET ⭐️
  Widget _buildNeumorphicAppBar(
    BuildContext context,
    ThemeData theme,
    Color baseColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: baseColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            offset: Offset(0, 10),
            blurRadius: 15,
            spreadRadius: -5,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ⭐️ PLATFORM FRIENDLY BACK BUTTON ⭐️
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.4),
                    offset: Offset(4, 4),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white,
                    offset: Offset(-4, -4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                isIOSPlatform ? CupertinoIcons.back : Icons.arrow_back_rounded,
                color: theme.hintColor,
                size: 22,
              ),
            ),
          ),

          // TITLE
          Text(
            _userRole == 'Seller' ? 'MY SALES' : 'YOUR ORDERS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: theme.primaryColor,
            ),
          ),

          // SPACER FOR BALANCE
          SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLoggedOutPage(ThemeData theme, Color baseColor) {
    return Scaffold(
      backgroundColor: baseColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 80,
              color: theme.primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 20),
            Text(
              "Access Restricted",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            SizedBox(height: 30),
            Container(
              width: 200,
              child: _buildNeumorphicButton(
                context,
                label: "Login Now",
                icon: Icons.login,
                onTap: () => Navigator.pushNamed(context, '/login'),
                isPrimary: true,
              ),
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerOrdersList(ThemeData theme, Color baseColor) {
    return Center(
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
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(theme, baseColor);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final order =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return _buildNeumorphicOrderTile(
                  context,
                  order,
                  theme,
                  baseColor,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSellerOrdersList(ThemeData theme, Color baseColor) {
    return Center(
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
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState(theme, baseColor, isSeller: true);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20.0),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final order =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                // Filter products for this seller
                final sellerProducts = (order['products'] as List<dynamic>?)
                    ?.where((p) => p['sellerId'] == _currentUser!.uid)
                    .toList();

                if (sellerProducts == null || sellerProducts.isEmpty) {
                  return const SizedBox.shrink();
                }

                final sellerOrder = Map<String, dynamic>.from(order);
                sellerOrder['products'] = sellerProducts;

                return _buildNeumorphicOrderTile(
                  context,
                  sellerOrder,
                  theme,
                  baseColor,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ⭐️ NEUMORPHIC ORDER TILE ⭐️
  Widget _buildNeumorphicOrderTile(
    BuildContext context,
    Map<String, dynamic> order,
    ThemeData theme,
    Color baseColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final String status = order['status'] ?? 'unknown';
    final String orderReference =
        order['orderReference'] ??
        order['orderId']?.toString().substring(0, 8) ??
        'N/A';
    final Timestamp? createdAt = order['createdAt'] as Timestamp?;

    return Container(
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : Colors.grey.withOpacity(0.4),
            offset: Offset(5, 5),
            blurRadius: 15,
          ),
          BoxShadow(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            offset: Offset(-5, -5),
            blurRadius: 15,
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '#$orderReference',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  _buildStatusBadge(status, theme),
                ],
              ),
              SizedBox(height: 8),
              Text(
                createdAt != null
                    ? DateFormat(
                        'dd MMM yyyy, hh:mm a',
                      ).format(createdAt.toDate())
                    : 'N/A',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          children: [_buildOrderDetails(context, order, orderReference)],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    Color color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status), color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase().replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(
    BuildContext context,
    Map<String, dynamic> order,
    String orderReference,
  ) {
    final theme = Theme.of(context);
    final List<dynamic> products = order['products'] ?? [];
    final String status = order['status'] ?? 'unknown';
    final double totalAmount =
        (order['totalPaidAmount'] as num?)?.toDouble() ?? 0.0;

    // Extract Contact Info
    String sellerEmail = '';
    String sellerName = 'Seller';
    if (products.isNotEmpty) {
      sellerEmail = products[0]['sellerEmail'] ?? '';
      sellerName = products[0]['sellerName'] ?? 'Seller';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: theme.hintColor.withOpacity(0.1)),

          // Status Tracker
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: OrderStatusTracker(
              currentStatus: status,
              allStatuses: _orderStatuses,
              needsDelivery: order['needsDelivery'] ?? false,
              getStatusIcon: _getStatusIcon,
              getStatusColor: _getStatusColor,
              baseColor: Theme.of(
                context,
              ).scaffoldBackgroundColor, // Pass base color
            ),
          ),

          Divider(color: theme.hintColor.withOpacity(0.1)),

          // Product List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: products.length,
            itemBuilder: (context, prodIndex) {
              final product = products[prodIndex];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    // Product Image (Neumorphic Frame)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          product['imageUrl'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.image_not_supported, size: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['productName'] ?? 'Product',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${product['selectedColor'] ?? '-'} / ${product['selectedSize'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'x${product['quantity'] ?? 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.hintColor,
                          ),
                        ),
                        Text(
                          'R${((product['price'] ?? 0) * (product['quantity'] ?? 1)).toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          SizedBox(height: 15),

          // Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Amount", style: TextStyle(color: theme.hintColor)),
              Text(
                "R${totalAmount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Contact Button
          _buildNeumorphicButton(
            context,
            label: "Contact Seller",
            icon: Icons.mail_outline_rounded,
            isPrimary: true,
            onTap: () => _handleContactSupport(
              context,
              sellerEmail,
              orderReference,
              sellerName,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    Color baseColor, {
    bool isSeller = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: Offset(5, 5),
                  blurRadius: 15,
                ),
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-5, -5),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Icon(
              isSeller
                  ? Icons.storefront_outlined
                  : Icons.shopping_bag_outlined,
              size: 60,
              color: theme.primaryColor.withOpacity(0.5),
            ),
          ),
          SizedBox(height: 25),
          Text(
            isSeller ? "No Sales Yet" : "No Orders Yet",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
            ),
          ),
          SizedBox(height: 10),
          Text(
            isSeller
                ? "Your sales history will appear here."
                : "Start exploring amazing products!",
            style: TextStyle(color: theme.hintColor.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

// ⭐️ UPDATED STATUS TRACKER ⭐️
class OrderStatusTracker extends StatelessWidget {
  final String currentStatus;
  final List<String> allStatuses;
  final bool needsDelivery;
  final Function(String) getStatusIcon;
  final Function(String) getStatusColor;
  final Color baseColor; // Passed for neumorphic effect

  const OrderStatusTracker({
    super.key,
    required this.currentStatus,
    required this.allStatuses,
    required this.needsDelivery,
    required this.getStatusIcon,
    required this.getStatusColor,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    if (currentStatus.toLowerCase() == 'cancelled') {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'ORDER CANCELLED',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
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
        final Color activeColor = getStatusColor(status);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Expanded(
          child: Column(
            children: [
              // Neumorphic Status Circle
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? activeColor : baseColor,
                  boxShadow: isActive
                      ? [
                          // Glow effect for active
                          BoxShadow(
                            color: activeColor.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          // Unpressed/Concave effect for inactive
                          BoxShadow(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.black.withOpacity(0.05),
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                          BoxShadow(
                            color: isDark
                                ? Colors.grey.withOpacity(0.1)
                                : Colors.white,
                            offset: Offset(-2, -2),
                            blurRadius: 4,
                          ),
                        ],
                ),
                child: Icon(
                  getStatusIcon(status),
                  color: isActive ? Colors.white : Colors.grey[400],
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status.toUpperCase().replaceAll('_', ' '),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isActive ? activeColor : Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
