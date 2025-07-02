import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:badges/badges.dart' as badges;
import 'package:toastification/toastification.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/ProductCard.dart';
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
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 5),
      title: Text('${product['productName']} added to cart'),
      description: RichText(
        text: const TextSpan(
          text: 'The product was successfully added to your cart.',
        ),
      ),
      alignment: Alignment.bottomCenter,
      animationDuration: const Duration(milliseconds: 500),
      animationBuilder: (context, animation, alignment, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      icon: const Icon(Icons.check),
      showIcon: true,
      primaryColor: color.scaffoldBackgroundColor,
      backgroundColor: color.primaryColor,
      foregroundColor: Colors.black,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x07000000),
          blurRadius: 16,
          offset: Offset(0, 16),
          spreadRadius: 0,
        ),
      ],
      showProgressBar: true,
      closeButton: ToastCloseButton(
        showType: CloseButtonShowType.onHover,
        buttonBuilder: (context, onClose) {
          return OutlinedButton.icon(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Close'),
          );
        },
      ),
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
      applyBlurEffect: true,
      callbacks: ToastificationCallbacks(
        onTap: (toastItem) => print('Toast ${toastItem.id} tapped'),
        onCloseButtonTap: (toastItem) =>
            print('Toast ${toastItem.id} close button tapped'),
        onAutoCompleteCompleted: (toastItem) =>
            print('Toast ${toastItem.id} auto complete completed'),
        onDismissed: (toastItem) => print('Toast ${toastItem.id} dismissed'),
      ),
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
        childAspectRatio: 0.67,
        padding: EdgeInsets.all(10),
        children: products.map((product) {
          return Product_Card(
            onCartPressed: () {
              addToCart(product);
            },
            imageUrl: product['imageUrl'],
            categoryName: product['categoryName'],
            productName: product['productName'],
            price: product['price'],
            productDescription: 'Nice product',
            isAvailable: true,
          );
        }).toList(),
      ),
    );
  }
}
