 import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'song.dart';

class PlaySong extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialIndex;

  const PlaySong({super.key, required this.songs, required this.initialIndex});

  @override
  State<PlaySong> createState() => _PlaySongState();
}

class _PlaySongState extends State<PlaySong> { // This variable is declared but not used, consider removing it if not needed.
  int _currentIndex = 0;
   Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

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

  bool isPlaying =
      false; // This 'isPlaying' is used more consistently in the UI logic.
  Future<void> _playSong() async {
    final songUrl = widget.songs[_currentIndex]['songUrl'];
    if (songUrl != null) {
      await _playerService.play(songUrl);
      setState(() {
        isPlaying = true; // Keep consistent with both _isPlaying and isPlaying
      });
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
    // Made async because _playSong() is async
    if (_currentIndex < widget.songs.length - 1) {
      setState(() {
        _currentIndex++;
      });
      await _playSong(); // <--- This is the crucial change
    } else {
      // Optional: Handle end of playlist, e.g., loop back to the beginning or stop
      // For now, it will just stop playing when it reaches the end.
      setState(() {
        isPlaying = false; 
      });
      await _playerService.pause(); // Stop playback at the end of the playlist
    }
  }

  void _playPrevious() async {
    // Made async because _playSong() is async
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      await _playSong(); // <--- This is also crucial for previous song
    } else {
      // Optional: Handle beginning of playlist, e.g., loop to the end or stop
      // For now, it will just stop playing when it reaches the beginning.
      setState(() {
        isPlaying = false; 
      });
      await _playerService
          .pause(); // Stop playback at the beginning of the playlist
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

    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
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
              ],
            ),
            Center(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(35),
                ),
                elevation: 15,
                color: Colors.transparent,
                child: Container(
                  width: 300,
                  height: 300,
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
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'By ${song.artist}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await _storage.downloadSong(song);
                              Api().showMessage(
                                context,
                                'Downloaded!',
                                '',
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
                  SizedBox(height: 20),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(35),
                    ),
                    elevation: 15,
                    color: Colors.transparent,
                    child: Container(
                      // height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: color.primaryColor.withOpacity(0.9),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Text(
                                    _formatDuration(_position),
                                    style: TextStyle(
                                      color: color.scaffoldBackgroundColor,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      activeColor: color.primaryColor,
                                      inactiveColor: Colors.grey,
                                      thumbColor: color.scaffoldBackgroundColor,
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
                                      color: color.scaffoldBackgroundColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                IconButton(
                                  onPressed: _playPrevious,
                                  icon: Icon(
                                    Icons.skip_previous,
                                    color: color.scaffoldBackgroundColor,
                                    size: 70,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _togglePlayPause,
                                  icon: Icon(
                                    // Simplified logic for play/pause icon
                                    isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: color.scaffoldBackgroundColor,
                                    size: 70,
                                  ),
                                ),
                                IconButton(
                                  onPressed: _playNext,
                                  icon: Icon(
                                    Icons.skip_next,
                                    color: color.scaffoldBackgroundColor,
                                    size: 70,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                          ],
                        ),
                      ),          
                    ),
                  ),
                ],
              ),
            ),
            Text(''),
          ],
        ),
      ),
    );
  }
}