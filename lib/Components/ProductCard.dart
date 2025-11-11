import 'package:flutter/material.dart';

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
  final bool
  isSellerProduct; // NEW: Flag to indicate if product belongs to seller

  // NEW: Added optional cardBorder for visual selection highlight in ShoppingPage
  final Border? cardBorder;

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
    required this.isSellerProduct, // NEW
    this.cardBorder, // NEW
  });

  @override
  State<Product_Card> createState() => _Product_CardState();
}

class _Product_CardState extends State<Product_Card> {
  bool _isFavorite = false;
  late double _calculatedOriginalPrice;

  // Map to convert color names to Flutter Color objects
  static final Map<String, Color> _colorNameMap = {
    'red': Colors.red,
    'blue': Colors.blue,
    'green': Colors.green,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'brown': Colors.brown,
    'black': Colors.black,
    'white': Colors.white,
    'grey': Colors.grey,
    'teal': Colors.teal,
    'light blue': Colors.lightBlue,
    'light green': Colors.lightGreen,
    'cyan': Colors.cyan,
    'magenta': const Color.fromARGB(255, 255, 0, 255),
    'indigo': Colors.indigo,
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

  // Helper function to get Color from name with case-insensitivity
  Color _getColorFromName(String colorName) {
    return _colorNameMap[colorName.toLowerCase()] ?? Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 5,
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.primaryColor, width: 2.0),
        ),
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
                        // Using theme colors
                        color: theme.hintColor.withOpacity(0.1),
                        child: Icon(
                          Icons.broken_image,
                          color: theme.hintColor,
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
                      // FIX: Using theme.primaryColor for contrast instead of primaryColorDark
                      color: _isFavorite ? Colors.red : theme.primaryColor,
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
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 4.0,
              ),
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
                      const SizedBox(width: 8),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
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
                                    // Use green color that fits with the theme's intent
                                    ? theme.splashColor.withOpacity(0.8)
                                    : Colors.red,
                              ),
                            ),
                            if (widget.availableColors != null &&
                                widget.availableColors!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
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
                                                color: _getColorFromName(
                                                  colorName,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color:
                                                      colorName.toLowerCase() ==
                                                          'white'
                                                      ? Colors.grey.shade400
                                                      : Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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
                                // Keep red for discount highlight
                                '${widget.discountPercentage!}% OFF',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const Row(children: [SizedBox(width: 4)]),
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
      ),
    );
  }
}
