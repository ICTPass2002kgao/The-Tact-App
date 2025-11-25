import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_full/session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:screenshot/screenshot.dart';
// NOTE: These are placeholders for your actual app imports.
// Make sure these files exist in your project:
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Share_Card_Generator.dart';
import 'package:ttact/main.dart'; // Required to access the global 'audioHandler'

// --- PLACEHOLDER FOR GLOBAL AUDIO HANDLER (DEFINE THIS IN main.dart) ---
// Since the original code relies on 'audioHandler', I'm defining a placeholder
// here for completeness. You must ensure this object is correctly initialized
// in your main application logic.
class MockAudioHandler {
  final playbackState = ValueNotifier(
    AudioPlaybackState(
      position: Duration.zero,
      processingState: AudioProcessingState.ready,
      playing: false,
    ),
  );
}

enum AudioProcessingState { ready }

class AudioPlaybackState {
  final Duration position;
  final AudioProcessingState processingState;
  final bool playing;
  AudioPlaybackState({
    required this.position,
    required this.processingState,
    required this.playing,
  });
}

MockAudioHandler? audioHandler = MockAudioHandler();

// --- PLATFORM UTILITIES ---
bool get isMobileNative =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

bool get isAndroidPlatform {
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}

// --- TIKTOK SHARE SHEET WIDGET ---
class TikTokShareSheet extends StatefulWidget {
  final String songName;
  final String artistName;
  final String songUrl;
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
  // --- STATE FOR VIDEO CLIPPING ---
  double _clipDurationSeconds = 15.0; // Default clip length
  bool _isGenerating = false;

  // Use your Firebase domain
  final String _appDomain = "https://tact-3c612.web.app";

