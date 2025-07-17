import 'dart:convert';
import 'package:flutter/material.dart'; // Keep this for basic Flutter types
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart'
    as badges; // Keep as it's used in ShoppingPage
import 'package:toastification/toastification.dart'; // Keep as it's used
import 'package:cloud_firestore/cloud_firestore.dart'; // Keep as it's used
import 'package:ttact/Components/API.dart'; // Keep as it's used
import 'package:ttact/Components/ProductCard.dart'; // Keep as it's used
import 'package:ttact/Components/Product_Details.dart'; // Keep as it's used
import 'package:ttact/Pages/CartPage.dart'; // Keep as it's used

// REMOVED AppColors class definition as per your request

class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> addToCart(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    List<Map<String, dynamic>> cart = [];

    if (cartData != null) {
      // Decode with a type cast to ensure correct map types
      cart = List<Map<String, dynamic>>.from(
        (json.decode(cartData) as List).map(
          (item) => item as Map<String, dynamic>,
        ),
      );
    }

    final String? productId = product['productId'];
    if (productId == null) {
      // It's good practice to log or handle this error
      print(
        "Error: Product ID is missing for product: ${product['productName']}",
      );
      return; // Cannot process without a product ID
    }

    bool productFound = false;
    for (int i = 0; i < cart.length; i++) {
      if (cart[i]['productId'] == productId) {
        // Product already in cart, increase quantity and update price
        // Ensure quantity exists and is an int, default to 0 if not
        int currentQuantity = (cart[i]['quantity'] as int?) ?? 0;
        double productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;

        cart[i]['quantity'] = currentQuantity + 1;
        cart[i]['itemTotalPrice'] = cart[i]['quantity'] * productPrice;
        productFound = true;
        break;
      }
    }

    if (!productFound) {
      // Product not in cart, add it with quantity 1
      double productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      product['quantity'] = 1;
      product['itemTotalPrice'] = productPrice; // Initial item total
      cart.add(product);
    }

    await prefs.setString(_cartKey, json.encode(cart));
  }

  // Method to decrease quantity or remove item from cart (still relevant for cart management)
  static Future<void> removeFromCart(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData == null) return;

    List<Map<String, dynamic>> cart = List<Map<String, dynamic>>.from(
      (json.decode(cartData) as List).map(
        (item) => item as Map<String, dynamic>,
      ),
    );

    for (int i = 0; i < cart.length; i++) {
      if (cart[i]['productId'] == productId) {
        int currentQuantity = (cart[i]['quantity'] as int?) ?? 0;
        if (currentQuantity > 1) {
          cart[i]['quantity'] = currentQuantity - 1;
          double productPrice = (cart[i]['price'] as num?)?.toDouble() ?? 0.0;
          cart[i]['itemTotalPrice'] = cart[i]['quantity'] * productPrice;
        } else {
          // Remove the item if quantity becomes 1 (or less)
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

  // REMOVED _favoriteProductIds Set as per your request
  // REMOVED _loadFavorites() and _saveFavorites() as per your request
  // REMOVED toggleFavorite() as per your request

  @override
  void initState() {
    super.initState();
    loadCartCount();
    // REMOVED _loadFavorites() call
    fetchAllSellerProducts();
  }

  // Calculate total distinct items in cart for badge count
  void loadCartCount() async {
    List<Map<String, dynamic>> cart = await CartHelper.getCart();
    int totalItems = 0;
    for (var item in cart) {
      // Sum up quantities. Ensure quantity is treated as int, default to 0.
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
          'categoryName': productData['category'] ?? 'Other',
          'productName': productData['name'],
          'price': (sellerData['price'] as num)
              .toDouble(), // Ensure price is double
          'location': sellerData['location'],
          'sellerId': sellerData['sellerId'],
          'productId':
              sellerData['productId'], // Make sure productId is included
          'description':
              productData['description'] ??
              'No description provided', // Add description
          'isAvailable': productData['isAvailable'] ?? true, // Add isAvailable
        });
      }
    }

    setState(() {
      products = loadedProducts;
    });
  }

  void addToCart(Map<String, dynamic> product) async {
    final themeColor = Theme.of(context); // Get theme colors dynamically
    await CartHelper.addToCart(product);
    loadCartCount(); // Recalculate cart count to reflect quantity changes

    toastification.dismissAll();
    // Assuming Api().showMessage is designed to use a BuildContext for theming
    Api().showMessage(
      context,
      '${product['productName']} added to the cart', // More specific message
      'Success',
      themeColor.splashColor, // Use themeColor as requested
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ensure 'color' is accessed within build for dynamic theming
    final themeColor = Theme.of(context); // Get theme colors dynamically

    return Scaffold(
      floatingActionButton:
          cartCount ==
              0 // Check for 0 directly, no isNaN needed if int
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CartPage()),
                );
              },
              backgroundColor: themeColor.primaryColor,
              child: Icon(
                Icons.shopping_cart_outlined,
                color: themeColor.scaffoldBackgroundColor,
              ),
            )
          : badges.Badge(
              badgeContent: Text(
                '$cartCount',
                style: TextStyle(color: Colors.white),
              ),
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => CartPage()),
                  );
                },

                backgroundColor: themeColor.primaryColor,
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: themeColor.scaffoldBackgroundColor,
                ),
              ),
            ),
      body: products.isEmpty
          ? const Center(
              child: CircularProgressIndicator(),
            ) // Show loading indicator if products are empty
          : SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 10.0, // Horizontal space between cards
                runSpacing: 10.0, // Vertical space between rows of cards
                alignment:
                    WrapAlignment.start, // Align items to the start of the row
                children: products.map((product) {
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
                            ); // Pass the correct product data
                          },
                        );
                      },
                      child: Product_Card(
                        onCartPressed: () {
                          addToCart(product);
                        },
                        imageUrl: product['imageUrl'],
                        categoryName: product['categoryName'],
                        productName: product['productName'],
                        price: product['price'],
                        location: product['location'] ?? '',
                        isAvailable:
                            product['isAvailable'] ??
                            true, // Use actual availability from data
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }
}
