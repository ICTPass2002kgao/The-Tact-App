// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'dart:async';
import 'dart:io'; // ⭐️ NEW IMPORT: For File checks

import 'package:audio_service/audio_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart'; // ⭐️ NEW IMPORT: For downloading
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:path_provider/path_provider.dart'; // ⭐️ NEW IMPORT: For paths
import 'package:permission_handler/permission_handler.dart'; // ⭐️ NEW IMPORT: For permissions
import 'package:shimmer/shimmer.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/LiabraryHelper.dart';
import 'package:ttact/Components/Share_Song.dart'
    hide audioHandler, AudioProcessingState;
import 'package:ttact/Components/Tactso_Branch_Details.dart';
import 'package:ttact/Components/UniversityCard.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';
import 'package:ttact/Components/bottomsheet.dart';
import 'package:ttact/Pages/Downloaded_Songs.dart';
import 'package:ttact/Pages/LibrarySongs.dart';
import 'package:ttact/Pages/MotherPage.dart';
import 'package:ttact/main.dart'; // To get the global 'audioHandler'

// --- PLATFORM UTILITIES ---
const double _webBreakpoint = 800.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _webBreakpoint;

// UPDATED: This logic now checks the OS, even on the web.
bool get isIOSPlatform {
  // Checks for iOS or macOS (which iPads/Macs report in browsers)
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

// UPDATED: This logic now checks the OS, even on the web.
bool get isAndroidPlatform {
  // Checks for Android, Linux, or Fuchsia to default to Material style.
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.fuchsia;
}
// ------------------------

// --- COPIED HELPERS ---

// Custom platform-aware TextField Builder
Widget _buildPlatformTextField({
  required TextEditingController controller,
  required String placeholder,
  IconData? prefixIcon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  bool readOnly = false,
  int? maxLines = 1,
  String? Function(String?)? validator,
  Widget? suffixIcon,
  required BuildContext context,
  Function(String)? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: isIOSPlatform
        ? CupertinoTextField(
            style: TextStyle(color: Theme.of(context).cardColor),
            controller: controller,
            placeholder: placeholder,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8.0),
            ),
            padding: const EdgeInsets.all(12.0),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
                  )
                : null,
            suffixMode: OverlayVisibilityMode.editing,
            suffix: suffixIcon,
            onChanged: onChanged,
          )
        : TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: placeholder,
              prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 16.0,
              ),
              fillColor: Theme.of(context).hintColor.withOpacity(0.2),
              filled: true,
            ),
            validator: validator,
            onChanged: onChanged,
          ),
  );
}

