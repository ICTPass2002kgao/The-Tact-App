// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/HomePageHelpers.dart'; // For isIOSPlatform
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/Share_Song.dart' hide isIOSPlatform;
import 'package:ttact/Components/TickTok_Share.dart';
import 'package:ttact/main.dart'; // For global audioHandler

class MusicPlayerSheet extends StatefulWidget {
  final ThemeData themeColor;
  final Function(String url, String title, String artist) onDownload;

  const MusicPlayerSheet({
    Key? key,
    required this.themeColor,
    required this.onDownload,
  }) : super(key: key);

  @override
  State<MusicPlayerSheet> createState() => _MusicPlayerSheetState();
}

class _MusicPlayerSheetState extends State<MusicPlayerSheet>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;

  // Player State
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  // Subscriptions
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;

  // Library State
  bool _isSongInLibrary = false;

  // Ad Logic
  static int _nextBtnClickCount = 0;
  final int _adThreshold = 5;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // Listen for Duration & Library Status
    _durationSubscription = audioHandler?.mediaItem.listen((mediaItem) {
      final newDuration = mediaItem?.duration ?? Duration.zero;
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
        if (mediaItem != null) {
          _checkLibraryStatus(mediaItem.id);
        }
      }
    });

    // Listen for Position
    _positionSubscription = AudioService.position.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });

    // Listen for Playback State (Animation)
    _playerCompleteSubscription = audioHandler?.playbackState.listen((state) {
      if (mounted) {
        if (state.playing &&
            state.processingState != AudioProcessingState.loading) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _checkLibraryStatus(String songId) async {
    bool exists = await LibraryHelper.isSongInLibrary(songId);
    if (mounted) setState(() => _isSongInLibrary = exists);
  }

  Future<void> _toggleLibrary() async {
    final mediaItem = audioHandler?.mediaItem.value;
    if (mediaItem == null) return;

    if (_isSongInLibrary) {
      await LibraryHelper.removeFromLibrary(mediaItem.id);
      if (mounted) {
        setState(() => _isSongInLibrary = false);
        Api().showMessage(
          context,
          "Removed from Library",
          "Success",
          Colors.red,
        );
      }
    } else {
      Map<String, dynamic> songMap = {
        'songName': mediaItem.title,
        'artist': mediaItem.artist,
        'songUrl': mediaItem.id,
      };
      await LibraryHelper.addToLibrary(songMap);
      if (mounted) {
        setState(() => _isSongInLibrary = true);
        Api().showMessage(context, "Added to Library", "Success", Colors.green);
      }
    }
  }

  void _handleNextPress() {
    _nextBtnClickCount++;
    if (_nextBtnClickCount >= _adThreshold) {
      if (!kIsWeb) {
        AdManager().showRewardedInterstitialAd(
          (ad, reward) {
            audioHandler?.skipToNext();
            _nextBtnClickCount = 0;
          },
          onAdFailed: () {
            audioHandler?.skipToNext();
            _nextBtnClickCount = 0;
          },
        );
      } else {
        audioHandler?.skipToNext();
        _nextBtnClickCount = 0;
      }
    } else {
      audioHandler?.skipToNext();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _buildSeekBar() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: widget.themeColor.hintColor,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: isIOSPlatform
                    ? CupertinoSlider(
                        activeColor: widget.themeColor.primaryColor,
                        min: 0.0,
                        max: _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0,
                        value: _position.inSeconds.toDouble().clamp(
                          0.0,
                          (_duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1.0),
                        ),
                        onChanged: (value) {
                          audioHandler?.seek(Duration(seconds: value.toInt()));
                        },
                      )
                    : Slider(
                        activeColor: widget.themeColor.primaryColor,
                        inactiveColor: widget.themeColor.hintColor.withOpacity(
                          0.3,
                        ),
                        thumbColor: widget.themeColor.primaryColor,
                        min: 0.0,
                        max: _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0,
                        value: _position.inSeconds.toDouble().clamp(
                          0.0,
                          (_duration.inSeconds.toDouble() > 0
                              ? _duration.inSeconds.toDouble()
                              : 1.0),
                        ),
                        onChanged: (value) {
                          audioHandler?.seek(Duration(seconds: value.toInt()));
                        },
                      ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  color: widget.themeColor.hintColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBtn({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 30,
    Color? color,
  }) {
    final c = color ?? widget.themeColor.primaryColor;
    return isIOSPlatform
        ? CupertinoButton(
            padding: EdgeInsets.zero,
            child: Icon(icon, size: size, color: c),
            onPressed: onPressed,
          )
        : IconButton(
            icon: Icon(icon, size: size, color: c),
            onPressed: onPressed,
          );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: widget.themeColor.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: StreamBuilder<MediaItem?>(
            stream: audioHandler?.mediaItem,
            builder: (context, mediaItemSnapshot) {
              final mediaItem = mediaItemSnapshot.data;

              if (mediaItem == null) {
                return SizedBox(
                  height: 300,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: widget.themeColor.primaryColor,
                    ),
                  ),
                );
              }

              return StreamBuilder<PlaybackState>(
                stream: audioHandler?.playbackState,
                builder: (context, playbackStateSnapshot) {
                  final playbackState = playbackStateSnapshot.data;
                  final isPlaying = playbackState?.playing ?? false;
                  final shuffleMode =
                      playbackState?.shuffleMode ??
                      AudioServiceShuffleMode.none;
                  final repeatMode =
                      playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 4,
                          decoration: BoxDecoration(
                            color: widget.themeColor.hintColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      RotationTransition(
                        turns: Tween(
                          begin: 0.0,
                          end: 1.0,
                        ).animate(_rotationController),
                        child: Center(
                          child: Container(
                            height: 200,
                            width: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: widget.themeColor.primaryColor,
                                width: 4,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.asset(
                                "assets/dankie_logo.PNG",
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mediaItem.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  mediaItem.artist ?? 'Unknown Artist',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: widget.themeColor.hintColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  isIOSPlatform
                                      ? CupertinoIcons.cloud_download
                                      : Icons.download_rounded,
                                  color: widget.themeColor.primaryColor,
                                ),
                                onPressed: () {
                                  widget.onDownload(
                                    mediaItem.id,
                                    mediaItem.title,
                                    mediaItem.artist ?? 'Unknown',
                                  );
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  _isSongInLibrary
                                      ? (isIOSPlatform
                                            ? CupertinoIcons.bookmark_solid
                                            : Icons.bookmark)
                                      : (isIOSPlatform
                                            ? CupertinoIcons.bookmark
                                            : Icons.bookmark_border),
                                  color: widget.themeColor.primaryColor,
                                ),
                                onPressed: _toggleLibrary,
                              ),
                              IconButton(
                                icon: Icon(
                                  color: widget.themeColor.primaryColor,
                                  isIOSPlatform
                                      ? CupertinoIcons.share
                                      : Icons.share,
                                ),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => TikTokShareSheet(
                                      songName: mediaItem.title,
                                      artistName: mediaItem.artist ?? "Unknown",
                                      songUrl: mediaItem.id,
                                      theme: widget.themeColor,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildSeekBar(),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.shuffle
                                : Icons.shuffle,
                            color: shuffleMode == AudioServiceShuffleMode.all
                                ? widget.themeColor.primaryColor
                                : widget.themeColor.hintColor,
                            onPressed: () {
                              final newMode =
                                  shuffleMode == AudioServiceShuffleMode.all
                                  ? AudioServiceShuffleMode.none
                                  : AudioServiceShuffleMode.all;
                              audioHandler?.setShuffleMode(newMode);
                            },
                          ),
                          _buildBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.backward_fill
                                : Icons.skip_previous,
                            size: 40,
                            onPressed: () => audioHandler?.skipToPrevious(),
                          ),
                          _buildBtn(
                            icon: isPlaying
                                ? (isIOSPlatform
                                      ? CupertinoIcons.pause_circle_fill
                                      : Icons.pause_circle_filled)
                                : (isIOSPlatform
                                      ? CupertinoIcons.play_circle_fill
                                      : Icons.play_circle_filled),
                            size: 70,
                            color: widget.themeColor.primaryColor,
                            onPressed: isPlaying
                                ? () => audioHandler?.pause()
                                : () => audioHandler?.play(),
                          ),
                          _buildBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.forward_fill
                                : Icons.skip_next,
                            size: 40,
                            onPressed: _handleNextPress,
                          ),
                          _buildBtn(
                            icon: repeatMode == AudioServiceRepeatMode.one
                                ? (isIOSPlatform
                                      ? CupertinoIcons.repeat_1
                                      : Icons.repeat_one)
                                : (isIOSPlatform
                                      ? CupertinoIcons.repeat
                                      : Icons.repeat),
                            color: repeatMode != AudioServiceRepeatMode.none
                                ? widget.themeColor.primaryColor
                                : widget.themeColor.hintColor,
                            onPressed: () {
                              final newMode =
                                  repeatMode == AudioServiceRepeatMode.none
                                  ? AudioServiceRepeatMode.all
                                  : (repeatMode == AudioServiceRepeatMode.all
                                        ? AudioServiceRepeatMode.one
                                        : AudioServiceRepeatMode.none);
                              audioHandler?.setRepeatMode(newMode);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
