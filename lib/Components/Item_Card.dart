import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String imageUrl;
  final String productName;
  final dynamic productPrice;
  final dynamic quantity;
  final Function() addQuantity;
  final Function() subtractQuantity;
  // NEW: Fields for product variants
  final String? selectedColor;
  final String? selectedSize;

  const ItemCard({
    super.key,
    required this.imageUrl,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.addQuantity,
    required this.subtractQuantity,
    this.selectedColor, // Optional color
    this.selectedSize, // Optional size
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context); 

    // Robust Price Formatting
    final String formattedPrice = productPrice != null 
        ? 'R${(productPrice as num).toStringAsFixed(2)}'
        : 'R0.00';
    
    // Determine the product image size
    const double imageSize = 90;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Product Image
            Card(
              elevation: 4, // Reduced elevation slightly for web cleanliness
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), // Slightly less rounded border
                side: BorderSide(color: color.dividerColor, width: 0.5),
              ),
              child: Container(
                width: imageSize,
                height: imageSize,
                color: color.scaffoldBackgroundColor,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: imageSize,
                  height: imageSize,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                        color: color.primaryColor,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => 
                    Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
            ),
            
            SizedBox(width: 12),
            
            // 2. Product Details and Controls
            Expanded(
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero, // Remove margin to align better
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.dividerColor, width: 0.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Name
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16, // Slightly larger font
                          fontWeight: FontWeight.bold,
                          color: color.primaryColor,
                        ),
                      ),
                      
                      SizedBox(height: 4),

                      // Variants (Color and Size)
                      if (selectedColor != null || selectedSize != null)
                        Text(
                          'Variant: ${selectedColor ?? ''}${selectedColor != null && selectedSize != null ? ' / ' : ''}${selectedSize ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: color.hintColor,
                          ),
                        ),
                      
                      SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Total Price
                          Text(
                            formattedPrice,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          
                          // Quantity Controls
                          Row(
                            children: [
                              GestureDetector(
                                onTap: subtractQuantity,
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  color: color.primaryColor,
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '$quantity',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: color.primaryColor,
                                ),
                              ),
                              SizedBox(width: 12),
                              GestureDetector(
                                onTap: addQuantity,
                                child: Icon(
                                  Icons.add_circle_outline,
                                  color: color.primaryColor,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}