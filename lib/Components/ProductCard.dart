import 'package:flutter/material.dart';
// Remove the unused import if it's not being used anywhere else in this file.
// import 'package:flutter_launcher_icons/xml_templates.dart';

class Product_Card extends StatefulWidget {
  final String? imageUrl;
  final String? categoryName; // This seems unused in your current build method.
  final String? productName;
  final double? price;
  final VoidCallback onCartPressed;
  final String location;
  final bool isAvailable;

  const Product_Card({
    super.key,
    this.imageUrl,
    this.categoryName, // Still exists but not used in the UI directly here
    this.productName,
    this.price,
    required this.location,
    required this.isAvailable,
    required this.onCartPressed,
  });

  @override
  State<Product_Card> createState() => _Product_CardState();
}

class _Product_CardState extends State<Product_Card> {
  // Internal state for the favorite button
  bool _isFavorite =
      false; // Changed to _isFavorite for internal state management

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Card(
      elevation: 5, // Reduced elevation slightly for a softer look
      color: color.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias, // Ensures content respects rounded corners
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              // Product Image
              AspectRatio(
                // Use AspectRatio to give the image a consistent height relative to its width
                aspectRatio:
                    1.0, // Or whatever ratio fits your design (e.g., 4/3, 16/9)
                child: Image.network(
                  // Use a placeholder if imageUrl is null or empty
                  widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                      ? widget.imageUrl!
                      : 'https://via.placeholder.com/150', // Good default placeholder
                  fit: BoxFit.cover,
                  // height: 150, // Removed fixed height as AspectRatio handles it
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 50,
                      ), // Larger icon for error
                    );
                  },
                ),
              ),
              // Favorite Button
              Positioned(
                right: 8,
                top: 8,
                child: IconButton.filledTonal(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite
                        ? Colors.red
                        : color
                              .primaryColorDark, // Apply primaryColorDark when not favorited
                  ),
                  onPressed: () {
                    setState(() {
                      _isFavorite = !_isFavorite; // Toggle the favorite state
                      // You can add logic here to save the like status to a local database (e.g., SharedPreferences)
                      // or perform other actions based on the new state, if this card needs to persist its own state.
                      if (_isFavorite) {
                        print('${widget.productName ?? 'Product'} liked!');
                      } else {
                        print('${widget.productName ?? 'Product'} unliked!');
                      }
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                      color.scaffoldBackgroundColor.withOpacity(0.2),
                    ),
                    shape: const WidgetStatePropertyAll(
                      CircleBorder(),
                    ), // Make the button round
                    padding: WidgetStateProperty.all(
                      EdgeInsets.zero,
                    ), // Adjust padding if needed
                  ),
                ),
              ),
            ],
          ),
          // Product Details
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 4.0,
            ), // Added vertical padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment
                      .start, // Align top for better text flow
                  children: [
                    Expanded(
                      child: Text(
                        widget.productName ?? 'Product Name',
                        maxLines: 2, // Allow up to 2 lines for product name
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Shopping Cart Button
                    SizedBox(
                      width: 8,
                    ), // Small space between text and cart button
                    Card(
                      elevation: 2, // Small elevation for cart button
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ), // Rounded corners for cart button card
                      margin: EdgeInsets.zero, // Remove default margin
                      child: InkWell(
                        // Use InkWell for better visual feedback on tap
                        onTap: widget.onCartPressed,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            color: color.primaryColor,
                          ), // Color the icon
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4), // Space after product name/cart button row
                Text(
                  'From:${widget.location}',
                  maxLines: 2, // Allow up to 2 lines for description
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14, // Slightly smaller font size
                    color: color.primaryColor,
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w900, // Slightly bolder than w100
                  ),
                ),
                SizedBox(height: 8), // Space before availability/price row
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isAvailable ? 'Available' : 'UnAvailable',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13, // Consistent font size
                            fontWeight:
                                FontWeight.w500, // Make it a bit more prominent
                            color: widget.isAvailable
                                ? const Color.fromARGB(
                                    255,
                                    41,
                                    143,
                                    45,
                                  ) // Green for available
                                : Colors.red, // Red for unavailable
                          ),
                        ),
                        // Star Rating - Consider making this dynamic based on actual product rating
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              color:
                                  index <
                                      4 // Assuming 4 stars is default for now
                                  ? Colors.amber
                                  : Colors
                                        .grey[300], // Grey for un-filled stars
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(), // Pushes price to the right
                    Padding(
                      padding: const EdgeInsets.all(
                        4.0,
                      ), // Smaller padding around price/discount
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment
                            .end, // Align price/discount to the right
                        children: [
                          const Text(
                            '30% OFF', // This is hardcoded; consider making it dynamic
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ), // Smaller, bolder for discount
                          ),
                          Text(
                            widget.price != null
                                ? 'R${widget.price!.toStringAsFixed(2)}' // Corrected currency symbol to R
                                : 'Price N/A', // Shorter text for price not available
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18, // Slightly larger for price
                              fontWeight: FontWeight.bold,
                              color: color.primaryColor,
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
