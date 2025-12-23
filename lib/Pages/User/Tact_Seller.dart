// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:ttact/Components/API.dart';

// Import foundation for kIsWeb check (safe practice)
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart'; // Import for Cupertino widgets

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 900.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

// UPDATED: This logic now checks the OS, even on the web.
bool get isIOSPlatform {
  // Checks for iOS or macOS (which iPads/Macs report in browsers)
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// UPDATED: This logic now checks the OS, even on the web.
bool get isAndroidPlatform {
  // Checks for Android, Linux, or Fuchsia to default to Material style.
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// ------------------------

// --- COPIED HELPERS FROM SIGNUPPAGE ---

// Custom platform-aware TextField Builder
Widget _buildPlatformTextField({
  required TextEditingController controller,
  required String placeholder,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  bool readOnly = false,
  int? maxLines = 1,
  String? Function(String?)? validator,
  Widget? suffixIcon,
  required BuildContext context,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: isIOSPlatform
        ? CupertinoTextField(
            style: TextStyle(color: Theme.of(context).cardColor),
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(12.0),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
                  )
                : null,
            suffixMode: OverlayVisibilityMode.editing,
            suffix: suffixIcon,
          )
        : TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
            ),
            validator: validator,
          ),
  );
}

// Custom platform-aware ListTile Builder
Widget _buildListTile({
  required String title,
  required String trailingText,
  required VoidCallback onTap,
  required BuildContext context,
}) {
  if (isIOSPlatform) {
    return CupertinoListTile(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText),
          const Icon(CupertinoIcons.chevron_right),
        ],
      ),
      onTap: onTap,
    );
  } else {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trailingText),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }
}

