import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Components/Item_Card.dart';
import 'package:ttact/Pages/Payment.dart';
import 'package:lottie/lottie.dart';

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
      setState(() {}); // Rebuild to reflect the removed item
    }
  }

  void increaseQty(int index) {
    setState(() {
      int currentQuantity = (cartItems[index]['quantity'] as int?) ?? 0;
      double productPrice =
          (cartItems[index]['price'] as num?)?.toDouble() ?? 0.0;
      cartItems[index]['quantity'] = currentQuantity + 1;
      cartItems[index]['itemTotalPrice'] = (currentQuantity + 1) * productPrice;
    });
    updateCart();
  }

  void decreaseQty(int index) {
    setState(() {
      int currentQuantity = (cartItems[index]['quantity'] as int?) ?? 0;
      if (currentQuantity > 1) {
        double productPrice =
            (cartItems[index]['price'] as num?)?.toDouble() ?? 0.0;
        cartItems[index]['quantity'] = currentQuantity - 1;
        cartItems[index]['itemTotalPrice'] =
            (currentQuantity - 1) * productPrice;
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
    final color = Theme.of(context); //Access your defined theme colors
    return Scaffold(
      appBar: AppBar(
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: const Text(
          'Your Shopping Cart',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0, // Remove shadow for a flat, modern look
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.network(
                    'https://lottie.host/4f43b42d-3e11-4aaf-b07e-c3352b086a45/9QoklefHek.json',
                    width: 250, // Slightly larger Lottie
                    height: 250,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.shopping_cart_outlined,
                        size: 100,
                        color: Colors.grey,
                      ); // Fallback icon
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
                      Navigator.pop(context); // Go back to shopping
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
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(
                      16.0,
                    ), // Padding for the entire list
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final qty = (item['quantity'] as int?) ?? 1;
                      final String productId =
                          item['productId']?.toString() ??
                          'uniqueId_${index}_${DateTime.now().microsecondsSinceEpoch}';

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12.0,
                        ), // Space between cards
                        child: Dismissible(
                          key: ValueKey(productId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // Match card border radius
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
                            removeFromCart(productId);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${item['productName']} removed from cart.',
                                ),
                                duration: const Duration(seconds: 2),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () {
                                    // A simple undo would re-add the item.
                                    // For a robust undo, you'd save the dismissed item and re-insert it.
                                    // For now, reloading the cart is the simplest way.
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
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // --- Cart Summary and Checkout Button ---
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: color
                        .scaffoldBackgroundColor, // Background for the summary
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, -3), // Shadow at the top
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
                            'Total (${cartItems.length} items):', // Show item count
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color
                                  .primaryColorDark, // Use a darker color for emphasis
                            ),
                          ),
                          Text(
                            'R${getTotalPrice().toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22, // Larger for total price
                              fontWeight: FontWeight.bold,
                              color:
                                  Colors.green[700], // Stronger green for total
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        // Make button full width
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color.primaryColor,
                            foregroundColor: color.scaffoldBackgroundColor,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                12,
                              ), // More rounded corners
                            ),
                            elevation: 5, // Add some elevation to the button
                          ),
                          onPressed:
                              cartItems
                                  .isEmpty // Disable button if cart is empty
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Proceeding to checkout...',
                                      ),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PaymentGatewayPage(
                                        cartProducts: cartItems, selectedColor: '', selectedSize: '',
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
            ),
    );
  }
}
