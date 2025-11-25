// introduction_page.dart
// ignore_for_file: prefer_const_constructs, sized_box_for_whitespace

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/Login.dart';

// --- ⭐️ 1. PulsingFeatureIcon Widget (Remains Unchanged) ---

// --- PLATFORM UTILITIES ---
bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

// UPDATED: This logic now checks the OS, even on the web.
bool get isIOSPlatform {
  // Checks for iOS or macOS (which iPads/Macs report in browsers)
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// UPDATED: This logic now checks the OS, even on the web.
bool get isAndroidPlatform {
  // Checks for Android, Linux, or Fuchsia to default to Material style.
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

class PulsingFeatureIcon extends StatefulWidget {
  final IconData iconData;
  final String label;
  final Color iconColor;
  final Color backgroundColor;
  final double iconSize;
  final double containerSize;
  final Duration delay;

  const PulsingFeatureIcon({
    super.key,
    required this.iconData,
    required this.label,
    required this.iconColor,
    required this.backgroundColor,
    this.iconSize = 24,
    this.containerSize = 75,
    required this.delay,
  });

  @override
  State<PulsingFeatureIcon> createState() => _PulsingFeatureIconState();
}

class _PulsingFeatureIconState extends State<PulsingFeatureIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      width: widget.containerSize + 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: widget.containerSize,
              height: widget.containerSize,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.iconColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                widget.iconData,
                size: widget.iconSize,
                color: widget.iconColor,
              ),
            ),
          ),
          SizedBox(height: 5),
          Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.0, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// --- ⭐️ 2. IntroductionPage (Main Widget: Optimized for Web/Mobile) ---

class Introductionpage extends StatefulWidget {
  final VoidCallback onGetStarted;

  const Introductionpage({super.key, required this.onGetStarted});

  @override
  State<Introductionpage> createState() => _IntroductionpageState();
}

class _IntroductionpageState extends State<Introductionpage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _titleOpacityAnimation;
  late Animation<double> _buttonScaleAnimation;
  late Animation<double> _mediaOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _titleOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.3, 0.8, curve: Curves.easeIn),
      ),
    );

    _buttonScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.7, 1.0, curve: Curves.elasticOut),
      ),
    );

    _mediaOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

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

    // Constrain content width for web/desktop readability
    const double contentMaxWidth = 650;

    // Use fixed heights or Expanded/Flexible within a Column, not screen height percentages
    const double imageMaxHeight = 250;

    final Color primaryIconColor = color.primaryColor;
    final Color iconBackgroundColor = color.scaffoldBackgroundColor;
    const double iconContainerSize = 75;

    final List<Map<String, dynamic>> features = [
      {
        'icon': Icons.headphones,
        'label': 'Listen to Music',
        'delay': Duration(milliseconds: 0),
      },
      {
        'icon': Icons.school,
        'label': 'Apply to University',
        'delay': Duration(milliseconds: 400),
      },
      {
        'icon': Icons.shopping_cart,
        'label': 'Buy/Sell Products',
        'delay': Duration(milliseconds: 800),
      },
      {
        'icon': Icons.history_edu,
        'label': 'Church History',
        'delay': Duration(milliseconds: 1200),
      },
      {
        'icon': Icons.calculate,
        'label': 'Generate Balance Sheets',
        'delay': Duration(milliseconds: 1600),
      },
    ];

    return Scaffold(
      // ⭐️ FIX: Use a SingleChildScrollView to wrap the content and Center it.
      // This is the most reliable way to center content vertically AND handle overflow on small screens.
      body: SingleChildScrollView(
        // The Center widget inside the SingleChildScrollView ensures vertical alignment
        // when the content doesn't fill the screen (common on web/desktop).
        child: Center(
          child: Container(
            // Use Min Height to ensure the container pushes down from the top edge
            constraints: BoxConstraints(
              minHeight: size
                  .height, // Forces the container to be at least screen height
              maxWidth: double.infinity,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.scaffoldBackgroundColor,
                  color.primaryColor.withOpacity(0.1),
                ],
              ),
            ),

            // Constrain width and apply padding
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 40.0,
                ), // Increased vertical padding for aesthetics
                child: Column(
                  mainAxisAlignment: MainAxisAlignment
                      .center, // Center the items within the column
                  mainAxisSize: MainAxisSize
                      .min, // Crucial for centering inside the ConstraintBox
                  children: [
                    // 1. Animated Title
                    FadeTransition(
                      opacity: _titleOpacityAnimation,
                      child: Column(
                        children: [
                          Text(
                            'Welcome to DANKIE Ministry',
                            style: TextStyle(
                              fontSize: size.width > 600 ? 36 : 28,
                              fontWeight: FontWeight.w800,
                              color: color.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 10),
                          // Slogan
                          Text(
                            'Connecting community, faith, and progress through technology.',
                            style: TextStyle(
                              fontSize: size.width > 600 ? 18 : 16,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30),

                    // 2. Animated Icons (Wrap Layout) and Church Community Image
                    FadeTransition(
                      opacity: _mediaOpacityAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icons Layout using Wrap
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 0,
                            runSpacing: 10,
                            children: features.map((feature) {
                              return PulsingFeatureIcon(
                                iconData: feature['icon'],
                                label: feature['label'],
                                iconColor: primaryIconColor,
                                backgroundColor: iconBackgroundColor,
                                containerSize: iconContainerSize,
                                delay: feature['delay'],
                              );
                            }).toList(),
                          ),

                          SizedBox(height: 30),

                          // Church Community Image (image4.jpeg)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              'assets/images4.jpeg',
                              // ⭐️ Use a max height constraint instead of screen percentage
                              height: imageMaxHeight,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 40),

                    isIOSPlatform
                        ? ScaleTransition(
                            scale: _buttonScaleAnimation,

                            child: SizedBox(
                              width: double.infinity,
                              child: CupertinoButton.filled(
                                color: color.primaryColor,
                                onPressed: () {
                                  widget.onGetStarted();
                                  Navigator.of(context).pushReplacement(
                                    CupertinoPageRoute(
                                      builder: (context) => const Login_Page(),
                                    ),
                                  );
                                },
                                child: const Text('Get Started'),
                              ),
                            ),
                          )
                        : ScaleTransition(
                            scale: _buttonScaleAnimation,
                            child: CustomOutlinedButton(
                              onPressed: () {
                                widget.onGetStarted();
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const Login_Page(),
                                  ),
                                );
                              },
                              text: 'Get Started',
                              backgroundColor: color.primaryColor,
                              foregroundColor: color.scaffoldBackgroundColor,
                              width: double.infinity,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
