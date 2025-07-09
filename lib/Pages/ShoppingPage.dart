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

class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> addToCart(Map<String, dynamic> product) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    List<Map<String, dynamic>> cart = [];

    if (cartData != null) {
      cart = List<Map<String, dynamic>>.from(json.decode(cartData));
    }

    cart.add(product);
    await prefs.setString(_cartKey, json.encode(cart));
  }

  static Future<List<Map<String, dynamic>>> getCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartData = prefs.getString(_cartKey);

    if (cartData != null) {
      return List<Map<String, dynamic>>.from(json.decode(cartData));
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

  @override
  void initState() {
    super.initState();
    loadCartCount();
    fetchAllSellerProducts(); // 🔥 Load seller-added products from Firestore
  }

  void loadCartCount() async {
    List<Map<String, dynamic>> cart = await CartHelper.getCart();
    setState(() {
      cartCount = cart.length;
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
          'price': sellerData['price'],
          'location': sellerData['location'],
          'productId': sellerData['productId'],
        });
      }
    }

    setState(() {
      products = loadedProducts;
    });
  }

  void addToCart(Map<String, dynamic> product) async {
    await CartHelper.addToCart(product);
    loadCartCount();

    final color = Theme.of(context);
    toastification.dismissAll();
    Api().showMessage(
      context,
      'Your Product is addded to the cart',
      'Success',
      color.splashColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      floatingActionButton: cartCount.isNaN || cartCount == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CartPage()),
                );
              },
              backgroundColor: color.primaryColor,
              child: Icon(
                Icons.shopping_cart_outlined,
                color: color.scaffoldBackgroundColor,
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
                backgroundColor: color.primaryColor,
                child: Icon(
                  Icons.shopping_cart_outlined,
                  color: color.scaffoldBackgroundColor,
                ),
              ),
            ),
      body: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.65,
        padding: EdgeInsets.all(10),
        children: products.map((product) {
          return GestureDetector(
            onTap: () {
              showModalBottomSheet(
                scrollControlDisabledMaxHeightRatio: 0.8,
                context: context,
                builder: (context) {
                  return ProductDetails(productDetails: products[4]);
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
              productDescription:
                  product['description'] ?? 'Here is a description',
              isAvailable: true,
            ),
          );
        }).toList(),
      ),
    );
  }
}
