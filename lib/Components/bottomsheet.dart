// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:url_launcher/url_launcher.dart';

// --- SHARING IMPORTS ---
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// --- PLATFORM IMPORTS ---
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

void _showPlatformMessage(
  BuildContext context,
  String title,
  String message,
  Color backgroundColor,
) {
  if (isIOSPlatform) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: Text('OK'),
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        backgroundColor: backgroundColor,
      ),
    );
  }
}

// ==========================================
// 1. MAIN BOTTOM SHEET (The User Interface)
// ==========================================
class EventDetailBottomSheet extends StatelessWidget {
  final String date;
  final String eventMonth;
  final String title;
  final String description;
  final String? posterUrl;

  const EventDetailBottomSheet({
    Key? key,
    required this.date,
    required this.eventMonth,
    required this.title,
    required this.description,
    this.posterUrl,
  }) : super(key: key);

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
            if (posterUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(15.0),
                child: Image.network(
                  posterUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      height: 200,
                      child: Center(child: Icon(Icons.error, color: Colors.grey)),
                    );
                  },
                ),
              ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "$title",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color.scaffoldBackgroundColor,
                    ),
                  ),
                ),
                // ⭐️ SHARE BUTTON ⭐️
                isIOSPlatform
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => _openShareSheet(context),
                        child: Icon(
                          CupertinoIcons.share,
                          color: color.scaffoldBackgroundColor,
                        ),
                      )
                    : IconButton(
                        onPressed: () => _openShareSheet(context),
                        icon: Icon(
                          Icons.share,
                          color: color.scaffoldBackgroundColor,
                        ),
                      ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  isIOSPlatform
                      ? CupertinoIcons.calendar
                      : Icons.calendar_month_outlined,
                  color: color.scaffoldBackgroundColor,
                ),
                SizedBox(width: 8),
                Text(
                  "$eventMonth $date",
                  style: TextStyle(
                    color: color.scaffoldBackgroundColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              "$description",
              style: TextStyle(
                color: color.scaffoldBackgroundColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: () async {
                final url = Uri.parse(''); 
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                } else {
                  _showPlatformMessage(
                    context,
                    "Error",
                    'Not live yet Counting down',
                    color.primaryColorDark,
                  );
                }
              },
              text: 'JOIN LIVE!',
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

  void _openShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, 
      builder: (context) => EventShareSheet(
        title: title,
        dateString: "$eventMonth $date",
        posterUrl: posterUrl,
        theme: Theme.of(context),
      ),
    );
  }
}

// ==========================================
// 2. EVENT SHARE SHEET (The Logic)
// ==========================================
class EventShareSheet extends StatefulWidget {
  final String title;
  final String dateString;
  final String? posterUrl;
  final ThemeData theme;

  const EventShareSheet({
    Key? key,
    required this.title,
    required this.dateString,
    required this.posterUrl,
    required this.theme,
  }) : super(key: key);

  @override
  State<EventShareSheet> createState() => _EventShareSheetState();
}

