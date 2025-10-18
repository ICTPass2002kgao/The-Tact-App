// ignore_for_file: prefer_const_constructors

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
import 'package:ttact/Pages/Downloaded_Songs.dart';

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
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    adManager.loadRewardedInterstitialAd();
  }

  String _searchQuery = '';
  String _selectedCategory = 'All'; // Default selected category

  @override
  Widget build(BuildContext context) {
    // final color = AppColor(color: const Color.fromARGB(255, 15, 76, 167));
    final color = Theme.of(context);
    return Scaffold(
      backgroundColor: color.scaffoldBackgroundColor,
      body: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            elevation: 15,
            margin: EdgeInsets.zero,
            color: color.primaryColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: color.scaffoldBackgroundColor,
              labelColor: color.scaffoldBackgroundColor,
              unselectedLabelColor: color.hintColor,
              tabs: [
                Tab(
                  text: 'RECENT EVENTS',
                  icon: Icon(Icons.event, color: color.scaffoldBackgroundColor),
                ),
                Tab(
                  text: 'TACTSO BRACHES',
                  icon: Icon(
                    Icons.location_city_outlined,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
                Tab(
                  text: 'TACT MUSIC',
                  icon: Icon(
                    Ionicons.musical_notes_outline,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 10),
                        SizedBox(height: 10),
                        Card(
                          color: Colors.transparent,
                          elevation: 4,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: color.primaryColor,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(0.5),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(19.5),
                                  color: color.scaffoldBackgroundColor,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8.0,
                                        right: 8,
                                      ),
                                      child: Text(
                                        'Daily Verse',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: color.primaryColor,
                                        ),
                                      ),
                                    ),
                                    Divider(thickness: 0.8),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 15.0,
                                        right: 15.0,
                                      ),
                                      child: Text(
                                        '"For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future."',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w100,
                                          color: color.primaryColor,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        '- Jeremiah 29:11',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: color.primaryColor.withOpacity(
                                            0.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upcoming Events',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color.primaryColor.withOpacity(0.8),
                          ),
                        ),
                        SizedBox(height: 5),
                        FutureBuilder(
                          future: FirebaseFirestore.instance
                              .collection('upcoming_events')
                              .get(),
                          builder: (context, snapshots) {
                            return GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  scrollControlDisabledMaxHeightRatio: 0.8,
                                  context: context,
                                  builder: (context) {
                                    return EventDetailBottomSheet(
                                      posterUrl: 'assets/Poster.jpg',
                                      date: '17',
                                      eventMonth: 'Aug',
                                      title: 'Music Concert',
                                      description:
                                          'Join us for a musical evening with Overseer MJ Kubheka.',
                                    );
                                  },
                                );
                              },
                              child: UpcomingEventsCard(
                                date: '17',
                                eventMonth: 'Aug',
                                eventTitle: 'Music Concert',
                                eventDescription:
                                    'Join us for a musical evening with Overseer MJ Kubheka.',
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 5),
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              scrollControlDisabledMaxHeightRatio: 0.8,
                              context: context,
                              builder: (context) {
                                return EventDetailBottomSheet(
                                  date: '18',
                                  eventMonth: 'Aug',
                                  title: 'Community Service',
                                  description:
                                      'Participate in our community service event.',
                                );
                              },
                            );
                          },
                          child: UpcomingEventsCard(
                            date: '18',
                            eventMonth: 'Aug',
                            eventTitle: 'Community Service',
                            eventDescription:
                                'Participate in our community service event.',
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              scrollControlDisabledMaxHeightRatio: 0.8,
                              context: context,
                              builder: (context) {
                                return EventDetailBottomSheet(
                                  date: '20',
                                  eventMonth: 'Sep',
                                  title: 'TACTSO SPORTS & MUSIC FESTIVAL',
                                  description:
                                      'Join us for a day of sports and music with TTACTSO.',
                                );
                              },
                            );
                          },
                          child: UpcomingEventsCard(
                            date: '20',
                            eventMonth: 'Sep',
                            eventTitle: 'TACTSO SPORTS & MUSIC FESTIVAL',
                            eventDescription:
                                'Join us for a day of sports and music with TTACTSO.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                FutureBuilder(
                  future: FirebaseFirestore.instance
                      .collection('tactso_branches')
                      .orderBy('createdAt', descending: true)
                      .get(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Shimmer.fromColors(
                        baseColor: color.hintColor.withOpacity(0.3),
                        highlightColor: color.hintColor.withOpacity(0.1),
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: 6.0,
                          runSpacing: 12.0,
                          children: List.generate(
                            4,
                            (index) => SizedBox(
                              // Show 4 shimmer cards
                              width: MediaQuery.of(context).size.width / 2 - 12,
                              height:
                                  150, // Approximate height of UniversityCard
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading branches'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No branches found'));
                    }

                    final branchList = snapshot.data!.docs;

                    // --- NEW LOGIC: Group campuses by University Name ---
                    Map<String, List<Map<String, dynamic>>>
                    groupedUniversities = {};
                    for (var doc in branchList) {
                      final data = doc.data() as Map<String, dynamic>;
                      final universityName =
                          data['universityName'] ??
                          'Unknown University'; // Use 'universityName' field
                      if (!groupedUniversities.containsKey(universityName)) {
                        groupedUniversities[universityName] = [];
                      }
                      groupedUniversities[universityName]!.add(data);
                    }
                    // --- END NEW LOGIC ---

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          spacing: 6.0,
                          runSpacing: 12.0,
                          children: groupedUniversities.entries.map((entry) {
                            final String universityName = entry.key;
                            final List<Map<String, dynamic>> campuses =
                                entry.value;

                            // Pick one campus's data to represent the university on the main card
                            // You might want to refine this to pick a 'main' campus's details
                            // For simplicity, we'll take the first one found.
                            final Map<String, dynamic>
                            representativeCampusData = campuses.first;

                            // Determine if the main university card should show 'application open'
                            // if ANY of its campuses have applications open.
                            final bool anyCampusApplicationOpen = campuses.any(
                              (campus) => campus['isApplicationOpen'] == true,
                            );

                            return SizedBox(
                              width: MediaQuery.of(context).size.width / 2 - 12,
                              child: GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    scrollControlDisabledMaxHeightRatio: 0.8,
                                    context: context,
                                    builder: (context) {
                                      // Pass the ENTIRE list of campuses for this university
                                      // TactsoBranchDetails will need to be updated to handle this list
                                      return TactsoBranchDetails(
                                        universityDetails:
                                            representativeCampusData, // Pass a single campus map for universityDetails
                                        campusListForUniversity:
                                            representativeCampusData['campuses'], // Pass the list of all campuses
                                      );
                                    },
                                  );
                                },
                                child: UniversityCard(
                                  imageUrl:
                                      representativeCampusData['imageUrl'][0],
                                  UniName:
                                      universityName, // Use the grouped university name
                                  uniAddress:
                                      representativeCampusData['address'] ??
                                      '', // Representative address
                                  applicationLink:
                                      representativeCampusData['applicationLink'] ??
                                      '', // Representative link
                                  onPressed: () {
                                    showModalBottomSheet(
                                      scrollControlDisabledMaxHeightRatio: 0.8,
                                      context: context,
                                      builder: (context) {
                                        return TactsoBranchDetails(
                                          universityDetails:
                                              campuses as dynamic,
                                          campusListForUniversity:
                                              representativeCampusData['campuses'], // Pass the list of all campuses
                                        );
                                      },
                                    );
                                  },
                                  applicationIsOpen:
                                      anyCampusApplicationOpen, // Show if any campus is open
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ), //===========================|> The Tact Music <|==============================================
                //  ]  // ],
                DefaultTabController(
                  length:
                      5, // Number of tabs: All, Choreography, Apostle Choir, Slow Jam
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.all(15),
                              hintText: 'Search song by name... 🎶',
                              fillColor: color.hintColor,
                              focusColor: color.primaryColor,
                              hoverColor: color.primaryColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        TabBar(
                          isScrollable: true,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: color.scaffoldBackgroundColor,
                          dividerColor: Colors.transparent,
                          indicatorColor: color.primaryColor,
                          unselectedLabelColor: color.hintColor,
                          overlayColor: WidgetStatePropertyAll(
                            color.primaryColor,
                          ),
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: color.primaryColor,
                          ),
                          onTap: (index) {
                            setState(() {
                              switch (index) {
                                case 0:
                                  _selectedCategory = 'All';
                                  break;
                                case 1:
                                  _selectedCategory = 'choreography';
                                  break;
                                case 2:
                                  _selectedCategory = 'Apostle choir';
                                  break;
                                case 3:
                                  _selectedCategory = 'Slow Jam';
                                  break;
                                case 4:
                                  _selectedCategory = 'Instrumental songs';
                                  break;
                              }
                            });
                          },
                          tabs: const [
                            Tab(text: 'All'),
                            Tab(text: 'Choreography'),
                            Tab(text: 'Apostle choir'),
                            Tab(text: 'Slow Jam'),
                            Tab(text: 'Instrumental Songs'),
                          ],
                        ),
                        SizedBox(height: 10),
                        Expanded(
                          child: FutureBuilder<QuerySnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('tact_music')
                                .where(
                                  'songName',
                                  isGreaterThanOrEqualTo: _searchQuery,
                                )
                                .where(
                                  'songName',
                                  isLessThanOrEqualTo: _searchQuery + '\uf8ff',
                                )
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Shimmer.fromColors(
                                  baseColor: color.hintColor.withOpacity(0.3),
                                  highlightColor: color.hintColor.withOpacity(
                                    0.1,
                                  ),
                                  child: ListView.builder(
                                    itemCount: 10, // Show 5 shimmer items
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          height:
                                              70, // Approximate height of ListTile
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Text('No songs available'),
                                );
                              }

                              final allSongs = snapshot.data!.docs;

                              final filteredSongs = _selectedCategory == 'All'
                                  ? allSongs
                                  : allSongs.where((doc) {
                                      final songData =
                                          doc.data() as Map<String, dynamic>;
                                      return songData['category'] ==
                                          _selectedCategory;
                                    }).toList();

                              if (filteredSongs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No songs found in this category.',
                                  ),
                                );
                              }

                              return Stack(
                                children: [
                                  ListView.builder(
                                    itemCount: filteredSongs.length,
                                    itemBuilder: (context, index) {
                                      final song =
                                          filteredSongs[index].data()
                                              as Map<String, dynamic>;

                                      return Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(width: 1.5),
                                          ),
                                          child: ListTile(
                                           // Your song list widget's onTap function
// ...
onTap: () {
  _songPlayCount++;
  print('Song play count: $_songPlayCount');

  // Function to play the song, regardless of ad status
  void playSong() {
    showCupertinoSheet(
      enableDrag: true,
      context: context,
      pageBuilder: (context) {
        return PlaySong(
          songs: filteredSongs.map((doc) => doc.data() as Map<String, dynamic>).toList(),
          initialIndex: index,
        );
      },
    );
  }

  if (_songPlayCount >= 4) {
    // Show the rewarded ad with a failure callback
    adManager.showRewardedInterstitialAd(
      (ad, reward) {
        // Ad success: play the song and reset count
        print('User earned reward: ${reward.amount} ${reward.type}');
        playSong();
        _songPlayCount = 0;
      },
    );

    // **NEW:** Listen for ad load failure
    adManager.loadRewardedInterstitialAd(
      onAdFailed: () {
        // Ad failure: still play the song, but don't reset count.
        // This is a business decision. You might want to let the user
        // try again for a reward.
        playSong();
        _songPlayCount = 0; // Or don't reset it, it's your call.
      },
    );
  } else {
    // If ad counter is not met, just play the song
    playSong();
  }
}, minVerticalPadding: 1,
                                            trailing: Icon(
                                              Icons.more_vert_outlined,
                                            ),
                                            subtitle: Text(
                                              'by - ${song['artist'] ?? 'Unknown artist'} released on ${song['released'] is Timestamp ? (song['released'] as Timestamp).toDate().toString().split(' ')[0] : (song['released'] ?? 'Unknown date')}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w200,
                                                fontStyle: FontStyle.italic,
                                                fontSize: 13,
                                              ),
                                            ),
                                            title: Text(
                                              song['songName']?.toString() ??
                                                  'Untitled song',
                                            ),
                                            leading: Container(
                                              height: 50,
                                              width: 50,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(width: 1.5),
                                              ),
                                              child: Icon(
                                                Icons.music_note_outlined,
                                                color: Theme.of(
                                                  context,
                                                ).primaryColor,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 10,
                                    right: 20,
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
                                        backgroundColor: WidgetStatePropertyAll(
                                          color.splashColor,
                                        ),
                                      ),
                                      icon: Icon(Icons.download_done, size: 40),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
