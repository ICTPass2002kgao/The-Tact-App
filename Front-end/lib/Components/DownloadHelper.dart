import 'dart:io';

import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/universal_html.dart' as html;
import 'package:universal_io/io.dart'; // Replaces dart:io 
import 'package:http/http.dart' as http;

class DownloadHelper {
  
  static Future<void> downloadSong({
    required String url,
    required String title,
    required String artist,
    required Function(String message, bool isError) onStatus,
  }) async {
    
    try {
      onStatus("Starting download...", false);

      // 1. Clean the filename
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final filename = '${safeTitle}_${safeArtist}.mp3';

      // 2. Fetch the file bytes (Common for both)
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception("Failed to download file: Server responded ${response.statusCode}");
      }
      final bytes = response.bodyBytes;

      // --- WEB LOGIC ---
      if (kIsWeb) {
        // On Web, we create a "Blob" and force the browser to download it
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download", filename)
          ..click();
        html.Url.revokeObjectUrl(url);
        
        onStatus("Download started. Check your browser downloads.", false);
      } 
      
      // --- MOBILE LOGIC ---
      else {
        // On Mobile, we save to the App Documents for the Offline Player
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$filename');
        
        await file.writeAsBytes(bytes);
        onStatus("Saved to Library for Offline Play", false);
      }

    } catch (e) {
      print("Download Error: $e");
      onStatus("Download failed: ${e.toString()}", true);
    }
  }
}