class _EventShareSheetState extends State<EventShareSheet> {
  bool _isGenerating = false;
  final String _appDomain = "https://tact-3c612.web.app";
  late final ScreenshotController _screenshotController;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _screenshotController = ScreenshotController();
    }
  }

  Future<void> _generateAndShare(bool isStatus) async {
    setState(() => _isGenerating = true);

    // Create Link
    String appLink = "$_appDomain/event?title=${Uri.encodeComponent(widget.title)}&date=${Uri.encodeComponent(widget.dateString)}";

    // Create Message
    String message = "📅 ${widget.title} - ${widget.dateString}\n\nTap to view event in TTACT:\n$appLink";

    try {
      if (kIsWeb) {
        await Share.share(message);
      } else {
        // MOBILE: Capture Image & Share
        final directory = (await getApplicationDocumentsDirectory()).path;
        String fileName = 'ttact_event_${DateTime.now().millisecondsSinceEpoch}.png';
        String path = '$directory/$fileName';

        // Capture the invisible card widget
        // Note: Increased delay slightly to allow NetworkImage to load in background
        final imageBytes = await _screenshotController.captureFromWidget(
          EventShareCardGenerator(
            title: widget.title,
            dateString: widget.dateString,
            posterUrl: widget.posterUrl,
          ),
          delay: const Duration(milliseconds: 150), 
          pixelRatio: 2.0,
        );

        File imgFile = File(path);
        await imgFile.writeAsBytes(imageBytes);

        final xFile = XFile(path);
        await Share.shareXFiles([xFile], text: message);
      }
    } catch (e) {
      debugPrint("Error sharing event: $e");
      if (kIsWeb) _copyLink();
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.pop(context);
      }
    }
  }

  void _copyLink() {
    String appLink = "$_appDomain/event?title=${Uri.encodeComponent(widget.title)}";
    Clipboard.setData(ClipboardData(text: appLink));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(kIsWeb ? "Link copied to clipboard!" : "Clickable App Link Copied!"),
      backgroundColor: Colors.green,
    ));
    Navigator.pop(context);
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
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(10)),
            ),
          ),
          SizedBox(height: 20),
          Text("Share Event", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.theme.hintColor)),
          SizedBox(height: 20),

          if (_isGenerating)
             Center(child: Column(
               children: [
                 CircularProgressIndicator(color: widget.theme.primaryColor),
                 SizedBox(height: 10),
                 Text("Generating poster...", style: TextStyle(color: widget.theme.hintColor)),
               ],
             ))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (!kIsWeb) ...[
                    _buildShareIcon(
                      icon: FontAwesomeIcons.whatsapp, color: Colors.white, bg: Color(0xFF25D366),
                      label: "Status",
                      onTap: () => _generateAndShare(true),
                    ),
                    SizedBox(width: 20),
                    _buildShareIcon(
                      icon: FontAwesomeIcons.whatsapp, color: Colors.white, bg: Color(0xFF25D366),
                      label: "WhatsApp",
                      onTap: () => _generateAndShare(false),
                    ),
                    SizedBox(width: 20),
                  ],
                  
                  _buildShareIcon(
                    icon: Icons.link, color: Colors.white, bg: Colors.blue,
                    label: "Copy Link", onTap: _copyLink,
                  ),
                   SizedBox(width: 20),
                   
                   _buildShareIcon(
                    icon: kIsWeb ? Icons.share : Icons.more_horiz, color: Colors.black, bg: Colors.grey[200]!,
                    label: kIsWeb ? "Share" : "More", 
                    onTap: () => _generateAndShare(false),
                  ),
                ],
              ),
            ),
          SizedBox(height: 30),
          
          if (kIsWeb)
             Padding(
               padding: const EdgeInsets.only(bottom: 10),
               child: Text("Share this link to open in TTACT app", style: TextStyle(fontSize: 12, color: widget.theme.hintColor, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
             ),

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

  Widget _buildShareIcon({required IconData icon, required Color color, required Color bg, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Center(child: Icon(icon, color: color, size: 30)),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: widget.theme.hintColor)),
        ],
      ),
    );
  }
}

// ==========================================
// 3. EVENT CARD GENERATOR (Visuals)
// ==========================================
class EventShareCardGenerator extends StatelessWidget {
  final String title;
  final String dateString;
  final String? posterUrl; // Original event poster

  const EventShareCardGenerator({
    Key? key,
    required this.title,
    required this.dateString,
    this.posterUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fixed size for status ratio (9:16)
    return Container(
      width: 1080 / 3,
      height: 1920 / 3,
      // ⭐️ BACKGROUND LOGIC ⭐️
      // If posterUrl exists, use it as the background. If not, use gradient.
      decoration: posterUrl != null
          ? BoxDecoration(
              color: Colors.black, // Fallback color
              image: DecorationImage(
                image: NetworkImage(posterUrl!),
                fit: BoxFit.cover,
                // Add a darken filter so white text is readable on top
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5), 
                  BlendMode.darken
                ),
              ),
            )
          : BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1a2a6c), Color(0xFFb21f1f), Color(0xFFfdbb2d)],
              ),
            ),
      child: Stack(
        children: [
          // Content Layer
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white54),
                ),
                child: Text("UPCOMING EVENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              SizedBox(height: 30),

              // ⭐️ If NO poster, show a placeholder icon in the middle.
              // If poster exists, we leave this empty so we see the background.
              if (posterUrl == null)
                Center(
                  child: Container(
                    height: 120, width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Icon(Icons.event, color: Colors.white, size: 60),
                  ),
                )
              else 
                 // Just a spacer if we have a background image
                 SizedBox(height: 50), 

              SizedBox(height: 30),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28, // Slightly larger for impact
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 15, offset: Offset(0, 2))
                    ],
                  ),
                ),
              ),
              SizedBox(height: 15),

              // Date
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    dateString,
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)]
                    ),
                  ),
                ],
              ),
              SizedBox(height: 60),

              // App Action
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white, // White button for high contrast
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app, color: Colors.black),
                    SizedBox(width: 8),
                    Text("Get more info on DANKIE App", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}