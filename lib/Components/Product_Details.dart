import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For incrementing views

class ProductDetails extends StatefulWidget {
  final Map<String, dynamic> productDetails;
  final String sellerProductId; // The document ID of the seller's specific product
  final Function(String?) onAddToCart; // Callback to add to cart with selected color

  const ProductDetails({
    super.key,
    required this.productDetails,
    required this.sellerProductId,
    required this.onAddToCart, // Initialize the callback
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  String? _selectedColor; // State variable for the selected color

  @override
  void initState() {
    super.initState();
    _incrementProductView();
    // Initialize selected color if available and only one option exists, or a default
    final List<String> availableColors = (widget.productDetails['availableColors'] as List?)
            ?.map((e) => e.toString())
            .toList() ?? [];
    if (availableColors.isNotEmpty) {
      _selectedColor = availableColors.first; // Auto-select the first color if available
    }
  }

  // Function to increment views in Firestore
  Future<void> _incrementProductView() async {
    try {
      if (widget.sellerProductId.isNotEmpty) {
        final docRef = FirebaseFirestore.instance.collection('seller_products').doc(widget.sellerProductId);
        await docRef.update({
          'views': FieldValue.increment(1),
        });
        print('Product view incremented for ${widget.productDetails['productName']}');
      }
    } catch (e) {
      print('Error incrementing product view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<dynamic> availableColors = (widget.productDetails['availableColors'] as List?)
            ?.map((e) => e.toString())
            .toList() ?? [];

    return Container(
      padding: const EdgeInsets.all(16.0),
      // Use media query for dynamic height to ensure keyboard visibility
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product Image
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  widget.productDetails['imageUrl'] ?? 'https://via.placeholder.com/150',
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Product Name
            Text(
              widget.productDetails['productName'] ?? 'Unknown Product',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            // Product Price and Discount
            Row(
              children: [
                Text(
                  'R${widget.productDetails['price']?.toStringAsFixed(2) ?? '0.00'}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                if (widget.productDetails['discountPercentage'] > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      '${widget.productDetails['discountPercentage'].toInt()}% OFF',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Product Description
            Text(
              widget.productDetails['description'] ?? 'No description provided.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // --- NEW: Color Selection ---
            if (availableColors.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Colors:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8.0, // horizontal space between chips
                    runSpacing: 8.0, // vertical space between lines of chips
                    children: availableColors.map((color) {
                      final bool isSelected = (_selectedColor == color);
                      return ChoiceChip(
                        label: Text(color),
                        selected: isSelected,
                        selectedColor: theme.primaryColor.withOpacity(0.2),
                        onSelected: (selected) {
                          setState(() {
                            _selectedColor = selected ? color : null;
                          });
                        },
                        labelStyle: TextStyle(
                          color: isSelected ? theme.primaryColor : theme.hintColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? theme.primaryColor : Colors.grey,
                        ),
                        // You can customize avatar or other properties if needed
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            // --- END NEW: Color Selection ---

            // Add to Cart Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (availableColors.isNotEmpty && _selectedColor == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a color.')),
                    );
                    return; // Prevent adding if color is required but not selected
                  }
                  // Call the provided onAddToCart callback with the selected color
                  widget.onAddToCart(
                    availableColors.isNotEmpty ? _selectedColor : null,
                  );
                  Navigator.pop(context); // Close the bottom sheet
                },
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}