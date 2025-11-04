// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/Play_Song.dart';
import 'package:ttact/Components/Tactso_Branch_Details.dart';
import 'package:ttact/Components/UniversityCard.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';
import 'package:ttact/Components/bottomsheet.dart';

// Import foundation for platform checks (needed for ad banner logic stability)
import 'package:flutter/foundation.dart';
import 'package:ttact/Pages/Downloaded_Songs.dart';

// --- PLATFORM UTILITIES ---
const double _webBreakpoint = 800.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= _webBreakpoint;
// ------------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AdManager adManager = AdManager();
  int _songPlayCount = 0;

  // Music Tab State
  String _searchQuery = '';
  String _selectedCategory = 'All'; // Default selected category

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Initialize rewarded ad manager, safely wrapped in AdBanner.dart
    adManager.loadRewardedInterstitialAd();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);
    final tabHeight = isDesktop ? 60.0 : 48.0;

    // Use a fixed max width for web content
    Widget contentWrapper({required Widget child}) {
      return Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 1200),
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20.0 : 0),
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
            color: color.primaryColor,
            child: SizedBox(
              height: tabHeight,
              child: contentWrapper(
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isDesktop
                      ? false
                      : true, // Full width on desktop
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
                      text: 'TACTSO BRACHES',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Icons.location_city_outlined,
                              color: color.scaffoldBackgroundColor,
                            ),
                    ),
                    Tab(
                      text: 'TACT MUSIC',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Ionicons.musical_notes_outline,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20),
          // Daily Verse Card
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
                return _buildShimmerLoading(color, 3, 100);
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
                        showModalBottomSheet(
                          context: context,
                          builder: (context) {
                            return FractionallySizedBox(
                              heightFactor: 0.9,
                              child: EventDetailBottomSheet(
                                date: date,
                                eventMonth: eventMonth,
                                title: eventTitle,
                                description: eventDescription,
                                posterUrl: posterUrl.isNotEmpty
                                    ? posterUrl
                                    : null,
                              ),
                            );
                          },
                        );
                      },
                      child: UpcomingEventsCard(
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Verse',
                  style: TextStyle(
                    fontSize: 28,
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
          return _buildShimmerLoading(
            color,
            isDesktop ? 6 : 4,
            isDesktop ? 250 : 150,
            isGrid: true,
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading branches'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No branches found'));
        }

        final branchList = snapshot.data!.docs;

        // Group campuses by University Name (Logic from original code)
        Map<String, List<Map<String, dynamic>>> groupedUniversities = {};
        for (var doc in branchList) {
          final data = doc.data() as Map<String, dynamic>;
          final universityName = data['universityName'] ?? 'Unknown University';
          if (!groupedUniversities.containsKey(universityName)) {
            groupedUniversities[universityName] = [];
          }
          groupedUniversities[universityName]!.add(data);
        }

        // Render List/Grid based on platform
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 0.0 : 8.0,
            vertical: 16.0,
          ),
          child: Wrap(
            alignment: WrapAlignment.start,
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
                  ? (MediaQuery.of(context).size.width * 0.8) / 3 -
                        40 // ~3 columns on desktop
                  : MediaQuery.of(context).size.width / 2 -
                        12; // 2 columns on mobile

              return SizedBox(
                width: cardWidth,
                child: GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      scrollControlDisabledMaxHeightRatio: 0.8,
                      context: context,
                      builder: (context) {
                        return TactsoBranchDetails(
                          universityDetails: representativeCampusData,
                          campusListForUniversity:
                              representativeCampusData['campuses'],
                        );
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
                        scrollControlDisabledMaxHeightRatio: 0.8,
                        context: context,
                        builder: (context) {
                          // NOTE: You are passing the ENTIRE campuses list as 'universityDetails' here
                          // The `TactsoBranchDetails` component will need to be prepared to handle this.
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
        );
      },
    );
  }

  // --- TAB 3: MUSIC ---
  Widget _buildMusicTab(ThemeData color, bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Sidebar: Search and Categories (Fixed Width)
          Container(
            width: 300,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: color.dividerColor.withOpacity(0.5)),
              ),
              color: color.cardColor,
            ),
            child: _buildMusicControls(color, isDesktop),
          ),
          // Right Main Content: Song List (Expanded)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildSongList(color),
            ),
          ),
        ],
      );
    } else {
      // Mobile/Tablet Layout (Original stacked design)
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildMusicControls(color, isDesktop),
            SizedBox(height: 10),
            Expanded(child: _buildSongList(color)),
          ],
        ),
      );
    }
  }

  // Music Controls (Search and Category Tabs)
  Widget _buildMusicControls(ThemeData color, bool isDesktop) {
    final categories = [
      'All',
      'Choreography',
      'Apostle choir',
      'Slow Jam',
      'Instrumental songs',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
      children: [
        // Search Field
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 8.0),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              contentPadding: EdgeInsets.all(15),
              hintText: 'Search song by name... 🎶',
              fillColor: color.hintColor.withOpacity(0.2),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(height: isDesktop ? 30 : 10),

        // Category Tabs (List View on Desktop Sidebar)
        isDesktop
            ? Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        title: Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? color.primaryColor
                                : color.hintColor,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        leading: Icon(
                          isSelected
                              ? Ionicons.musical_notes
                              : Ionicons.musical_notes_outline,
                          color: isSelected
                              ? color.primaryColor
                              : color.hintColor,
                        ),
                        tileColor: isSelected
                            ? color.primaryColor.withOpacity(0.1)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                      ),
                    );
                  },
                ),
              )
            : SizedBox(
                height: 40, // Height for horizontal TabBar on mobile
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
                      });
                    },
                    tabs: categories.map((c) => Tab(text: c)).toList(),
                  ),
                ),
              ),

        // Downloaded Songs Button (Only on Mobile/Bottom of Desktop Sidebar)
        if (isDesktop) Spacer(),
        Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: IconButton.filled(
            onPressed: () {
              showCupertinoSheet(
                enableDrag: true,
                context: context,
                pageBuilder: (context) {
                  return DownloadedSongs();
                },
              );
            },
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(color.splashColor),
            ),
            icon: Icon(
              Icons.download_done,
              size: 40,
              color: color.scaffoldBackgroundColor,
            ),
            tooltip: 'Downloaded Songs',
          ),
        ),
      ],
    );
  }

  // Song List Content
  Widget _buildSongList(ThemeData color) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('tact_music')
          // Firestore optimization for search
          .where('songName', isGreaterThanOrEqualTo: _searchQuery)
          .where('songName', isLessThanOrEqualTo: _searchQuery + '\uf8ff')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerLoading(color, 8, 70);
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No songs available'));
        }

        final allSongs = snapshot.data!.docs;

        final filteredSongs = _selectedCategory == 'All'
            ? allSongs
            : allSongs.where((doc) {
                final songData = doc.data() as Map<String, dynamic>;
                return songData['category'] == _selectedCategory;
              }).toList();

        if (filteredSongs.isEmpty) {
          return Center(child: Text('No songs found in this category.'));
        }

        return ListView.builder(
          itemCount: filteredSongs.length,
          itemBuilder: (context, index) {
            final song = filteredSongs[index].data() as Map<String, dynamic>;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    width: 1.5,
                    color: color.dividerColor.withOpacity(0.5),
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    _handleSongPlay(index, filteredSongs, color);
                  },
                  minVerticalPadding:
                      15, // Increased padding for web readability
                  trailing: Icon(
                    Icons.more_vert_outlined,
                    color: color.hintColor,
                  ),
                  subtitle: Text(
                    'by - ${song['artist'] ?? 'Unknown artist'} released on ${song['released'] is Timestamp ? (song['released'] as Timestamp).toDate().toString().split(' ')[0] : (song['released'] ?? 'Unknown date')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w200,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: color.hintColor,
                    ),
                  ),
                  title: Text(
                    song['songName']?.toString() ?? 'Untitled song',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  leading: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(width: 1.5, color: color.primaryColor),
                    ),
                    child: Icon(
                      Icons.music_note_outlined,
                      color: color.primaryColor,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- AD LOGIC HANDLER ---
  void _handleSongPlay(
    int index,
    List<QueryDocumentSnapshot<Object?>> filteredSongs,
    ThemeData color,
  ) {
    _songPlayCount++;
    debugPrint('Song play count: $_songPlayCount');

    void playSong() {
      showCupertinoSheet(
        enableDrag: true,
        context: context,
        pageBuilder: (context) {
          return PlaySong(
            songs: filteredSongs
                .map((doc) => doc.data() as Map<String, dynamic>)
                .toList(),
            initialIndex: index,
          );
        },
      );
    }

    // Determine if we should show the ad
    if (_songPlayCount >= 4) {
      if (!kIsWeb) {
        // Only attempt to show rewarded ad on non-web platforms
        adManager.showRewardedInterstitialAd(
          (ad, reward) {
            // Ad success: play the song and reset count
            debugPrint('User earned reward: ${reward.amount} ${reward.type}');
            playSong();
            setState(() => _songPlayCount = 0);
          },
          onAdFailed: () {
            // Ad failure: still play the song, and reset count to try again later
            playSong();
            // Resetting count here is optional, but helps ensure the ad prompt is less frequent
            setState(() => _songPlayCount = 0);
          },
        );
      } else {
        // On Web/Desktop, skip the rewarded ad, just play the song, but still reset the counter
        // to match mobile logic flow (or implement a different monetization model).
        playSong();
        setState(() => _songPlayCount = 0);
      }
    } else {
      // If ad counter is not met, just play the song
      playSong();
    }
  }

  // --- SHIMMER LOADER ---
  Widget _buildShimmerLoading(
    ThemeData color,
    int itemCount,
    double itemHeight, {
    bool isGrid = false,
  }) {
    return Shimmer.fromColors(
      baseColor: color.hintColor.withOpacity(0.3),
      highlightColor: color.hintColor.withOpacity(0.1),
      child: isGrid
          ? Wrap(
              alignment: WrapAlignment.start,
              spacing: 6.0,
              runSpacing: 12.0,
              children: List.generate(
                itemCount,
                (index) => SizedBox(
                  width:
                      MediaQuery.of(context).size.width /
                          (isLargeScreen(context) ? 3 : 2) -
                      12,
                  height: itemHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            )
          : ListView.builder(
              itemCount: itemCount,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    height: itemHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
