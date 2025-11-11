import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'song.dart';

class PlaySong extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final int initialIndex;
  // Flag to indicate if the player is used standalone (e.g., in a desktop column)
  final bool isStandalone;

  const PlaySong({
    super.key,
    required this.songs,
    required this.initialIndex,
    this.isStandalone = false,
  });

  @override
  State<PlaySong> createState() => _PlaySongState();
}

class _PlaySongState extends State<PlaySong> {
  int _currentPlaylistIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final LocalStorageService _storage = LocalStorageService();
  final AudioPlayerService _playerService = AudioPlayerService();

  @override
  void initState() {
    super.initState();
    _currentPlaylistIndex = widget.initialIndex;

    _playerService.audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _playerService.audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _playerService.audioPlayer.onPlayerComplete.listen((event) {
      _playNext();
    });

    _playSong();
  }

  // >>> FIX: Use didUpdateWidget to detect song changes from the parent <<<
  @override
  void didUpdateWidget(covariant PlaySong oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if the song index provided by the parent has changed
    if (widget.initialIndex != oldWidget.initialIndex) {
      setState(() {
        _currentPlaylistIndex = widget.initialIndex;
      });
      // Force the new song to load and play
      _playSong();
    }
  }

  bool isPlaying = false;

  Future<void> _playSong() async {
    final songUrl = widget.songs[_currentPlaylistIndex]['songUrl'];

    if (songUrl != null) {
      // The _playerService.play() method should handle stopping the old source and playing the new one.
      await _playerService.play(songUrl);

      if (mounted) {
        setState(() {
          isPlaying = true;
          _position = Duration.zero;
        });
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
    if (_currentPlaylistIndex < widget.songs.length - 1) {
      setState(() {
        _currentPlaylistIndex++;
      });
      await _playSong();
    } else {
      // Handle end of playlist: stop playing
      await _playerService.stop();
      if (mounted) {
        setState(() {
          isPlaying = false;
          _position = Duration.zero;
        });
      }
    }
  }

  void _playPrevious() async {
    if (_currentPlaylistIndex > 0) {
      setState(() {
        _currentPlaylistIndex--;
      });
      await _playSong();
    } else {
      // Handle beginning of playlist: stop playing
      await _playerService.stop();
      if (mounted) {
        setState(() {
          isPlaying = false;
          _position = Duration.zero;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildContent(ThemeData color) {
    final song = Song.fromMap(widget.songs[_currentPlaylistIndex]);

    return SingleChildScrollView(
      // Only add padding if NOT standalone (mobile sheet)
      padding: widget.isStandalone
          ? EdgeInsets.zero
          : const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Aligns content to the start (top) on desktop, which is pushed down by the Align widget in HomePage
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Mobile 'Cancel' Button (Removed for Desktop/Standalone)
          if (!widget.isStandalone)
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

          if (!widget.isStandalone) SizedBox(height: 20),

          Center(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(35),
              ),
              elevation: 15,
              color: Colors.transparent,
              child: Container(
                // Smaller size for desktop player column
                width: widget.isStandalone ? 200 : 300,
                height: widget.isStandalone ? 200 : 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(35),
                  color: color.primaryColor.withOpacity(0.9),
                ),
                child: Center(
                  child: Icon(
                    Ionicons.musical_notes,
                    color: color.scaffoldBackgroundColor,
                    size: widget.isStandalone ? 100 : 140,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: widget.isStandalone ? 15 : 20),

          Padding(
            padding: EdgeInsets.all(widget.isStandalone ? 0.0 : 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isStandalone)
                  Text(
                    'Now Playing',
                    style: TextStyle(
                      color: color.primaryColor,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (!widget.isStandalone) SizedBox(height: 10),

                // Song Title and Actions Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.songName,
                            maxLines: widget.isStandalone ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: widget.isStandalone ? 15 : 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'By ${song.artist}',
                            style: TextStyle(
                              fontSize: widget.isStandalone ? 13 : 15,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons (Condensed for desktop)
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            await _storage.downloadSong(song);
                            if (!widget.isStandalone) {
                              Api().showMessage(
                                context,
                                'Downloaded!',
                                '',
                                color.splashColor,
                              );
                            }
                          },
                          icon: Icon(
                            Icons.download_outlined,
                            size: widget.isStandalone ? 25 : 30,
                            color: color.primaryColor,
                          ),
                        ),
                        // Only show share/playlist on mobile
                        if (!widget.isStandalone) ...[
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
                      ],
                    ),
                  ],
                ),
                SizedBox(height: widget.isStandalone ? 15 : 20),

                // Player Controls Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(35),
                  ),
                  elevation: 15,
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: color.primaryColor.withOpacity(0.9),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          // Seek Bar
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

                          // Play/Pause/Skip Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                onPressed: _playPrevious,
                                icon: Icon(
                                  Icons.skip_previous,
                                  color: color.scaffoldBackgroundColor,
                                  size: widget.isStandalone ? 50 : 70,
                                ),
                              ),
                              IconButton(
                                onPressed: _togglePlayPause,
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: color.scaffoldBackgroundColor,
                                  size: widget.isStandalone ? 50 : 70,
                                ),
                              ),
                              IconButton(
                                onPressed: _playNext,
                                icon: Icon(
                                  Icons.skip_next,
                                  color: color.scaffoldBackgroundColor,
                                  size: widget.isStandalone ? 50 : 70,
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
          if (!widget.isStandalone) Text(''),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    if (widget.isStandalone) {
      return _buildContent(color);
    }

    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: _buildContent(color),
    );
  }

  @override
  void dispose() {
    // Keep this section clean unless you explicitly want the player service managed here.
    super.dispose();
  }
}
