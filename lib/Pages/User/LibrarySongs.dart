import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/MusicPlayerSheet.dart';
import 'package:ttact/Components/Tabs/MusicTab.dart';
import 'package:ttact/Pages/User/HomePage.dart';
import 'package:ttact/main.dart';

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class LibrarySongs extends StatefulWidget {
  const LibrarySongs({super.key});

  @override
  State<LibrarySongs> createState() => _LibrarySongsState();
}

class _LibrarySongsState extends State<LibrarySongs> {
  List<Map<String, dynamic>> _librarySongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final songs = await LibraryHelper.getLibrarySongs();
    if (mounted) {
      setState(() {
        _librarySongs = songs;
        _isLoading = false;
      });
    }
  }

  void _removeFromLibrary(String songId) async {
    await LibraryHelper.removeFromLibrary(songId);
    _loadLibrary();
  }

  // --- UPDATED: Play Song and Show Player Sheet ---
  void _playLibrarySong(int index) async {
    if (_librarySongs.isEmpty || audioHandler == null) return;

    final song = _librarySongs[index];
    final color = Theme.of(context);

    // 1. Create MediaItem
    final mediaItem = MediaItem(
      id: song['songUrl'] ?? '',
      title: song['songName'] ?? 'Untitled',
      artist: song['artist'] ?? 'Unknown',
      artUri: Uri.parse(
        "https://firebasestorage.googleapis.com/v0/b/tact-3c612.firebasestorage.app/o/App%20Logo%2Fdankie_logo.PNG?alt=media&token=fb3a28a9-ab50-43f0-bee1-eecb34e5f394",
      ),
    );

    // 2. Load into Audio Handler
    await audioHandler!.loadPlaylist([mediaItem], 0);

    // 3. Show the Music Player Sheet
    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MusicPlayerSheet(
          themeColor: color,
          onDownload: (url, title, artist) {
            // You can add download logic here if needed,
            // or pass a dummy function if downloaded songs are handled elsewhere
            print("Download from library: $title");
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return Scaffold(
      appBar: isIOSPlatform
          ? CupertinoNavigationBar(
              middle: const Text("My Library"),
              backgroundColor: color.primaryColor,
            )
          : AppBar(
                  backgroundColor: color.primaryColor,
                  foregroundColor: color.scaffoldBackgroundColor,
                  title: const Text("My Library"),
                  centerTitle: true,
                )
                as PreferredSizeWidget,
      body: _isLoading
          ? Center(
              child: isIOSPlatform
                  ? const CupertinoActivityIndicator()
                  : CircularProgressIndicator(color: color.primaryColor),
            )
          : _librarySongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIOSPlatform
                        ? CupertinoIcons.music_albums
                        : Icons.library_music_outlined,
                    size: 80,
                    color: color.hintColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Your library is empty",
                    style: TextStyle(color: color.hintColor),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _librarySongs.length,
              itemBuilder: (context, index) {
                final song = _librarySongs[index];
                final songName = song['songName'] ?? 'Untitled';
                final artist = song['artist'] ?? 'Unknown Artist';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        width: 1.5,
                        color: color.hintColor.withOpacity(0.5),
                      ),
                    ),
                    child: ListTile(
                      onTap: () => _playLibrarySong(index),
                      leading: Container(
                        height: 50,
                        width: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            "assets/dankie_logo.PNG",
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      title: Text(
                        songName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        artist,
                        style: TextStyle(color: color.hintColor),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isIOSPlatform
                              ? CupertinoIcons.delete
                              : Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          _removeFromLibrary(song['songUrl'] ?? songName);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
