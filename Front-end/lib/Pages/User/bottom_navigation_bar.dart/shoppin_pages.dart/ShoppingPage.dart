// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;
import 'package:toastification/toastification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/ProductCard.dart'; // Assuming this exists
import 'package:ttact/Components/Product_Details.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/CartPage.dart';
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

// --- CART HELPER (Unchanged Logic) ---
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
    if (productId == null) return;

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
  String _searchQuery = '';

  // Desktop State
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
    if (user != null) _currentUserId = user.uid;
  }

  void loadCartCount() async {
    List<Map<String, dynamic>> cart = await CartHelper.getCart();
    int totalItems = 0;
    for (var item in cart) {
      totalItems += (item['quantity'] as int? ?? 0);
    }
    setState(() => cartCount = totalItems);
  }

  void fetchAllSellerProducts() async {
    setState(() => _isLoading = true);
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
    Iterable<Map<String, dynamic>> tempProducts = products;

    if (_selectedCategory != 'All') {
      tempProducts = tempProducts.where(
        (product) => product['category'] == _selectedCategory,
      );
    }
    if (query.isNotEmpty) {
      tempProducts = tempProducts.where((product) {
        final productName =
            (product['productName'] as String?)?.toLowerCase() ?? '';
        final category = (product['category'] as String?)?.toLowerCase() ?? '';
        return productName.contains(query) || category.contains(query);
      });
    }
    _filteredProducts = tempProducts.toList();
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
      '${product['productName']} added to cart',
      'Success',
      theme.primaryColor,
    );
  }

  void _handleProductClick(Map<String, dynamic> product) {
    if (isLargeScreen(context)) {
      setState(() {
        _selectedProductDetails = product;
        _isDetailsPanelVisible = true;
      });
    } else {
      final theme = Theme.of(context);
      final baseColor = Color.alphaBlend(
        theme.primaryColor.withOpacity(0.08),
        theme.scaffoldBackgroundColor,
      );

      showModalBottomSheet(
        scrollControlDisabledMaxHeightRatio: 0.8,
        context: context,
        backgroundColor: baseColor,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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

  // --- NEUMORPHIC PRODUCT GRID ---
  Widget _buildProductGrid(
    ThemeData theme,
    Color baseColor,
    double horizontalPadding,
    double spacing,
    double cardWidth,
  ) {
    final isDesktop = isLargeScreen(context);

    Widget productContent = SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⭐️ 1. NEUMORPHIC SEARCH BAR
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: NeumorphicContainer(
              color: baseColor,
              isPressed: true, // Sunken
              borderRadius: 30,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilter();
                    _isDetailsPanelVisible = false;
                    _selectedProductDetails = null;
                  });
                },
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: TextStyle(color: theme.hintColor),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, color: theme.primaryColor),
                ),
              ),
            ),
          ),

          // ⭐️ 2. NEUMORPHIC CATEGORY PILLS
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productCategories.length,
              itemBuilder: (context, index) {
                final category = _productCategories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _applyFilter();
                        _isDetailsPanelVisible = false;
                        _selectedProductDetails = null;
                      });
                    },
                    child: NeumorphicContainer(
                      color: isSelected ? theme.primaryColor : baseColor,
                      isPressed: false,
                      borderRadius: 20,
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 0,
                      ), // Vertical 0 allows centering
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : theme.hintColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 20),

          // ⭐️ 3. PRODUCT GRID
          if (_filteredProducts.isEmpty && !_isLoading)
            Center(
              child: NeumorphicContainer(
                color: baseColor,
                isPressed: true,
                borderRadius: 20,
                padding: EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 50, color: theme.hintColor),
                    SizedBox(height: 10),
                    Text(
                      'No products found.',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _filteredProducts.map((product) {
                final bool isSellerProduct =
                    _currentUserId == product['sellerId'];
                final bool isSelected =
                    isDesktop &&
                    _selectedProductDetails?['productId'] ==
                        product['productId'] &&
                    _selectedProductDetails?['sellerId'] == product['sellerId'];

                return SizedBox(
                  width: cardWidth,
                  child: GestureDetector(
                    onTap: () => _handleProductClick(product),
                    // Wrapping the existing ProductCard in a Neumorphic Container
                    child: NeumorphicContainer(
                      color: isSelected
                          ? theme.primaryColor.withOpacity(0.05)
                          : baseColor,
                      isPressed: false, // Convex Tile
                      borderRadius: 18,
                      padding: EdgeInsets.all(0), // Tight wrap
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Product_Card(
                          onCartPressed: () => _handleProductClick(product),
                          imageUrl: product['imageUrl'],
                          categoryName: product['category'],
                          productName: product['productName'],
                          price: product['price'],
                          discountPercentage: product['discountPercentage'],
                          location: product['location'] ?? '',
                          isAvailable: product['isAvailable'] ?? true,
                          availableColors:
                              product['availableColors'] as dynamic,
                          isSellerProduct: isSellerProduct,
                          // Pass null for border as NeumorphicContainer handles it visually
                          cardBorder: null,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(maxWidth: 1200.0),
        child: productContent,
      ),
    );
  }

  // --- NEUMORPHIC DETAILS PANEL ---
  Widget _buildDetailsPanel(ThemeData theme, Color baseColor) {
    if (!_isDetailsPanelVisible || _selectedProductDetails == null) {
      return Center(child: Text('Select a product to view details.'));
    }

    return Container(
      padding: EdgeInsets.all(20.0),
      decoration: BoxDecoration(color: baseColor), // Match background
      child: NeumorphicContainer(
        color: baseColor,
        isPressed: false, // Convex Panel
        borderRadius: 20,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
            onClose: () => setState(() {
              _isDetailsPanelVisible = false;
              _selectedProductDetails = null;
            }),
            isStandalone: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    // Layout Logic
    final int crossAxisCount = isDesktop ? (_isDetailsPanelVisible ? 3 : 5) : 2;
    final double horizontalPadding = isDesktop ? 20.0 : 10.0;
    final double spacing = isDesktop ? 20.0 : 12.0;
    final double screenWidth = MediaQuery.of(context).size.width;

    double availableWidth = isDesktop
        ? (screenWidth > 1200 ? 1200 : screenWidth)
        : screenWidth;

    if (isDesktop && _isDetailsPanelVisible)
      availableWidth = availableWidth * 0.6; // 60% width if split

    availableWidth -= (horizontalPadding * 2);
    final double cardWidth =
        (availableWidth - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

    Widget content;
    if (_isLoading) {
      content = Center(
        child: isIOSPlatform
            ? CupertinoActivityIndicator()
            : CircularProgressIndicator(),
      );
    } else if (products.isEmpty) {
      content = Center(
        child: Text(
          "No products available",
          style: TextStyle(color: theme.hintColor),
        ),
      );
    } else if (isDesktop) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _buildProductGrid(
              theme,
              neumoBaseColor,
              horizontalPadding,
              spacing,
              cardWidth,
            ),
          ),
          if (_isDetailsPanelVisible)
            Expanded(flex: 2, child: _buildDetailsPanel(theme, neumoBaseColor)),
        ],
      );
    } else {
      content = _buildProductGrid(
        theme,
        neumoBaseColor,
        horizontalPadding,
        spacing,
        cardWidth,
      );
    }

    return Scaffold(
      backgroundColor: neumoBaseColor,
      // ⭐️ NEUMORPHIC FLOATING CART BUTTON
      floatingActionButton: GestureDetector(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CartPage()),
          );
          loadCartCount();
        },
        child: NeumorphicContainer(

              color: NeuTheme.background, 

          isPressed: false,
          padding: EdgeInsets.all(16),
          child: cartCount == 0
              ? Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.white,
                  size: 28,
                )
              : badges.Badge(
                  badgeContent: Text(
                    '$cartCount',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(badgeColor: Colors.white),
                  child: Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
        ),
      ),
      body: content,
    );
  }
}