// Custom platform-aware ListTile Builder
Widget _buildListTile({
  required String title,
  String? subtitle,
  Widget? leading,
  Widget? trailing,
  required VoidCallback onTap,
  required BuildContext context,
  bool isSelected = false,
}) {
  final color = Theme.of(context);
  if (isIOSPlatform) {
    return CupertinoListTile(
      backgroundColor: isSelected ? color.primaryColor.withOpacity(0.1) : null,
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? color.primaryColor : color.cardColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color.primaryColor : color.hintColor,
              ),
            )
          : null,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
    );
  } else {
    return ListTile(
      tileColor: isSelected ? color.primaryColor.withOpacity(0.1) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? color.primaryColor : color.cardColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? color.primaryColor : color.hintColor,
              ),
            )
          : null,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// Platform-Aware Message
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
    // Use the original SnackBar method for Material
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        backgroundColor: backgroundColor,
      ),
    );
  }
}
// --- END COPIED HELPERS ---

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  AdManager adManager = AdManager();
  int _songPlayCount = 0;

  // Music Tab State
  final TextEditingController _musicSearchController = TextEditingController();
  final TextEditingController _branchSearchController = TextEditingController();
  String _musicSearchQuery = '';
  String _branchSearchQuery = '';
  String _selectedCategory = 'All'; // Default selected category
  // Tracks the index of the song selected for the player column
  int? _selectedSongIndex;
  // Stores the current list of songs being displayed/played
  List<QueryDocumentSnapshot<Object?>> _currentFilteredSongs = [];
  late Future<QuerySnapshot> _musicFuture;

  // Animation Controller
  late AnimationController _rotationController;

  // ⭐️ NEW: Store local path to check for files synchronously
  String? _localAppPath;

  // ⭐️ NEW: Initialize local path
  Future<void> _initLocalPath() async {
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      setState(() {
        _localAppPath = dir.path;
      });
    }
  }

  // DOWNLOAD SONG LOGIC
  Future<void> _downloadSong(String url, String title, String artist) async {
    if (!kIsWeb && isAndroidPlatform) {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    try {
      final dir = await getApplicationDocumentsDirectory();

      // Sanitize filename
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final safeArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '').trim();
      final filename = '${safeTitle}_${safeArtist}.mp3';
      final savePath = '${dir.path}/$filename';

      if (File(savePath).existsSync()) {
        _showPlatformMessage(
          context,
          'Info',
          'Song already downloaded!',
          Colors.blue,
        );
        return;
      }

      _showPlatformMessage(
        context,
        'Downloading',
        'Downloading $title...',
        Colors.orange,
      );

      await Dio().download(url, savePath);

      _showPlatformMessage(
        context,
        'Success',
        'Song saved to library!',
        Colors.green,
      );

      // ⭐️ UPDATE UI: Refresh state so the "Check" icon appears immediately
      setState(() {});

      debugPrint("Song saved to: $savePath");
    } catch (e) {
      debugPrint("Download Error: $e");
      _showPlatformMessage(
        context,
        'Error',
        'Failed to download. Check connection.',
        Colors.red,
      );
    }
  }

  // Listener callback for the deep link notifier
  void _onDeepLinkReceived() async {
    // MUSIC TAB IS INDEX 2
    const int musicTabIndex = 2;

    final songUrlId = MotherPage.deepLinkSongIdNotifier.value;
    if (songUrlId == null) return;

    debugPrint("🎵 HomePage received deep link request: $songUrlId");

    // 1. Switch TabBar to Music Tab (Index 2)
    if (_tabController.index != musicTabIndex) {
      _tabController.animateTo(musicTabIndex);

      // Wait for tab animation to complete and data to load
      await Future.delayed(Duration(milliseconds: 500));
    }

    // 2. Reset the notifier value immediately to prevent repeated calls
    MotherPage.deepLinkSongIdNotifier.value = null;

    // 3. Play the song
    await _playDeepLinkedSong(songUrlId);
  }

  // Find and play song by URL
  Future<void> _playDeepLinkedSong(String targetUrl) async {
    try {
      // Wait for the Firebase data to be available
      QuerySnapshot snapshot = await _musicFuture;
      final allDocs = snapshot.docs;

      // Filter out invalid songs (songs without a valid URL)
      final validSongs = allDocs.where((doc) {
        final sData = doc.data() as Map<String, dynamic>;
        final sUrl = sData['songUrl'] as String?;
        return sUrl != null && sUrl.trim().startsWith('https://');
      }).toList();

      int foundIndex = -1;

      // Search through all valid songs for matching URL
      for (int i = 0; i < validSongs.length; i++) {
        final data = validSongs[i].data() as Map<String, dynamic>;
        if (data['songUrl'] == targetUrl) {
          foundIndex = i;
          break;
        }
      }

      if (foundIndex != -1) {
        debugPrint("✅ Deep Linked Song found at index $foundIndex. Playing...");

        // Update the current filtered list to show the correct context
        setState(() {
          _selectedCategory = 'All';
          _musicSearchController.clear();
          _musicSearchQuery = '';
          _currentFilteredSongs = validSongs;
          _selectedSongIndex = foundIndex;
        });

        // Trigger the existing play logic with the found index and context list
        _handleSongPlay(foundIndex, _currentFilteredSongs, Theme.of(context));
      } else {
        _showPlatformMessage(
          context,
          "Song Not Found",
          "The shared song could not be found in our library.",
          Colors.orange,
        );
      }
    } catch (e) {
      debugPrint("Error processing deep link song: $e");
      _showPlatformMessage(
        context,
        "Error",
        "Failed to load song data. Please check your connection.",
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
    // Initialize the future here so it only runs ONCE
    _musicFuture = FirebaseFirestore.instance
        .collection('tact_music')
        .orderBy('released', descending: true)
        .get();

    _tabController = TabController(length: 3, vsync: this);

    // Add listeners to search controllers
    _musicSearchController.addListener(() {
      setState(() {
        _musicSearchQuery = _musicSearchController.text;
        _selectedSongIndex = null;
      });
    });

    _branchSearchController.addListener(() {
      setState(() {
        _branchSearchQuery = _branchSearchController.text;
      });
    });

    // Subscribe to the deep link notifier with delay to ensure widgets are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MotherPage.deepLinkSongIdNotifier.addListener(_onDeepLinkReceived);

      // Check if there's already a pending deep link
      if (MotherPage.deepLinkSongIdNotifier.value != null) {
        // Small delay to ensure everything is initialized
        Future.delayed(Duration(milliseconds: 1000), _onDeepLinkReceived);
      }
    });

    // Initialize rewarded ad manager
    adManager.loadRewardedInterstitialAd();
  }

  @override
  void dispose() {
    // Unsubscribe from the deep link notifier
    MotherPage.deepLinkSongIdNotifier.removeListener(_onDeepLinkReceived);

    _rotationController.dispose();
    _tabController.dispose();
    _musicSearchController.dispose();
    _branchSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use 'color' for ThemeData object, which holds all theme properties
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);
    final tabHeight = isDesktop ? 70.0 : 48.0; // Reverted to original 48.0

    // Use a fixed max width for web content
    Widget contentWrapper({required Widget child}) {
      return Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 1200),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 30.0 : 0),
          child: child,
        ),
      );
    }

    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Column(
        children: [
          // 1. TabBar: Standard for Mobile, Elevated for Desktop
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            elevation: isDesktop ? 8 : 15,
            margin: EdgeInsets.zero,
            color: color.primaryColor, // Use primaryColor
            child: SizedBox(
              height: tabHeight,
              child: contentWrapper(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicatorColor: color.scaffoldBackgroundColor,
                  labelColor: color.scaffoldBackgroundColor,
                  unselectedLabelColor: color.hintColor,
                  tabs: [
                    Tab(
                      text: 'RECENT EVENTS',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Icons.event,
                              color: color.scaffoldBackgroundColor,
                            ),
                    ),
                    Tab(
                      text: 'TACTSO BRANCHES',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Ionicons.school_outline,
                              color: color.scaffoldBackgroundColor,
                            ),
                    ),
                    Tab(
                      text: 'TACT MUSIC',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Ionicons.musical_note_outline,
                              color: color.scaffoldBackgroundColor,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                contentWrapper(child: _buildEventsTab(color)),
                contentWrapper(child: _buildBranchesTab(color, isDesktop)),
                contentWrapper(child: _buildMusicTab(color, isDesktop)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: EVENTS ---
  Widget _buildEventsTab(ThemeData color) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ListView(
        children: [
          _buildDailyVerseCard(color),
          SizedBox(height: 20),
          Text(
            'Upcoming Events',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
          SizedBox(height: 10),

          // Upcoming Events List
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('upcoming_events')
                .where(
                  'parsedDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
                )
                .orderBy('parsedDate', descending: false)
                .limit(5)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: isIOSPlatform
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text('Error loading events: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No upcoming events found.'));
              }

              final events = snapshot.data!.docs;

              return Column(
                children: events.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String date = data['day'] ?? '';
                  final String eventMonth = data['month'] ?? '';
                  final String eventTitle = data['title'] ?? 'No Title';
                  final String eventDescription =
                      data['description'] ?? 'No Description';
                  final String posterUrl = data['posterUrl'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: GestureDetector(
                      onTap: () {
                        final widget = EventDetailBottomSheet(
                          date: date,
                          eventMonth: eventMonth,
                          title: eventTitle,
                          description: eventDescription,
                          posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
                        );

                        showModalBottomSheet(
                          scrollControlDisabledMaxHeightRatio: double.infinity,
                          context: context,
                          builder: (context) {
                            return widget;
                          },
                        );
                      },
                      child: UpcomingEventsCard(
                        posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
                        date: date,
                        eventMonth: eventMonth,
                        eventTitle: eventTitle,
                        eventDescription: eventDescription,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyVerseCard(ThemeData color) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Card uses transparent color, Container handles the styling
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.primaryColor, color.primaryColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              color: color.scaffoldBackgroundColor,
            ),
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Verse',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: color.primaryColor,
                  ),
                ),
                Divider(
                  thickness: 1,
                  color: color.primaryColor.withOpacity(0.5),
                ),
                Text(
                  '"For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future."',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: color.primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- Jeremiah 29:11',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.primaryColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TAB 2: BRANCHES ---
  Widget _buildBranchesTab(ThemeData color, bool isDesktop) {
    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('tactso_branches')
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading branches'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No branches found'));
        }

        final branchList = snapshot.data!.docs;

        // Group campuses by University Name
        Map<String, List<Map<String, dynamic>>> groupedUniversities = {};
        for (var doc in branchList) {
          final data = doc.data() as Map<String, dynamic>;
          final universityName =
              (data['universityName'] as String? ?? 'Unknown University')
                  .toLowerCase();

          // Filter by search query
          if (_branchSearchQuery.isEmpty ||
              universityName.contains(_branchSearchQuery.toLowerCase())) {
            if (!groupedUniversities.containsKey(universityName)) {
              groupedUniversities[universityName] = [];
            }
            groupedUniversities[universityName]!.add(data);
          }
        }

        // Render List/Grid based on platform
        return ListView(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 0 : 8.0,
                vertical: isDesktop ? 20.0 : 10.0,
              ),
              child: _buildPlatformTextField(
                controller: _branchSearchController,
                placeholder: 'Search branch by name...',
                prefixIcon: isIOSPlatform
                    ? CupertinoIcons.search
                    : Icons.search,
                context: context,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: isDesktop ? 20.0 : 6.0, // Increased spacing for web
              runSpacing: isDesktop
                  ? 20.0
                  : 12.0, // Increased run spacing for web
              children: groupedUniversities.entries.map((entry) {
                final String universityName = entry.key;
                final List<Map<String, dynamic>> campuses = entry.value;
                final Map<String, dynamic> representativeCampusData =
                    campuses.first;
                final bool anyCampusApplicationOpen = campuses.any(
                  (campus) => campus['isApplicationOpen'] == true,
                );

                // Responsive Card Width
                final cardWidth = isDesktop
                    ? (MediaQuery.of(context).size.width * 0.8) / 4 -
                          40 // ~3 columns on desktop
                    : MediaQuery.of(context).size.width / 2 -
                          12; // 2 columns on mobile

                return SizedBox(
                  width: cardWidth,
                  child: GestureDetector(
                    onTap: () {
                      final widget = TactsoBranchDetails(
                        universityDetails: representativeCampusData,
                        campusListForUniversity:
                            representativeCampusData['campuses'],
                      );

                      showModalBottomSheet(
                        scrollControlDisabledMaxHeightRatio: double.infinity,

                        context: context,
                        builder: (context) {
                          return widget;
                        },
                      );
                    },
                    child: UniversityCard(
                      imageUrl:
                          representativeCampusData['imageUrl'] != null &&
                              representativeCampusData['imageUrl'].isNotEmpty
                          ? representativeCampusData['imageUrl'][0]
                          : null,
                      UniName: universityName,
                      uniAddress: representativeCampusData['address'] ?? '',
                      applicationLink:
                          representativeCampusData['applicationLink'] ?? '',
                      onPressed: () {
                        showModalBottomSheet(
                          scrollControlDisabledMaxHeightRatio: double.infinity,

                          context: context,
                          builder: (context) {
                            return TactsoBranchDetails(
                              universityDetails: campuses as dynamic,
                              campusListForUniversity:
                                  representativeCampusData['campuses'],
                            );
                          },
                        );
                      },
                      applicationIsOpen: anyCampusApplicationOpen,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // --- TAB 3: MUSIC ---

  // Helper method to format Duration
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // Helper widget for the Seek Bar
  Widget _buildSeekBar(ThemeData color) {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler?.playbackState,
      builder: (context, playbackSnapshot) {
        final state = playbackSnapshot.data;
        final position = state?.updatePosition ?? Duration.zero;

        // Get duration from the media item
        final duration =
            audioHandler?.mediaItem.value?.duration ?? Duration.zero;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The Slider
            if (isIOSPlatform)
              CupertinoSlider(
                value:
                    (position.inMilliseconds > 0 &&
                        position.inMilliseconds < duration.inMilliseconds)
                    ? position.inMilliseconds.toDouble()
                    : 0.0,
                max: (duration.inMilliseconds > 0)
                    ? duration.inMilliseconds.toDouble()
                    : 1.0, // Prevent division by zero
                onChanged: (value) {
                  audioHandler?.seek(Duration(milliseconds: value.round()));
                },
                activeColor: color.primaryColor,
              )
            else
              Slider(
                value:
                    (position.inMilliseconds > 0 &&
                        position.inMilliseconds < duration.inMilliseconds)
                    ? position.inMilliseconds.toDouble()
                    : 0.0,
                max: (duration.inMilliseconds > 0)
                    ? duration.inMilliseconds.toDouble()
                    : 1.0, // Prevent division by zero
                onChanged: (value) {
                  audioHandler?.seek(Duration(milliseconds: value.round()));
                },
                activeColor: color.primaryColor,
                inactiveColor: color.hintColor.withOpacity(0.3),
              ),

            // The Row with timestamps
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(color: color.hintColor, fontSize: 12),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(color: color.hintColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMusicTab(ThemeData color, bool isDesktop) {
    if (isDesktop) {
      // DESKTOP: 3-Column Layout
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 1: Controls
          Container(
            width: 300,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: color.hintColor.withOpacity(0.5)),
              ),
            ),
            child: _buildMusicControls(color, isDesktop),
          ),

          // Column 2: Song List
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildSongList(color, isDesktop),
            ),
          ),

          // Column 3: Player (Listens to handler)
          Container(
            alignment: Alignment.centerRight,
            width: 300, // Fixed width for player
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              border: Border.all(color: color.primaryColor.withOpacity(0.5)),
            ),
            child: _buildDesktopPlayer(color),
          ),
        ],
      );
    } else {
      // MOBILE: Stacked Layout
      return Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 20),

              // Controls section
              _buildMusicControls(color, isDesktop),
              SizedBox(height: 10),

              // Song List section - Expanded to take remaining space
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildSongList(color, isDesktop),
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

  // Music Controls (Search and Category Tabs)
  Widget _buildMusicControls(ThemeData color, bool isDesktop) {
    final categories = [
      'All',
      'choreography',
      'Apostle choir',
      'Slow Jam',
      'Instrumental songs',
    ];

    return Column(
      mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // Search Field
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 8.0),
          child: _buildPlatformTextField(
            controller: _musicSearchController,
            placeholder: 'Search song by name or artist...',
            prefixIcon: isIOSPlatform ? CupertinoIcons.search : Icons.search,
            context: context,
            // onChanged is handled by the controller listener
          ),
        ),
        SizedBox(height: isDesktop ? 30 : 10),

        // Category Tabs (List View on Desktop Sidebar)
        isDesktop
            ? Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      // --- PLATFORM AWARE ---
                      child: _buildListTile(
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
                          color: isSelected
                              ? color.primaryColor
                              : color.hintColor,
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
                // --- REVERTED: Always use Material TabBar as requested ---
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
                // --- END REVERT ---
              ),
      ],
    );
  }

  // Song List Content (FIXED VERSION)
  Widget _buildSongList(ThemeData color, bool isDesktop) {
    return FutureBuilder<QuerySnapshot>(
      // 1. Use the state variable, not a new future
      future: _musicFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          ); // Simpler loading
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No songs available'));
        }

        final allSongs = snapshot.data!.docs;
        // Use the state variable for the query
        final String query = _musicSearchQuery.toLowerCase().trim();

        // Perform local filtering
        final filteredSongs = allSongs.where((doc) {
          final songData = doc.data() as Map<String, dynamic>;
          final String songName = (songData['songName'] as String? ?? '')
              .toLowerCase();
          final String artist = (songData['artist'] as String? ?? '')
              .toLowerCase();
          final String category = (songData['category'] as String? ?? '')
              .toLowerCase();

          // Category filter
          final bool categoryMatches =
              _selectedCategory == 'All' ||
              category == _selectedCategory.toLowerCase();

          // Search filter
          final bool searchMatches =
              query.isEmpty ||
              songName.contains(query) ||
              artist.contains(query);

          return categoryMatches && searchMatches;
        }).toList();

        if (filteredSongs.isEmpty) {
          return Center(child: Text('No songs found matching your criteria.'));
        }

        // 2. STASH THE FILTERED LIST
        _currentFilteredSongs = filteredSongs;

        // Use ListView for both desktop and mobile
        return ListView.builder(
          itemCount: _currentFilteredSongs.length,
          itemBuilder: (context, index) {
            // 3. Pass the stashed list
            return _buildSongListItem(
              color,
              _currentFilteredSongs,
              index,
              isDesktop,
            );
          },
        );
      },
    );
  }

  // 1. REPLACE your existing _buildSongListItem with this:
  Widget _buildSongListItem(
    ThemeData color,
    List<QueryDocumentSnapshot<Object?>> filteredSongs,
    int index,
    bool isDesktop,
  ) {
    final song = filteredSongs[index].data() as Map<String, dynamic>;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final currentlyPlayingId = mediaItemSnapshot.data?.id;
        final songUrl = song['songUrl'] as String?;
        final isSelected =
            (isDesktop && index == _selectedSongIndex) ||
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
            child: _buildListTile(
              context: context,
              onTap: () => _handleSongPlay(index, filteredSongs, color),
              // ⭐️ UPDATED TRAILING WIDGET: The "..." Menu
              trailing: IconButton(
                icon: Icon(
                  isIOSPlatform
                      ? CupertinoIcons.ellipsis
                      : Icons.more_vert_outlined,
                  color: color.hintColor,
                ),
                onPressed: () {
                  // Call the menu helper
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

  // 2. ADD this new method to your main class to handle the options menu:
  void _showSongOptions(
    BuildContext context,
    ThemeData color,
    Map<String, dynamic> song,
  ) {
    // Define actions as closures to avoid code duplication
    void handleDownload() {
      Navigator.pop(context); // Close menu
      // Calls your existing download logic
      _downloadSong(
        song['songUrl'],
        song['songName'] ?? 'Untitled',
        song['artist'] ?? 'Unknown',
      );
    }

    Future<void> handleAddToLibrary() async {
      Navigator.pop(context); // Close menu
      await LibraryHelper.addToLibrary(song);
      _showPlatformMessage(
        context,
        "Added",
        "Song added to library",
        color.primaryColor,
      );
    }

    if (isIOSPlatform) {
      // iOS Action Sheet
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
      // Android Bottom Sheet
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

  // Widget for the Desktop Player Column
  Widget _buildDesktopPlayer(ThemeData color) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler?.mediaItem,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;

        // Show player only if a song is loaded
        if (mediaItem == null) {
          return Center(
            child: Text(
              'Select a song to play!',
              style: TextStyle(color: color.hintColor),
              textAlign: TextAlign.center,
            ),
          );
        }

        // The main player UI
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Album Art is now the rotating logo
            StreamBuilder<PlaybackState>(
              stream: audioHandler?.playbackState,
              builder: (context, playbackStateSnapshot) {
                // Logic to control animation
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
                  ).animate(_rotationController), // Counter-clockwise
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100), // Circular
                        border: Border.all(color: color.primaryColor, width: 4),
                      ),
                      height: 200,
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: Image.asset(
                          "assets/dankie_logo.PNG", // <-- YOUR APP LOGO
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 20),

            // Song Title
            Text(
              mediaItem.title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),

            // Artist
            Text(
              mediaItem.artist ?? 'Unknown Artist',
              style: TextStyle(fontSize: 14, color: color.hintColor),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20),

            // Seek Bar
            _buildSeekBar(color),
            SizedBox(height: 10),

            // Controls (now with Shuffle/Repeat)
            StreamBuilder<PlaybackState>(
              stream: audioHandler?.playbackState,
              builder: (context, playbackStateSnapshot) {
                final playbackState = playbackStateSnapshot.data;
                final isPlaying = playbackState?.playing ?? false;
                final processingState = playbackState?.processingState;

                // Get states for shuffle/repeat buttons
                final shuffleMode =
                    playbackState?.shuffleMode ?? AudioServiceShuffleMode.none;
                final repeatMode =
                    playbackState?.repeatMode ?? AudioServiceRepeatMode.none;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle Button
                    isIOSPlatform
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(
                              CupertinoIcons.shuffle,
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
                          )
                        : IconButton(
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

                    // Previous Button
                    isIOSPlatform
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(CupertinoIcons.backward_fill, size: 30),
                            onPressed: audioHandler?.skipToPrevious,
                          )
                        : IconButton(
                            icon: Icon(Icons.skip_previous, size: 30),
                            onPressed: audioHandler?.skipToPrevious,
                          ),

                    // Play/Pause/Loading Button
                    if (processingState == AudioProcessingState.loading ||
                        processingState == AudioProcessingState.buffering)
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: isIOSPlatform
                            ? CupertinoActivityIndicator()
                            : CircularProgressIndicator(),
                      )
                    else
                      isIOSPlatform
                          ? CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: Icon(
                                isPlaying
                                    ? CupertinoIcons.pause_circle_fill
                                    : CupertinoIcons.play_circle_fill,
                                size: 50,
                                color: color.primaryColor,
                              ),
                              onPressed: isPlaying
                                  ? audioHandler?.pause
                                  : audioHandler?.play,
                            )
                          : IconButton(
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

                    // Next Button
                    isIOSPlatform
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(CupertinoIcons.forward_fill, size: 30),
                            onPressed: audioHandler?.skipToNext,
                          )
                        : IconButton(
                            icon: Icon(Icons.skip_next, size: 30),
                            onPressed: audioHandler?.skipToNext,
                          ),

                    // Repeat Button
                    isIOSPlatform
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(
                              repeatMode == AudioServiceRepeatMode.one
                                  ? CupertinoIcons.repeat_1
                                  : CupertinoIcons.repeat,
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
                          )
                        : IconButton(
                            icon: Icon(
                              repeatMode == AudioServiceRepeatMode.one
                                  ? Icons.repeat_one
                                  : Ionicons.repeat,
                              color: repeatMode != AudioServiceRepeatMode.none
                                  ? color.primaryColor
                                  : color.hintColor,
                            ),
                            onPressed: () {
                              // Cycle: none -> all -> one -> none
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

  // Logic to handle song selection
  void _handleSongPlay(
    int index,
    List<QueryDocumentSnapshot<Object?>> filteredSongs,
    ThemeData color,
  ) {
    final isDesktop = isLargeScreen(context);
    final doc = filteredSongs[index];
    final songData = doc.data() as Map<String, dynamic>;
    final clickedSongUrl = songData['songUrl'] as String?;

    // --- 1. CHECK IF ALREADY PLAYING ---
    final currentMediaItem = audioHandler?.mediaItem.value;

    // If the clicked song is the SAME as what is currently playing
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
            // ⭐️ ALSO PASS IT HERE
            onDownload: (url, title, artist) {
              _downloadSong(url, title, artist);
            },
          ),
        );
      }
      return;
    }

    // --- 2. IF NOT PLAYING, PROCEED TO LOAD ---

    // Convert Firestore docs to MediaItems with SAFETY CHECKS
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

        // If this loop iteration is the song the user clicked
        if (sUrl == clickedSongUrl) {
          // This matches the index in the newly created *valid* mediaItems list
          validSongIndex = mediaItems.length - 1;
        }
      }
    }

    if (validSongIndex == -1) {
      _showPlatformMessage(context, 'Error', 'Invalid Song URL', Colors.red);
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

              // ⭐️ PASS THE DOWNLOAD CALLBACK HERE
              onDownload: (url, title, artist) {
                // Call your existing download method
                _downloadSong(url, title, artist);
              },
            ),
          );
        }
      } catch (e) {
        debugPrint("Error loading playlist: $e");
      }
    }

    // --- Ad Logic for Initial Click ---
    if (isDesktop) {
      playAction();
      return;
    }

    // Your existing Logic for counting song selections
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

