// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Pages/User/bottom_navigation_bar.dart/shoppin_pages.dart/Payment.dart';
import 'package:lottie/lottie.dart';

// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;

bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> cartItems = [];

  @override
  void initState() {
    super.initState();
    loadCartItems();
  }

  Future<void> loadCartItems() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cartJson = prefs.getString('cart');

    if (cartJson != null) {
      final List decoded = json.decode(cartJson);
      setState(() {
        cartItems = decoded.cast<Map<String, dynamic>>();
      });
    }
  }

  Future<void> updateCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart', json.encode(cartItems));
  }

  Future<void> removeFromCart(String productIdToRemove) async {
    final int initialLength = cartItems.length;
    cartItems.removeWhere((item) => item['productId'] == productIdToRemove);

    if (cartItems.length < initialLength) {
      await updateCart();
      setState(() {});
    }
  }

  void increaseQty(int index) {
    setState(() {
      int currentQuantity = (cartItems[index]['quantity'] as int?) ?? 0;
      double productPrice = (cartItems[index]['price'] as num?)?.toDouble() ?? 0.0;
      cartItems[index]['quantity'] = currentQuantity + 1;
      cartItems[index]['itemTotalPrice'] = (currentQuantity + 1) * productPrice;
    });
    updateCart();
  }

  void decreaseQty(int index) {
    setState(() {
      int currentQuantity = (cartItems[index]['quantity'] as int?) ?? 0;
      if (currentQuantity > 1) {
        double productPrice = (cartItems[index]['price'] as num?)?.toDouble() ?? 0.0;
        cartItems[index]['quantity'] = currentQuantity - 1;
        cartItems[index]['itemTotalPrice'] = (currentQuantity - 1) * productPrice;
        updateCart();
      } else {
        removeFromCart(cartItems[index]['productId'].toString());
      }
    });
  }

  double getTotalPrice() {
    return cartItems.fold(0.0, (total, item) {
      final itemTotalPrice = (item['itemTotalPrice'] as num?)?.toDouble();
      if (itemTotalPrice != null) {
        return total + itemTotalPrice;
      } else {
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (item['quantity'] as int?) ?? 1;
        return total + (price * qty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ⭐️ NEUMORPHIC TINT CALCULATION
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    // Layout Constraints
    final double constrainedWidth = MediaQuery.of(context).size.width > _desktopContentMaxWidth 
        ? _desktopContentMaxWidth 
        : double.infinity;

    // --- EMPTY STATE VIEW ---
    Widget emptyCartView = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Sunken container for the animation
              NeumorphicContainer(
                color: neumoBaseColor,
                isPressed: true, // Sunken
                borderRadius: 200, // Circle
                padding: EdgeInsets.all(30),
                child: Lottie.network(
                  'https://lottie.host/4f43b42d-3e11-4aaf-b07e-c3352b086a45/9QoklefHek.json',
                  width: 180,
                  height: 180,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.shopping_cart_outlined, size: 80, color: theme.hintColor);
                  },
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Your cart is empty!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
              const SizedBox(height: 10),
              Text(
                'Start adding some amazing products.',
                style: TextStyle(fontSize: 16, color: theme.hintColor),
              ),
              const SizedBox(height: 40),
              
              // Neumorphic "Start Shopping" Button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: NeumorphicContainer(
                  color: theme.primaryColor,
                  isPressed: false,
                  borderRadius: 30,
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.shopping_bag_outlined, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Start Shopping',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // --- MAIN CART CONTENT ---
    Widget cartContentView = Column(
      children: [
        Expanded(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: constrainedWidth),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  final qty = (item['quantity'] as int?) ?? 1;
                  final String uniqueKey = '${item['productId']}_${item['selectedColor']}_${item['selectedSize']}_$index'; 

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Dismissible(
                      key: ValueKey(uniqueKey),
                      direction: DismissDirection.endToStart,
                      background: Padding(
                        padding: const EdgeInsets.only(left: 20.0), // Indent so it slides behind
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 30),
                        ),
                      ),
                      onDismissed: (direction) {
                        removeFromCart(item['productId'].toString());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item['productName']} removed from cart.'),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(label: 'UNDO', onPressed: () => loadCartItems()),
                          ),
                        );
                      },
                      child: _buildNeumorphicCartItem(theme, neumoBaseColor, item, qty, index),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        
        // --- NEUMORPHIC FOOTER ---
        Container(
          width: constrainedWidth,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: neumoBaseColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            // Soft top shadow to separate footer
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, -5),
              )
            ]
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Totals Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total (${cartItems.length} items)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                    ),
                  ),
                  Text(
                    'R${getTotalPrice().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              
              // Checkout Button
              GestureDetector(
                onTap: cartItems.isEmpty ? null : () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Proceeding to checkout...'), duration: Duration(seconds: 1)),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentGatewayPage(
                        cartProducts: cartItems,
                        selectedColor: '',
                        selectedSize: '',
                      ),
                    ),
                  );
                },
                child: NeumorphicContainer(
                  color: theme.primaryColor,
                  borderRadius: 20,
                  isPressed: false,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.payment, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Proceed to Checkout',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            // --- CUSTOM NEUMORPHIC APP BAR ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: NeumorphicContainer(
                      color: neumoBaseColor,
                      borderRadius: 50,
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back, color: theme.primaryColor),
                    ),
                  ),
                  Text(
                    "My Cart",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: theme.primaryColor,
                    ),
                  ),
                  // Placeholder for spacing to center title
                  SizedBox(width: 45), 
                ],
              ),
            ),
            
            Expanded(
              child: cartItems.isEmpty ? emptyCartView : cartContentView,
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER: Build a single Neumorphic Cart Item ---
  Widget _buildNeumorphicCartItem(ThemeData theme, Color baseColor, Map<String, dynamic> item, int qty, int index) {
    return NeumorphicContainer(
      color: baseColor,
      isPressed: false, // Convex Card
      borderRadius: 20,
      padding: EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGE (Framed)
          NeumorphicContainer(
            color: baseColor,
            isPressed: true, // Sunken frame
            borderRadius: 15,
            padding: EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item['imageUrl'] ?? '',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (c,e,s) => Container(
                  width: 80, height: 80, 
                  color: Colors.grey[200], 
                  child: Icon(Icons.image_not_supported, color: Colors.grey)
                ),
              ),
            ),
          ),
          
          SizedBox(width: 15),
          
          // 2. DETAILS & CONTROLS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Name and Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['productName'] ?? 'Product',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'R${((item['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.primaryColor),
                    ),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // Variants (Size/Color)
                if (item['selectedSize'] != null || item['selectedColor'] != null)
                  Wrap(
                    spacing: 8,
                    children: [
                      if(item['selectedSize'] != null)
                        Text("Size: ${item['selectedSize']}", style: TextStyle(fontSize: 12, color: theme.hintColor)),
                      if(item['selectedColor'] != null)
                        Text("Color: ${item['selectedColor']}", style: TextStyle(fontSize: 12, color: theme.hintColor)),
                    ],
                  ),
                  
                SizedBox(height: 12),
                
                // Bottom Row: Qty Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Decrease Button
                    GestureDetector(
                      onTap: () => decreaseQty(index),
                      child: NeumorphicContainer(
                        color: baseColor,
                        borderRadius: 10,
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.remove, size: 16, color: theme.hintColor),
                      ),
                    ),
                    
                    // Quantity Display (Sunken)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        '$qty',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    // Increase Button
                    GestureDetector(
                      onTap: () => increaseQty(index),
                      child: NeumorphicContainer(
                        color: theme.primaryColor, // Highlighted
                        borderRadius: 10,
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.add, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}