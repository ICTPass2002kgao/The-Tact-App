// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:flutter_image_slider/carousel.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'Images/Images.dart';

class Introductionpage extends StatefulWidget {
  const Introductionpage({super.key});

  @override
  State<Introductionpage> createState() => _IntroductionpageState();
}

class _IntroductionpageState extends State<Introductionpage> {
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Spacer(),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Carousel(
                    animationPageCurve: Curves.easeInOut,
                    autoScroll: true,
                    autoScrollDuration: Duration(seconds: 5),
                    indicatorBarColor: Colors.transparent,
                    unActivatedIndicatorColor: Colors.white,
                    activateIndicatorColor: color.primaryColor,
                    items: const [
                      ImagesPage(imageName: 'assets/tact_logo.PNG'),
                      ImagesPage(imageName: 'assets/images4.jpeg'),
                      ImagesPage(imageName: 'assets/image3.jpeg'),
                      ImagesPage(imageName: 'assets/TActso2.jpeg'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Spacer(),
              CustomOutlinedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                text: 'Get started',
                backgroundColor: color.primaryColor,
                foregroundColor: color.scaffoldBackgroundColor,
                width: double.infinity,
              ),
              Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