class MusicPlayerSheet extends StatefulWidget {
  final ThemeData themeColor;
  // Callback to trigger download in the parent/main widget
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

    // 1. Init Animation
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // 2. Listen for Duration & Library Status
    _durationSubscription = audioHandler?.mediaItem.listen((mediaItem) {
      final newDuration = mediaItem?.duration ?? Duration.zero;
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
        // Check if current song is in library
        if (mediaItem != null) {
          _checkLibraryStatus(mediaItem.id);
        }
      }
    });

    // 3. Listen for Position (Seek Bar)
    _positionSubscription = AudioService.position.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });

    // 4. Listen for Playback State (Animation & Icons)
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

  // --- Library Logic ---
  Future<void> _checkLibraryStatus(String songId) async {
    bool exists = await LibraryHelper.isSongInLibrary(songId);
    if (mounted) setState(() => _isSongInLibrary = exists);
  }

  Future<void> _toggleLibrary() async {
    final mediaItem = audioHandler?.mediaItem.value;
    if (mediaItem == null) return;

    if (_isSongInLibrary) {
      // Remove
      await LibraryHelper.removeFromLibrary(mediaItem.id);
      if (mounted) {
        setState(() => _isSongInLibrary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Removed from Library"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Add
      Map<String, dynamic> songMap = {
        'songName': mediaItem.title,
        'artist': mediaItem.artist,
        'songUrl': mediaItem.id,
        // Add any other fields you need to save
      };
      await LibraryHelper.addToLibrary(songMap);
      if (mounted) {
        setState(() => _isSongInLibrary = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Added to Library"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  // --- Next Button Ad Logic ---
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

  // --- Helper: Format Duration ---
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // --- Helper: Build Seek Bar ---
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

  // --- Helper: Build Platform Button ---
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
                      // 1. Grab Handle
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

                      // 2. Rotating Logo (Album Art)
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

                      // 3. Title, Artist & Interactive Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Song Details (Expanded)
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

                          // Action Buttons Row
                          Row(
                            children: [
                              // A. Download Button
                              IconButton(
                                icon: Icon(
                                  isIOSPlatform
                                      ? CupertinoIcons.cloud_download
                                      : Icons.download_rounded,
                                  color: widget.themeColor.primaryColor,
                                ),
                                onPressed: () {
                                  // Trigger callback to parent
                                  widget.onDownload(
                                    mediaItem.id,
                                    mediaItem.title,
                                    mediaItem.artist ?? 'Unknown',
                                  );
                                },
                              ),

                              // B. Library Button (Interactive)
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

                              // C. Share Button
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

                      // 4. Seek Bar
                      _buildSeekBar(),

                      const SizedBox(height: 20),

                      // 5. Player Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Shuffle
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

                          // Previous
                          _buildBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.backward_fill
                                : Icons.skip_previous,
                            size: 40,
                            onPressed: () => audioHandler?.skipToPrevious(),
                          ),

                          // Play/Pause
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

                          // Next (With Ads)
                          _buildBtn(
                            icon: isIOSPlatform
                                ? CupertinoIcons.forward_fill
                                : Icons.skip_next,
                            size: 40,
                            onPressed: _handleNextPress,
                          ),

                          // Repeat
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
