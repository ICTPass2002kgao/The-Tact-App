import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart'; // Assuming this provides Api().showMessage and Api().login
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Components/TextField.dart';
import 'package:text_field_validation/text_field_validation.dart';
import 'package:http/http.dart' as http; // Import for HTTP requests
import 'dart:convert'; // Import for JSON encoding/decoding
import 'package:url_launcher/url_launcher.dart'; // Import for url_launcher
import 'package:geolocator/geolocator.dart'; // Import geolocator
import 'package:geocoding/geocoding.dart'; // Import geocoding
import 'package:shared_preferences/shared_preferences.dart'; // Import for CartHelper

// --- IMPORTANT: CONFIGURE YOUR BACKEND ENDPOINT ---
// This should be your Cloud Function base URL for generating Stripe Payment Links
const String YOUR_BACKEND_BASE_URL =
    'https://us-central1-tact-3c612.cloudfunctions.net';

// Import CartHelper (assuming it's in a separate file or defined earlier in main.dart)
// Make sure CartHelper.clearCart() is accessible.
// If CartHelper is in this file, ensure it's above this class definition.
class CartHelper {
  static const String _cartKey = 'cart';

  static Future<void> clearCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
  }

  // Add other methods from your CartHelper here if not in a separate file.
  // For this fix, only clearCart is strictly needed within PaymentGatewayPage context.
}

class PaymentGatewayPage extends StatefulWidget {
  final List<Map<String, dynamic>> cartProducts;
  const PaymentGatewayPage({required this.cartProducts, Key? key})
    : super(key: key);

  @override
  State<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends State<PaymentGatewayPage> {
  final TextEditingController _addressController = TextEditingController();
  bool needsDelivery = false;
  double deliveryCharge = 50.0;
  String? selectedPaymentMethod;
  bool isPlacingOrder = false;
  bool _isLoadingAddress = false; // New state to manage address loading

  // Updated payment methods, removing direct Stripe integration for Payment Link
  final paymentMethods = [
    'Credit/Debit Card (Stripe Payment Link)', // Renamed for clarity
    'Mobile Wallet',
    'PayPal',
    'Scan to Pay (QR Code)',
    'Ozow Instant EFT',
  ];

  final Map<String, IconData> paymentMethodIcons = {
    'Credit/Debit Card (Stripe Payment Link)': Icons.credit_card,
    'Mobile Wallet': Icons.account_balance_wallet,
    'PayPal': Icons.payments,
    'Scan to Pay (QR Code)': Icons.qr_code_scanner,
    'Ozow Instant EFT': Icons.account_balance,
  };

  final FirebaseAuth _auth = FirebaseAuth.instance;
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeAddress(); // Call the new address initialization logic
  }

  @override
  void dispose() {
    _addressController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- NEW: Function to initialize the address based on login status and location ---
  void _initializeAddress() async {
    setState(() {
      _isLoadingAddress = true; // Start loading state
      _addressController.text = 'Loading address...'; // Temporary message
    });

    User? currentUser = _auth.currentUser;

    if (currentUser != null) {
      // User is logged in, try to get address from Firestore
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          String? storedAddress = userData?['Address'];
          if (storedAddress != null && storedAddress.isNotEmpty) {
            _addressController.text = storedAddress;
            setState(() {
              _isLoadingAddress = false;
            });
            return; // Address found and set, no need for location
          }
        }
      } catch (e) {
        print("Error fetching user address from Firestore: $e");
      }
    }

