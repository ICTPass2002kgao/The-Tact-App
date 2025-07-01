import 'package:flutter/material.dart';
import 'package:flutter_product_card/flutter_product_card.dart';
import 'package:ttact/Components/Buttons/Buttons.dart';
 
import 'package:ttact/Components/Color.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final color = AppColor(color: const Color.fromARGB(255, 15, 76, 167));
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title:Text('Product name'),
        centerTitle: true,
        backgroundColor:color.color,
        foregroundColor:Colors.white
      ),
      body:Column(
        children:[
          ProductCard(
                      imageUrl:
                          //add your image url here
                          'https://encrypted-tbn3.gstatic.com/shopping?q=tbn:ANd9GcQndSK7hvssofrM2uzv75NxVjrkAwH3RwyqWcBesUsmq1ipmkuljRr6x_SRbCKaBXvjTR9CKfAaEFtmUFw-69o52wgVMgk2hp8KDYr4FvKtQ8ZfKewgOW4gDQ&usqp=CAE4',
                      categoryName: 'Pants',
                      productName: 'Men Linen Pants',
                      price: 199.99,
                      currency: '\$', // Default is '$'
                      onTap: () {
                        // Handle card tap event
                      },
                      onFavoritePressed: () {
                        // Handle favorite button press
                      },
                      shortDescription:
                          'comfortable & airy.', // Optional short description
                      rating: 4.2, // Optional rating
                      discountPercentage: 35.0, // Optional discount percentage
                      isAvailable: true, // Optional availability status
                      cardColor: Colors.white, // Optional card background color
                      textColor: Colors.black, // Optional text color
                      borderRadius: 8.0, // Optional border radius
                    ),
                Buttons(function: () {  }, buttonText: 'Add to cart', foregroundcolor: color.color, backgroundcolor: Colors.white,)
        ]
      )
    );
  }
}