// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, prefer_const_literals_to_create_immutables

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;
import 'package:toastification/toastification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/ProductCard.dart';
import 'package:ttact/Components/Product_Details.dart';
import 'package:ttact/Pages/CartPage.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;
// --------------------------

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

class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> addToCart(
    Map<String, dynamic> product,
    String? selectedColor,
    String? selectedSize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    List<Map<String, dynamic>> cart = [];

    if (cartData != null) {
      cart = List<Map<String, dynamic>>.from(
        (json.decode(cartData) as List).map(
          (item) => item as Map<String, dynamic>,
        ),
      );
    }

    final String? productId = product['productId'];
    if (productId == null) {
      print("Error: Product ID is missing.");
      return;
    }

    bool productFound = false;
    for (int i = 0; i < cart.length; i++) {
      if (cart[i]['productId'] == productId &&
          cart[i]['selectedColor'] == selectedColor &&
          cart[i]['selectedSize'] == selectedSize) {
        int currentQuantity = (cart[i]['quantity'] as int?) ?? 0;
        double productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;

        cart[i]['quantity'] = currentQuantity + 1;
        cart[i]['itemTotalPrice'] = cart[i]['quantity'] * productPrice;
        productFound = true;
        break;
      }
    }

    if (!productFound) {
      double productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      product['quantity'] = 1;
      product['itemTotalPrice'] = productPrice;
      product['selectedColor'] = selectedColor;
      product['selectedSize'] = selectedSize;
      cart.add(product);
    }

    await prefs.setString(_cartKey, json.encode(cart));
  }

  static Future<void> removeFromCart(
    String productId,
    String? selectedColor,
    String? selectedSize,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData == null) return;

    List<Map<String, dynamic>> cart = List<Map<String, dynamic>>.from(
      (json.decode(cartData) as List).map(
        (item) => item as Map<String, dynamic>,
      ),
    );

    for (int i = 0; i < cart.length; i++) {
      if (cart[i]['productId'] == productId &&
          cart[i]['selectedColor'] == selectedColor &&
          cart[i]['selectedSize'] == selectedSize) {
        int currentQuantity = (cart[i]['quantity'] as int?) ?? 0;
        if (currentQuantity > 1) {
          cart[i]['quantity'] = currentQuantity - 1;
          double productPrice = (cart[i]['price'] as num?)?.toDouble() ?? 0.0;
          cart[i]['itemTotalPrice'] = cart[i]['quantity'] * productPrice;
        } else {
          cart.removeAt(i);
        }
        break;
      }
    }
    await prefs.setString(_cartKey, json.encode(cart));
  }

  static Future<List<Map<String, dynamic>>> getCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData != null) {
      return List<Map<String, dynamic>>.from(
        (json.decode(cartData) as List).map(
          (item) => item as Map<String, dynamic>,
        ),
      );
    }

    return [];
  }

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({super.key});

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  int cartCount = 0;
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _currentUserId;

  // NEW STATE: Search query string
  String _searchQuery = '';

  // NEW STATE FOR DESKTOP SPLIT VIEW
  Map<String, dynamic>? _selectedProductDetails;
  bool _isDetailsPanelVisible = false;

  final List<String> _productCategories = const [
    'All',
    'Shirts & Polos',
    'Suits & Jackets',
    'Trousers & Skirts',
    'Footwear',
    'Accessories',
    'Hats',
    'Shoes',
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentUser();
    loadCartCount();
    fetchAllSellerProducts();
  }

  void _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
    }
  }

  void loadCartCount() async {
    List<Map<String, dynamic>> cart = await CartHelper.getCart();
    int totalItems = 0;
    for (var item in cart) {
      totalItems += (item['quantity'] as int? ?? 0);
    }
    setState(() {
      cartCount = totalItems;
    });
  }

  void fetchAllSellerProducts() async {
    setState(() {
      _isLoading = true;
    });

    final sellerProductsSnap = await FirebaseFirestore.instance
        .collection('seller_products')
        .where('sellerId', isNotEqualTo: _currentUserId)
        .get();

    List<Map<String, dynamic>> loadedProducts = [];

    for (var doc in sellerProductsSnap.docs) {
      final sellerData = doc.data();

      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .doc(sellerData['productId'])
          .get();

      if (productSnap.exists) {
        final productData = productSnap.data()!;
        loadedProducts.add({
          'imageUrl': (productData['imageUrl'] is List)
              ? productData['imageUrl'][0]
              : productData['imageUrl'],
          'category': productData['category'] ?? 'Other',
          'productName': productData['name'],
          'price': (sellerData['price'] as num).toDouble(),
          'location': sellerData['location'],
          'sellerId': sellerData['sellerId'],
          'productId': sellerData['productId'],
          'description':
              productData['description'] ?? 'No description provided',
          'isAvailable': productData['isAvailable'] ?? true,
          'discountPercentage':
              (sellerData['discountPercentage'] as num?)?.toDouble() ?? 0.0,
          'availableColors': sellerData['availableColors'] ?? [],
          'availableSizes': sellerData['availableSizes'] ?? [],
          'subAccountCode': sellerData['subAccountCode'] ?? '',
          'sellerEmail': sellerData['sellerEmail'] ?? '',
          'sellerName': sellerData['sellerName'] ?? '',
          'sellerSurname': sellerData['sellerSurname'] ?? '',
          'profileUrl': sellerData['profileUrl'] ?? '',
        });
      }
    }

    setState(() {
      products = loadedProducts;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    String query = _searchQuery.toLowerCase();

    // 1. Start with products
    Iterable<Map<String, dynamic>> tempProducts = products;

    // 2. Apply Category filter
    if (_selectedCategory != 'All') {
      tempProducts = tempProducts.where(
        (product) => product['category'] == _selectedCategory,
      );
    }

    // 3. Apply Search query filter
    if (query.isNotEmpty) {
      tempProducts = tempProducts.where((product) {
        final productName =
            (product['productName'] as String?)?.toLowerCase() ?? '';
        final category = (product['category'] as String?)?.toLowerCase() ?? '';

        return productName.contains(query) || category.contains(query);
      });
    }

    _filteredProducts = tempProducts.toList();

    // Re-trigger rebuild after filtering
    setState(() {});
  }

  void addToCartFromProductDetails(
    Map<String, dynamic> product,
    String? selectedColor,
    String? selectedSize,
  ) async {
    final theme = Theme.of(context);
    await CartHelper.addToCart(product, selectedColor, selectedSize);
    loadCartCount();

    toastification.dismissAll();
    Api().showMessage(
      context,
      '${product['productName']} (${selectedColor ?? 'Default'}, ${selectedSize ?? 'Default'}) added to the cart',
      'Success',
      theme.primaryColor,
    );
  }

  // --- NEW: Function to handle product click ---
  void _handleProductClick(Map<String, dynamic> product) {
    final isDesktop = isLargeScreen(context);

    if (isDesktop) {
      // Desktop: Update state to show details in the side panel
      setState(() {
        _selectedProductDetails = product;
        _isDetailsPanelVisible = true;
      });
    } else {
      // Mobile: Use bottom sheet
      showModalBottomSheet(
        scrollControlDisabledMaxHeightRatio: 0.8,
        context: context,
        builder: (context) {
          return ProductDetails(
            productDetails: product,
            sellerProductId: product['sellerId'],
            onAddToCart: (selectedColor, selectedSize) {
              addToCartFromProductDetails(product, selectedColor, selectedSize);
            },
          );
        },
      );
    }
  }

  // --- Widget for the Main Product Grid ---
  // [THIS IS THE FIXED VERSION]
  Widget _buildProductGrid(
    ThemeData theme,
    double horizontalPadding,
    double spacing,
    double cardWidth,
  ) {
    final isDesktop = isLargeScreen(context);

    // The main content area where products are listed
    Widget productContent = SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: DefaultTabController(
        length: _productCategories.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // NEW: Search Bar
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilter();
                    // Hide details panel on search change
                    _isDetailsPanelVisible = false;
                    _selectedProductDetails = null;
                  });
                },
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(15),
                  hintText: 'Search product by name or category...',
                  prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                  fillColor: theme.hintColor.withOpacity(0.2),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Product Category Tabs
            TabBar(
              isScrollable: !isDesktop, // Scrollable only on smaller screens
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: theme.scaffoldBackgroundColor.withOpacity(
                0.7,
              ), // Label color changes when selected
              dividerColor: Colors.transparent,
              indicatorColor: theme.primaryColor,
              unselectedLabelColor: theme.hintColor,
              overlayColor: WidgetStatePropertyAll(theme.primaryColor),
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: theme.primaryColor,
              ),
              onTap: (index) {
                setState(() {
                  _selectedCategory = _productCategories[index];
                  _applyFilter();
                  // Hide details panel on category change
                  _isDetailsPanelVisible = false;
                  _selectedProductDetails = null;
                });
              },
              tabs: _productCategories
                  .map((category) => Tab(text: category))
                  .toList(),
            ),
            SizedBox(height: 20),

            // Product Grid/Wrap
            if (_filteredProducts.isEmpty && _isLoading == false)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 50.0),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 60, color: theme.hintColor),
                      SizedBox(height: 10),
                      Text(
                        'No products found matching your search and filter.',
                        style: TextStyle(fontSize: 18, color: theme.hintColor),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.start,
                children: _filteredProducts.map((product) {
                  final bool isSellerProduct =
                      _currentUserId == product['sellerId'];

                  // Highlight selected product on desktop
                  final bool isSelected =
                      isDesktop &&
                      _selectedProductDetails?['productId'] ==
                          product['productId'] &&
                      _selectedProductDetails?['sellerId'] ==
                          product['sellerId'];

                  return SizedBox(
                    width: cardWidth, // Use responsive card width
                    child: GestureDetector(
                      onTap: () => _handleProductClick(product),
                      child: Product_Card(
                        onCartPressed: () => _handleProductClick(product),
                        imageUrl: product['imageUrl'],
                        categoryName: product['category'],
                        productName: product['productName'],
                        price: product['price'],
                        discountPercentage: product['discountPercentage'],
                        location: product['location'] ?? '',
                        isAvailable: product['isAvailable'] ?? true,
                        availableColors: product['availableColors'] as dynamic,
                        isSellerProduct: isSellerProduct,
                        // Optional: Add visual highlight for selected card on desktop
                        cardBorder: isSelected
                            ? Border.all(color: theme.primaryColor, width: 2.5)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );

    // Apply max width constraint and top alignment
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(
          // [THIS WAS THE FIX]
          // Changed from 400 to 1200.0 to match your 'maxWidth' constant
          maxWidth: 1200.0,
        ),
        child: productContent,
      ),
    );
  }

  // --- Widget for the Details Panel (Desktop) ---
  Widget _buildDetailsPanel(ThemeData theme) {
    if (!_isDetailsPanelVisible || _selectedProductDetails == null) {
      return Center(
        child: Text(
          'Select a product to view details.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.hintColor.withOpacity(0.5)),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.hintColor.withOpacity(0.5)),
        ),
        color: theme.scaffoldBackgroundColor.withOpacity(
          0.7,
        ), // Use scaffoldBackgroundColor.withOpacity(0.7) for the panel background
      ),
      child: ProductDetails(
        productDetails: _selectedProductDetails!,
        sellerProductId: _selectedProductDetails!['sellerId'],
        onAddToCart: (selectedColor, selectedSize) {
          addToCartFromProductDetails(
            _selectedProductDetails!,
            selectedColor,
            selectedSize,
          );
        },
        // Callback to hide the panel
        onClose: () {
          setState(() {
            _isDetailsPanelVisible = false;
            _selectedProductDetails = null;
          });
        },
        isStandalone: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // Determine the number of columns for the grid based on screen size
    final int baseCrossAxisCount = 2; // Mobile default
    final int desktopCrossAxisCount = _isDetailsPanelVisible
        ? 3
        : 4; // Grid shrinks when panel is visible
    final int crossAxisCount = isDesktop
        ? desktopCrossAxisCount
        : baseCrossAxisCount;

    // Calculate widths
    final double horizontalPadding = isDesktop ? 20.0 : 10.0;
    final double spacing = isDesktop ? 20.0 : 10.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    const double maxWidth = 1200.0;

    // Adjust calculation for when the panel is visible on desktop
    double availableWidth;
    if (isDesktop) {
      // Max width of the entire row container is maxWidth (1200) or screenWidth
      double containerWidth = screenWidth > maxWidth ? maxWidth : screenWidth;

      if (_isDetailsPanelVisible) {
        // Left pane (Flex 2) is 2/3 of the total width
        availableWidth = (containerWidth * (2 / 3)) - (horizontalPadding * 2);
      } else {
        // Full width when not split
        availableWidth = containerWidth - (horizontalPadding * 2);
      }
    } else {
      availableWidth = screenWidth - (horizontalPadding * 2);
    }

    // Ensure we don't divide by zero or negative number
    final double calculatedCardWidth =
        (availableWidth - ((crossAxisCount - 1) * spacing));
    final double cardWidth =
        calculatedCardWidth.isFinite && calculatedCardWidth > 0
        ? calculatedCardWidth / crossAxisCount
        : (screenWidth / crossAxisCount) - spacing;

    Widget content;

    if (_isLoading) {
      // Shimmer Loading (Always top-aligned)
      isIOSPlatform
          ? content = Center(child: CupertinoActivityIndicator())
          : content = Center(child: CircularProgressIndicator());
    } else if (products.isEmpty) {
      // Empty state (centered for full-screen impact)
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: theme.hintColor),
              const SizedBox(height: 20),
              Text(
                'No products available right now.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check back later for new arrivals!',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.hintColor.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (isDesktop) {
      // DESKTOP SPLIT VIEW: Products (2) | Details (1)
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 1 (Products - Flex 2)
          Expanded(
            flex: 2,
            child: _buildProductGrid(
              theme,
              horizontalPadding,
              spacing,
              cardWidth,
            ),
          ),

          // Column 2 (Details - Flex 1, Visible if selected)
          if (_isDetailsPanelVisible)
            Expanded(flex: 1, child: _buildDetailsPanel(theme))
          else
            // If panel is hidden, show a placeholder in the remaining space
            Expanded(flex: 1, child: _buildDetailsPanel(theme)),
        ],
      );
    } else {
      // MOBILE/TABLET VIEW (Single Column, always top-aligned)
      content = _buildProductGrid(theme, horizontalPadding, spacing, cardWidth);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButton: cartCount == 0
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
                loadCartCount();
              },
              backgroundColor: theme.primaryColor,
              child: Icon(
                Icons.shopping_cart_outlined,
                color: theme.scaffoldBackgroundColor.withOpacity(0.7),
              ),
            )
          : badges.Badge(
              badgeContent: Text(
                '$cartCount',
                style: const TextStyle(color: Colors.white),
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartPage()),
                  );
                  loadCartCount();
                },
                backgroundColor: theme.primaryColor,
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: theme.scaffoldBackgroundColor.withOpacity(0.5),
                ),
              ),
            ),
      body: content,
    );
  }
}
