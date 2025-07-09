import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/ShoppingPage.dart';

class ProductDetails extends StatefulWidget {
  final Map<String, dynamic> productDetails;
  const ProductDetails({super.key, required this.productDetails});

  @override
  State<ProductDetails> createState() => _ProductDetailsState();
}

class _ProductDetailsState extends State<ProductDetails> {
  @override
  void initState() {
    super.initState();
  }

  int cartCount = 1;
  void loadCartCount() async {
    List<Map<String, dynamic>> cart = await CartHelper.getCart();
    setState(() {
      cartCount = cart.length;
    });
  }

  void addToCart(Map<String, dynamic> product) async {
    await CartHelper.addToCart(product);
    loadCartCount();

    final color = Theme.of(context);
    toastification.dismissAll();
    Api().showMessage(
      context,
      'Your Product is addded to the cart',
      'Success',
      color.splashColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.primaryColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: color.hintColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 20),
            if (widget.productDetails['imageUrl'] != null)
              Image.network(
                widget.productDetails['imageUrl']!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.productDetails['productName'] ?? 'None',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color.scaffoldBackgroundColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    SharePlus.instance.share(
                      ShareParams(
                        text: widget.productDetails['imageUrl'] ?? "",
                      ),
                    );
                  },
                  icon: Icon(Icons.share, color: color.scaffoldBackgroundColor),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: color.scaffoldBackgroundColor,
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.productDetails['address'] ??
                              'laiwefbilEBFejhfblsjkdLFBiuefjbw;KEJFBlekjfb;eKJFBe;kfjb;KJFBekjfbdfJKB',

                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            decorationColor: color.scaffoldBackgroundColor,
                            color: color.scaffoldBackgroundColor,
                            fontSize: 16,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    growable: true,
                    5,
                    (index) => Icon(
                      Icons.star_border,
                      color: index == 0
                          ? color.primaryColorDark
                          : Colors.yellow,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              widget.productDetails['description'] ?? "wd",
              style: TextStyle(
                color: color.scaffoldBackgroundColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: () {
                addToCart(widget.productDetails);
              },
              text: 'Add to cart',
              backgroundColor: color.scaffoldBackgroundColor,
              foregroundColor: color.primaryColor,
              width: double.infinity,
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
