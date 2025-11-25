import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/Share_Card_Generator.dart';

class TikTokShareSheet extends StatefulWidget {
  final String songName;
  final String artistName;
  final String songUrl; // This is the deep link ID
  final ThemeData theme;

  const TikTokShareSheet({
    Key? key,
    required this.songName,
    required this.artistName,
    required this.songUrl,
    required this.theme,
  }) : super(key: key);

  @override
  State<TikTokShareSheet> createState() => _TikTokShareSheetState();
}

class _TikTokShareSheetState extends State<TikTokShareSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isGenerating = false;

  // --- THE DEEP LOGIC ---
  Future<void> _generateAndShare(bool isStatus) async {
    setState(() => _isGenerating = true);

    try {
      // 1. Capture the "Ghost Widget"
      final directory = (await getApplicationDocumentsDirectory()).path;
      String fileName =
          'ttact_share_${DateTime.now().millisecondsSinceEpoch}.png';
      String path = '$directory/$fileName';

      // Capture logic
      final imageBytes = await _screenshotController.captureFromWidget(
        ShareCardGenerator(
          songName: widget.songName,
          artistName: widget.artistName,
          appLogoPath: "assets/dankie_logo.PNG",
        ),
        delay: Duration(milliseconds: 10),
      );

      File imgFile = File(path);
      await imgFile.writeAsBytes(imageBytes);

      // 2. Create the Deep Link
      // NOTE: Using a standard HTTPS link here, configured on the OS to open the app.
      String deepLink =
          "https://ttact.app/song?url=${Uri.encodeComponent(widget.songUrl)}";
      String message =
          "🎵 Listening to ${widget.songName} by ${widget.artistName}.\n\nListen here: $deepLink";

      // 3. Share using SharePlus
      final xFile = XFile(path);

      await Share.shareXFiles([xFile], text: message);
    } catch (e) {
      debugPrint("Error sharing: $e");
    } finally {
      setState(() => _isGenerating = false);
      Navigator.pop(context); // Close sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            "Share to",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.theme.hintColor,
            ),
          ),
          SizedBox(height: 20),

          // The Horizontal Scroll Row (TikTok Style)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 1. WhatsApp Status
                _buildShareIcon(
                  icon: FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  bg: Color(0xFF25D366),
                  label: "Status",
                  onTap: () => _generateAndShare(true),
                ),
                SizedBox(width: 20),

                // 2. WhatsApp Chat
                _buildShareIcon(
                  icon: FontAwesomeIcons.whatsapp,
                  color: Colors.white,
                  bg: Color(0xFF25D366),
                  label: "WhatsApp",
                  onTap: () => _generateAndShare(false),
                ),
                SizedBox(width: 20),

                // 3. Copy Link
                _buildShareIcon(
                  icon: Icons.link,
                  color: Colors.white,
                  bg: Colors.blue,
                  label: "Copy Link",
                  onTap: () {
                    // ⭐️ FIX: Construct the full deep link for copying
                    String deepLink =
                        "https://ttact.app/song?url=${Uri.encodeComponent(widget.songUrl)}";
                        
                    Clipboard.setData(ClipboardData(text: deepLink));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Link Copied!")));
                    Navigator.pop(context);
                  },
                ),
                SizedBox(width: 20),

                // 4. More
                _buildShareIcon(
                  icon: Icons.more_horiz,
                  color: Colors.black,
                  bg: Colors.grey[200]!,
                  label: "More",
                  onTap: () => _generateAndShare(false),
                ),
              ],
            ),
          ),
          SizedBox(height: 30),

          // Cancel Button
          if (_isGenerating)
            Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.cardColor,
                  foregroundColor: widget.theme.primaryColor,
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text("Cancel"),
              ),
            ),
          SizedBox(height: 10),
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
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(child: Icon(icon, color: color, size: 30)),
          ),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: widget.theme.hintColor),
          ),
        ],
      ),
    );
  }
}