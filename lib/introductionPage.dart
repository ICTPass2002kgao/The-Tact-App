// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace

import 'package:flutter/material.dart';
import 'package:flutter_image_slider/carousel.dart';
// Assuming CustomOutlinedButton and ImagesPage are defined in your project
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'Images/Images.dart'; 

class Introductionpage extends StatefulWidget {
  const Introductionpage({super.key});

  @override
  State<Introductionpage> createState() => _IntroductionpageState();
}

// Added TickerProviderStateMixin for AnimationController
class _IntroductionpageState extends State<Introductionpage> with TickerProviderStateMixin {
  // Animation controllers for staggered effect
  late AnimationController _fadeController;
  late Animation<double> _titleOpacityAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _carouselOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Fade-in animation for Title/Slogan
    _titleOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Scale animation for the Get Started button
    _buttonScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );
    
    // Opacity animation for the Carousel
    _carouselOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Start the animation when the page loads
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // Replacing solid color with a gradient for a modern background
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Using primary color and a lighter shade for the gradient
            colors: [color.scaffoldBackgroundColor, color.primaryColor.withOpacity(0.1)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Animated Carousel (takes up more space)
                FadeTransition(
                  opacity: _carouselOpacityAnimation,
                  child: Container(
                    height: size.height * 0.5, // Use 50% of screen height
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20), // More rounded corners
                      child: Carousel(
                        animationPageCurve: Curves.easeInOut,
                        autoScroll: true,
                        autoScrollDuration: Duration(seconds: 4), // Slightly faster
                        indicatorBarColor: Colors.transparent,
                        unActivatedIndicatorColor: const Color.fromARGB(255, 185, 182, 182),
                        activateIndicatorColor: color.primaryColor,
                        items: const [
                          ImagesPage(imageName: 'assets/dankie_logo.PNG'),
                          ImagesPage(imageName: 'assets/images4.jpeg'),
                          ImagesPage(imageName: 'assets/image3.jpeg'),
                          ImagesPage(imageName: 'assets/TActso2.jpeg'),
                        ],
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 30),

                // 2. Animated Title and Slogan
                FadeTransition(
                  opacity: _titleOpacityAnimation,
                  child: Column(
                    children: [
                      Text(
                        'Welcome to DANKIE Ministry',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: color.primaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Connecting community, faith, and progress through technology.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                Spacer(), // Push content towards edges

                // 3. Animated "Get Started" Button
                ScaleTransition(
                  scale: _buttonScaleAnimation,
                  child: CustomOutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    text: 'Get Started',
                    backgroundColor: color.primaryColor,
                    foregroundColor: color.scaffoldBackgroundColor,
                    width: double.infinity,
                  ),
                ),
                Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}