    // If not logged in, or no address found in Firestore, get current location
    await _getCurrentLocation();
  }

  // --- NEW: Function to get the device's current location ---
  Future<void> _getCurrentLocation() async {
    setState(() {
      _addressController.text =
          'Fetching your current location...'; // Provide immediate feedback
    });

    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationError(
        'Location services are disabled. Please enable them in your device settings.',
      );
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationError(
          'Location permissions are denied. You will need to manually enter your address.',
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationError(
        'Location permissions are permanently denied. Please enable them in app settings.',
      );
      return;
    }

    // Get current position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Added a timeout
      );

      // Convert coordinates to address
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
        _isLoadingAddress = false; // End loading state regardless of outcome
      });
    }
  }

  // Helper to show SnackBar messages for location errors
  void _showLocationError(String message) {
    setState(() {
      _isLoadingAddress = false;
      _addressController.text =
          ''; // Clear text if error or user needs to input
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
    if (needsDelivery) {
      subtotal += deliveryCharge; // Add delivery charge if needed
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

  // --- Function to handle Ozow payment using url_launcher (kept as is) ---
  Future<void> _processOzowPaymentWithUrlLauncher() async {
    final color = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Api().showMessage(
        context,
        'Authentication Error',
        'Please log in to proceed with payment.',
        color.primaryColorDark,
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$YOUR_BACKEND_BASE_URL/initiateOzowPayment'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': user.uid,
          'amount': (_calculateTotal() * 100)
              .toInt(), // Ozow often expects cents
          'orderReference':
              'TTAC-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 8)}',
          'customerName': user.displayName ?? 'Guest User',
          'customerEmail': user.email ?? 'no_email@example.com',
          'products': widget.cartProducts,
          'address': _addressController.text,
          'needsDelivery': needsDelivery,
          'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
          'paymentMethod': selectedPaymentMethod,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? paymentUrl = responseData['paymentUrl'];
        final String? orderId = responseData['orderId'];

        if (paymentUrl != null) {
          final Uri uri = Uri.parse(paymentUrl);

          if (await canLaunchUrl(uri) &&
              await supportsLaunchMode(LaunchMode.inAppBrowserView)) {
            await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
            Api().showMessage(
              context,
              'Processing your Ozow payment...',
              'We will notify you once complete.',
              color.splashColor,
            );
            // Consider passing orderId to the next page for tracking
            // Use pushReplacement or pushNamed to prevent going back to payment page
            Navigator.pushNamed(context, '/orders');
          } else {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            Api().showMessage(
              context,
              'Opened Ozow in external browser.',
              'Please complete payment there and return to the app.',
              color.splashColor,
            );
            Navigator.pushNamed(context, '/orders');
          }
        } else {
          Api().showMessage(
            context,
            'Payment Failed',
            'Failed to get Ozow payment URL from backend. Please try again.',
            color.primaryColorDark,
          );
        }
      } else {
        Api().showMessage(
          context,
          'Server Error',
          'Could not initiate payment. Status: ${response.statusCode}',
          color.primaryColorDark,
        );
        print('Backend Error Body: ${response.body}');
      }
    } catch (e) {
      Api().showMessage(
        context,
        'Payment Error',
        'An unexpected error occurred: ${e.toString()}',
        color.primaryColorDark,
      );
      print('Error initiating Ozow payment: $e');
    } finally {
      setState(() {
        isPlacingOrder = false;
      });
    }
  }

  // --- MODIFIED: Function to handle Stripe Payment Link ---
  Future<void> _processStripePaymentLink() async {
    final color = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Api().showMessage(
        context,
        'Authentication Error',
        'Please log in to proceed with payment.',
        color.primaryColorDark,
      );
      return;
    }

    setState(() {
      isPlacingOrder = true;
    });

    try {
      // Ensure products have all necessary fields for the Cloud Function (especially sellerId)
      final List<Map<String, dynamic>>
      formattedProducts = widget.cartProducts.map((product) {
        // These fields MUST match what your Cloud Function expects and what you need in the order doc
        return {
          'productId': product['productId']?.toString() ?? 'unknown_id',
          'productName':
              product['productName']?.toString() ?? 'Unknown Product',
          'price': (product['price'] is String)
              ? double.tryParse(product['price']) ?? 0.0
              : (product['price'] as num?)?.toDouble() ?? 0.0,
          'quantity': (product['quantity'] as int?) ?? 1,
          'imageUrl': product['imageUrl']?.toString() ?? '',
          'sellerId':
              product['sellerId']?.toString() ??
              'unknown_seller', // Crucial for seller view
          // Add other fields you store in the order's products array
          'itemTotalPrice':
              ((product['price'] as num?)?.toDouble() ?? 0.0) *
              ((product['quantity'] as int?) ?? 1),
        };
      }).toList();

      final response = await http.post(
        Uri.parse('$YOUR_BACKEND_BASE_URL/createStripePaymentLink'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'amount':
              _calculateSubtotal(), // Send subtotal to backend, it calculates totalPaidAmount
          'currency': 'ZAR',
          'userId': user.uid,
          'customerEmail': user.email ?? 'no_email@example.com',
          'customerName': user.displayName ?? 'Guest User',
          'orderReference':
              'TTACT-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 8)}',
          'products': formattedProducts, // Use the properly formatted products
          'address': _addressController.text,
          'needsDelivery': needsDelivery,
          'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
          'paymentMethod': selectedPaymentMethod,
        }),
      );

      print(
        '✅ Backend Request Body: ${json.encode({'amount': _calculateSubtotal(), 'currency': 'ZAR', 'userId': user.uid, 'customerEmail': user.email ?? 'no_email@example.com', 'customerName': user.displayName ?? 'Guest User', 'orderReference': 'TTACT-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 8)}', 'products': formattedProducts, 'address': _addressController.text, 'needsDelivery': needsDelivery, 'deliveryCharge': needsDelivery ? deliveryCharge : 0.0, 'paymentMethod': selectedPaymentMethod})}',
      );
      print('✅ Backend Response: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final String? paymentLinkUrl = responseData['paymentLinkUrl'];
        final String? orderId =
            responseData['orderId']; // Get the Firestore orderId

        if (paymentLinkUrl != null) {
          final Uri uri = Uri.parse(paymentLinkUrl);

          // Launch Stripe checkout
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.inAppWebView,
              webViewConfiguration: const WebViewConfiguration(
                enableJavaScript: true,
                enableDomStorage: true,
              ),
            );

            Api().showMessage(
              context,
              'Redirected to Stripe',
              'Complete payment and return to the app.',
              color.splashColor,
            );

            // IMPORTANT: Do NOT clear cart here.
            // Cart clearing will happen in the webhook Cloud Function AFTER successful payment.
            // Navigate to orders page to allow user to see status updates.
            Navigator.pushReplacementNamed(
              context,
              '/orders',
            ); // Use pushReplacement to prevent going back
          } else {
            throw 'Could not launch $paymentLinkUrl';
          }
        } else {
          Api().showMessage(
            context,
            'No payment link returned from the server.',
            'Please try again or contact support.',
            color.primaryColorDark,
          );
        }
      } else {
        final errorResponse = json.decode(response.body);
        Api().showMessage(
          context,
          'Payment Failed',
          errorResponse['error'] ??
              'Failed to create payment link (Status: ${response.statusCode})',
          color.primaryColorDark,
        );
      }
    } catch (e) {
      Api().showMessage(
        context,
        'Payment Error',
        'Failed to process payment: ${e.toString()}',
        color.primaryColorDark,
      );
      print('Stripe Payment Link Error: $e');
    } finally {
      setState(() {
        isPlacingOrder = false;
      });
    }
  }

  Future<void> placeOrder() async {
    final color = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showModalBottomSheet(
        backgroundColor: color.scaffoldBackgroundColor,
        scrollControlDisabledMaxHeightRatio: 0.4,
        context: context,
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              children: [
                AuthTextField(
                  icon: Icons.email_outlined,
                  controller: emailController,
                  onValidate: TextFieldValidation.email,
                  placeholder: 'Enter your email',
                ),
                AuthTextField(
                  icon: Icons.password_sharp,
                  controller: passwordController,
                  onValidate: TextFieldValidation.password,
                  placeholder: 'Password',
                ),
                CustomOutlinedButton(
                  onPressed: () async {
                    // Make onPressed async
                    await Api().login(
                      // Await the login call
                      context,
                      emailController.text,
                      passwordController.text,
                    );
                    // After login attempt, re-initialize address field
                    // to populate it if login was successful.
                    _initializeAddress();
                    if (Navigator.canPop(context)) {
                      Navigator.pop(
                        context,
                      ); // Close the bottom sheet after login
                    }
                  },
                  text: "Login",
                  backgroundColor: color.primaryColor,
                  foregroundColor: color.scaffoldBackgroundColor,
                  width: double.infinity,
                ),
              ],
            ),
          );
        },
      );
      return;
    }

    if (_addressController.text.isEmpty && needsDelivery) {
      Api().showMessage(
        context,
        'Please provide your address!',
        '',
        color.primaryColorDark,
      );
      return;
    }

    if (selectedPaymentMethod == null) {
      Api().showMessage(
        context,
        'Please select a Payment method!',
        '',
        color.primaryColorDark,
      );
      return;
    }

  String customerName = 'Guest User'; // Default if not found
  String customerEmail = user.email ?? 'no_email@example.com';
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
      if (userData != null && userData.containsKey('name')) {
        customerName = userData['name'];
      }
      // You might also get the email from Firestore if you store it there
      // customerEmail = userData['email'] ?? user.email ?? 'no_email@example.com';
    } 

    if (selectedPaymentMethod == 'Ozow Instant EFT') {
      await _processOzowPaymentWithUrlLauncher();
      return;
    } else if (selectedPaymentMethod ==
        'Credit/Debit Card (Stripe Payment Link)') {
      await _processStripePaymentLink(); // Call the Stripe Payment Link process
      return; // The Stripe process handles its own loading state and navigation
    }

    // --- Original logic for other payment methods (e.g., Cash on Delivery, Mobile Wallet, PayPal, Scan to Pay) ---
    // These methods would typically be "pending" payment and confirmed outside the app
    // or through specific integrations if supported.
    setState(() {
      isPlacingOrder = true;
    });

    // For other methods (not Stripe/Ozow), the order needs to be created directly here
    // and marked as 'pending'. The cart would only be cleared AFTER successful confirmation.
    // However, for simplicity for these "other" methods, we'll clear the cart directly here
    // assuming they are either cash-on-delivery or handled in a way that doesn't need
    // a webhook for confirmation within the app.
    // If you plan to implement specific confirmation for these, you'd adapt similarly to Stripe/Ozow.

    // Group products by seller for batching
    Map<String, List<Map<String, dynamic>>> productsBySeller = {};
    for (var product in widget.cartProducts) {
      String sellerId =
          product['sellerId'] ?? 'unknown_seller'; // Ensure sellerId is present
      if (!productsBySeller.containsKey(sellerId)) {
        productsBySeller[sellerId] = [];
      }
      productsBySeller[sellerId]!.add(product);
    }

    final batch = FirebaseFirestore.instance.batch();

    String? createdOrderId; // To store the first order ID for navigation

    for (var entry in productsBySeller.entries) {
      final sellerId = entry.key;
      final productsForSeller = entry.value;
      final orderDoc = FirebaseFirestore.instance.collection('orders').doc();
      if (createdOrderId == null) {
        createdOrderId = orderDoc.id; // Capture the first order ID
      }

      batch.set(orderDoc, {
        'userId': user
            .uid, // Changed from buyerId to userId for consistency with other parts
        'sellerId': sellerId,
        'products': productsForSeller,
        'address': _addressController.text,
        'needsDelivery': needsDelivery,
        'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
        'paymentMethod': selectedPaymentMethod,
        'status': 'pending', // Remains pending until actual confirmation
        'createdAt': FieldValue.serverTimestamp(),
        'customerName': customerName,
        'customerEmail': customerEmail,
        'orderReference':
            'TTACT-${DateTime.now().millisecondsSinceEpoch}-${user.uid.substring(0, 8)}',
        'amount': _calculateSubtotal(), // Subtotal before delivery
        'totalPaidAmount': _calculateTotal(), // Total including delivery
      });
    }

    try {
      await batch.commit();
      // Clear cart ONLY for these non-webhook payment methods
      await CartHelper.clearCart();

      Api().showMessage(
        context,
        'Order Placed Successfully',
        'Your order has been placed and is awaiting confirmation.',
        color.splashColor,
      );
      Navigator.pushNamed(context, '/orders'); // Navigate to orders page
    } catch (e) {
      Api().showMessage(
        context,
        'Something went wrong!',
        '${e.toString()}',
        color.primaryColorDark,
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
                      readOnly:
                          _isLoadingAddress, // Make it read-only while loading
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
                        Icon(Icons.payment, color: color.primaryColor),
                        const SizedBox(width: 8.0),
                        const Text(
                          'Choose Payment Method',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...paymentMethods.map((method) {
                      return RadioListTile<String>(
                        title: Text(method),
                        secondary: Icon(paymentMethodIcons[method]),
                        value: method,
                        groupValue: selectedPaymentMethod,
                        onChanged: (val) {
                          setState(() {
                            selectedPaymentMethod = val;
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
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
                        final imageUrl =
                            product['imageUrl']?.toString() ??
                            ''; // Get the image URL

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment
                                .center, // Align items to the top
                            children: [
                              // Product Image
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    imageUrl,
                                    width: 40, // Fixed width for the image
                                    height: 40, // Fixed height for the image
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
                                  // Placeholder if no image URL
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
                              // Product Details
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isPlacingOrder ? null : placeOrder,
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
