import 'package:flutter/material.dart';

class ShareCardGenerator extends StatelessWidget {
  final String songName;
  final String artistName;
  final String appLogoPath; // e.g., "assets/dankie_logo.PNG"

  const ShareCardGenerator({
    Key? key,
    required this.songName,
    required this.artistName,
    required this.appLogoPath,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    // This design mimics a "Status" sticker
    return Container(
      width: 1080 / 3, // Scaled down for capture speed
      height: 1920 / 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.centerLeft,
          colors: [
            Theme.of(context).scaffoldBackgroundColor,
            Theme.of(context).scaffoldBackgroundColor,
            Colors.blue.withOpacity(0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. The Centered Logo (TikTok Style)
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 5),
              boxShadow: [
                BoxShadow(color: Colors.blue, blurRadius: 10, spreadRadius: 5),
              ],
              image: DecorationImage(
                image: AssetImage(appLogoPath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SizedBox(height: 30),

          // 2. Song Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              songName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: "Arial", // Use your app font
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
          ),
          SizedBox(height: 10),

          // 3. Artist Name
          Text(
            "by $artistName",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 40),

          // 4. "Listen on TTACT App" Badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill, color: Colors.white),
                SizedBox(width: 8),
                Text("Available on Dankie following link🔗", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