// Custom platform-aware Action Sheet Builder
void _buildActionSheet({
  required BuildContext context,
  required String title,
  required List<String> actions,
  required ValueChanged<String> onSelected,
}) {
  if (isIOSPlatform) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(title),
        actions: actions.map((item) {
          return CupertinoActionSheetAction(
            child: Text(item),
            onPressed: () {
              onSelected(item);
              Navigator.pop(context);
            },
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, textAlign: TextAlign.center),
              const Divider(),
              ...actions.map((item) {
                return ListTile(
                  title: Text(item),
                  onTap: () {
                    onSelected(item);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
// --- END COPIED HELPERS ---

class SellerProductPage extends StatefulWidget {
  const SellerProductPage({super.key});

  @override
  _SellerProductPageState createState() => _SellerProductPageState();
}

class _SellerProductPageState extends State<SellerProductPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentSegment = 0; // For CupertinoSegmentedControl

  final priceController = TextEditingController();
  final locationController = TextEditingController();
  final suitSizeController = TextEditingController();
  final user = FirebaseAuth.instance.currentUser;

  String? _sellerAddress;

  List<String> _selectedColors = [];
  List<String> _selectedStandardSizes = [];
  List<String> _selectedNumericSizes = [];
  List<String> _selectedSuitSizes = [];
  String? _selectedSizeType;

  // Predefined lists of colors and sizes to choose from
  final List<String> _availableColors = [
    'Black',
    'White',
    'Grey',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Pink',
    'Purple',
    'Orange',
    'Brown',
  ];

  final List<String> _availableSizeTypes = [
    'Standard/Missy Sizes',
    'Numeric Sizes (US/UK)',
    'Suit Sizes',
  ];

  final List<String> _availableStandardSizes = [
    'S',
    'M',
    'X',
    'XX',
    'SS',
    'SSS',
    'XL',
  ];

  final List<Map<String, String>> _availableNumericSizes = [
    {'size': '1', 'type': 'Kids'},
    {'size': '2', 'type': 'Kids'},
    {'size': '3', 'type': 'Kids'},
    {'size': '4', 'type': 'Kids'},
    {'size': '5', 'type': 'Kids'},
    {'size': '6', 'type': 'Kids'},
    {'size': '7', 'type': 'Kids'},
    {'size': '8', 'type': 'Kids'},
    {'size': '9', 'type': 'Kids'},
    {'size': '10', 'type': 'Kids'},
    {'size': '1', 'type': 'Adults'},
    {'size': '2', 'type': 'Adults'},
    {'size': '3', 'type': 'Adults'},
    {'size': '4', 'type': 'Adults'},
    {'size': '5', 'type': 'Adults'},
    {'size': '6', 'type': 'Adults'},
    {'size': '7', 'type': 'Adults'},
    {'size': '8', 'type': 'Adults'},
    {'size': '9', 'type': 'Adults'},
    {'size': '10', 'type': 'Adults'},
    {'size': '11', 'type': 'Adults'},
    {'size': '12', 'type': 'Adults'},
    {'size': '13', 'type': 'Adults'},
  ];

  final List<String> _availableSuitSizes = List.generate(
    (58 - 20) ~/ 2 + 1,
    (index) => (20 + index * 2).toString(),
  );

  final List<String> orderStatuses = [
    'pending',
    'processing',
    'ready_for_pickup',
    'dispatched',
    'completed',
    'cancelled',
  ];

  late int _randomDisplayPercentage;

  // Map for CupertinoSegmentedControl
  final Map<int, Widget> _tabs = const {
    0: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dashboard),
          SizedBox(height: 4),
          Text("Dashboard"),
        ],
      ),
    ),
    1: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory),
          SizedBox(height: 4),
          Text("My Products"),
        ],
      ),
    ),
    2: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_shopping_cart),
          SizedBox(height: 4),
          Text("Add Product"),
        ],
      ),
    ),
    3: Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping),
          SizedBox(height: 4),
          Text("Orders"),
        ],
      ),
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(
      _handleTabSelection,
    ); // Sync controller to segment
    _generateRandomDisplayDiscount();
    fetchCurrentUser();
  }

  void _handleTabSelection() {
    // Sync TabController index with CupertinoSegmentedControl
    if (_tabController.index != _currentSegment) {
      setState(() {
        _currentSegment = _tabController.index;
      });
    }
  }

  void _generateRandomDisplayDiscount() {
    final random = Random();
    _randomDisplayPercentage = 13 + random.nextInt(44 - 13 + 1);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    priceController.dispose();
    locationController.dispose();
    suitSizeController.dispose();
    super.dispose();
  }

  bool isVerified = false;
  String? email;
  String? name;
  String? surname;
  Future<void> fetchCurrentUser() async {
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid)
        .get();

    setState(() {
      // ⭐️ FIX 2: Default to false, not true
      isVerified = userData.data()?['accountVerified'] ?? false;
      name = userData.data()?['name'] ?? "N/A";
      surname = userData.data()?['surname'] ?? "N/A";
      email = userData.data()?['email'] ?? "N/A";
    });
  }

  Future<void> addSellerProduct(
    String productId,
    String name,
    String descrip,
    dynamic imageUrl,
    List<String> colors,
    List<String> sizes,
  ) async {
    // ... (Add Product Logic - No changes needed to business logic)
    if (user == null ||
        priceController.text.isEmpty ||
        locationController.text.isEmpty ||
        colors.isEmpty ||
        sizes.isEmpty) {
      if (mounted) {
        Api().showMessage(
          context,
          "Please fill all required fields: price, location, at least one color, and at least one size.",
          "Warning",
          Colors.red,
        );
      }
      return;
    }
    if (!isVerified) {
      Api().showMessage(
        context,
        "You account is not yet verified as a seller",
        "Warning",
        Colors.red,
      );
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
        'createdAt': FieldValue.serverTimestamp(),
        'productName': name,
        'productDescription': descrip,
        'discountPercentage': _randomDisplayPercentage,
        'imageUrl': (imageUrl is List) ? imageUrl[0] : imageUrl,
        'views': 0,
        'availableColors': colors,
        'availableSizes': sizes,
        'subaccountCode': subaccountCode,
        'sellerName': name,
        'sellerEmail': email,
        'sellerSurname': surname,
      });

      priceController.clear();
      locationController.clear();
      setState(() {
        _selectedColors.clear();
        _selectedStandardSizes.clear();
        _selectedNumericSizes.clear();
        _selectedSuitSizes.clear();
        _selectedSizeType = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!')),
        );
        // The modal is popped in the calling function, so we only need to rebuild state.
      }

      setState(() {});
    } catch (e) {
      print("Error adding seller product: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding product: $e')));
      }
    }
  }

  Future<void> updateSellerProductPrice(String docId, double newPrice) async {
    if (!isVerified) {
      Api().showMessage(
        context,
        "You account is not yet verified as a seller",
        "Warning",
        Colors.red,
      );
      return;
    }
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

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    if (!isVerified) {
      Api().showMessage(
        context,
        "You account is not yet verified as a seller",
        "Warning",
        Colors.red,
      );
      return;
    }
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

  // --- DASHBOARD TAB (Enhanced for Desktop) ---
  Widget dashboardTab() {
    final currentSellerId = user?.uid;
    if (currentSellerId == null) {
      return const Center(child: Text("Please log in to view your dashboard."));
    }
    final isDesktop = isLargeScreen(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your Shop Performance Overview",
                style: TextStyle(
                  fontSize: isDesktop ? 32 : 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),

              // Dashboard Cards Grid/Wrap
              _buildDashboardMetrics(currentSellerId, isDesktop),

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
        ),
      ),
    );
  }

  Widget _buildDashboardMetrics(String currentSellerId, bool isDesktop) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('orders').get(),
      builder: (context, ordersSnapshot) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('seller_products')
              .where('sellerId', isEqualTo: currentSellerId)
              .get(),
          builder: (context, productsSnapshot) {
            // Loading State
            if (ordersSnapshot.connectionState == ConnectionState.waiting ||
                productsSnapshot.connectionState == ConnectionState.waiting) {
              return Wrap(
                spacing: 15,
                runSpacing: 15,
                children: List.generate(
                  4,
                  (i) => _buildDashboardCard(
                    "Loading...",
                    "...",
                    Icons.hourglass_empty,
                    isDesktop,
                  ),
                ),
              );
            }

            // Error State
            if (ordersSnapshot.hasError || productsSnapshot.hasError) {
              return Text(
                "Error loading data.",
                style: TextStyle(color: Colors.red),
              );
            }

            // Processing Data
            int totalProducts = productsSnapshot.data?.docs.length ?? 0;
            int totalViews = 0;
            final sellerProducts = productsSnapshot.data?.docs ?? [];
            for (var doc in sellerProducts) {
              final data = doc.data() as Map<String, dynamic>;
              totalViews += (data['views'] as int?) ?? 0;
            }

            int totalOrdersForSeller = 0;
            double totalRevenueForSeller = 0.0;
            final allOrders = ordersSnapshot.data?.docs ?? [];

            for (var orderDoc in allOrders) {
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final List<dynamic> productsInOrder = orderData['products'] ?? [];

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

            // Build the final set of cards
            return Wrap(
              spacing: 15,
              runSpacing: 15,
              children: [
                _buildDashboardCard(
                  "Total Products Listed",
                  totalProducts.toString(),
                  Icons.storage,
                  isDesktop,
                ),
                _buildDashboardCard(
                  "Total Orders Received",
                  totalOrdersForSeller.toString(),
                  Icons.shopping_bag,
                  isDesktop,
                ),
                _buildDashboardCard(
                  "Total Revenue (Your Products)",
                  "R${totalRevenueForSeller.toStringAsFixed(2)}",
                  Icons.attach_money,
                  isDesktop,
                ),
                _buildDashboardCard(
                  "Total Product Views",
                  totalViews.toString(),
                  Icons.visibility,
                  isDesktop,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardCard(
    String title,
    String value,
    IconData icon,
    bool isDesktop,
  ) {
    // Calculate card width based on desktop status
    final cardWidth = isDesktop
        ? (MediaQuery.of(context).size.width * 0.8 / 2) - 30
        : double.infinity;

    return Card(
      elevation: 4,
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(width: 0.4, color: Theme.of(context).hintColor),
        ),
        width: cardWidth,
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Theme.of(context).primaryColor),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
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
            ),
          ],
        ),
      ),
    );
  }
  // --- END DASHBOARD TAB ---

  // --- MY PRODUCTS TAB (Maintains List layout) ---
  Widget myProductsTab() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('seller_products')
          .where('sellerId', isEqualTo: user?.uid)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No products added yet."));
        }

        final sellerProds = snapshot.data!.docs;

        return Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: 900),
            child: ListView.builder(
              itemCount: sellerProds.length,
              itemBuilder: (context, index) {
                final doc = sellerProds[index];
                final data = doc.data() as Map<String, dynamic>;
                final String docId = doc.id;

                final productName = data['productName'] ?? 'Unnamed Product';
                final imageUrl = data['imageUrl'];
                final currentPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
                final productViews = (data['views'] as int?) ?? 0;
                final List<String> availableColors =
                    (data['availableColors'] as List<dynamic>? ?? [])
                        .map((c) => c.toString())
                        .toList();
                final List<String> availableSizes =
                    (data['availableSizes'] as List<dynamic>? ?? [])
                        .map((s) => s.toString())
                        .toList();

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  elevation: 2,
                  child: ListTile(
                    leading:
                        imageUrl != null &&
                            (imageUrl is String && imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            height: 60,
                            width: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                          )
                        : Icon(Icons.inventory, size: 40, color: Colors.grey),
                    title: Text(
                      productName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Price: R${currentPrice.toStringAsFixed(2)}",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          "Location: ${data['location'] ?? 'N/A'}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14),
                        ),
                        Text(
                          "Views: $productViews | Colors: ${availableColors.join(', ')} | Sizes: ${availableSizes.join(', ')}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        isIOSPlatform ? CupertinoIcons.pencil : Icons.edit,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () {
                        // UPDATED: Call new helper
                        _showUpdatePriceDialog(
                          docId,
                          productName,
                          currentPrice,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  // --- END MY PRODUCTS TAB ---

  // --- NEW: Platform-Aware Price Update Dialog ---
  void _showUpdatePriceDialog(
    String docId,
    String productName,
    double currentPrice,
  ) {
    final TextEditingController newPriceController = TextEditingController(
      text: currentPrice.toStringAsFixed(2),
    );

    final content = _buildPlatformTextField(
      context: context,
      controller: newPriceController,
      placeholder: "e.g., 175.50",
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      prefixIcon: isIOSPlatform
          ? CupertinoIcons.money_dollar
          : Icons.attach_money,
    );

    if (isIOSPlatform) {
      showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: Text("Update Price for $productName"),
            content: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Material(
                color: Colors.transparent,
                child: content,
              ), // Material wrapper
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text("Update"),
                onPressed: () async {
                  final double? updatedPrice = double.tryParse(
                    newPriceController.text,
                  );
                  if (updatedPrice != null && updatedPrice >= 0) {
                    await updateSellerProductPrice(docId, updatedPrice);
                    if (mounted) {
                      Navigator.pop(context);
                    }
                  } else {
                    // Show error
                    Api().showMessage(
                      context,
                      "Please enter a valid positive number.",
                      "Invalid Price",
                      Colors.red,
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Update Price for $productName"),
            content: content,
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
                    await updateSellerProductPrice(docId, updatedPrice);
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
    }
  }
  // --- END Price Update Dialog ---

  // --- ADD PRODUCT TAB (Modal Constrained) ---
 Widget addProductTab() {
    if (user == null) {
      return const Center(child: Text("Please log in to add products."));
    }

    if (!isVerified) {
      return _buildNotVerifiedWidget();
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
          return Center(
            child: isIOSPlatform
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(),
          );
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
              return Center(
                child: isIOSPlatform
                    ? const CupertinoActivityIndicator()
                    : const CircularProgressIndicator(),
              );
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

            // Filter out products the seller already has
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

            // Wrap the ListView in a constrained container for web aesthetic
            return Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView.builder(
                  itemCount: availableProducts.length,
                  itemBuilder: (context, index) {
                    final prod = availableProducts[index];
                    final data = prod.data() as Map<String, dynamic>;

                    final String adminProductName =
                        data['name'] ?? 'Unnamed Product';
                    final String adminProductDescription =
                        data['description'] ?? 'No description';
                    final dynamic adminProductImageUrl = data['imageUrl'];
                    
                    // ⭐️ NEW: Fetch Type and Category
                    final String productType = data['type'] ?? 'Product'; 
                    final String category = data['category'] ?? 'General';
                    final bool isService = productType == 'Service';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      elevation: 2,
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
                                height: 60,
                                width: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image),
                              )
                            : Icon(
                                isService 
                                    ? Icons.handyman_outlined // Icon for Service
                                    : Icons.inventory_2_outlined, // Icon for Product
                                size: 40,
                                color: Colors.grey,
                              ),
                        title: Text(
                          adminProductName,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$category • $productType", // Show type and category
                              style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor),
                            ),
                            Text(
                              adminProductDescription,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () async {
                          // ... (Location fetching logic - Kept As Is)
                          if (_sellerAddress == null) {
                            Api().showLoading(context);
                            try {
                              final sellerSnapshot = await FirebaseFirestore
                                  .instance
                                  .collection('users')
                                  .where('role', isEqualTo: 'Seller')
                                  .where(
                                    'email',
                                    isEqualTo: FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .email,
                                  )
                                  .get();
                              if (sellerSnapshot.docs.isNotEmpty) {
                                setState(() {
                                  _sellerAddress = sellerSnapshot.docs.first
                                      .data()['address'];
                                });
                              }
                            } catch (e) {
                              print("Error fetching seller location: $e");
                              // Handle error
                            } finally {
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            }
                          }
                          // ... (End Location fetching logic)

                          if (context.mounted) {
                            priceController.clear();
                            locationController.text = _sellerAddress ?? '';
                            suitSizeController.clear();
                            setState(() {
                              _selectedColors.clear();
                              _selectedStandardSizes.clear();
                              _selectedNumericSizes.clear();
                              _selectedSuitSizes.clear();
                              _selectedSizeType = null;
                            });

                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (context) {
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 600,
                                    ),
                                    child: StatefulBuilder(
                                      builder:
                                          (
                                            BuildContext context,
                                            StateSetter setModalState,
                                          ) {
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
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Center(
                                                      child: Text(
                                                        isService 
                                                          ? "Set Rates & Location for:" 
                                                          : "Add Price, Location, Colors & Sizes:",
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Theme.of(
                                                            context,
                                                          ).primaryColor,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                    Center(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 16.0,
                                                            ),
                                                        child: Text(
                                                          adminProductName,
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Theme.of(
                                                              context,
                                                            ).primaryColor,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                        ),
                                                      ),
                                                    ),
                                                    
                                                    // --- COMMON FIELDS (Price & Location) ---
                                                    _buildPlatformTextField(
                                                      context: context,
                                                      controller:
                                                          priceController,
                                                      placeholder: isService ? "Rate/Price (R)" : "Price (R)",
                                                      keyboardType:
                                                          TextInputType.number,
                                                      prefixIcon: isIOSPlatform
                                                          ? CupertinoIcons
                                                                .money_dollar
                                                          : Icons.attach_money,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    _buildPlatformTextField(
                                                      context: context,
                                                      controller:
                                                          locationController,
                                                      placeholder:
                                                          "Location (e.g., Shop A12, Market St)",
                                                      prefixIcon: isIOSPlatform
                                                          ? CupertinoIcons
                                                                .location_solid
                                                          : Icons.location_on,
                                                    ),
                                                    
                                                    const SizedBox(height: 20),
                                                    const Divider(),

                                                    // ⭐️ CONDITIONAL UI: Only show Colors/Sizes if it is a PRODUCT
                                                    if (!isService) ...[
                                                      Text(
                                                        "Select Colors:",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8.0,
                                                        runSpacing: 8.0,
                                                        children: _availableColors.map((
                                                          color,
                                                        ) {
                                                          final isSelected =
                                                              _selectedColors
                                                                  .contains(
                                                                    color,
                                                                  );
                                                          return FilterChip(
                                                            label: Text(color),
                                                            selected: isSelected,
                                                            onSelected: (selected) {
                                                              setModalState(() {
                                                                if (selected) {
                                                                  _selectedColors
                                                                      .add(color);
                                                                } else {
                                                                  _selectedColors
                                                                      .remove(
                                                                        color,
                                                                      );
                                                                }
                                                              });
                                                            },
                                                            backgroundColor:
                                                                isSelected
                                                                ? Theme.of(
                                                                        context,
                                                                      )
                                                                      .primaryColor
                                                                      .withOpacity(
                                                                        0.2,
                                                                      )
                                                                : Colors
                                                                      .grey
                                                                      .shade100,
                                                            selectedColor:
                                                                Theme.of(
                                                                  context,
                                                                ).primaryColor,
                                                            labelStyle: TextStyle(
                                                              color: isSelected
                                                                  ? Colors.white
                                                                  : Theme.of(
                                                                          context,
                                                                        )
                                                                        .textTheme
                                                                        .bodyMedium!
                                                                        .color,
                                                            ),
                                                          );
                                                        }).toList(),
                                                      ),
                                                      const SizedBox(height: 20),
                                                      const Divider(),
                                                      Text(
                                                        "Select Size Type:",
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 16,
                                                          color: Colors.grey[700],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      _buildListTile(
                                                        context: context,
                                                        title: "Select Size Type",
                                                        trailingText:
                                                            _selectedSizeType ??
                                                            "Choose type",
                                                        onTap: () {
                                                          _buildActionSheet(
                                                            context: context,
                                                            title:
                                                                "Choose a size type",
                                                            actions:
                                                                _availableSizeTypes,
                                                            onSelected: (value) {
                                                              setModalState(() {
                                                                _selectedSizeType =
                                                                    value;
                                                                _selectedStandardSizes
                                                                    .clear();
                                                                _selectedNumericSizes
                                                                    .clear();
                                                                _selectedSuitSizes
                                                                    .clear();
                                                              });
                                                            },
                                                          );
                                                        },
                                                      ),
                                                      const SizedBox(height: 20),
                                                      if (_selectedSizeType !=
                                                          null) ...[
                                                        Text(
                                                          "Select Size:",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 16,
                                                            color:
                                                                Colors.grey[700],
                                                          ),
                                                        ),
                                                        const SizedBox(height: 8),
                                                        if (_selectedSizeType ==
                                                            'Standard/Missy Sizes')
                                                          _buildStandardSizeSelector(
                                                            setModalState,
                                                          )
                                                        else if (_selectedSizeType ==
                                                            'Numeric Sizes (US/UK)')
                                                          _buildNumericSizeSelector(
                                                            setModalState,
                                                          )
                                                        else if (_selectedSizeType ==
                                                            'Suit Sizes')
                                                          _buildSuitSizeSelector(
                                                            setModalState,
                                                          ),
                                                        const SizedBox(
                                                          height: 20,
                                                        ),
                                                      ],
                                                    ],
                                                    // --- END CONDITIONAL UI ---

                                                    // --- BUTTONS ---
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        isIOSPlatform
                                                            ? CupertinoButton(
                                                                child:
                                                                    const Text(
                                                                      "Cancel",
                                                                    ),
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                              )
                                                            : TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                      context,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      "Cancel",
                                                                    ),
                                                              ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        isIOSPlatform
                                                            ? CupertinoButton.filled(
                                                                child:
                                                                    const Text(
                                                                      "Submit",
                                                                    ),
                                                                onPressed: () async {
                                                                  _handleSubmitProduct(
                                                                    prod.id,
                                                                    adminProductName,
                                                                    adminProductDescription,
                                                                    adminProductImageUrl,
                                                                    // Pass empty lists if Service to avoid errors
                                                                  );
                                                                },
                                                              )
                                                            : ElevatedButton(
                                                                onPressed: () async {
                                                                  _handleSubmitProduct(
                                                                    prod.id,
                                                                    adminProductName,
                                                                    adminProductDescription,
                                                                    adminProductImageUrl,
                                                                  );
                                                                },
                                                                child:
                                                                    const Text(
                                                                      "Submit",
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
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  } // --- END ADD PRODUCT TAB ---

  // --- NEW: Helper for Submit Logic ---
  void _handleSubmitProduct(
    String productId,
    String adminProductName,
    String adminProductDescription,
    dynamic adminProductImageUrl,
  ) async {
    List<String> sizesToSave = [];
    if (_selectedSizeType == 'Standard/Missy Sizes') {
      sizesToSave = _selectedStandardSizes;
    } else if (_selectedSizeType == 'Numeric Sizes (US/UK)') {
      sizesToSave = _selectedNumericSizes;
    } else if (_selectedSizeType == 'Suit Sizes') {
      sizesToSave = _selectedSuitSizes;
    }

    if (priceController.text.isEmpty ||
        locationController.text.isEmpty ||
        _selectedColors.isEmpty ||
        sizesToSave.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please fill in all fields: price, location, colors, and at least one size.',
            ),
          ),
        );
      }
      return;
    }

    try {
      Api().showLoading(context);
      if (!isVerified) {
        Api().showMessage(
          context,
          "You account is not yet verified as a seller",
          "Warning",
          Colors.red,
        );
        Navigator.of(context).pop(); // Pop loading
        return;
      }
      await addSellerProduct(
        productId,
        adminProductName,
        adminProductDescription,
        adminProductImageUrl,
        _selectedColors,
        sizesToSave,
      );
      if (mounted) {
        Navigator.pop(context); // Dismiss loading
        Navigator.pop(context); // Dismiss modal
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding product: $e')));
      }
    }
  }
  // --- END Submit Logic Helper ---

  // --- ⭐️ ADD THIS NEW WIDGET ⭐️ ---
  Widget _buildNotVerifiedWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gpp_bad_outlined, size: 80, color: Colors.red[700]),
            SizedBox(height: 20),
            Text(
              "Account Not Verified",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              "Your account has not been verified by an admin yet. You cannot add products until your account is approved.",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- ORDERS TAB (Maintains List layout) ---
  Widget ordersTab() {
    final currentSellerId = user?.uid;
    if (currentSellerId == null) {
      return const Center(child: Text("Please log in to view your sales."));
    }

    // Wrap the Order List in a constrained container for web aesthetic
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 1000),
        child: FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('orders')
              .orderBy('createdAt', descending: true)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: isIOSPlatform
                    ? CupertinoActivityIndicator()
                    : CircularProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text("No orders found."));
            }

            final allOrders = snapshot.data!.docs;
            final relevantOrders = _filterOrders(allOrders, currentSellerId);

            if (relevantOrders.isEmpty) {
              return const Center(
                child: Text("No orders found for your products."),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: relevantOrders.length,
              itemBuilder: (context, index) {
                final orderDoc = relevantOrders[index];
                final orderData = orderDoc.data() as Map<String, dynamic>;
                final orderId = orderDoc.id;

                final customerId = orderData['userId'] as dynamic;

                final orderRef =
                    orderData['orderReference'] ??
                    orderId.substring(0, 8).toUpperCase();
                final currentStatus = orderData['status'] ?? 'pending';
                final orderDate = (orderData['createdAt'] as Timestamp?)
                    ?.toDate();

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(customerId)
                      .get(),
                  builder: (context, customerSnapshot) {
                    String customerName = 'Unknown Customer';
                    String customerEmail = '';
                    if (customerSnapshot.connectionState ==
                            ConnectionState.done &&
                        customerSnapshot.hasData) {
                      final customerData =
                          customerSnapshot.data!.data()
                              as Map<String, dynamic>?;
                      if (customerData != null &&
                          customerData.containsKey('name')) {
                        customerName =
                            customerData['name'] ?? 'Unknown Customer';
                        customerEmail = customerData['email'] ?? '';
                      }
                    }
                    return Card(
                      color: Theme.of(context).scaffoldBackgroundColor,
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
        ),
      ),
    );
  }
  // --- END ORDERS TAB ---

  // --- SHARED BUILDERS (No functional changes) ---

  Widget _buildStandardSizeSelector(StateSetter setModalState) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _availableStandardSizes.map((size) {
        final isSelected = _selectedStandardSizes.contains(size);
        return FilterChip(
          label: Text(size),
          selected: isSelected,
          onSelected: (selected) {
            setModalState(() {
              if (selected) {
                _selectedStandardSizes.add(size);
              } else {
                _selectedStandardSizes.remove(size);
              }
            });
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium!.color,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumericSizeSelector(StateSetter setModalState) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _availableNumericSizes.map((sizeMap) {
        final size = sizeMap['size']!;
        final type = sizeMap['type']!;
        final displayLabel = "$size ($type)";
        final isSelected = _selectedNumericSizes.contains(size);

        return FilterChip(
          label: Text(displayLabel),
          selected: isSelected,
          onSelected: (selected) {
            setModalState(() {
              if (selected) {
                _selectedNumericSizes.add(size);
              } else {
                _selectedNumericSizes.remove(size);
              }
            });
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium!.color,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSuitSizeSelector(StateSetter setModalState) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _availableSuitSizes.map((size) {
        final isSelected = _selectedSuitSizes.contains(size);
        return FilterChip(
          label: Text(size),
          selected: isSelected,
          onSelected: (selected) {
            setModalState(() {
              if (selected) {
                _selectedSuitSizes.add(size);
              } else {
                _selectedSuitSizes.remove(size);
              }
            });
          },
          selectedColor: Theme.of(context).primaryColor,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium!.color,
          ),
        );
      }).toList(),
    );
  }

  // (Helper functions _getStatusColor, _getStatusIcon, _filterOrders,
  // _buildOrderSummary, _buildOrderDetails, _showStatusUpdateDialog)
  // ... (are kept as is from the original code)

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

  List<DocumentSnapshot> _filterOrders(
    List<DocumentSnapshot> allOrders,
    String sellerId,
  ) {
    return allOrders.where((orderDoc) {
      final orderData = orderDoc.data() as Map<String, dynamic>?;
      if (orderData == null) return false;

      final products = orderData['products'] as List<dynamic>?;
      if (products == null) return false;

      return products.any((product) {
        if (product is Map<String, dynamic> &&
            product['sellerId'] == sellerId) {
          return true;
        }
        return false;
      });
    }).toList();
  }

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
            final selectedSize = product['selectedSize'] ?? 'N/A';

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 8),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$prodName (x$prodQty) @ R${prodPrice.toStringAsFixed(2)} each = R${prodTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          'Size: $selectedSize',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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
              // --- PLATFORM AWARE ---
              isIOSPlatform
                  ? CupertinoButton.filled(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.pencil, size: 18),
                          SizedBox(width: 6),
                          Text("Update Status"),
                        ],
                      ),
                      onPressed: () {
                        _showStatusUpdateDialog(
                          context,
                          orderId,
                          orderData['status'] ?? 'pending',
                          orderStatuses,
                          updateOrderStatus,
                        );
                      },
                    )
                  : ElevatedButton.icon(
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
              // --- END PLATFORM AWARE ---
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

    final content = StatefulBuilder(
      builder: (context, setDialogState) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: orderStatuses.map((status) {
                // Use Material RadioListTile on both platforms for simplicity
                // as Cupertino doesn't have a direct equivalent.
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
        );
      },
    );

    if (isIOSPlatform) {
      showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: const Text("Update Order Status"),
            content: Material(color: Colors.transparent, child: content),
            actions: [
              CupertinoDialogAction(
                child: const Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text("Confirm Update"),
                onPressed: () async {
                  _confirmStatusUpdate(
                    orderId,
                    tempSelectedStatus,
                    currentStatus,
                  );
                },
              ),
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Update Order Status"),
            content: content,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  _confirmStatusUpdate(
                    orderId,
                    tempSelectedStatus,
                    currentStatus,
                  );
                },
                icon: const Icon(Icons.update),
                label: const Text("Confirm Update"),
              ),
            ],
          );
        },
      );
    }
  }

  // --- NEW: Helper for Status Update Logic ---
  void _confirmStatusUpdate(
    String orderId,
    String? tempSelectedStatus,
    String currentStatus,
  ) async {
    if (tempSelectedStatus != null && tempSelectedStatus != currentStatus) {
      await updateOrderStatus(orderId, tempSelectedStatus!);
      if (context.mounted) Navigator.pop(context);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No status selected or no change.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    // Check if the screen is large enough for desktop layout
    final isDesktop = isLargeScreen(context);

    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Center(
        child: Container(
          // Constrain the entire content view on large screens
          constraints: BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              // --- PLATFORM AWARE TAB BAR ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: isIOSPlatform
                    ? CupertinoSegmentedControl<int>(
                        children: _tabs,
                        groupValue: _currentSegment,
                        onValueChanged: (int newValue) {
                          setState(() {
                            _currentSegment = newValue;
                            _tabController.animateTo(newValue);
                          });
                        },
                        padding: EdgeInsets.zero,
                      )
                    : TabBar(
                        controller: _tabController,
                        labelColor: color.primaryColor,
                        unselectedLabelColor: color.hintColor,
                        indicatorColor: color.primaryColor,
                        isScrollable: isDesktop
                            ? false
                            : true, // Full width tabs on desktop
                        tabs: const [
                          Tab(text: "Dashboard", icon: Icon(Icons.dashboard)),
                          Tab(text: "My Products", icon: Icon(Icons.inventory)),
                          Tab(
                            text: "Add Product",
                            icon: Icon(Icons.add_shopping_cart),
                          ),
                          Tab(text: "Orders", icon: Icon(Icons.local_shipping)),
                        ],
                      ),
              ),
              // --- END PLATFORM AWARE TAB BAR ---
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Pass isDesktop to Dashboard for responsive grid layout
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
      ),
    );
  }
}
