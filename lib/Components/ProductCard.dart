import 'package:flutter/material.dart';
import 'package:flutter_launcher_icons/xml_templates.dart';

class Product_Card extends StatelessWidget {
  final String? imageUrl;
  final String? categoryName;
  final String? productName;
  final double? price;
  final VoidCallback onCartPressed;
  final String productDescription;
  final bool isAvailable;

  const Product_Card({
    super.key,
    this.imageUrl,
    this.categoryName,
    this.productName,
    this.price,
    required this.productDescription,
    required this.isAvailable,
    required this.onCartPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl ?? 'assets/images/default_product_image.png',
                  fit: BoxFit.cover,
                  height: 150,
                  width: double.infinity,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.favorite_border,),
                  onPressed: () {
                    // Handle favorite action
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        productName ?? 'Product Name',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Card(
                      elevation: 5,
                      child: IconButton(
                        onPressed: onCartPressed,
                        icon: const Icon(Icons.shopping_cart_outlined),
                      ),
                    ),
                  ],
                ),
                Text(
                  productDescription,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.hintColor,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w100,
                  ),
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Text(
                            isAvailable ? 'Available' : 'UnAvailable',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              fontWeight: FontWeight.w100,
                              color:
                                  isAvailable
                                      ? const Color.fromARGB(255, 41, 143, 45)
                                      : Colors.red,
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              Icons.star,
                              color:
                                  index < 4
                                      ? Colors.amber
                                      : const Color.fromARGB(255, 41, 143, 45),
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          const Text(
                            '30% OFF',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: Colors.red),
                          ),
                          Text(
                            price != null
                                ? '\R${price!.toStringAsFixed(2)}'
                                : 'Price not available',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
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