  late final ScreenshotController _screenshotController; // Explicitly typed

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _screenshotController = ScreenshotController();
    } else {
      // Initialize with a mock or handle web case gracefully if needed
      _screenshotController = ScreenshotController();
    }
  }

  // Helper function to get the LIVE position from your audio handler
  double _getLiveStartSeconds() {
    if (audioHandler != null) {
      return audioHandler!.playbackState.value.position.inSeconds.toDouble();
    }
    return 0.0; // Fallback to start if handler is null
  }

  // --- CORE VIDEO GENERATION LOGIC ---
  Future<void> _generateAndShareVideoClip() async {
    if (kIsWeb) {
      // NOTE: Original code calls _generateAndShareStatic(false),
      // which is retained here.
      return _generateAndShareStatic(false);
    }

    setState(() => _isGenerating = true);
    // NOTE: Replace these API calls with your actual loading UI logic
    // isIOSPlatform ? Api().showIosLoading(context) : Api().showLoading(context);
    Api().showLoading(context); // Using a single loading call placeholder

    final directory = await getTemporaryDirectory();
    final startSeconds = _getLiveStartSeconds();
    final duration = _clipDurationSeconds.toInt();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Define temporary file paths
    final tempDir = "${directory.path}/ffmpeg_share_$now";
    await Directory(tempDir).create(recursive: true);

    final String tempVisualPath = '$tempDir/visual_loop.mp4';
    final String tempAudioClipPath = '$tempDir/audio_clip.aac';
    final String finalVideoPath = '$tempDir/final_clip_$now.mp4';
    String appLink =
        "$_appDomain/song?url=${Uri.encodeComponent(widget.songUrl)}&song=${Uri.encodeComponent(widget.songName)}&artist=${Uri.encodeComponent(widget.artistName)}";

    String message =
        "🎵 ${widget.songName} - ${widget.artistName}\n\nTap to listen in DANKIE:\n$appLink";

    try {
      // 1. GET REAL FILE
      File sourceFile = await DefaultCacheManager().getSingleFile(
        widget.songUrl,
      );
      String sourceFilePath = sourceFile.path;
      debugPrint("✅ Source file ready at: $sourceFilePath");

      // 2. Capture Visual
      final imageBytes = await _screenshotController.captureFromWidget(
        ShareCardGenerator(
          songName: widget.songName,
          artistName: widget.artistName,
          appLogoPath: "assets/dankie_logo.PNG",
        ),
        delay: const Duration(
          milliseconds: 50,
        ), // Increased delay slightly for safety
      );
      final String tempPngPath = '$tempDir/frame.png';
      await File(tempPngPath).writeAsBytes(imageBytes);

      // --- FFmpeg COMMAND EXECUTION ---

      // 3. Command 1: Cut the Audio
      String audioCmd =
          "-y -i \"$sourceFilePath\" -ss $startSeconds -t $duration -c:a aac -b:a 128k -map 0:a? \"$tempAudioClipPath\"";

      Session audioSession = await FFmpegKit.execute(audioCmd);
      if (!ReturnCode.isSuccess(await audioSession.getReturnCode())) {
        // Detailed error logging
        final logs = await audioSession.getLogsAsString();
        throw Exception("Audio Cut Failed. Logs: $logs");
      }

      // 4. Command 2: Generate Visual Video (WITH ANIMATED WAVEFORM)
      String visualCmd =
          "-y "
          "-loop 1 -i \"$tempPngPath\" " // Input 0: Background Image
          "-i \"$tempAudioClipPath\" " // Input 1: Audio (Used to generate waves)
          "-filter_complex \""
          // A. Generate Waveform from Input 1 (Audio)
          "[1:a]showwaves=s=600x300:mode=cline:colors=white@0.9[waves];"
          // B. Scale Background Image from Input 0
          "[0:v]scale=trunc(iw/2)*2:trunc(ih/2)*2[bg];"
          // C. Overlay Waves on Background
          "[bg][waves]overlay=(W-w)/2:H-h-410:shortest=1[video_out]"
          "\" "
          "-map \"[video_out]\" "
          // 🔥 FIX IS HERE: Changed -c:v libx264 to -c:v mpeg4 🔥
          "-t $duration -c:v mpeg4 -q:v 3 -pix_fmt yuv420p -r 24 \"$tempVisualPath\"";

      Session visualSession = await FFmpegKit.execute(visualCmd);
      if (!ReturnCode.isSuccess(await visualSession.getReturnCode())) {
        final logs = await visualSession.getLogsAsString();
        throw Exception("Visual Gen Failed. Logs: $logs");
      }

      // 5. Command 3: Mux Audio and Video
      String muxCmd =
          "-y -i \"$tempVisualPath\" -i \"$tempAudioClipPath\" -c:v copy -c:a aac -shortest \"$finalVideoPath\"";

      Session muxSession = await FFmpegKit.execute(muxCmd);
      if (!ReturnCode.isSuccess(await muxSession.getReturnCode())) {
        final logs = await muxSession.getLogsAsString();
        throw Exception("Muxing Failed. Logs: $logs");
      }

      // 6. Share
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Close the loading dialog
      Navigator.pop(context);

      final xFile = XFile(finalVideoPath);
      await Share.shareXFiles([xFile], text: message);
    } catch (e) {
      debugPrint("⛔️ VIDEO ERROR: $e");

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Video generation failed. Sharing link only."),
        ),
      );

      // Ensure loading dialog is closed if it's open
      try {
        Navigator.pop(context);
      } catch (_) {}

      // Fallback
      await Share.share(message);
    } finally {
      final loadingPopped = _isGenerating;

      try {
        // Clean up temporary directory
        await Directory(tempDir).delete(recursive: true);
      } catch (_) {}

      if (mounted) {
        setState(() => _isGenerating = false);
        // Only pop the bottom sheet if we didn't pop the loading dialog already
        // and we are not in the loading state anymore.
        if (loadingPopped) {
          Navigator.pop(context); // Close the sheet
        }
      }
    }
  }

  // Fallback static share logic for web or errors
  Future<void> _generateAndShareStatic(bool isStatus) async {
    setState(() => _isGenerating = true);

    try {
      final appLink =
          "$_appDomain/music?url=${Uri.encodeComponent(widget.songUrl)}";
      final message =
          "🎵 ${widget.songName} - ${widget.artistName}\n\nListen here: $appLink";

      if (kIsWeb) {
        await Share.share(message);
      } else {
        final directory = (await getApplicationDocumentsDirectory()).path;
        String path = '$directory/ttact_share.png';

        final imageBytes = await _screenshotController.captureFromWidget(
          ShareCardGenerator(
            songName: widget.songName,
            artistName: widget.artistName,
            appLogoPath: "assets/dankie_logo.PNG",
          ),
          delay: const Duration(milliseconds: 10),
        );

        File(path).writeAsBytesSync(imageBytes);
        await Share.shareXFiles([XFile(path)], text: message);
      }
    } catch (e) {
      debugPrint("Static Share Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        Navigator.pop(context);
      }
    }
  }

  void _copyDeepLink() {
    String appLink =
        "$_appDomain/music?url=${Uri.encodeComponent(widget.songUrl)}";

    Clipboard.setData(ClipboardData(text: appLink));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb ? "Link copied to clipboard!" : "Clickable App Link Copied!",
        ),
        backgroundColor: Colors.green,
      ),
    );
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
          const SizedBox(height: 20),
          Text(
            "Share to",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: widget.theme.hintColor,
            ),
          ),
          const SizedBox(height: 20),

          // ⭐️ NEW: CLIP DURATION SLIDER ⭐️
          if (!kIsWeb) ...[
            Text(
              "Clip Duration: ${_clipDurationSeconds.toInt()} seconds",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: widget.theme.primaryColor,
              ),
            ),
            Slider(
              min: 5.0,
              max: 60.0,
              divisions: 11, // 5, 10, 15, 20, ... 60 (increments of 5)
              value: _clipDurationSeconds,
              label: "${_clipDurationSeconds.toInt()}s",
              activeColor: widget.theme.primaryColor,
              onChanged: (value) {
                setState(() {
                  _clipDurationSeconds = value;
                });
              },
            ),
            const SizedBox(height: 20),
          ],

          // --- SHARE ICONS ROW ---
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // WhatsApp options (Video Share) - Mobile Only
                if (!kIsWeb) ...[
                  _buildShareIcon(
                    icon: FontAwesomeIcons.whatsapp,
                    color: Colors.white,
                    bg: const Color(0xFF25D366),
                    label: "Video Status",
                    onTap: _isGenerating ? () {} : _generateAndShareVideoClip,
                  ),
                  const SizedBox(width: 20),

                  _buildShareIcon(
                    icon: FontAwesomeIcons.whatsapp,
                    color: Colors.white,
                    bg: const Color(0xFF25D366),
                    label: "WhatsApp Chat",
                    onTap: _isGenerating ? () {} : _generateAndShareVideoClip,
                  ),
                  const SizedBox(width: 20),
                ],

                // Copy Link
                _buildShareIcon(
                  icon: Icons.link,
                  color: Colors.white,
                  bg: Colors.blue,
                  label: "Copy Link",
                  onTap: _copyDeepLink,
                ),
                const SizedBox(width: 20),

                // Web/General Share options (Fallback to static/text)
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Footer logic moved to inside generation methods (snackbars)
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

// NOTE: You will need to make sure your actual `ttact/Components/API.dart` 
// and `ttact/Components/Share_Card_Generator.dart` files are in place 
// for this code to compile successfully.
// The `Api()` calls for loading are placeholders that need your implementation.