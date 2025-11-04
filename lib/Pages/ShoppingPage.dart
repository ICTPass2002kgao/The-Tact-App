// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;
import 'package:toastification/toastification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/ProductCard.dart';
import 'package:ttact/Components/Product_Details.dart';
import 'package:ttact/Pages/CartPage.dart' ;
import 'package:shimmer/shimmer.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- PLATFORM UTILITIES ---
const double _desktopBreakpoint = 1000.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _desktopBreakpoint;
// --------------------------

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
    if (_selectedCategory == 'All') {
      _filteredProducts = products;
    } else {
      _filteredProducts = products
          .where((product) => product['category'] == _selectedCategory)
          .toList();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = isLargeScreen(context);
    
    // Determine the number of columns for the grid based on screen size
    final int crossAxisCount = isDesktop ? 4 : 2;
    
    // Calculate the width for individual product cards in the grid/wrap
    final double horizontalPadding = isDesktop ? 20.0 : 10.0;
    final double spacing = isDesktop ? 20.0 : 10.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    
    final double availableWidth = screenWidth > 1200 ? 1200 - (horizontalPadding * 2) : screenWidth - (horizontalPadding * 2);
    final double cardWidth = (availableWidth - ((crossAxisCount - 1) * spacing)) / crossAxisCount;

    Widget content;

    if (_isLoading) {
      // Responsive Shimmer Loading
      content = Shimmer.fromColors(
        baseColor: theme.colorScheme.onSurface.withOpacity(0.1),
        highlightColor: theme.colorScheme.onSurface.withOpacity(0.05),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shimmer for Tabs/Filter
              Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                margin: const EdgeInsets.only(bottom: 20),
              ),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                alignment: WrapAlignment.start,
                children: List.generate(
                  8,
                  (index) => SizedBox(
                    width: cardWidth, // Use responsive card width
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 200,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(height: 14, width: double.infinity, color: Colors.white, margin: const EdgeInsets.only(bottom: 5)),
                                Container(height: 12, width: 80, color: Colors.white),
                                const SizedBox(height: 10),
                                Container(height: 16, width: 100, color: Colors.white),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (products.isEmpty) {
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
    } else {
      content = Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 1200), // Max width constraint
          child: SingleChildScrollView(
            padding: EdgeInsets.all(horizontalPadding),
            child: DefaultTabController(
              length: _productCategories.length,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Category Tabs
                  TabBar(
                    isScrollable: !isLargeScreen(context), // Scrollable only on smaller screens
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: theme.scaffoldBackgroundColor, // Label color changes when selected
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
                      });
                    },
                    tabs: _productCategories.map((category) => Tab(text: category)).toList(),
                  ),
                  SizedBox(height: 20),
                  
                  // Product Grid/Wrap
                  Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.start,
                    children: _filteredProducts.map((product) {
                      final bool isSellerProduct =
                          _currentUserId == product['sellerId'];
                      
                      return SizedBox(
                        width: cardWidth, // Use responsive card width
                        child: GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              scrollControlDisabledMaxHeightRatio: 0.8,
                              context: context,
                              builder: (context) {
                                return ProductDetails(
                                  productDetails: product,
                                  sellerProductId: product['sellerId'],
                                  onAddToCart: (selectedColor, selectedSize) {
                                    addToCartFromProductDetails(
                                      product,
                                      selectedColor,
                                      selectedSize,
                                    );
                                  },
                                );
                              },
                            );
                          },
                          child: Product_Card(
                            onCartPressed: () {
                              showModalBottomSheet(
                                scrollControlDisabledMaxHeightRatio: 0.8,
                                context: context,
                                builder: (context) {
                                  return ProductDetails(
                                    productDetails: product,
                                    sellerProductId: product['sellerId'],
                                    onAddToCart: (selectedColor, selectedSize) {
                                      addToCartFromProductDetails(
                                        product,
                                        selectedColor,
                                        selectedSize,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            imageUrl: product['imageUrl'],
                            categoryName: product['category'],
                            productName: product['productName'],
                            price: product['price'],
                            discountPercentage: product['discountPercentage'],
                            location: product['location'] ?? '',
                            isAvailable: product['isAvailable'] ?? true,
                            availableColors: product['availableColors'] as dynamic,
                            isSellerProduct: isSellerProduct,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
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
                color: theme.scaffoldBackgroundColor,
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
                  color: theme.scaffoldBackgroundColor,
                ),
              ),
            ),
      body: content,
    );
  }
}