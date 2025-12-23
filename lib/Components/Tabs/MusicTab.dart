// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ttact/Components/AdBanner.dart' hide isAndroidPlatform;
import 'package:ttact/Components/HomePageHelpers.dart'; // Import helpers
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/MusicPlayerSheet.dart'; 
import 'package:ttact/Pages/User/Downloaded_Songs.dart' hide isIOSPlatform;
import 'package:ttact/Pages/User/LibrarySongs.dart' hide isIOSPlatform;
import 'package:ttact/main.dart'; // To get audioHandler

class MusicTab extends StatefulWidget {
  final bool isDesktop;
  
  // Method needed for Deep Linking to work from HomePage
  const MusicTab({super.key, required this.isDesktop});

  @override
  State<MusicTab> createState() => MusicTabState();
}

class MusicTabState extends State<MusicTab> with TickerProviderStateMixin {
  AdManager adManager = AdManager();
  int _songPlayCount = 0;

  final TextEditingController _musicSearchController = TextEditingController();
  String _musicSearchQuery = '';
  String _selectedCategory = 'All';
  int? _selectedSongIndex;
  List<QueryDocumentSnapshot<Object?>> _currentFilteredSongs = [];
  late Future<QuerySnapshot> _musicFuture;
  late AnimationController _rotationController;
  
  // Local path
  String? _localAppPath;

