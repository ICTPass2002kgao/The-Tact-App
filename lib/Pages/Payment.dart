import 'dart:async';
import 'package:flutter/foundation.dart';
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
import 'package:ttact/Pages/Login.dart'; // Assume Login_Page exists in Pages directory
import 'package:ttact/Pages/SignUpPage.dart'; // Assume SignUpPage exists in Pages directory

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 700.0;
// --------------------------

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

// Inline login form used by Payment page when the user is not authenticated.
// This widget performs a simple email/password sign-in with FirebaseAuth and
// invokes the onSuccess callback when authentication succeeds.
class InlineLoginForm extends StatefulWidget {
  final VoidCallback? onSuccess;
  const InlineLoginForm({Key? key, this.onSuccess}) : super(key: key);

  @override
  _InlineLoginFormState createState() => _InlineLoginFormState();
}

class _InlineLoginFormState extends State<InlineLoginForm> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      widget.onSuccess?.call();
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else if (e.message != null) {
        message = e.message!;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please sign in to continue',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Sign in'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No account?'),
                TextButton(
                  onPressed: () {
                    // Navigate to SignUpPage if available in app
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  child: const Text('Create one'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

  String? name;
  String? surname;
  String? email;
  String? sellerName;
  String? sellerSurname;
  String? sellerEmail;
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
              name = userData?['name'];
              surname = userData?['surname'];
              email = userData?['email'];
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
    // FIX: Guard against running location services on web, where they often fail or are disallowed.
    if (mounted && kIsWeb) {
      _addressController.text =
          'Please enter your address manually (Location access restricted on web)';
      setState(() {
        _isLoadingAddress = false;
      });
      return;
    }

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

  // NEW: Function to show the conditional login prompt
  void _showLoginPrompt() {
    final loginForm = InlineLoginForm(
      onSuccess: () {
        // Upon successful login, close the prompt and retry payment
        if (kIsWeb) {
          Navigator.pop(context); // Close dialog
        } else {
          Navigator.pop(context); // Close bottom sheet
        }
        // Retry the payment process with the now-logged-in user
        _payWithPaystack();
      },
    );

    if (kIsWeb) {
      // Web: Show as a centered dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 400,
            height: 550, // Constrain size for desktop visibility
            child: loginForm,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ),
      );
    } else {
      // Mobile: Show as a bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: loginForm,
        ),
      );
    }
  }

  Future<void> _payWithPaystack() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Redirect to the new login prompt
      _showLoginPrompt();
      return;
    }

    // --- Existing Payment Validation and Logic ---
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
          setState(() {
            sellerEmail = p['sellerEmail'];
            sellerName = p['sellerName'];
            sellerSurname = p['sellerSurname'];
          });
          return {
            'productName': p['productName'],
            'price': p['price'],
            'quantity': p['quantity'] ?? 1,
            'imageUrl': p['imageUrl'],
            'sellerId': p['sellerId'],
            'subaccountCode': p['subaccountCode'],
            'selectedColor': p['selectedColor'],
            'selectedSize': p['selectedSize'],
            'itemTotalPrice': (p['price'] as num) * (p['quantity'] as num),
          };
        }).toList(),
        'address': _addressController.text,
        'needsDelivery': needsDelivery,
        'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
        'paymentMethod': 'Paystack',
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
        'customerEmail': email ?? 'no_email@example.com',
        'totalPaidAmount': _calculateTotal(),
      };

      await orderDoc.set(orderData);

      // 2. LISTEN FOR STATUS CHANGES ON THE ORDER DOCUMENT
      subscription = orderDoc.snapshots().listen((DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final orderData = snapshot.data() as Map<String, dynamic>;
          final newStatus = orderData['status'];

          if (newStatus == 'paid') {
            subscription?.cancel(); // Stop listening

            Api().sendEmail(
              email!, // recipient: the buyer
              "Payment Successful – Check Your Order",
              """
  <p>Dear ${name} ${surname},</p>

  <p>Thank you for your purchase on <strong>Dankie Mobile (TACT)</strong>!</p>

  <p>We have successfully received your payment. You can now visit your <strong>Order Page</strong> to view the status of your order and track any updates.</p>

  <p>If you did not make this purchase or notice any issues, please contact our support team immediately.</p>

  <br>
  <p>Best regards,<br>
  Dankie Mobile Support Team</p>
  <a href="https://dankie-website.web.app/">Dankie Mobile</a>
  """,
              context,
            );
            Api().sendEmail(
              sellerEmail!, // the seller's email
              "New Order Received – Customer Purchase",
              """
  <p>Dear ${sellerName},</p>

  <p>You have received a new order on <strong>Dankie Mobile (TACT)</strong>!</p>

  <ul>
    <li>Customer: ${name} ${surname}</li>
    <li>Email: ${email}</li> 
    <li>Purchased At: ${DateTime.now().toLocal()}</li>
    <li>Total Amount: R${_calculateTotal()}</li>
  </ul>

  <p>Please check your <strong>Orders Page</strong> to view and process this order.</p>

  <p>If there are any issues, contact the support team immediately.</p>

  <br>
  <p>Best regards,<br>
  Dankie Mobile Support Team</p>
  <a href="https://dankie-website.web.app/">Dankie Mobile</a>
  """,
              context,
            );

            // FIX: Clear the local cart storage upon successful payment
            CartHelper.clearCart();
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
          'email': email ?? 'no_email@example.com',
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
      // FIX: Center and constrain content for web/desktop
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Address Card ---
                Card(
                  // Use theme colors for card background
                  color: color.scaffoldBackgroundColor.withOpacity(0.9),
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
                  // Use theme colors for card background
                  color: color.scaffoldBackgroundColor.withOpacity(0.9),
                  elevation: 5,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              color: color.primaryColor,
                            ),
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
                              child: SizedBox(
                                height:
                                    50, // FIX: Give space to prevent collapsing
                                child: RadioListTile<bool>(
                                  title: const Text(
                                    'Collect',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                    ), // Slightly larger font
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
                            ),
                            Expanded(
                              child: SizedBox(
                                height:
                                    50, // FIX: Give space to prevent collapsing
                                child: RadioListTile<bool>(
                                  contentPadding: const EdgeInsets.all(10),
                                  title: const Text(
                                    'Delivery',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                    ), // Slightly larger font
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
                            ),
                          ],
                        ),
                        if (needsDelivery)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 8.0,
                              left: 16.0,
                            ),
                            child: Text(
                              'Delivery Charge: R${deliveryCharge.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: color
                                    .hintColor, // Use hintColor for detail text
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // --- Order Summary Card ---
                Card(
                  // Use theme colors for card background
                  color: color.scaffoldBackgroundColor.withOpacity(0.9),
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
                        // List of Products
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
                            final selectedColor =
                                product['selectedColor'] ?? 'N/A';
                            final selectedSize =
                                product['selectedSize'] ?? 'N/A';
                            final subtotal = productPrice * productQuantity;
                            final imageUrl =
                                product['imageUrl']?.toString() ?? '';

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Product Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) =>
                                                _buildPlaceholderImage(color),
                                          )
                                        : _buildPlaceholderImage(color),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            color: color
                                                .hintColor, // Use hintColor
                                          ),
                                        ),
                                        Text(
                                          'Color: $selectedColor, Size: $selectedSize',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontStyle: FontStyle.italic,
                                            color: color.hintColor.withOpacity(
                                              0.7,
                                            ), // Use hintColor
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

                        // Totals and Final Price
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Subtotal:',
                              style: TextStyle(fontSize: 16),
                            ),
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
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build image placeholder
  Widget _buildPlaceholderImage(ThemeData color) {
    return Container(
      width: 40,
      height: 40,
      color: color.hintColor.withOpacity(0.2), // Use theme hintColor
      child: Icon(Icons.image, color: color.hintColor, size: 20),
    );
  }
}
