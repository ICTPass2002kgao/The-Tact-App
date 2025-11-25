import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart'; // Essential for iOS widgets
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ttact/Components/API.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ttact/Pages/SignUpPage.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 700.0;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
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

// --- INLINE LOGIN FORM (Platform Aware) ---
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
  bool _obscureText = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
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
      _showError(message);
    } catch (e) {
      _showError('Login error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Helper to build TextFields based on platform
  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String label,
    bool isPassword = false,
    required Iterable<String> autofillHints,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final theme = Theme.of(context);

    if (isIOSPlatform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.hintColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoTextField(
            controller: controller,
            placeholder: 'Enter $label',
            obscureText: isPassword ? _obscureText : false,
            keyboardType: keyboardType,
            padding: const EdgeInsets.all(14),
            autofillHints: autofillHints,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
            suffix: isPassword
                ? CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(
                      _obscureText
                          ? CupertinoIcons.eye_slash
                          : CupertinoIcons.eye,
                      color: CupertinoColors.systemGrey,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  )
                : null,
            clearButtonMode: isPassword
                ? OverlayVisibilityMode.never
                : OverlayVisibilityMode.editing,
          ),
        ],
      );
    } else {
      return TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? _obscureText : false,
        autofillHints: autofillHints,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
        ),
      );
    }
  }

  // Helper to build Main Action Button
  Widget _buildPlatformButton({
    required VoidCallback? onPressed,
    required String text,
  }) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Center(
        child: isIOSPlatform
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(),
      );
    }

    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          disabledColor: CupertinoColors.quaternarySystemFill,
          // Use Theme Primary Color
          borderRadius: BorderRadius.circular(8),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(text),
        ),
      );
    }
  }

  Widget _buildPlatformTextButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    if (isIOSPlatform) {
      return CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        minSize: 0,
        child: Text(
          text,
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return TextButton(onPressed: onPressed, child: Text(text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Please sign in to continue',
                style: isIOSPlatform
                    ? theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                    : theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 20),
            _buildPlatformTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),
            _buildPlatformTextField(
              controller: _passwordController,
              label: 'Password',
              isPassword: true,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 24),
            _buildPlatformButton(
              onPressed: _isLoading ? null : _signIn,
              text: 'Sign in',
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No account? ', style: TextStyle(color: theme.hintColor)),
                _buildPlatformTextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  text: 'Create one',
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

  bool needsDelivery = true;
  double deliveryCharge = 50.0;
  bool isPlacingOrder = false;
  bool _isLoadingAddress = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? name;
  String? surname;
  String? email;

  // Store seller info to notify them later
  // Note: If you have multiple sellers in one cart, this simple logic
  // only notifies the last one processed in the loop.
  // Ideally, you should group items by seller.
  String? sellerName;
  String? sellerSurname;
  String? sellerEmail;

  @override
  void initState() {
    super.initState();
    _fetchUserAddressFromFirestore();
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserAddressFromFirestore() async {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoadingAddress = true;
      _addressController.text = 'Loading address...';
    });

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic>? userData =
            userDoc.data() as Map<String, dynamic>?;

        setState(() {
          name = userData?['name'];
          surname = userData?['surname'];
          email = userData?['email'];

          String? storedAddress = userData?['address'];
          if (storedAddress != null && storedAddress.isNotEmpty) {
            _addressController.text = storedAddress;
          } else {
            _addressController.text = '';
          }
        });
      }
    } catch (e) {
      print("Error fetching user address from Firestore: $e");
      _addressController.text = '';
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  String _getPickupInfo() {
    StringBuffer buffer = StringBuffer();
    for (var item in widget.cartProducts) {
      String productName = item['productName'] ?? 'Item';
      String location = item['location'] ?? 'Contact seller for location';
      buffer.writeln("• $productName: $location");
    }
    return buffer.toString().trim();
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

  // --- NEW HELPER: Generate Detailed HTML Email ---
  String _generateOrderHtml({
    required String orderId,
    required bool isForSeller,
  }) {
    final total = _calculateTotal().toStringAsFixed(2);
    final subtotal = _calculateSubtotal().toStringAsFixed(2);
    final delivery = needsDelivery
        ? "R${deliveryCharge.toStringAsFixed(2)}"
        : "Collection (Free)";
    final address = needsDelivery
        ? _addressController.text
        : "Customer will collect from: ${_getPickupInfo()}";

    StringBuffer itemsHtml = StringBuffer();
    itemsHtml.write('<table style="width:100%; border-collapse: collapse;">');
    itemsHtml.write(
      '<tr style="background-color: #f2f2f2;"><th>Item</th><th>Qty</th><th>Price</th><th>Total</th></tr>',
    );

    for (var p in widget.cartProducts) {
      final pName = p['productName'] ?? 'Item';
      final pQty = p['quantity'] ?? 1;
      final pPrice = (p['price'] as num?)?.toDouble() ?? 0.0;
      final pTotal = (pPrice * pQty).toStringAsFixed(2);

      itemsHtml.write('<tr>');
      itemsHtml.write(
        '<td style="border: 1px solid #ddd; padding: 8px;">$pName</td>',
      );
      itemsHtml.write(
        '<td style="border: 1px solid #ddd; padding: 8px;">$pQty</td>',
      );
      itemsHtml.write(
        '<td style="border: 1px solid #ddd; padding: 8px;">R$pPrice</td>',
      );
      itemsHtml.write(
        '<td style="border: 1px solid #ddd; padding: 8px;">R$pTotal</td>',
      );
      itemsHtml.write('</tr>');
    }
    itemsHtml.write('</table>');

    String title = isForSeller ? "New Order Received" : "Order Confirmation";
    String intro = isForSeller
        ? "You have received a new order. Please prepare the following items:"
        : "Thank you for your purchase! Here are your order details:";

    return '''
      <h2>$title</h2>
      <p><strong>Order ID:</strong> $orderId</p>
      <p>$intro</p>
      <br>
      ${itemsHtml.toString()}
      <br>
      <p><strong>Subtotal:</strong> R$subtotal</p>
      <p><strong>Delivery:</strong> $delivery</p>
      <h3 style="color: green;">Total Paid: R$total</h3>
      <hr>
      <h3>Delivery/Collection Details:</h3>
      <p>$address</p>
    ''';
  }

  void _showLoginPrompt() {
    final loginForm = InlineLoginForm(
      onSuccess: () {
        Navigator.pop(context); // Close dialog/sheet
        _fetchUserAddressFromFirestore();
        Api().showMessage(
          context,
          'Logged in successfully.',
          'Success',
          Colors.green,
        );
      },
    );

    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 400,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: loginForm,
          ),
        ),
      );
    } else {
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
      _showLoginPrompt();
      return;
    }

    if (widget.cartProducts.isEmpty) {
      Api().showMessage(
        context,
        'Cart is empty!',
        'No items to checkout.',
        Colors.red,
      );
      return;
    }

    if (needsDelivery && _addressController.text.trim().isEmpty) {
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
      final orderDoc = FirebaseFirestore.instance.collection('orders').doc();
      createdOrderReference = orderDoc.id;

      final String finalAddressToSave = needsDelivery
          ? _addressController.text.trim()
          : _getPickupInfo();

      // Prepare products and capture seller info
      final productsList = widget.cartProducts.map((p) {
        // Note: This overwrites sellerEmail if multiple sellers exist.
        // It captures the last one in the list.
        sellerEmail = p['sellerEmail'];
        sellerName = p['sellerName'];
        sellerSurname = p['sellerSurname'];

        return {
          'productName': p['productName'],
          'price': p['price'],
          'quantity': p['quantity'] ?? 1,
          'imageUrl': p['imageUrl'],
          'sellerId': p['sellerId'],
          'subaccountCode': p['subaccountCode'],
          'selectedColor': p['selectedColor'],
          'selectedSize': p['selectedSize'],
          'pickupLocation': p['location'] ?? 'N/A',
          'itemTotalPrice': (p['price'] as num) * (p['quantity'] as num),
        };
      }).toList();

      final orderData = {
        'orderId': createdOrderReference,
        'userId': user.uid,
        'products': productsList,
        'email': email ?? user.email,
        'address': finalAddressToSave,
        'needsDelivery': needsDelivery,
        'deliveryCharge': needsDelivery ? deliveryCharge : 0.0,
        'paymentMethod': 'Paystack',
        'status': 'pending_payment',
        'createdAt': FieldValue.serverTimestamp(),
        'customerEmail': email ?? user.email,
        'totalPaidAmount': _calculateTotal(),
      };

      await orderDoc.set(orderData);

      subscription = orderDoc.snapshots().listen((DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final orderData = snapshot.data() as Map<String, dynamic>;
          final newStatus = orderData['status'];

          if (newStatus == 'paid') {
            subscription?.cancel();

            // --- UPDATED EMAIL SENDING LOGIC ---
            final buyerEmail = email ?? user.email;

            // 1. Email to Buyer (Safe check)
            if (buyerEmail != null && buyerEmail.isNotEmpty) {
              Api().sendEmail(
                buyerEmail,
                "Payment Successful – Order #${createdOrderReference!}",
                _generateOrderHtml(
                  orderId: createdOrderReference,
                  isForSeller: false,
                ),
                context,
              );
            }

            // 2. Email to Seller (Safe check)
            if (sellerEmail != null && sellerEmail!.isNotEmpty) {
              Api().sendEmail(
                sellerEmail!,
                "New Order Received - #${createdOrderReference!}",
                _generateOrderHtml(
                  orderId: createdOrderReference,
                  isForSeller: true,
                ),
                context,
              );
            }

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
          'email': email ?? user.email,
          'products': productsForPaystack,
          'orderReference': createdOrderReference,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['paymentLink'] != null) {
        final url = Uri.parse(data['paymentLink']);
        if (await canLaunchUrl(url)) {
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
      print('Payment Error: $e');
      subscription?.cancel();
      Api().showMessage(
        context,
        'An error occurred: $e',
        'Payment Error',
        Colors.red,
      );
    } finally {
      setState(() {
        isPlacingOrder = false;
      });
    }
  }

  // --- BUILDERS FOR PAYMENT PAGE ---

  Widget _buildDeliveryMethodSelector() {
    final theme = Theme.of(context);

    if (isIOSPlatform) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<bool>(
            thumbColor: theme.primaryColor,
            backgroundColor: CupertinoColors.systemGrey5,
            groupValue: needsDelivery,
            children: {
              false: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Collect',
                  style: TextStyle(
                    color: !needsDelivery
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              true: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Delivery',
                  style: TextStyle(
                    color: needsDelivery
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            },
            onValueChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  needsDelivery = value;
                });
              }
            },
          ),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: RadioListTile<bool>(
                title: const Text('Collect', style: TextStyle(fontSize: 14)),
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
              height: 50,
              child: RadioListTile<bool>(
                title: const Text('Delivery', style: TextStyle(fontSize: 14)),
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
      );
    }
  }

  Widget _buildAddressInput() {
    final theme = Theme.of(context);
    if (isIOSPlatform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoTextField(
            controller: _addressController,
            placeholder: _isLoadingAddress
                ? 'Fetching profile address...'
                : 'Enter Delivery Address or Pexi Code',
            enabled: !_isLoadingAddress,
            padding: const EdgeInsets.all(12),
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
            suffix: _isLoadingAddress
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CupertinoActivityIndicator(),
                  )
                : null,
          ),
        ],
      );
    } else {
      return TextField(
        controller: _addressController,
        maxLines: 3,
        enabled: !_isLoadingAddress,
        decoration: InputDecoration(
          hintText: _isLoadingAddress
              ? 'Fetching profile address...'
              : 'Enter Delivery Address or Pexi Code',
          border: const OutlineInputBorder(),
          suffixIcon: _isLoadingAddress
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
      );
    }
  }

  Widget _buildPaymentButton() {
    if (isPlacingOrder) {
      return Center(
        child: isIOSPlatform
            ? const CupertinoActivityIndicator()
            : const CircularProgressIndicator(),
      );
    }

    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: _payWithPaystack,
          color: Theme.of(context).primaryColor,
          disabledColor: CupertinoColors.quaternarySystemFill,
          borderRadius: BorderRadius.circular(12),
          child: const Text(
            'Proceed to Payment',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _payWithPaystack,
          icon: const Icon(Icons.payment),
          label: const Text(
            'Proceed to Payment',
            style: TextStyle(fontSize: 18),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    // FIX: Removed ! to prevent null check crash
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              middle: const Text('Payment & Delivery'),
              backgroundColor: color.primaryColor,
            )
          : AppBar(
              backgroundColor: color.primaryColor,
              foregroundColor: color.scaffoldBackgroundColor,
              title: const Text('Payment & Delivery'),
              centerTitle: true,
            ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Delivery Option Card ---
                Card(
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
                              'Delivery Method',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 10),

                        _buildDeliveryMethodSelector(),

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
                                color: color.hintColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // --- Address / Pickup Card ---
                Card(
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
                              needsDelivery
                                  ? Icons.location_on
                                  : Icons.store_mall_directory,
                              color: color.primaryColor,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              needsDelivery
                                  ? 'Delivery Address or Pexi Code'
                                  : 'Pickup Point(s)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        const SizedBox(height: 10),

                        if (needsDelivery) ...[
                          _buildAddressInput(),

                          // FIX: Safe null check on currentUser
                          if (currentUser == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Sign in to load saved address or enter a new one.",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ),

                          // FIX: Safe null check on currentUser
                          if (currentUser != null)
                            Row(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "Please provide your pexi code for accurate delivery. ",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: GestureDetector(
                                    onTap: () {
                                      launchUrl(
                                        Uri.parse(
                                          'https://www.paxi.co.za/paxi-points',
                                        ),
                                        mode: LaunchMode.inAppBrowserView,
                                      );
                                    },
                                    child: Text(
                                      "Click here",
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,

                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    " to find your pexi code.",
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ] else ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: color.hintColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: color.hintColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "You will collect the items from:",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getPickupInfo(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: color.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Please contact the seller to arrange a time.",
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // --- Order Summary Card ---
                Card(
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
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.cartProducts.length,
                          itemBuilder: (context, index) {
                            final product = widget.cartProducts[index];
                            final productName =
                                product['productName'] ?? 'Product';
                            final productPrice =
                                (product['price'] as num?)?.toDouble() ?? 0.0;
                            final productQuantity =
                                (product['quantity'] as int?) ?? 1;
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
                                          'R${productPrice.toStringAsFixed(2)} x $productQuantity',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: color.hintColor,
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

                // --- PLATFORM SPECIFIC PAYMENT BUTTON ---
                _buildPaymentButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData color) {
    return Container(
      width: 40,
      height: 40,
      color: color.hintColor.withOpacity(0.2),
      child: Icon(Icons.image, color: color.hintColor, size: 20),
    );
  }
}
