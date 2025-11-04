import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/Item_Card.dart';
import 'package:ttact/Pages/Payment.dart';
import 'package:lottie/lottie.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;
// --------------------------

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
    // NOTE: For robustness, you may want to ensure this removal logic also considers
    // color and size if multiple identical products with different variants are in the cart.
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
        // If quantity is 1 and user tries to decrease, remove the item
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
    final color = Theme.of(context);
    
    // Determine the constrained width for the body content
    final double constrainedWidth = MediaQuery.of(context).size.width > _desktopContentMaxWidth 
        ? _desktopContentMaxWidth 
        : double.infinity;

    Widget emptyCartView = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 450), // Constrain empty cart view
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.network(
                'https://lottie.host/4f43b42d-3e11-4aaf-b07e-c3352b086a45/9QoklefHek.json',
                width: 250,
                height: 250,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Colors.grey,
                  );
                },
              ),
              const SizedBox(height: 30),
              Text(
                'Your cart is empty!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: color.hintColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Start adding some amazing products.',
                style: TextStyle(
                  fontSize: 16,
                  color: color.hintColor.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('Start Shopping'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.primaryColor,
                  foregroundColor: color.scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget cartContentView = Column(
      children: [
        Expanded(
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: constrainedWidth),
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  final qty = (item['quantity'] as int?) ?? 1;
                  // Use a combination of productId, color, and size for a unique key in case of identical products with different variants
                  final String uniqueKey = '${item['productId']}_${item['selectedColor']}_${item['selectedSize']}_$index'; 

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Dismissible(
                      key: ValueKey(uniqueKey),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      onDismissed: (direction) {
                        // NOTE: This currently removes ALL items with the same productId.
                        // For a precise cart, you should remove based on the unique key (productId, color, size).
                        removeFromCart(item['productId'].toString());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${item['productName']} removed from cart.',
                            ),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'UNDO',
                              onPressed: () {
                                loadCartItems();
                              },
                            ),
                          ),
                        );
                      },
                      child: ItemCard(
                        imageUrl: item['imageUrl'],
                        productName: item['productName'],
                        productPrice: (item['price'] as num?)?.toDouble(),
                        quantity: qty,
                        addQuantity: () => increaseQty(index),
                        subtractQuantity: () => decreaseQty(index),
                        // Display selected variants in the cart list item
                        selectedColor: item['selectedColor'] as String?, 
                        selectedSize: item['selectedSize'] as String?,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        // --- Cart Summary and Checkout Button (Sticky Footer) ---
        Container(
          // FIX: Ensure footer width is consistent with the constrained body content width
          width: constrainedWidth,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: color.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total (${cartItems.length} items):',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color.primaryColorDark,
                    ),
                  ),
                  Text(
                    'R${getTotalPrice().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.primaryColor,
                    foregroundColor: color.scaffoldBackgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  onPressed: cartItems.isEmpty
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Proceeding to checkout...'),
                              duration: Duration(seconds: 1),
                            ),
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
                  icon: const Icon(Icons.payment),
                  label: const Text(
                    'Proceed to Checkout',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: const Text(
          'Your Shopping Cart',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      // FIX: Use the responsive content views
      body: cartItems.isEmpty ? emptyCartView : cartContentView,
    );
  }
}