import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORTANT: CONFIGURE YOUR BACKEND ENDPOINT ---
const String YOUR_BACKEND_BASE_URL =
    'https://us-central1-tact-3c612.cloudfunctions.net/api';

class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }
}

class PaymentGatewayPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartProducts;
  final String selectedColor;
  final String selectedSize;
  const PaymentGatewayPage({
    required this.cartProducts,
    Key? key,
    required this.selectedColor,
    required this.selectedSize,
  }) : super(key: key);

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final TextEditingController _addressController = TextEditingController();
  bool needsDelivery = false;
  double deliveryCharge = 50.0;
  bool isPlacingOrder = false;
  bool _isLoadingAddress = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _initializeAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  void _initializeAddress() async {
    setState(() {
      _isLoadingAddress = true;
      _addressController.text = 'Loading address...';
    });

    User? currentUser = _auth.currentUser;
    if (currentUser != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          String? storedAddress = userData?['address'];
          if (storedAddress != null && storedAddress.isNotEmpty) {
            _addressController.text = storedAddress;
            setState(() {
              _isLoadingAddress = false;
            });
            return;
          }
        }
      } catch (e) {
        print("Error fetching user address from Firestore: $e");
      }
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _addressController.text = 'Fetching your current location...';
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationError('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationError('Location permissions are denied.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationError('Location permissions are permanently denied.');
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address =
            "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}, ${place.country}";
        _addressController.text = address;
      } else {
        _addressController.text = 'Could not determine address from location.';
      }
    } catch (e) {
      print("Error getting current location: $e");
      _showLocationError(
        'Failed to get current location. Please enter your address manually.',
      );
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _showLocationError(String message) {
    setState(() {
      _isLoadingAddress = false;
      _addressController.text = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  double _calculateSubtotal() {
    double subtotal = 0.0;
    for (var product in widget.cartProducts) {
      final productPrice = (product['price'] as num?)?.toDouble() ?? 0.0;
      final productQuantity = (product['quantity'] as int?) ?? 1;
      subtotal += productPrice * productQuantity;
    }
    return subtotal;
  }

  double _calculateTotal() {
    double total = _calculateSubtotal();
    if (needsDelivery) {
      total += deliveryCharge;
    }
    return total;
  }

  Future<void> _payWithPaystack() async {
    if (widget.cartProducts.isEmpty) {
      Api().showMessage(
        context,
        'Cart is empty!',
        'No items to checkout.',
        Colors.red,
      );
      return;
    }
    if (_addressController.text.isEmpty) {
      Api().showMessage(
        context,
        'Please provide a delivery address.',
        'Address Missing',
        Colors.red,
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Api().showMessage(
        context,
        'You must be logged in to pay.',
        'Not Logged In',
        Colors.red,
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    String? createdOrderReference;
    StreamSubscription<DocumentSnapshot>? subscription;

    try {
      // 1. CREATE PENDING ORDER IN FIRESTORE
      final orderDoc = FirebaseFirestore.instance.collection('orders').doc();
      createdOrderReference = orderDoc.id;

      final orderData = {
        'orderId': createdOrderReference,
        'userId': user.uid,
        'products': widget.cartProducts.map((p) {
          return {
            'productName': p['productName'],
            'price': p['price'],
            'quantity': p['quantity'] ?? 1,
            'imageUrl': p['imageUrl'],
            'sellerId': p['sellerId'],
            'subaccountCode': p['subaccountCode'],
            'selectedColor': p['selectedColor'], // Use the correct key
            'selectedSize': p['selectedSize'], // Use the correct key
            'itemTotalPrice': (p['price'] as num) * (p['quantity'] as num),
          };
        }).toList(),
        'address': _addressController.text,
        'needsDelivery': needsDelivery,
        'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
        'paymentMethod': 'Paystack',
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
        'customerEmail': user.email ?? 'no_email@example.com',
        'totalPaidAmount': _calculateTotal(),
      };

      await orderDoc.set(orderData);

      // 2. LISTEN FOR STATUS CHANGES ON THE ORDER DOCUMENT
      // This is the key part for real-time updates.
      subscription = orderDoc.snapshots().listen((DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final orderData = snapshot.data() as Map<String, dynamic>;
          final newStatus = orderData['status'];

          if (newStatus == 'paid') {
            subscription?.cancel(); // Stop listening
            Navigator.pushReplacementNamed(context, '/orders');
            Api().showMessage(
              context,
              'Payment Successful! You can now view your order.',
              'Payment Confirmed',
              Colors.green,
            );
          }
        }
      });

      // 3. PREPARE PAYLOAD AND CALL BACKEND
      List<Map<String, dynamic>> productsForPaystack = widget.cartProducts.map((
        p,
      ) {
        return {
          'name': p['productName'],
          'price': p['price'],
          'quantity': p['quantity'] ?? 1,
          'subaccount': p['subaccountCode'] ?? '',
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$YOUR_BACKEND_BASE_URL/create-payment-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': user.email ?? 'no_email@example.com',
          'products': productsForPaystack,
          'orderReference': createdOrderReference,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['paymentLink'] != null) {
        final url = Uri.parse(data['paymentLink']);
        if (await canLaunchUrl(url)) {
          // Launch the URL
          await launchUrl(url, mode: LaunchMode.inAppBrowserView);
        } else {
          throw 'Could not open payment link';
        }
      } else {
        throw data['error'] ?? 'Failed to create payment link';
      }

      Api().showMessage(
        context,
        'Redirecting to payment...',
        'Please complete the payment to finalize your order.',
        Theme.of(context).primaryColor,
      );
    } catch (e) {
      print('An error occurred while processing your payment: $e');
      subscription?.cancel(); // Cancel subscription on error
      Api().showMessage(
        context,
        'An error occurred while processing your payment: $e',
        'Payment Error',
        Colors.red,
      );
    } finally {
      setState(() {
        isPlacingOrder = false;
      });
    }
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ... (Your existing UI widgets for address, delivery option, and order summary) ...

            // --- Address Card ---
            Card(
              color: color.scaffoldBackgroundColor.withOpacity(0.7),
              elevation: 5,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: color.primaryColor),
                        const SizedBox(width: 8.0),
                        const Text(
                          'Delivery Address',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _addressController,
                      maxLines: 3,
                      readOnly: _isLoadingAddress,
                      decoration: InputDecoration(
                        hintText: _isLoadingAddress
                            ? 'Fetching address...'
                            : 'Enter an Address',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isLoadingAddress
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                icon: const Icon(Icons.my_location),
                                onPressed: _getCurrentLocation,
                                tooltip: 'Get current location',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- Delivery Option Card ---
            Card(
              color: color.scaffoldBackgroundColor.withOpacity(0.7),
              elevation: 5,
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: color.primaryColor),
                        const SizedBox(width: 8.0),
                        const Text(
                          'Delivery Option',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<bool>(
                            title: const Text(
                              'Collect',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                            secondary: const Icon(Icons.store),
                            value: false,
                            groupValue: needsDelivery,
                            onChanged: (val) {
                              setState(() {
                                needsDelivery = val ?? false;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<bool>(
                            contentPadding: const EdgeInsets.all(10),
                            title: const Text(
                              'Delivery',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12),
                            ),
                            secondary: const Icon(Icons.delivery_dining),
                            value: true,
                            groupValue: needsDelivery,
                            onChanged: (val) {
                              setState(() {
                                needsDelivery = val ?? false;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (needsDelivery)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Delivery Charge: R${deliveryCharge.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // --- Order Summary Card ---
            Card(
              color: color.scaffoldBackgroundColor.withOpacity(0.7),
              elevation: 5,
              margin: const EdgeInsets.only(bottom: 20.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: color.primaryColor),
                        const SizedBox(width: 8.0),
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.cartProducts.length,
                      itemBuilder: (context, index) {
                        final product = widget.cartProducts[index];
                        final productName =
                            product['productName'] ?? 'Unknown Product';
                        final productPrice =
                            (product['price'] as num?)?.toDouble() ?? 0.0;
                        final productQuantity =
                            (product['quantity'] as int?) ?? 1;
                        final subtotal = productPrice * productQuantity;
                        final imageUrl = product['imageUrl']?.toString() ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    imageUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey[600],
                                          size: 30,
                                        ),
                                      );
                                    },
                                  ),
                                )
                              else
                                Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey[600],
                                    size: 30,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'R${productPrice.toStringAsFixed(2)} x ${productQuantity}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'R${subtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:', style: TextStyle(fontSize: 16)),
                        Text(
                          'R${_calculateSubtotal().toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    if (needsDelivery)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Delivery Charge:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              'R${deliveryCharge.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'R${_calculateTotal().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- Proceed to Payment Button ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isPlacingOrder ? null : _payWithPaystack,
                icon: isPlacingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  isPlacingOrder ? 'Processing...' : 'Proceed to Payment',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color.primaryColor,
                  foregroundColor: color.scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
