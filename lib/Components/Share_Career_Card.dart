import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';

class CareerShareSheet extends StatefulWidget {
  final String title;
  final String category;
  final String expiryDate;
  final String docId; // ⭐️ CHANGED: Now takes the Firestore Document ID
  final ThemeData theme;

  const CareerShareSheet({
    Key? key,
    required this.title,
    required this.category,
    required this.expiryDate,
    required this.docId,
    required this.theme,
  }) : super(key: key);

  @override
  State<CareerShareSheet> createState() => _CareerShareSheetState();
}

class _CareerShareSheetState extends State<CareerShareSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isGenerating = false;

  // ⭐️ Your App Domain (Same as Share_Song)
  final String _appDomain = "https://tact-3c612.web.app";

  Future<void> _generateAndShare() async {
    setState(() => _isGenerating = true);

    try {
      final directory = (await getApplicationDocumentsDirectory()).path;
      String fileName =
          'dankie_career_${DateTime.now().millisecondsSinceEpoch}.png';
      String path = '$directory/$fileName';

      // 1. Capture the "Visual Card"
      final imageBytes = await _screenshotController.captureFromWidget(
        CareerShareCardGenerator(
          title: widget.title,
          category: widget.category,
          expiryDate: widget.expiryDate,
        ),
        delay: const Duration(milliseconds: 20),
        pixelRatio: 3.0,
      );

      File(path).writeAsBytesSync(imageBytes);

      // 2. Construct Deep Link
      // This link directs the user to the specific opportunity in the app
      String deepLink =
          "$_appDomain/career?title=${Uri.encodeComponent(widget.title)}";

      // 3. Prepare Message
      String message =
          "🚀 New Opportunity: ${widget.title.toUpperCase()}\n"
          "📅 Closing: ${widget.expiryDate}\n\n"
          "Tap to apply in DANKIE:\n$deepLink";

      // 4. Share
      await Share.shareXFiles([XFile(path)], text: message);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Share Error: $e");
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyLink() {
    String deepLink =
        "$_appDomain/career?id=${widget.docId}&title=${Uri.encodeComponent(widget.title)}";
    Clipboard.setData(ClipboardData(text: deepLink));
    Api().showMessage(context, "Link Copied!", "Successful", Colors.green);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Share Opportunity",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: widget.theme.hintColor,
            ),
          ),
          const SizedBox(height: 20),

          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildShareIcon(
                    icon: Icons.share,
                    color: Colors.white,
                    bg: widget.theme.primaryColor,
                    label: "More Options",
                    onTap: _generateAndShare,
                  ),
                  const SizedBox(width: 25),
                  _buildShareIcon(
                    icon: Icons.link,
                    color: Colors.white,
                    bg: Colors.blue,
                    label: "Copy App Link",
                    onTap: _copyLink,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildShareIcon({
    required IconData icon,
    required Color color,
    required Color bg,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(child: Icon(icon, color: color, size: 28)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: widget.theme.hintColor),
          ),
        ],
      ),
    );
  }
}

// --- THE VISUAL CARD GENERATOR ---
class CareerShareCardGenerator extends StatelessWidget {
  final String title;
  final String category;
  final String expiryDate;

  const CareerShareCardGenerator({
    super.key,
    required this.title,
    required this.category,
    required this.expiryDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 711, // 9:16 Aspect Ratio
      decoration: BoxDecoration(
        color: Colors.white,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D47A1), // Dark Blue
            const Color(0xFF42A5F5), // Light Blue
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background Pattern
          Positioned(
            top: -70,
            right: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -70,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(50),
                  child: Image.asset(
                    "assets/dankie_logo.PNG",
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Category Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  title.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Closing Date
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Closing: $expiryDate",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              const Text(
                "Tap link to apply!",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 5),
              const Text(
                "Available on DANKIE App",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
