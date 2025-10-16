import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProductDetails extends StatefulWidget {
  final Map<String, dynamic> productDetails;
  final String sellerProductId;
  final void Function(String?, String?) onAddToCart;

  const ProductDetails({
    super.key,
    required this.productDetails,
    required this.sellerProductId,
    required this.onAddToCart,
  });

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  String? _selectedColor;
  String? _selectedSize;
  final TextEditingController _customSizeController = TextEditingController();

  // Map to convert color names to Flutter Color objects
  final Map<String, Color> _colorMap = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Black': Colors.black,
    'White': Colors.white,
    'Yellow': Colors.yellow,
    'Pink': Colors.pink,
    'Purple': Colors.purple,
    'Orange': Colors.orange,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
    'Cyan': Colors.cyan,
    'Magenta': const Color.fromARGB(255, 255, 0, 255),
    'Teal': Colors.teal,
    'Indigo': Colors.indigo,
  };

  @override
  void initState() {
    super.initState();
    _incrementProductView();

    // Auto-select the first color and size if available
    final List<String> availableColors =
        (widget.productDetails['availableColors'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (availableColors.isNotEmpty) {
      _selectedColor = availableColors.first;
    }

    final List<String> availableSizes =
        (widget.productDetails['availableSizes'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (availableSizes.isNotEmpty) {
      if (availableSizes.length == 1 && availableSizes[0] == 'All') {
        _selectedSize = ''; // Placeholder for custom size
      } else {
        _selectedSize = availableSizes.first;
      }
    }
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  Future<void> _incrementProductView() async {
    try {
      if (widget.sellerProductId.isNotEmpty) {
        final docRef = FirebaseFirestore.instance
            .collection('seller_products')
            .doc(widget.sellerProductId);
        await docRef.update({'views': FieldValue.increment(1)});
      }
    } catch (e) {
      print('Error incrementing product view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<dynamic> availableColors =
        (widget.productDetails['availableColors'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final List<dynamic> availableSizes =
        (widget.productDetails['availableSizes'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final bool allSizesAvailable =
        availableSizes.length == 1 && availableSizes[0] == 'All';

    return Container(
      padding: const EdgeInsets.all(16.0),
      // REMOVED THE FIXED HEIGHT to prevent overflow errors
      // height: MediaQuery.of(context).size.height * 0.8,
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
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  widget.productDetails['imageUrl'] ??
                      'https://via.placeholder.com/150',
                  height: 250,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 100),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.productDetails['productName'] ?? 'Unknown Product',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
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
            Text(
              widget.productDetails['description'] ??
                  'No description provided.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),

            // --- Color Selection Section with Visuals ---
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
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: availableColors.map((color) {
                      final bool isSelected = (_selectedColor == color);
                      final Color chipColor = _colorMap[color] ?? Colors.grey;

                      return ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: chipColor,
                          child:
                              isSelected && chipColor.computeLuminance() > 0.5
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 16,
                                )
                              : (isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null),
                        ),
                        label: Text(color),
                        selected: isSelected,
                        selectedColor: theme.primaryColor.withOpacity(0.2),
                        onSelected: (selected) {
                          setState(() {
                            _selectedColor = selected ? color : null;
                          });
                        },
                        labelStyle: TextStyle(
                          color: isSelected
                              ? theme.primaryColor
                              : theme.hintColor,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? theme.primaryColor : Colors.grey,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // --- Size Selection Section ---
            if (availableSizes.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Sizes:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (allSizesAvailable)
                    TextField(
                      controller: _customSizeController,
                      decoration: const InputDecoration(
                        labelText: "Enter your size (e.g., M, 32, 7)",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedSize = value.trim();
                        });
                      },
                    )
                  else
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: availableSizes.map((size) {
                        final bool isSelected = (_selectedSize == size);
                        return ChoiceChip(
                          label: Text(size),
                          selected: isSelected,
                          selectedColor: theme.primaryColor.withOpacity(0.2),
                          onSelected: (selected) {
                            setState(() {
                              _selectedSize = selected ? size : null;
                            });
                          },
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.primaryColor
                                : theme.hintColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.grey,
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                ],
              ),

            // --- Add to Cart Button with Validation ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final bool colorRequired = availableColors.isNotEmpty;
                  final bool sizeRequired = availableSizes.isNotEmpty;

                  if (colorRequired && _selectedColor == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select a color.')),
                    );
                    return;
                  }

                  if (sizeRequired &&
                      (_selectedSize == null || _selectedSize!.isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select or enter a size.'),
                      ),
                    );
                    return;
                  }

                  widget.onAddToCart(_selectedColor, _selectedSize);
                  Navigator.pop(context);
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
