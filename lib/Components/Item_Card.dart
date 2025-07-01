import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String imageUrl;
  final String productName;
  final dynamic productPrice;
  final dynamic quantity; // Assuming quantity is 1 for simplicity
  final Function() addQuantity;
  final Function() subtractQuantity;
  const ItemCard({
    super.key,
    required this.imageUrl,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.addQuantity,
    required this.subtractQuantity,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Column(
      children: [
        Container(
          child: Row(
            children: [
              Card(
                elevation: 10,
                color: Colors.transparent,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: color.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.primaryColor, width: 0.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: 85,
                            height: 87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Card(
                  elevation: 10,
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: color.primaryColor, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color.primaryColor.withOpacity(0.8),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'R$productPrice',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: color.primaryColor.withOpacity(0.8),
                            ),
                          ),
                          //Quantity of this product
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: subtractQuantity,
                                child: Icon(
                                  Icons.remove_circle_outline,
                                  color: color.primaryColor,
                                ),
                              ),
                              SizedBox(width: 15),
                              Text(
                                '$quantity', // Assuming quantity is 1 for simplicity
                                style: TextStyle(
                                  fontSize: 18,
                                  color: color.primaryColor,
                                ),
                              ),
                              SizedBox(width: 15),
                              GestureDetector(
                                onTap: addQuantity,
                                child: Icon(
                                  Icons.add_circle_outline,
                                  color: color.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
