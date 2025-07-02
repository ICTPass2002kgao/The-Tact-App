import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentGatewayPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartProducts;
  const PaymentGatewayPage({required this.cartProducts, Key? key})
    : super(key: key);

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final _addressController = TextEditingController();
  bool needsDelivery = false;
  double deliveryCharge = 50.0;
  String? selectedPaymentMethod;
  bool isPlacingOrder = false;

  final paymentMethods = [
    'Credit/Debit Card',
    'Mobile Wallet',
    'PayPal',
    'Scan to Pay (QR Code)',
  ];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to place an order')),
      );
      return;
    }

    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your address')),
      );
      return;
    }

    if (selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    // Group products by seller for order creation
    Map<String, List<Map<String, dynamic>>> productsBySeller = {};
    for (var product in widget.cartProducts) {
      String sellerId = product['sellerId'] ?? 'unknown_seller';
      if (!productsBySeller.containsKey(sellerId)) {
        productsBySeller[sellerId] = [];
      }
      productsBySeller[sellerId]!.add(product);
    }

    final batch = FirebaseFirestore.instance.batch();

    productsBySeller.forEach((sellerId, products) {
      final orderDoc = FirebaseFirestore.instance.collection('orders').doc();

      batch.set(orderDoc, {
        'buyerId': user.uid,
        'sellerId': sellerId,
        'products': products,
        'address': _addressController.text,
        'needsDelivery': needsDelivery,
        'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
        'paymentMethod': selectedPaymentMethod,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();

    setState(() {
      isPlacingOrder = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order placed successfully!')));
    Navigator.pushNamed(context, 'routeName');
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: color.primaryColor,
        foregroundColor: color.scaffoldBackgroundColor,
        title: const Text('Payment & Delivery'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Enter your delivery address',
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Delivery Option',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Text('Pickup'),
                Radio<bool>(
                  value: false,
                  groupValue: needsDelivery,
                  onChanged: (val) {
                    setState(() {
                      needsDelivery = val ?? false;
                    });
                  },
                ),
                const Text('Delivery'),
                Radio<bool>(
                  value: true,
                  groupValue: needsDelivery,
                  onChanged: (val) {
                    setState(() {
                      needsDelivery = val ?? false;
                    });
                  },
                ),
              ],
            ),
            if (needsDelivery)
              Text(
                'Delivery Charge: R$deliveryCharge',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            const SizedBox(height: 20),
            const Text(
              'Choose Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ...paymentMethods.map((method) {
              return ListTile(
                title: Text(method),
                leading: Radio<String>(
                  value: method,
                  groupValue: selectedPaymentMethod,
                  onChanged: (val) {
                    setState(() {
                      selectedPaymentMethod = val;
                    });
                  },
                ),
              );
            }).toList(),
            const Spacer(),
            ElevatedButton(
              onPressed: isPlacingOrder ? null : placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                minimumSize: const Size.fromHeight(50),
              ),
              child: isPlacingOrder
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Continue to Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
