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
    setState(() {});
  }

  Future<void> removeFromCart(int index) async {

    cartItems.removeAt(index);
    await updateCart();
  }

  void increaseQty(int index) {
    setState(() {
      cartItems[index]['quantity'] = (cartItems[index]['quantity'] ?? 1) + 1;
    });
    updateCart();
  }

  void decreaseQty(int index) {
    setState(() {
      if ((cartItems[index]['quantity'] ?? 1) > 1) {
        cartItems[index]['quantity'] -= 1;
        updateCart();
      }
    });
  }

  double getTotalPrice() {
    return cartItems.fold(0.0, (total, item) {
      final price = item['price'] ?? 0.0;
      final qty = item['quantity'] ?? 1;
      return total + (price * qty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: const Text('I T E M S  I N  C A R T'),
        centerTitle: true,
      ),
      body:
          cartItems.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.network(
                      'https://lottie.host/4f43b42d-3e11-4aaf-b07e-c3352b086a45/9QoklefHek.json',
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text('Animation failed to load');
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Your cart is empty!',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              )
              : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        final qty = item['quantity'] ?? 1;

                        return Dismissible(
                          key: Key(item['id'].toString()), 
                          direction: DismissDirection.endToStart,  
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            removeFromCart(index);
                          },
                          child: ItemCard(
                            imageUrl: item['imageUrl'],
                            productName: item['productName'],
                            productPrice: item['price'],
                            quantity: qty,
                            addQuantity: () => increaseQty(index),
                            subtractQuantity: () => decreaseQty(index),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: color.primaryColor,
                              ),
                            ),
                            Text(
                              'R${getTotalPrice().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color.primaryColor,
                            foregroundColor: color.scaffoldBackgroundColor,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: () {
                            // TODO: Implement checkout logic
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Proceeding to checkout...'),
                              ),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const PaymentGatewayPage(),
                              ),
                            );
                          },
                          child: const Text('Proceed to Checkout'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }
}
