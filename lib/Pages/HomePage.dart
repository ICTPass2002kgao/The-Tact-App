// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart'; 
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
  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
  }

  Map<String, dynamic> tactsoBranches = {
    'University of Cape Town': {
      'institutionName': 'University of Cape Town',
      'applicationLink': 'https://applyonline.uct.ac.za/',
      'address': 'Rondebosch, Cape Town, 7700, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7c/University_of_Cape_Town_logo.svg',
      'isApplicationOpen': true,
    },
    'University of the Witwatersrand': {
      'institutionName': 'University of the Witwatersrand',
      'applicationLink': 'https://www.wits.ac.za/applications/',
      'address':
          '1 Jan Smuts Ave, Braamfontein, Johannesburg, 2000, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/2/2e/Wits_Logo.png',
      'isApplicationOpen': true,
    },
    'Stellenbosch University': {
      'institutionName': 'Stellenbosch University',
      'applicationLink': 'https://www.sun.ac.za/english/maties/apply',
      'address':
          'Victoria St, Stellenbosch Central, Stellenbosch, 7602, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Stellenbosch_University_logo.svg',
      'isApplicationOpen': true,
    },
    'University of Pretoria': {
      'institutionName': 'University of Pretoria',
      'applicationLink': 'https://www.up.ac.za/online-application',
      'address': 'Lynnwood Rd, Hatfield, Pretoria, 0002, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7c/University_of_Pretoria_logo.svg',
      'isApplicationOpen': true,
    },
    'University of KwaZulu-Natal': {
      'institutionName': 'University of KwaZulu-Natal',
      'applicationLink': 'https://applications.ukzn.ac.za/',
      'address': 'King George V Ave, Glenwood, Durban, 4041, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/2/2a/University_of_KwaZulu-Natal_logo.svg',
      'isApplicationOpen': true,
    },
    'University of Johannesburg': {
      'institutionName': 'University of Johannesburg',
      'applicationLink': 'https://www.uj.ac.za/admission-aid/undergraduate/',
      'address':
          'Kingsway Ave, Auckland Park, Johannesburg, 2092, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/2/2b/University_of_Johannesburg_logo.svg',
      'isApplicationOpen': true,
    },
    'North-West University': {
      'institutionName': 'North-West University',
      'applicationLink':
          'https://studies.nwu.ac.za/undergraduate-studies/apply',
      'address': 'Hoffman St, Potchefstroom, 2531, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7d/North-West_University_logo.svg',
      'isApplicationOpen': true,
    },
    'University of the Western Cape': {
      'institutionName': 'University of the Western Cape',
      'applicationLink': 'https://www.uwc.ac.za/study-at-uwc/apply-now',
      'address': 'Robert Sobukwe Rd, Bellville, Cape Town, 7535, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/8/8d/University_of_the_Western_Cape_logo.svg',
      'isApplicationOpen': true,
    },
    'Rhodes University': {
      'institutionName': 'Rhodes University',
      'applicationLink': 'https://www.ru.ac.za/admissiongateway/',
      'address': 'Drosty Rd, Grahamstown, 6139, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/6/6e/Rhodes_University_logo.svg',
      'isApplicationOpen': true,
    },
    'University of the Free State': {
      'institutionName': 'University of the Free State',
      'applicationLink': 'https://apply.ufs.ac.za/',
      'address':
          '205 Nelson Mandela Dr, Park West, Bloemfontein, 9301, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/2/2e/University_of_the_Free_State_logo.svg',
      'isApplicationOpen': true,
    },
    'Nelson Mandela University': {
      'institutionName': 'Nelson Mandela University',
      'applicationLink': 'https://applyonline.mandela.ac.za/',
      'address': 'University Way, Summerstrand, Gqeberha, 6031, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/2/2c/Nelson_Mandela_University_logo.svg',
      'isApplicationOpen': true,
    },
    'University of Fort Hare': {
      'institutionName': 'University of Fort Hare',
      'applicationLink': 'https://www.ufh.ac.za/apply/',
      'address': '50 Church St, Alice, 5700, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7d/University_of_Fort_Hare_logo.svg',
      'isApplicationOpen': true,
    },
    'University of Limpopo': {
      'institutionName': 'University of Limpopo',
      'applicationLink': 'https://www.ul.ac.za/index.php?Entity=Apply%20Now',
      'address': 'University Rd, Mankweng, Polokwane, 0727, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7b/University_of_Limpopo_logo.svg',
      'isApplicationOpen': true,
    },
    'University of Venda': {
      'institutionName': 'University of Venda',
      'applicationLink': 'https://www.univen.ac.za/apply/',
      'address': 'University Rd, Thohoyandou, 0950, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/University_of_Venda_logo.svg',
      'isApplicationOpen': true,
    },
    'Walter Sisulu University': {
      'institutionName': 'Walter Sisulu University',
      'applicationLink':
          'https://www.wsu.ac.za/index.php/wsu-online-application',
      'address': 'Mthatha, Eastern Cape, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7d/Walter_Sisulu_University_logo.svg',
      'isApplicationOpen': true,
    },
    'Cape Peninsula University of Technology': {
      'institutionName': 'Cape Peninsula University of Technology',
      'applicationLink': 'https://www.cput.ac.za/study/apply',
      'address': 'Symphony Way, Bellville, Cape Town, 7535, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Cape_Peninsula_University_of_Technology_logo.svg',
      'isApplicationOpen': true,
    },
    'Durban University of Technology': {
      'institutionName': 'Durban University of Technology',
      'applicationLink': 'https://www.dut.ac.za/apply-to-dut/',
      'address': 'Steve Biko Campus, Durban, 4001, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Durban_University_of_Technology_logo.svg',
      'isApplicationOpen': true,
    },
    'Tshwane University of Technology': {
      'institutionName': 'Tshwane University of Technology',
      'applicationLink':
          'https://www.tut.ac.za/study-at-tut/i-want-to-study/apply',
      'address':
          'Staatsartillerie Rd, Pretoria West, Pretoria, 0183, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Tshwane_University_of_Technology_logo.svg',
      'isApplicationOpen': true,
    },
    'Vaal University of Technology': {
      'institutionName': 'Vaal University of Technology',
      'applicationLink': 'https://www.vut.ac.za/apply-to-vut/',
      'address': 'Andries Potgieter Blvd, Vanderbijlpark, 1900, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Vaal_University_of_Technology_logo.svg',
      'isApplicationOpen': true,
    },

    'Mangosuthu University of Technology': {
      'institutionName': 'Mangosuthu University of Technology',
      'applicationLink': 'https://www.mut.ac.za/apply-to-mut/',
      'address': '511 Griffiths Mxenge Hwy, Umlazi, Durban, 4066, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Mangosuthu_University_of_Technology_logo.svg',
      'isApplicationOpen': true,
    },
    'Sol Plaatje University': {
      'institutionName': 'Sol Plaatje University',
      'applicationLink': 'https://www.spu.ac.za/index.php/how-to-apply/',
      'address': 'Danie Theron St, Civic Centre, Kimberley, 8300, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Sol_Plaatje_University_logo.svg',
      'isApplicationOpen': true,
    },
    'Sefako Makgatho Health Sciences University': {
      'institutionName': 'Sefako Makgatho Health Sciences University',
      'applicationLink': 'https://www.smu.ac.za/students/applications/',
      'address': 'Molotlegi St, Ga-Rankuwa, Pretoria, 0208, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Sefako_Makgatho_Health_Sciences_University_logo.svg',
      'isApplicationOpen': true,
    },
    'University of Zululand': {
      'institutionName': 'University of Zululand',
      'applicationLink': 'https://www.unizulu.ac.za/apply-to-unizulu/',
      'address': '1 Main Rd, Vulindlela, KwaDlangezwa, 3886, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/University_of_Zululand_logo.svg',
      'isApplicationOpen': true,
    },
    'Central University of Technology': {
      'institutionName': 'Central University of Technology',
      'applicationLink': 'https://www.cut.ac.za/application-process',
      'address': '1 Park Rd, Bloemfontein, 9301, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/Central_University_of_Technology_logo.svg',
      'isApplicationOpen': true,
    },
    'University of South Africa': {
      'institutionName': 'University of South Africa',
      'applicationLink':
          'https://www.unisa.ac.za/sites/corporate/default/Apply-for-admission',
      'address': 'Preller St, Muckleneuk, Pretoria, 0002, South Africa',
      'imageUrl':
          'https://upload.wikimedia.org/wikipedia/en/7/7e/University_of_South_Africa_logo.svg',
      'isApplicationOpen': true,
    },
  };

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
                        StreamBuilder(
                          stream: FirebaseFirestore.instance
                              .collection('upcoming_events')
                              .snapshots(),
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
                //##########################   Available Tactso Branches tab ################################
                StreamBuilder(
                  stream: FirebaseFirestore.instance
                      .collection('tactso_branches')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading branches'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No branches found'));
                    }

                    final branchList = snapshot.data!.docs;

                    return SingleChildScrollView(
                      // Use SingleChildScrollView to allow scrolling if Wrap content exceeds screen height
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ), // Add some padding around the wrap
                        child: Wrap(
                          alignment:
                              WrapAlignment.start, // Align items to the start
                          spacing: 6.0, // Horizontal spacing between cards
                          runSpacing:
                              12.0, // Vertical spacing between rows of cards
                          children: branchList.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return SizedBox(
                              // Wrap each card in a SizedBox to give it a fixed width for two columns
                              width:
                                  MediaQuery.of(context).size.width / 2 -
                                  12, // Roughly half screen width minus spacing
                              child: GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    scrollControlDisabledMaxHeightRatio: 0.8,
                                    context: context,
                                    builder: (context) {
                                      return TactsoBranchDetails(
                                        universityDetails: data,
                                      );
                                    },
                                  );
                                },
                                child: UniversityCard(
                                  imageUrl: data['imageUrl'][0],
                                  UniName: data['institutionName'] ?? '',
                                  uniAddress: data['address'] ?? '',
                                  applicationLink:
                                      data['applicationLink'] ?? '',
                                  onPressed: () {
                                    showModalBottomSheet(
                                      scrollControlDisabledMaxHeightRatio: 0.8,
                                      context: context,
                                      builder: (context) {
                                        return TactsoBranchDetails(
                                          universityDetails: data,
                                        );
                                      },
                                    );
                                  },
                                  applicationIsOpen:
                                      data['isOpplicationOpen'] ?? false,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
                //===========================|> The Tact Music <|==============================================
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
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('tact_music')
                                .where(
                                  'songName',
                                  isGreaterThanOrEqualTo: _searchQuery,
                                )
                                .where(
                                  'songName',
                                  isLessThanOrEqualTo: _searchQuery + '\uf8ff',
                                )
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(),
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
                                            onTap: () {
                                              showCupertinoSheet(
                                                enableDrag: true,
                                                context: context,
                                                pageBuilder: (context) {
                                                  return PlaySong(
                                                    songs: filteredSongs
                                                        .map(
                                                          (doc) =>
                                                              doc.data()
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >,
                                                        )
                                                        .toList(),
                                                    initialIndex: index,
                                                  );
                                                },
                                              );
                                            },
                                            minVerticalPadding: 1,
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
