import 'dart:convert';
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

// No need to define AppColors here as it's not in the provided code

class CartHelper {
  static const String _cartKey = 'cart';

  // --- UPDATED: addToCart now accepts a selectedColor ---
  static Future<void> addToCart(
      Map<String, dynamic> product, String? selectedColor) async {
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
      print("Error: Product ID is missing for product: ${product['productName']}");
      return;
    }

    bool productFound = false;
    for (int i = 0; i < cart.length; i++) {
      // --- IMPORTANT: Include selectedColor in the comparison for uniqueness ---
      if (cart[i]['productId'] == productId && cart[i]['selectedColor'] == selectedColor) {
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
      // --- Store the selected color in the cart item ---
      product['selectedColor'] = selectedColor;
      // The `subAccountCode` is already in the `product` map and is automatically added here.
      cart.add(product);
    }

    await prefs.setString(_cartKey, json.encode(cart));
  }

  static Future<void> removeFromCart(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData == null) return;

    List<Map<String, dynamic>> cart = List<Map<String, dynamic>>.from(
      (json.decode(cartData) as List).map(
        (item) => item as Map<String, dynamic>,
      ),
    );

    // This removeFromCart method removes a product by ID, which can be an issue if there are multiple
    // items with the same product ID but different colors. A more robust solution would be to
    // remove based on a unique identifier that includes both product ID and color.
    for (int i = 0; i < cart.length; i++) {
      if (cart[i]['productId'] == productId) {
        // Check only by productId for now
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

  @override
  void initState() {
    super.initState();
    loadCartCount();
    fetchAllSellerProducts();
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
          'description': productData['description'] ?? 'No description provided',
          'isAvailable': productData['isAvailable'] ?? true,
          'discountPercentage':
              (sellerData['discountPercentage'] as num?)?.toDouble() ?? 0.0,
          // --- NEW: Fetch availableColors from productData ---
          'availableColors': productData['availableColors'] ?? [],
          // --- NEW: Fetch subAccountCode from productData ---
          'subAccountCode': productData['subAccountCode'] ?? '',
          // Ensure it's a List<String>, default to empty list
        });
      }
    }

    setState(() {
      products = loadedProducts;
      _applyFilter();
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
  }

  // --- UPDATED: addToCart now accepts selectedColor from ProductDetails ---
  void addToCartFromProductDetails(
      Map<String, dynamic> product, String? selectedColor) async {
    final theme = Theme.of(context);
    await CartHelper.addToCart(product, selectedColor); // Pass selectedColor
    loadCartCount();

    toastification.dismissAll();
    Api().showMessage(
      context,
      '${product['productName']} (${selectedColor ?? 'Default'}) added to the cart', // Indicate color in message
      'Success',
      theme.primaryColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: cartCount == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CartPage()),
                  );
                },
                backgroundColor: theme.primaryColor,
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: theme.scaffoldBackgroundColor,
                ),
              ),
            ),
      body: products.isEmpty
          ? Shimmer.fromColors(
              baseColor: theme.colorScheme.onSurface.withOpacity(0.1),
              highlightColor: theme.colorScheme.onSurface.withOpacity(0.05),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 70,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                    ),
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      alignment: WrapAlignment.start,
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          width: (MediaQuery.of(context).size.width / 2) - 15,
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 230,
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
                                      Container(
                                        height: 14,
                                        width: double.infinity,
                                        color: Colors.white,
                                        margin: const EdgeInsets.only(bottom: 5),
                                      ),
                                      Container(
                                        height: 12,
                                        width: 80,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        height: 16,
                                        width: 100,
                                        color: Colors.white,
                                      ),
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
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: DefaultTabController(
                length: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabBar(
                      isScrollable: true,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: theme.hintColor,
                      dividerColor: Colors.transparent,
                      indicatorColor: theme.primaryColor,
                      unselectedLabelColor: theme.cardColor,
                      overlayColor: WidgetStatePropertyAll(theme.primaryColor),
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: theme.primaryColor,
                      ),
                      onTap: (index) {
                        setState(() {
                          switch (index) {
                            case 0:
                              _selectedCategory = 'All';
                              break;
                            case 1:
                              _selectedCategory = 'Shirts & Polos';
                              break;
                            case 2:
                              _selectedCategory = 'Suits & Jackets';
                              break;
                            case 3:
                              _selectedCategory = 'Trousers & Skirts';
                              break;
                            case 4:
                              _selectedCategory = 'Footwear';
                              break;
                            case 5:
                              _selectedCategory = 'Accessories';
                              break;
                            case 6:
                              _selectedCategory = 'Hats';
                              break;
                            case 7:
                              _selectedCategory = 'Shoes';
                              break;
                          }
                          _applyFilter();
                        });
                      },
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Shirts & Polos'),
                        Tab(text: 'Suits & Jackets'),
                        Tab(text: 'Trousers & Skirts'),
                        Tab(text: 'Footwear'),
                        Tab(text: 'Accessories'),
                        Tab(text: 'Hats'),
                        Tab(text: 'Shoes'),
                      ],
                    ),
                    Wrap(
                      spacing: 10.0,
                      runSpacing: 10.0,
                      alignment: WrapAlignment.start,
                      children: _filteredProducts.map((product) {
                        return SizedBox(
                          width: (MediaQuery.of(context).size.width / 2) - 15,
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                scrollControlDisabledMaxHeightRatio: 0.8,
                                context: context,
                                builder: (context) {
                                  return ProductDetails(
                                    productDetails: product,
                                    // The `sellerProductId` key is not used in the provided code,
                                    // but if it's needed elsewhere, ensure it's fetched correctly.
                                    sellerProductId: product['sellerProductId'] ?? '',
                                    onAddToCart: (selectedColor) {
                                      addToCartFromProductDetails(
                                        product,
                                        selectedColor,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                            child: Product_Card(
                              onCartPressed: () {
                                // This button will open the product details to allow the user
                                // to select a color before adding to the cart.
                                showModalBottomSheet(
                                  scrollControlDisabledMaxHeightRatio: 0.8,
                                  context: context,
                                  builder: (context) {
                                    return ProductDetails(
                                      productDetails: product,
                                      sellerProductId: product['sellerProductId'] ?? '',
                                      onAddToCart: (selectedColor) {
                                        addToCartFromProductDetails(
                                          product,
                                          selectedColor,
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
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}