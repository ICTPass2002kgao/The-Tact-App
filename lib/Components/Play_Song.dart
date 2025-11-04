// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'song.dart';

// Import foundation for kIsWeb check
import 'package:flutter/foundation.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 600.0;
// --------------------------

class PlaySong extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialIndex;

  const PlaySong({super.key, required this.songs, required this.initialIndex});

  @override
  State<PlaySong> createState() => _PlaySongState();
}

class _PlaySongState extends State<PlaySong> {
  int _currentIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Assuming LocalStorageService and AudioPlayerService are properly defined
  final LocalStorageService _storage = LocalStorageService();
  final AudioPlayerService _playerService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    _playerService.audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    _playerService.audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });

    _playerService.audioPlayer.onPlayerComplete.listen((event) {
      _playNext();
    });

    _playSong();
  }

  bool isPlaying = false;

  @override
  void dispose() {
    // Ensure the player is stopped when the page/modal is disposed
    _playerService.pause();
    super.dispose();
  }

  // FIX: Added robust try-catch block to handle PlatformExceptions (like WebAudioError)
  Future<void> _playSong() async {
    final songUrl = widget.songs[_currentIndex]['songUrl'];
    if (songUrl != null) {
      try {
        await _playerService.play(songUrl);
        setState(() {
          isPlaying = true;
        });
      } catch (e) {
        // Handle the error gracefully without breaking the app
        setState(() {
          isPlaying = false;
        });

        // Provide user feedback about the failure
        Api().showMessage(
          context,
          'Playback Failed',
          'The audio file could not be played. This might be a file format issue, especially on the web.',
          Colors.red,
        );
        print('Playback error caught: $e');
      }
    }
  }

  void _togglePlayPause() async {
    if (_playerService.isPlaying) {
      await _playerService.pause();
      setState(() {
        isPlaying = false;
      });
    } else {
      await _playerService.resume();
      setState(() {
        isPlaying = true;
      });
    }
  }

  void _seekTo(double seconds) {
    final newPosition = Duration(seconds: seconds.toInt());
    _playerService.audioPlayer.seek(newPosition);
  }

  void _playNext() async {
    if (_currentIndex < widget.songs.length - 1) {
      setState(() {
        _currentIndex++;
      });
      await _playSong();
    } else {
      setState(() {
        isPlaying = false;
      });
      await _playerService.pause();
    }
  }

  void _playPrevious() async {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      await _playSong();
    } else {
      setState(() {
        isPlaying = false;
      });
      await _playerService.pause();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final song = Song.fromMap(widget.songs[_currentIndex]);
    final isDesktop =
        !kIsWeb && MediaQuery.of(context).size.width > _desktopContentMaxWidth;

    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      // FIX: Center and constrain content for web/desktop
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _desktopContentMaxWidth,
            maxHeight: isDesktop ? 800 : double.infinity,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Increased padding
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel Button
                      GestureDetector(
                        onTap: () {
                          _playerService.pause();
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: color.primaryColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      // Downloaded Songs Button (can be accessed here for convenience)
                      IconButton(
                        onPressed: () {
                          Api().showMessage(
                            context,
                            "Access Downloaded Songs",
                            "Use the main menu to access your downloads.",
                            Colors.blue,
                          );
                        },
                        icon: Icon(Icons.library_music, color: color.hintColor),
                        tooltip: 'Downloaded Songs',
                      ),
                    ],
                  ),
                  SizedBox(height: 20),

                  // 1. Player Art Card (Responsive Sizing)
                  Center(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(35),
                      ),
                      elevation: 15,
                      color: Colors.transparent,
                      child: Container(
                        // FIX: Use responsive width, max 300
                        width: isDesktop
                            ? 300
                            : MediaQuery.of(context).size.width * 0.7,
                        height: isDesktop
                            ? 300
                            : MediaQuery.of(context).size.width * 0.7,
                        constraints: BoxConstraints(
                          maxWidth: 350,
                          maxHeight: 350,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35),
                          color: color.primaryColor.withOpacity(0.9),
                        ),
                        child: Center(
                          child: Icon(
                            Ionicons.musical_notes,
                            color: color.scaffoldBackgroundColor,
                            size: 140,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),

                  // 2. Song Info and Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Now Playing',
                          style: TextStyle(
                            color: color.primaryColor,
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 10),

                        // Title, Artist, and Utility Icons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.songName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize:
                                          24, // Increased size for desktop
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'By ${song.artist}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Action Icons Group
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    await _storage.downloadSong(song);
                                    Api().showMessage(
                                      context,
                                      'Downloaded!',
                                      'Song saved locally.',
                                      color.splashColor,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.download_outlined,
                                    size: 30,
                                    color: color.primaryColor,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await _storage.saveToPlaylist(song);
                                    Api().showMessage(
                                      context,
                                      "Song added to playlist",
                                      '',
                                      color.splashColor,
                                    );
                                  },
                                  icon: Icon(
                                    Icons.playlist_add,
                                    color: color.primaryColor,
                                    size: 39,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    // Share song URL, this is platform safe
                                    Share.share(
                                      'Check out this song: ${song.songUrl}',
                                    );
                                  },
                                  icon: Icon(
                                    Ionicons.share_outline,
                                    color: color.primaryColor,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 30),

                        // 3. Playback Controls Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              30,
                            ), // Slightly reduced rounding for sleekness
                          ),
                          elevation: 10, // Slightly reduced elevation
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: color.primaryColor.withOpacity(0.9),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(
                                12.0,
                              ), // Increased padding
                              child: Column(
                                children: [
                                  // Slider and Timestamps
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4.0,
                                      vertical: 8.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _formatDuration(_position),
                                          style: TextStyle(
                                            color:
                                                color.scaffoldBackgroundColor,
                                          ),
                                        ),
                                        Expanded(
                                          child: Slider(
                                            activeColor: color
                                                .scaffoldBackgroundColor, // Use scaffold color for active track
                                            inactiveColor: color
                                                .scaffoldBackgroundColor
                                                .withOpacity(0.5),
                                            thumbColor:
                                                color.scaffoldBackgroundColor,
                                            min: 0,
                                            max: _duration.inSeconds.toDouble(),
                                            value: _position.inSeconds
                                                .clamp(0, _duration.inSeconds)
                                                .toDouble(),
                                            onChanged: (value) {
                                              _seekTo(value);
                                            },
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(_duration),
                                          style: TextStyle(
                                            color:
                                                color.scaffoldBackgroundColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Navigation Buttons
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      IconButton(
                                        onPressed: _playPrevious,
                                        icon: Icon(
                                          Icons.skip_previous,
                                          color: color.scaffoldBackgroundColor,
                                          size:
                                              60, // Slightly smaller for better control contrast
                                        ),
                                        tooltip: 'Previous Song',
                                      ),
                                      IconButton(
                                        onPressed: _togglePlayPause,
                                        icon: Icon(
                                          isPlaying
                                              ? Icons.pause_circle_filled
                                              : Icons
                                                    .play_circle_filled, // Using filled icons for a modern look
                                          color: color.scaffoldBackgroundColor,
                                          size: 80, // Large main control icon
                                        ),
                                        tooltip: isPlaying ? 'Pause' : 'Play',
                                      ),
                                      IconButton(
                                        onPressed: _playNext,
                                        icon: Icon(
                                          Icons.skip_next,
                                          color: color.scaffoldBackgroundColor,
                                          size: 60,
                                        ),
                                        tooltip: 'Next Song',
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ), // Reduced bottom spacing
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
