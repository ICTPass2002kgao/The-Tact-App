import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:share_plus/share_plus.dart';

class Product_Card extends StatefulWidget {
  final String? imageUrl;
  final String? categoryName;
  final String? productName;
  final double? price; // This is the actual selling price from the database
  final VoidCallback onCartPressed;
  final String location;
  final bool isAvailable;
  final double? discountPercentage;
  final List<dynamic>?
  availableColors; // Now contains color names like "blue", "red"

  const Product_Card({
    super.key,
    this.imageUrl,
    this.categoryName,
    this.productName,
    this.price,
    required this.location,
    required this.isAvailable,
    required this.onCartPressed,
    this.discountPercentage,
    required this.availableColors,
  });

  @override
  State<Product_Card> createState() => _Product_CardState();
}

class _Product_CardState extends State<Product_Card> {
  bool _isFavorite = false;
  late double _calculatedOriginalPrice;

  // --- NEW: Map for converting color names to Flutter Colors ---
  static final Map<String, Color> _colorNameMap = {
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Yellow': Colors.yellow,
    'Orange': Colors.orange,
    'Purple': Colors.purple,
    'Pink': Colors.pink,
    'Brown': Colors.brown,
    'Black': Colors.black,
    'White': Colors.white,
    'Grey': Colors.grey, // Using standard grey for simplicity
    'Teal': Colors.teal,
    'light blue': Colors.lightBlue,
    'light green': Colors.lightGreen,
    // Add more color mappings as needed based on your database values
    // For white color swatch, you might want to add a visible border
  };

  @override
  void initState() {
    super.initState();
    _isFavorite = false;
    _calculateOriginalPrice();
  }

  void _calculateOriginalPrice() {
    if (widget.price == null || widget.price! <= 0) {
      _calculatedOriginalPrice = 0.0;
      return;
    }

    final double effectiveDiscountRate =
        (widget.discountPercentage ?? 0.0) / 100.0;

    if (effectiveDiscountRate >= 1.0 || effectiveDiscountRate < 0) {
      _calculatedOriginalPrice = widget.price!;
    } else {
      _calculatedOriginalPrice = widget.price! / (1 - effectiveDiscountRate);
    }

    if (_calculatedOriginalPrice <= widget.price! + 0.01) {
      _calculatedOriginalPrice = widget.price!;
    }
  }

  // --- NEW: Helper function to get Color from name ---
  Color _getColorFromName(String colorName) {
    return _colorNameMap[colorName.toLowerCase()] ??
        Colors.transparent; // Fallback to transparent for unrecognized names
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 5,
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.0,
                child: Image.network(
                  widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? widget.imageUrl!
                      : 'https://via.placeholder.com/150',
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 50,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : theme.primaryColorDark,
                  ),
                  onPressed: () {
                    setState(() {
                      _isFavorite = !_isFavorite;
                      if (_isFavorite) {
                        print('${widget.productName ?? 'Product'} liked!');
                      } else {
                        print('${widget.productName ?? 'Product'} unliked!');
                      }
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      theme.scaffoldBackgroundColor.withOpacity(0.2),
                    ),
                    shape: const WidgetStatePropertyAll(CircleBorder()),
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.productName ?? 'Product Name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: widget.onCartPressed,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'From:${widget.location}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isAvailable ? 'Available' : 'Unavailable',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: widget.isAvailable
                                ? const Color.fromARGB(255, 41, 143, 45)
                                : Colors.red,
                          ),
                        ),
                        // --- REPLACED WITH COLOR SWATCHES FROM NAMES ---
                        if (widget.availableColors != null &&
                            widget.availableColors!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: widget.availableColors!
                                  .map(
                                    (colorName) => Padding(
                                      padding: const EdgeInsets.only(
                                        right: 4.0,
                                      ),
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: _getColorFromName(colorName),
                                          shape: BoxShape.circle,
                                          // Add a border for white colors to make them visible
                                          border: Border.all(
                                            color:
                                                colorName.toLowerCase() ==
                                                    'White'
                                                ? Colors
                                                      .grey // Visible border for white
                                                : Colors.grey.shade300,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        // --- END REPLACEMENT ---
                      ],
                    ),
                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_calculatedOriginalPrice >
                                  (widget.price ?? 0.0) &&
                              (widget.discountPercentage ?? 0.0) > 0)
                            Text(
                              'R${_calculatedOriginalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                                color: theme.hintColor,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: theme.hintColor,
                              ),
                            ),
                          if (widget.discountPercentage != null &&
                              widget.discountPercentage! > 0)
                            Text(
                              '${widget.discountPercentage!.toInt()}% OFF',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          Row(children: [SizedBox(width: 4)]),
                          Text(
                            widget.price != null
                                ? 'R${widget.price!.toStringAsFixed(2)}'
                                : 'Price N/A',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