  Future<void> _initLocalPath() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        _localAppPath = dir.path;
      });
    }
  }

  // --- PUBLIC METHOD FOR DEEP LINKING CALLED BY HOMEPAGE ---
  Future<void> playDeepLinkedSong(String targetUrl) async {
    try {
      QuerySnapshot snapshot = await _musicFuture;
      final allDocs = snapshot.docs;

      final validSongs = allDocs.where((doc) {
        final sData = doc.data() as Map<String, dynamic>;
        final sUrl = sData['songUrl'] as String?;
        return sUrl != null && sUrl.trim().startsWith('https://');
      }).toList();

      int foundIndex = -1;
      for (int i = 0; i < validSongs.length; i++) {
        final data = validSongs[i].data() as Map<String, dynamic>;
        if (data['songUrl'] == targetUrl) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex != -1) {
        debugPrint("✅ Deep Linked Song found at index $foundIndex. Playing...");
        setState(() {
          _selectedCategory = 'All';
          _musicSearchController.clear();
          _musicSearchQuery = '';
          _currentFilteredSongs = validSongs;
          _selectedSongIndex = foundIndex;
        });
        _handleSongPlay(foundIndex, _currentFilteredSongs, Theme.of(context));
      } else {
        showPlatformMessage(
          context,
          "Song Not Found",
          "The shared song could not be found in our library.",
          Colors.orange,
        );
      }
    } catch (e) {
      debugPrint("Error processing deep link song: $e");
      showPlatformMessage(
        context,
        "Error",
        "Failed to load song data. Please check your connection.",
        Colors.red,
      );
    }
  }

  // --- DOWNLOAD LOGIC ---
  Future<void> _downloadSong(String url, String title, String artist) async {
    if (!kIsWeb && isAndroidPlatform) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final filename = '${safeTitle}_${safeArtist}.mp3';
      final savePath = '${dir.path}/$filename';

      if (File(savePath).existsSync()) {
        showPlatformMessage(
          context,
          'Info',
          'Song already downloaded!',
          Colors.blue,
        );
        return;
      }

      showPlatformMessage(
        context,
        'Downloading',
        'Downloading $title...',
        Colors.orange,
      );

      await Dio().download(url, savePath);

      showPlatformMessage(
        context,
        'Success',
        'Song saved to library!',
        Colors.green,
      );
      setState(() {});
    } catch (e) {
      debugPrint("Download Error: $e");
      showPlatformMessage(
        context,
        'Error',
        'Failed to download. Check connection.',
        Colors.red,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
    _initLocalPath();
    _musicFuture = FirebaseFirestore.instance
        .collection('tact_music') 
        .get();

    _musicSearchController.addListener(() {
      setState(() {
        _musicSearchQuery = _musicSearchController.text;
        _selectedSongIndex = null;
      });
    });

    adManager.loadRewardedInterstitialAd();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _musicSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    if (widget.isDesktop) {
      // DESKTOP LAYOUT
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 300,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: color.hintColor.withOpacity(0.5)),
              ),
            ),
            child: _buildMusicControls(color),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildSongList(color),
            ),
          ),
          Container(
            alignment: Alignment.centerRight,
            width: 300,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              border: Border.all(color: color.primaryColor.withOpacity(0.5)),
            ),
            child: _buildDesktopPlayer(color),
          ),
        ],
      );
    } else {
      // MOBILE LAYOUT
      return Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 20),
              _buildMusicControls(color),
              SizedBox(height: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildSongList(color),
                ),
              ),
            ],
          ),
          if (!kIsWeb)
            Positioned(
              right: 10,
              bottom: 10,
              child: IconButton(
                color: color.scaffoldBackgroundColor,
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(color.splashColor),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DownloadedSongs()),
                  );
                },
                icon: Icon(Icons.download_done_outlined, size: 40),
              ),
            ),
          Positioned(
            right: kIsWeb ? 10 : 80,
            bottom: 10,
            child: IconButton(
              color: color.scaffoldBackgroundColor,
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(color.splashColor),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LibrarySongs()),
                );
              },
              icon: Icon(Icons.library_add, size: 40),
            ),
          ),
        ],
      );
    }
  }

  // --- HELPER WIDGETS ---

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildSeekBar(ThemeData color) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, playbackSnapshot) {
        final state = playbackSnapshot.data;
        final position = state?.updatePosition ?? Duration.zero;
        final duration =
            audioHandler?.mediaItem.value?.duration ?? Duration.zero;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isIOSPlatform)
              CupertinoSlider(
                value: (position.inMilliseconds > 0 &&
                        position.inMilliseconds < duration.inMilliseconds)
                    ? position.inMilliseconds.toDouble()
                    : 0.0,
                max: (duration.inMilliseconds > 0)
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) {
                  audioHandler?.seek(Duration(milliseconds: value.round()));
                },
                activeColor: color.primaryColor,
              )
            else
              Slider(
                value: (position.inMilliseconds > 0 &&
                        position.inMilliseconds < duration.inMilliseconds)
                    ? position.inMilliseconds.toDouble()
                    : 0.0,
                max: (duration.inMilliseconds > 0)
                    ? duration.inMilliseconds.toDouble()
                    : 1.0,
                onChanged: (value) {
                  audioHandler?.seek(Duration(milliseconds: value.round()));
                },
                activeColor: color.primaryColor,
                inactiveColor: color.hintColor.withOpacity(0.3),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position),
                      style: TextStyle(color: color.hintColor, fontSize: 12)),
                  Text(_formatDuration(duration),
                      style: TextStyle(color: color.hintColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMusicControls(ThemeData color) {
    final categories = [
      'All',
      'choreography',
      'Apostle choir',
      'Slow Jam',
      'Instrumental songs',
      'Evangelical Brothers Songs'
    ];

    return Column(
      mainAxisSize: widget.isDesktop ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.isDesktop ? 0 : 8.0),
          child: buildPlatformTextField(
            controller: _musicSearchController,
            placeholder: 'Search song by name or artist...',
            prefixIcon: isIOSPlatform ? CupertinoIcons.search : Icons.search,
            context: context,
          ),
        ),
        SizedBox(height: widget.isDesktop ? 30 : 10),
        widget.isDesktop
            ? Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: buildListTile(
                        context: context,
                        title: category,
                        leading: Icon(
                          isSelected
                              ? (isIOSPlatform
                                  ? CupertinoIcons.music_note_2
                                  : Ionicons.musical_notes)
                              : (isIOSPlatform
                                  ? CupertinoIcons.music_note
                                  : Ionicons.musical_notes_outline),
                          color: isSelected ? color.primaryColor : color.hintColor,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                            _selectedSongIndex = null;
                          });
                        },
                        isSelected: isSelected,
                      ),
                    );
                  },
                ),
              )
            : SizedBox(
                height: 40,
                child: DefaultTabController(
                  length: categories.length,
                  child: TabBar(
                    isScrollable: true,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: color.scaffoldBackgroundColor,
                    dividerColor: Colors.transparent,
                    indicatorColor: color.primaryColor,
                    unselectedLabelColor: color.hintColor,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: color.primaryColor,
                    ),
                    onTap: (index) {
                      setState(() {
                        _selectedCategory = categories[index];
                        _selectedSongIndex = null;
                      });
                    },
                    tabs: categories.map((c) => Tab(text: c)).toList(),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSongList(ThemeData color) {
    return FutureBuilder<QuerySnapshot>(
      future: _musicFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No songs available'));
        }

        final allSongs = snapshot.data!.docs;
        final String query = _musicSearchQuery.toLowerCase().trim();

        final filteredSongs = allSongs.where((doc) {
          final songData = doc.data() as Map<String, dynamic>;
          final String songName =
              (songData['songName'] as String? ?? '').toLowerCase();
          final String artist =
              (songData['artist'] as String? ?? '').toLowerCase();
          final String category =
              (songData['category'] as String? ?? '').toLowerCase();

          final bool categoryMatches = _selectedCategory == 'All' ||
              category == _selectedCategory.toLowerCase();

          final bool searchMatches = query.isEmpty ||
              songName.contains(query) ||
              artist.contains(query);

          return categoryMatches && searchMatches;
        }).toList();

        if (filteredSongs.isEmpty) {
          return Center(child: Text('No songs found matching your criteria.'));
        }

        _currentFilteredSongs = filteredSongs;

        return ListView.builder(
          itemCount: _currentFilteredSongs.length,
          itemBuilder: (context, index) {
            return _buildSongListItem(
              color,
              _currentFilteredSongs,
              index,
            );
          },
        );
      },
    );
  }

  Widget _buildSongListItem(
    ThemeData color,
    List<QueryDocumentSnapshot<Object?>> filteredSongs,
    int index,
  ) {
    final song = filteredSongs[index].data() as Map<String, dynamic>;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final currentlyPlayingId = mediaItemSnapshot.data?.id;
        final songUrl = song['songUrl'] as String?;
        final isSelected = (widget.isDesktop && index == _selectedSongIndex) ||
            (songUrl != null && currentlyPlayingId == songUrl);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                width: isSelected ? 2.5 : 1.5,
                color: isSelected
                    ? color.primaryColor
                    : color.hintColor.withOpacity(0.5),
              ),
              color: isSelected ? color.primaryColor.withOpacity(0.05) : null,
            ),
            child: buildListTile(
              context: context,
              onTap: () => _handleSongPlay(index, filteredSongs, color),
              trailing: IconButton(
                icon: Icon(
                  isIOSPlatform
                      ? CupertinoIcons.ellipsis
                      : Icons.more_vert_outlined,
                  color: color.hintColor,
                ),
                onPressed: () {
                  _showSongOptions(context, color, song);
                },
              ),
              subtitle:
                  'by - ${song['artist'] ?? 'Unknown artist'} released on ${song['released'] is Timestamp ? (song['released'] as Timestamp).toDate().toString().split(' ')[0] : (song['released'] ?? 'Unknown date')}',
              title: song['songName']?.toString() ?? 'Untitled song',
              isSelected: isSelected,
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
            ),
          ),
        );
      },
    );
  }

  void _showSongOptions(
    BuildContext context,
    ThemeData color,
    Map<String, dynamic> song,
  ) {
    void handleDownload() {
      Navigator.pop(context);
      _downloadSong(
        song['songUrl'],
        song['songName'] ?? 'Untitled',
        song['artist'] ?? 'Unknown',
      );
    }

    Future<void> handleAddToLibrary() async {
      Navigator.pop(context);
      await LibraryHelper.addToLibrary(song);
      showPlatformMessage(
        context,
        "Added",
        "Song added to library",
        color.primaryColor,
      );
    }

    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: Text(song['songName'] ?? 'Song Options'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: handleDownload,
              child: const Text('Download Song'),
            ),
            CupertinoActionSheetAction(
              onPressed: handleAddToLibrary,
              child: const Text('Add to Library'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.download_rounded,
                  color: color.primaryColor,
                ),
                title: const Text('Download Song'),
                onTap: handleDownload,
              ),
              ListTile(
                leading: Icon(Icons.library_add, color: color.primaryColor),
                title: const Text('Add to Library'),
                onTap: handleAddToLibrary,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDesktopPlayer(ThemeData color) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;

        if (mediaItem == null) {
          return Center(
            child: Text(
              'Select a song to play!',
              style: TextStyle(color: color.hintColor),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<PlaybackState>(
              stream: audioHandler?.playbackState,
              builder: (context, playbackStateSnapshot) {
                final playbackState = playbackStateSnapshot.data;
                final isPlaying = playbackState?.playing ?? false;
                final processingState = playbackState?.processingState;

                if (isPlaying &&
                    processingState != AudioProcessingState.loading) {
                  _rotationController.repeat();
                } else {
                  _rotationController.stop();
                }

                return RotationTransition(
                  turns: Tween(
                    begin: 1.0,
                    end: 0.0,
                  ).animate(_rotationController),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: color.primaryColor, width: 4),
                      ),
                      height: 200,
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.asset(
                          "assets/dankie_logo.PNG",
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),
            Text(
              mediaItem.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(
              mediaItem.artist ?? 'Unknown Artist',
              style: TextStyle(fontSize: 14, color: color.hintColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20),
            _buildSeekBar(color),
            SizedBox(height: 10),
            StreamBuilder<PlaybackState>(
              stream: audioHandler?.playbackState,
              builder: (context, playbackStateSnapshot) {
                final playbackState = playbackStateSnapshot.data;
                final isPlaying = playbackState?.playing ?? false;
                final processingState = playbackState?.processingState;
                final shuffleMode =
                    playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
                final repeatMode =
                    playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle Button
                    IconButton(
                      icon: Icon(
                        Ionicons.shuffle,
                        color: shuffleMode == AudioServiceShuffleMode.all
                            ? color.primaryColor
                            : color.hintColor,
                      ),
                      onPressed: () {
                        final newMode =
                            shuffleMode == AudioServiceShuffleMode.all
                                ? AudioServiceShuffleMode.none
                                : AudioServiceShuffleMode.all;
                        audioHandler?.setShuffleMode(newMode);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.skip_previous, size: 30),
                      onPressed: audioHandler?.skipToPrevious,
                    ),
                    if (processingState == AudioProcessingState.loading ||
                        processingState == AudioProcessingState.buffering)
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                          size: 50,
                          color: color.primaryColor,
                        ),
                        onPressed: isPlaying
                            ? audioHandler?.pause
                            : audioHandler?.play,
                      ),
                    IconButton(
                      icon: Icon(Icons.skip_next, size: 30),
                      onPressed: audioHandler?.skipToNext,
                    ),
                    IconButton(
                      icon: Icon(
                        repeatMode == AudioServiceRepeatMode.one
                            ? Icons.repeat_one
                            : Ionicons.repeat,
                        color: repeatMode != AudioServiceRepeatMode.none
                            ? color.primaryColor
                            : color.hintColor,
                      ),
                      onPressed: () {
                        final newMode =
                            repeatMode == AudioServiceRepeatMode.none
                                ? AudioServiceRepeatMode.all
                                : repeatMode == AudioServiceRepeatMode.all
                                    ? AudioServiceRepeatMode.one
                                    : AudioServiceRepeatMode.none;
                        audioHandler?.setRepeatMode(newMode);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSongPlay(
    int index,
    List<QueryDocumentSnapshot<Object?>> filteredSongs,
    ThemeData color,
  ) {
    final isDesktop = isLargeScreen(context);
    final doc = filteredSongs[index];
    final songData = doc.data() as Map<String, dynamic>;
    final clickedSongUrl = songData['songUrl'] as String?;

    final currentMediaItem = audioHandler?.mediaItem.value;

    if (clickedSongUrl != null && currentMediaItem?.id == clickedSongUrl) {
      if (isDesktop) {
        setState(() {
          _selectedSongIndex = index;
        });
      } else {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (context) => MusicPlayerSheet(
            themeColor: color,
            onDownload: (url, title, artist) {
              _downloadSong(url, title, artist);
            },
          ),
        );
      }
      return;
    }

    final List<MediaItem> mediaItems = [];
    int validSongIndex = -1;

    for (int i = 0; i < filteredSongs.length; i++) {
      final sDoc = filteredSongs[i];
      final sData = sDoc.data() as Map<String, dynamic>;
      final sUrl = sData['songUrl'] as String?;

      if (sUrl != null && sUrl.trim().startsWith('https://')) {
        mediaItems.add(
          MediaItem(
            id: sUrl,
            title: sData['songName'] ?? 'Untitled',
            artist: sData['artist'] ?? 'Unknown Artist',
            album: 'TACT Music',
            artUri: Uri.parse(
              "https://firebasestorage.googleapis.com/v0/b/tact-3c612.firebasestorage.app/o/App%20Logo%2Fdankie_logo.PNG?alt=media&token=fb3a28a9-ab50-43f0-bee1-eecb34e5f394",
            ),
          ),
        );

        if (sUrl == clickedSongUrl) {
          validSongIndex = mediaItems.length - 1;
        }
      }
    }

    if (validSongIndex == -1) {
      showPlatformMessage(context, 'Error', 'Invalid Song URL', Colors.red);
      return;
    }
    void playAction() {
      try {
        if (audioHandler == null) return;
        audioHandler?.loadPlaylist(mediaItems, validSongIndex);

        if (isDesktop) {
          setState(() {
            _selectedSongIndex = index;
          });
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => MusicPlayerSheet(
              themeColor: color,
              onDownload: (url, title, artist) {
                _downloadSong(url, title, artist);
              },
            ),
          );
        }
      } catch (e) {
        debugPrint("Error loading playlist: $e");
      }
    }

    if (isDesktop) {
      playAction();
      return;
    }

    _songPlayCount++;
    if (_songPlayCount >= 4) {
      if (!kIsWeb) {
        adManager.showRewardedInterstitialAd(
          (ad, reward) {
            playAction();
            setState(() => _songPlayCount = 0);
          },
          onAdFailed: () {
            playAction();
            setState(() => _songPlayCount = 0);
          },
        );
      } else {
        playAction();
        setState(() => _songPlayCount = 0);
      }
    } else {
      playAction();
    }
  }
}
  