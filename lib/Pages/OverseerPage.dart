import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:pdf/pdf.dart'; // Import for PDF generation
import 'package:pdf/widgets.dart' as pw; // Import for PDF widgets
import 'package:printing/printing.dart'; // Import for printing/sharing
import 'package:path_provider/path_provider.dart'; // Import for path provider
import 'package:ttact/Components/Play_Song.dart';
import 'dart:io';

import 'package:ttact/Pages/Downloaded_Songs.dart';
import 'package:ttact/Pages/HomePage.dart'; // For File operations

class OverseerPage extends StatefulWidget {
  const OverseerPage({super.key});

  @override
  State<OverseerPage> createState() => _OverseerPageState();
}

class _OverseerPageState extends State<OverseerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Uint8List? _logoBytes;

  String _selectedCategory =
      'All';  
  String _searchQuery = '';
  int _songPlayCount = 0;  
  final AdManager adManager = AdManager();  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadLogoBytes();
  }

  Future<void> _loadLogoBytes() async {
    try {
      final ByteData bytes = await rootBundle.load('assets/tact_logo.PNG');
      setState(() {
        _logoBytes = bytes.buffer.asUint8List();
      });
    } catch (e) {
      _logoBytes = null;
    }
  }

  TextEditingController _searchController = TextEditingController();

  final TextEditingController memberNameController = TextEditingController();
  final TextEditingController memberEmailController = TextEditingController();
  final TextEditingController memberAddressController = TextEditingController();
  final TextEditingController memberContactController = TextEditingController();
  final TextEditingController memberSurnameController = TextEditingController();
  final TextEditingController week1Controller = TextEditingController();
  final TextEditingController week2Controller = TextEditingController();
  final TextEditingController week3Controller = TextEditingController();
  final TextEditingController week4Controller = TextEditingController();
  double week1 = 0.0;
  double week2 = 0.0;
  double week3 = 0.0;
  double week4 = 0.0;
  String? selectedDistrictElder;
  String? selectedCommunityElder;
  String? selectedCommunityName;
  String selectedProvince = '';
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Overseer Page'), centerTitle: true),
      backgroundColor: color.scaffoldBackgroundColor,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: color.primaryColor),
              child: Text(
                'Overseer Dashboard',
                style: TextStyle(
                  color: color.scaffoldBackgroundColor,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.person),
              title: Text('Help'),
              onTap: () {
                showCupertinoDialog(
                  context: context,
                  builder: (context) {
                    return CupertinoAlertDialog(
                      title: Text('Help'),
                      content: Text('This is the help dialog.'),
                      actions: [
                        CupertinoDialogAction(
                          child: Text('OK'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: 'Dashboard'),
              Tab(text: 'Music'),
              Tab(text: 'Add Member'),
              Tab(text: 'All Members'),
              Tab(text: 'Reports'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Dashboard Tab with Graphs
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tithe Offerings (Last 4 Weeks)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        FutureBuilder(
                          future: FirebaseFirestore.instance
                              .collection('users')
                              .where(
                                'overseerUid',
                                isEqualTo:
                                    FirebaseAuth.instance.currentUser?.uid,
                              )
                              .get(),
                          builder: (context, asyncSnapshot) {
                            if (asyncSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }
                            if (asyncSnapshot.hasError) {
                              return Center(
                                child: Text('Error: ${asyncSnapshot.error}'),
                              );
                            }
                            if (!asyncSnapshot.hasData ||
                                asyncSnapshot.data!.docs.isEmpty) {
                              return Center(child: Text('No members found.'));
                            }
                            var totalMembers = asyncSnapshot.data!.docs.length;
                            var data = asyncSnapshot.data!.docs;
                            return Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: color.primaryColor.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18.0),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Total Overseer Members',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 23,
                                                  fontWeight: FontWeight.bold,
                                                  color: color
                                                      .scaffoldBackgroundColor,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.person,
                                              color:
                                                  color.scaffoldBackgroundColor,
                                              size: 60,
                                            ),
                                          ],
                                        ),
                                        Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '$totalMembers',
                                                style: TextStyle(
                                                  fontSize: 50,
                                                  fontWeight: FontWeight.bold,
                                                  color: color
                                                      .scaffoldBackgroundColor,
                                                ),
                                              ),
                                              SizedBox(width: 20),
                                              Icon(
                                                Icons.group,
                                                color: color
                                                    .scaffoldBackgroundColor,
                                                size: 60,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: 15),
                                FutureBuilder(
                                  future: FirebaseFirestore.instance
                                      .collection('overseers')
                                      .where(
                                        'uid',
                                        isEqualTo: FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.uid,
                                      )
                                      .get(),
                                  builder: (context, asyncSnapshot) {
                                    if (asyncSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    var oveerData = asyncSnapshot.data!.docs;
                                    return Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: color.primaryColor.withBlue(130),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(18.0),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    'Total Overseer Districts:',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 23,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: color
                                                          .scaffoldBackgroundColor,
                                                    ),
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.person,
                                                  color: color
                                                      .scaffoldBackgroundColor,
                                                  size: 60,
                                                ),
                                              ],
                                            ),
                                            Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  for (var info in oveerData)
                                                    Text(
                                                      '${info?['districts'].length ?? 0}',
                                                      style: TextStyle(
                                                        fontSize: 50,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: color
                                                            .scaffoldBackgroundColor,
                                                      ),
                                                    ),
                                                  SizedBox(width: 20),
                                                  Icon(
                                                    Icons.group,
                                                    color: color
                                                        .scaffoldBackgroundColor,
                                                    size: 60,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Mussic Tab
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
                                            onTap: () {
                                              _songPlayCount++;
                                              print(
                                                'Song play count: $_songPlayCount',
                                              );
                                  void playSong() {
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
                                              }

                                              if (_songPlayCount >= 4) { 
                                                     adManager.showRewardedInterstitialAd((
                                                  ad,
                                                  reward,
                                                ) { 
                                                  print(
                                                    'User earned reward: ${reward.amount} ${reward.type}',
                                                  );
                                                  playSong();
                                                  _songPlayCount = 0;
                                                });
                                                AdManager().loadRewardedInterstitialAd(
                                                  onAdFailed: () { 
                                                    playSong();
                                                    _songPlayCount =
                                                        0;   },
                                                );
                                              } else { 
                                                playSong();
                                                
                                              }
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

                // Add Member Tab
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView(
                    children: [
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberNameController,
                        placeholder: 'Enter Member Name',
                        padding: EdgeInsets.all(16.0),
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberSurnameController,
                        placeholder: 'Enter Member Surname',
                        padding: EdgeInsets.all(16.0),
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberEmailController,
                        placeholder: 'Enter Member Email (Optional)',
                        padding: EdgeInsets.all(16.0),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberAddressController,
                        placeholder: 'Enter Member Address',
                        padding: EdgeInsets.all(16.0),
                      ),
                      SizedBox(height: 10),
                      CupertinoTextField(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18.0),
                          border: Border.all(color: color.primaryColor),
                        ),
                        controller: memberContactController,
                        placeholder: 'Enter Contact Number',
                        padding: EdgeInsets.all(16.0),
                      ),
                      SizedBox(height: 10),

                      // Dropdown selection for District Elder, Community Elder, and Community Name
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('overseers')
                            .where(
                              'uid',
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                            )
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text('No overseer data found.'),
                            );
                          }
                          var overseerData =
                              snapshot.data!.docs.first.data()
                                  as Map<String, dynamic>;

                          selectedProvince = overseerData['province'];

                          List<dynamic> districts =
                              overseerData['districts'] ?? [];

                          // Find the selected district object
                          Map<String, dynamic>? selectedDistrict = districts
                              .firstWhere(
                                (d) =>
                                    d['districtElderName'] ==
                                    selectedDistrictElder,
                                orElse: () => null,
                              );

                          // Get unique district elder names
                          List<String> districtElderNames = districts
                              .map((d) => d['districtElderName'] as String?)
                              .where((name) => name != null)
                              .cast<String>()
                              .toSet()
                              .toList();

                          // Get unique community elder names and community names for selected district
                          List<String> communityElderNames =
                              selectedDistrict != null
                              ? (selectedDistrict['communities']
                                            as List<dynamic>?)
                                        ?.map(
                                          (c) =>
                                              c['communityElderName']
                                                  as String?,
                                        )
                                        .where((name) => name != null)
                                        .cast<String>()
                                        .toSet()
                                        .toList() ??
                                    []
                              : [];
                          List<String> communityNames = selectedDistrict != null
                              ? (selectedDistrict['communities']
                                            as List<dynamic>?)
                                        ?.map(
                                          (c) => c['communityName'] as String?,
                                        )
                                        .where((name) => name != null)
                                        .cast<String>()
                                        .toSet()
                                        .toList() ??
                                    []
                              : [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              DropdownButton<String>(
                                menuWidth: double.infinity,
                                value: selectedDistrictElder,
                                hint: Text('Choose a District Elder'),
                                items: districtElderNames
                                    .map(
                                      (e) => DropdownMenuItem(
                                        alignment: Alignment.center,
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedDistrictElder = value;
                                    // Update selectedDistrict and reset community selections
                                    selectedDistrict = districts.firstWhere(
                                      (d) => d['districtElderName'] == value,
                                      orElse: () => null,
                                    );
                                    selectedCommunityElder = null;
                                    selectedCommunityName = null;
                                  });
                                },
                              ),
                              if (selectedDistrictElder != null) ...[
                                DropdownButton<String>(
                                  menuWidth: double.infinity,
                                  value: selectedCommunityElder,
                                  hint: Text('Choose a Community Elder'),
                                  items: communityElderNames
                                      .map(
                                        (e) => DropdownMenuItem(
                                          alignment: Alignment.center,

                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCommunityElder = value;
                                    });
                                  },
                                ),
                                DropdownButton<String>(
                                  menuWidth: double.infinity,
                                  value: selectedCommunityName,
                                  hint: Text('Choose a Community Name'),
                                  items: communityNames
                                      .map(
                                        (e) => DropdownMenuItem(
                                          alignment: Alignment.center,
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCommunityName = value;
                                    });
                                  },
                                ),
                              ],
                              SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                      CustomOutlinedButton(
                        onPressed: () async {
                          if (memberNameController.text.isEmpty ||
                              memberSurnameController.text.isEmpty ||
                              memberAddressController.text.isEmpty ||
                              memberContactController.text.isEmpty) {
                            Api().showMessage(
                              context,
                              'Please fill in all fields',
                              'Error',
                              color.primaryColorDark,
                            );
                            return;
                          }
                          try {
                            Api().showLoading(context);
                            FirebaseFirestore firestore =
                                FirebaseFirestore.instance;
                            await firestore.collection('users').add({
                              'name': memberNameController.text,
                              'surname': memberSurnameController.text,
                              'email': memberEmailController.text,
                              'address': memberAddressController.text,
                              'phone': memberContactController.text,
                              'overseerUid':
                                  FirebaseAuth.instance.currentUser?.uid,
                              'role': 'Member',
                              'week1': 0.00,
                              'week2': 0.00,
                              'week3': 0.00,
                              'week4': 0.00,
                              "province": selectedProvince,
                              "districtElderName": selectedDistrictElder,
                              "communityElderName": selectedCommunityElder,
                              "communityName": selectedCommunityName,
                            });
                            Navigator.of(context);
                            Api().showMessage(
                              context,
                              'Member added successfully',
                              'Success',
                              color.splashColor,
                            );
                          } catch (error) {
                            Api().showMessage(
                              context,
                              'Failed to add member: $error',
                              'Error',
                              color.primaryColorDark,
                            );
                          }

                          memberNameController.clear();
                          memberSurnameController.clear();
                          memberEmailController.clear();
                          memberAddressController.clear();
                          memberContactController.clear();
                        },
                        text: 'Add Member',
                        backgroundColor: color.primaryColor,
                        foregroundColor: Colors.white,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),

                // All Members Tab
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where(
                        'overseerUid',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                      )
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No members found.'));
                    }
                    final members = snapshot.data!.docs;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: CupertinoTextField(
                            controller:
                                _searchController, // Assign the controller
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.0),
                              border: Border.all(color: color.primaryColor),
                            ),
                            placeholder: 'Search Members',
                            // onChanged is now handled by the listener on _searchController
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final member = members[index];
                              return Column(
                                children: [
                                  Card(
                                    color: color.scaffoldBackgroundColor
                                        .withOpacity(0.7),
                                    elevation: 5,
                                    margin: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.person,
                                        color: color.primaryColor,
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${member['name']} ${member['surname'] ?? ''}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: color.primaryColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (member['email'].isNotEmpty)
                                              Text(
                                                '${member['email'] ?? 'N/A'}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            Text(
                                              '${member['address'] ?? 'N/A'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${member['phone'] ?? 'N/A'}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      trailing: IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () async {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              backgroundColor: color
                                                  .scaffoldBackgroundColor
                                                  .withOpacity(0.8),
                                              title: Text('Edit Member'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CupertinoTextField(
                                                    controller: week1Controller,
                                                    placeholder: 'Week 1',
                                                  ),
                                                  SizedBox(height: 10),
                                                  CupertinoTextField(
                                                    controller: week2Controller,
                                                    placeholder: 'Week 2',
                                                  ),
                                                  SizedBox(height: 10),
                                                  CupertinoTextField(
                                                    controller: week3Controller,
                                                    placeholder: 'Week 3',
                                                  ),
                                                  SizedBox(height: 10),
                                                  CupertinoTextField(
                                                    controller: week4Controller,
                                                    placeholder: 'Week 4',
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                  },
                                                  child: Text('Cancel'),
                                                ),
                                                SizedBox(height: 10),

                                                TextButton(
                                                  onPressed: () async {
                                                    Api().showLoading(context);
                                                    week1 =
                                                        double.tryParse(
                                                          week1Controller.text,
                                                        ) ??
                                                        0.0;
                                                    week2 =
                                                        double.tryParse(
                                                          week2Controller.text,
                                                        ) ??
                                                        0.0;
                                                    week3 =
                                                        double.tryParse(
                                                          week3Controller.text,
                                                        ) ??
                                                        0.0;
                                                    week4 =
                                                        double.tryParse(
                                                          week4Controller.text,
                                                        ) ??
                                                        0.0;

                                                    await FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(member.id)
                                                        .update({
                                                          'week1': week1,
                                                          'week2': week2,
                                                          'week3': week3,
                                                          'week4': week4,
                                                        });
                                                    Navigator.pop(context);
                                                    Navigator.pop(context);

                                                    week1Controller.clear();
                                                    week2Controller.clear();
                                                    week3Controller.clear();
                                                    week4Controller.clear();
                                                    Api().showMessage(
                                                      context,
                                                      'Member updated successfully',
                                                      'Success',
                                                      color.splashColor,
                                                    );
                                                  },
                                                  child: Text('Save'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                      onTap: () {
                                        Api().showMessage(
                                          context,
                                          'Tapped on ${member['name']}',
                                          'Info',
                                          color.primaryColor,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Reports Tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('overseers')
                        .get(),
                    builder: (context, asyncSnapshot) {
                      var overseerData = asyncSnapshot.data?.docs ?? [];
                      if (asyncSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (overseerData.isEmpty) {
                        return Center(child: Text('No overseers found.'));
                      }
                      var overseer =
                          overseerData.first.data() as Map<String, dynamic>?;
                      String province = overseer?['province'] ?? 'N/A';
                      return Center(
                        child: GestureDetector(
                          onTap: () async {
                            FirebaseFirestore firestore =
                                FirebaseFirestore.instance;
                            QuerySnapshot<Map<String, dynamic>> snapshot =
                                await firestore
                                    .collection('overseers')
                                    .where(
                                      'uid',
                                      isEqualTo: FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid,
                                    )
                                    .get();

                            var overseerData = snapshot.docs.isNotEmpty
                                ? snapshot.docs.first.data()
                                : null;
                            String overseerName =
                                overseerData?['name'] ?? 'N/A';
                            String overseerSurname =
                                overseerData?['surname'] ?? 'N/A';

                            // Assuming these are declared in your State class
                            String? selectedProvince = province;

                            // You'll also need a way to store the currently selected district object
                            // so you can filter communities based on it.
                            Map<String, dynamic>? selectedDistrict;

                            // Function to get distinct district elder names
                            List<String> getDistrictElderNames(
                              Map<String, dynamic>? data,
                            ) {
                              if (data == null ||
                                  !data.containsKey('districts') ||
                                  data['districts'] == null) {
                                return [];
                              }
                              return (data['districts'] as List<dynamic>)
                                  .map(
                                    (district) =>
                                        district['districtElderName']
                                            as String?,
                                  )
                                  .where((name) => name != null)
                                  .cast<String>()
                                  .toSet() // Use a Set to get unique names
                                  .toList();
                            }

                            // Function to get community elder names for a given district
                            List<String> getCommunityElderNamesForDistrict(
                              Map<String, dynamic>? district,
                            ) {
                              if (district == null ||
                                  !district.containsKey('communities') ||
                                  district['communities'] == null) {
                                return [];
                              }
                              return (district['communities'] as List<dynamic>)
                                  .map(
                                    (community) =>
                                        community['communityElderName']
                                            as String?,
                                  )
                                  .where((name) => name != null)
                                  .cast<String>()
                                  .toSet() // Use a Set to get unique names
                                  .toList();
                            }

                            // Function to get community names for a given district
                            List<String> getCommunityNamesForDistrict(
                              Map<String, dynamic>? district,
                            ) {
                              if (district == null ||
                                  !district.containsKey('communities') ||
                                  district['communities'] == null) {
                                return [];
                              }
                              return (district['communities'] as List<dynamic>)
                                  .map(
                                    (community) =>
                                        community['communityName'] as String?,
                                  )
                                  .where((name) => name != null)
                                  .cast<String>()
                                  .toSet() // Use a Set to get unique names
                                  .toList();
                            }

                            // Your showBottomSheet function
                            showModalBottomSheet(
                              showDragHandle: true,
                              sheetAnimationStyle: AnimationStyle(
                                duration: Duration(milliseconds: 300),
                                reverseDuration: Duration(milliseconds: 300),
                              ),
                              context: context,
                              builder: (context) {
                                return StatefulBuilder(
                                  builder: (context, setState) {
                                    // Prepare lists for dropdowns
                                    final List<String> districtElderNames =
                                        getDistrictElderNames(overseerData);
                                    final List<String> communityElderNames =
                                        getCommunityElderNamesForDistrict(
                                          selectedDistrict,
                                        );
                                    final List<String> communityNames =
                                        getCommunityNamesForDistrict(
                                          selectedDistrict,
                                        );

                                    return Center(
                                      child: Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.all(
                                          16.0,
                                        ), // This creates the horizontal margin, making it "fuller" within the screen
                                        decoration: BoxDecoration(
                                          color: color
                                              .scaffoldBackgroundColor, // Background color of the sheet
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ), // Rounded corners
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 10,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              DropdownButton<String>(
                                                value: selectedDistrictElder,
                                                hint: Text(
                                                  'Choose a District Elder',
                                                ),
                                                items: districtElderNames
                                                    .map(
                                                      (e) => DropdownMenuItem(
                                                        value: e,
                                                        child: Text(e),
                                                      ),
                                                    )
                                                    .toList(),
                                                onChanged: (value) {
                                                  setState(() {
                                                    selectedDistrictElder =
                                                        value;
                                                    // When a district elder is selected, find the corresponding district
                                                    // and update the selectedDistrict. This allows filtering communities.
                                                    selectedDistrict =
                                                        (overseerData?['districts']
                                                                    as List<
                                                                      dynamic
                                                                    >?)
                                                                ?.firstWhere(
                                                                  (district) =>
                                                                      district['districtElderName'] ==
                                                                      value,
                                                                  orElse: () =>
                                                                      null,
                                                                )
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >?;

                                                    // Reset community selections if district changes
                                                    selectedCommunityElder =
                                                        null;
                                                    selectedCommunityName =
                                                        null;
                                                  });
                                                },
                                              ),
                                              if (selectedDistrictElder !=
                                                  null) ...[
                                                DropdownButton<String>(
                                                  value: selectedCommunityElder,
                                                  hint: Text(
                                                    'Choose a Community Elder',
                                                  ),
                                                  items: communityElderNames
                                                      .map(
                                                        (e) => DropdownMenuItem(
                                                          value: e,
                                                          child: Text(e),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      selectedCommunityElder =
                                                          value;
                                                    });
                                                  },
                                                ),
                                                DropdownButton<String>(
                                                  value: selectedCommunityName,
                                                  hint: Text(
                                                    'Choose a Community Name',
                                                  ),
                                                  items: communityNames
                                                      .map(
                                                        (e) => DropdownMenuItem(
                                                          value: e,
                                                          child: Text(e),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      selectedCommunityName =
                                                          value;
                                                    });
                                                  },
                                                ),
                                              ],
                                              SizedBox(height: 20),
                                              CustomOutlinedButton(
                                                onPressed: () async {
                                                  // Add validation here if needed to ensure all are selected
                                                  if (selectedDistrictElder !=
                                                          null &&
                                                      selectedCommunityElder !=
                                                          null &&
                                                      selectedCommunityName !=
                                                          null) {
                                                    Navigator.pop(context);
                                                    await _generatePdfAndDownload(
                                                      selectedDistrictElder!,
                                                      selectedCommunityElder!,
                                                      selectedCommunityName!,
                                                      selectedProvince,
                                                      overseerName,
                                                      overseerSurname,
                                                      overseerData!,
                                                    );
                                                  } else {
                                                    // Show a snackbar or alert to inform the user to select all fields
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Please select all fields.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                                text:
                                                    'Generate Balance sheet (PDF)',
                                                backgroundColor: color
                                                    .scaffoldBackgroundColor,
                                                foregroundColor:
                                                    color.primaryColor,
                                                width: double.infinity,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            );
                          },

                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    border: Border.all(width: 2),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Center(
                                          child: Icon(
                                            Icons.file_download_outlined,
                                            size: 50,
                                          ),
                                        ),
                                        SizedBox(height: 20),
                                        Center(
                                          child: Text(
                                            'Download Balance Sheet a PDF',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PDF Generation Logic ---
  // --- PDF Generation Logic ---
  Future<void> _generatePdfAndDownload(
    String selectedDistrictElder,
    String selectedCommunityElder,
    String selectedCommunityName,
    String selectedProvince,
    String overseerName,
    String overseerSurname,
    Map<String, dynamic> overseerData,
  ) async {
    Api().showLoading(context); // Show loading indicator
    try {
      final balanceSheetTable = await _buildPdfBalanceSheetTable(
        context,
        selectedDistrictElder,
        selectedCommunityName,
        selectedCommunityElder,
      );

      // Check if the balanceSheetTable is null (meaning no members were found)
      if (balanceSheetTable == null) {
        Navigator.pop(context); // Dismiss loading dialog
        return; // Exit the function to prevent further execution
      }

      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              if (_logoBytes != null)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Image(
                      pw.MemoryImage(_logoBytes!),
                      width: 100,
                      height: 100,
                    ),
                    pw.Column(
                      children: [
                        pw.Center(
                          child: pw.Text(
                            'The Twelve Apostles Church in Trinity',
                            style: pw.TextStyle(
                              fontSize: 20,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Center(
                          child: pw.Text('P. O. Box 40376, Red Hill, 4071'),
                        ),
                        pw.Center(
                          child: pw.Text('Tel./Fax No\'s: (031) 569 6164'),
                        ),
                        pw.Center(
                          child: pw.Text('Email: thetacc@telkomsa.net'),
                        ),
                      ],
                    ),
                  ],
                ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Income and Expenditure Statement',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfTextRow(
                'For the Month:',
                '${DateTime.now().month}',
                'Year:',
                '${DateTime.now().year}',
              ),
              _buildPdfTextRow(
                'Overseer:',
                '$overseerName $overseerSurname',
                'Code No:',
                '________',
              ),
              _buildPdfTextRow('District Elder:', '$selectedDistrictElder'),
              _buildPdfTextRow('Community Elder:', '$selectedCommunityElder'),
              _buildPdfTextRow('Community Name:', '$selectedCommunityName'),
              _buildPdfTextRow(
                'Province: ${overseerData['province']}',
                '',
                'Region:',
                '__________',
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text(
                'Income / Receipts',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Tithe Offerings - Week 1', 'R', 'c'),
              _buildPdfReportRow('Tithe Offerings - Week 2', 'R', 'c'),
              _buildPdfReportRow('Tithe Offerings - Week 3', 'R', 'c'),
              _buildPdfReportRow('Tithe Offerings - Week 4', 'R', 'c'),
              _buildPdfReportRow('Others', 'R', 'c'),
              _buildPdfReportRow('Month End', 'R', 'c'),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Total Income', 'R', 'c', isTotal: true),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Text(
                'Expenditure',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Rent Period', 'R', 'c'),
              _buildPdfReportRow('Wine and Priest Wafers', 'R', 'c'),
              _buildPdfReportRow('Power and Lights', 'R', 'c'),
              _buildPdfReportRow('Sundries/Repairs', 'R', 'c'),
              _buildPdfReportRow('Central Council', 'R', 'c'),
              _buildPdfReportRow('Equipment / General', 'R', 'c'),
              pw.SizedBox(height: 10),
              _buildPdfReportRow('Total Expenditure', 'R', 'c', isTotal: true),
              pw.SizedBox(height: 20),
              pw.Divider(),
              _buildPdfReportRow(
                'Credit Balance (Amount Banked)',
                'R',
                'c',
                isTotal: true,
                isCreditBalance: true,
              ),
              pw.SizedBox(height: 20),
              pw.Text('Bank Name: Standard Bank'),
              pw.Text('Account Name: The TACT'),
              pw.Text('Account No: 051074958'),
              pw.Text('Branch Name: Kingsmead'),
              pw.Text('Branch Code: 040026'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Please write your name and the name of your Community in the Deposit Slip Senders Details Column.',
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Balance Sheet',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfTextRow(
                'For the Month of:',
                '${DateTime.now().month}',
                'Year:',
                '${DateTime.now().year}',
              ),
              _buildPdfTextRow('Overseer:', '$overseerName $overseerSurname'),
              _buildPdfTextRow('District Elder:', '$selectedDistrictElder'),
              _buildPdfTextRow('Community Elder:', '$selectedCommunityElder'),
              _buildPdfTextRow('Community Name:', '$selectedCommunityName'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Members Tithe Offerings',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              balanceSheetTable,
              pw.SizedBox(height: 10),

              pw.SizedBox(height: 30),
              pw.Text(
                'NB: Attach all receipts and Bank Deposit Slips with Neat and Clear Details',
                style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Signatures:',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPdfSignatureRow(
                'Overseer',
                overseerName + ' ' + overseerSurname,
              ),
              _buildPdfSignatureRow('Community Elder', selectedCommunityElder),
              _buildPdfSignatureRow('Secretary', '_____________'),
              _buildPdfSignatureRow('District Elder', selectedDistrictElder),
              _buildPdfSignatureRow('Treasurer', '_____________'),
              _buildPdfSignatureRow('Contact Person', '_____________'),
              pw.SizedBox(height: 20),
              pw.Text('Telephone No: __________'),
              pw.Text('Email Address: __________'),
            ];
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/church_report.pdf');
      await file.writeAsBytes(await pdf.save());

      await Printing.sharePdf(
        bytes: await file.readAsBytes(),
        filename: 'church_report(${DateTime.now().toIso8601String()}).pdf',
      );

      Navigator.pop(context);
      Api().showMessage(
        context,
        'Report generated and ready to share!',
        'Success',
        Theme.of(context).splashColor,
      );
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        'Failed to generate PDF: $e',
        'Error',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  // Helper for PDF Balance Sheet Table
  Future<pw.Widget?> _buildPdfBalanceSheetTable(
    BuildContext context,
    String selectedDistrictElder,
    String selectedCommunityName,
    String selectedCommunityElder,
  ) async {
    FirebaseFirestore firestore = FirebaseFirestore.instance;

    var memberLatestData = await firestore
        .collection('users')
        .where('districtElderName', isEqualTo: selectedDistrictElder)
        .where('communityName', isEqualTo: selectedCommunityName)
        .where('communityElderName', isEqualTo: selectedCommunityElder)
        .where('overseerUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
        .get();

    if (memberLatestData.docs.isEmpty) {
      Api().showMessage(
        context,
        'No members found for the selected community. Please ensure your data is accurate.',
        'Error',
        Theme.of(context).primaryColorDark,
      );
      return null; // Return null to indicate no data was found
    }

    List<Map<String, dynamic>> allMembersData = [];
    for (var d in memberLatestData.docs) {
      allMembersData.add(d.data());
    }

    List<List<String>> tableData = [
      <String>[
        'Members Name and Surname',
        'WEEK 1',
        'WEEK 2',
        'WEEK 3',
        'WEEK 4',
        'MONTHLY',
      ],
    ];

    double grandTotal = 0.00;

    for (var memberData in allMembersData) {
      String memberName = memberData['name'] ?? 'N/A';
      String memberSurname = memberData['surname'] ?? 'N/A';
      String memberWeek1 = memberData['week1']?.toString() ?? '0.00';
      String memberWeek2 = memberData['week2']?.toString() ?? '0.00';
      String memberWeek3 = memberData['week3']?.toString() ?? '0.00';
      String memberWeek4 = memberData['week4']?.toString() ?? '0.00';

      var total =
          (double.parse(memberWeek1) +
                  double.parse(memberWeek2) +
                  double.parse(memberWeek3) +
                  double.parse(memberWeek4))
              .toStringAsFixed(2);

      tableData.add(<String>[
        '${memberName} ${memberSurname}',
        'R${double.parse(memberWeek1).toStringAsFixed(2)}',
        'R${double.parse(memberWeek2).toStringAsFixed(2)}',
        'R${double.parse(memberWeek3).toStringAsFixed(2)}',
        'R${double.parse(memberWeek4).toStringAsFixed(2)}',
        'R${total}',
      ]);

      grandTotal += double.parse(total);
    }

    return pw.Column(
      children: [
        pw.TableHelper.fromTextArray(
          cellAlignment: pw.Alignment.centerLeft,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            fontSize: 14,
          ),
          cellPadding: const pw.EdgeInsets.all(2),
          data: tableData,
        ),
        pw.SizedBox(height: 10),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'GRAND TOTAL: R ${grandTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // Helper for PDF text rows (e.g., "For the Month: ___ Year: ___")
  pw.Widget _buildPdfTextRow(
    String label1,
    String value1, [
    String? label2,
    String? value2,
  ]) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('$label1 $value1'),
        if (label2 != null && value2 != null) pw.Text('$label2 $value2'),
      ],
    );
  }

  // Helper for PDF report rows (income/expenditure)
  pw.Widget _buildPdfReportRow(
    String label,
    String rText,
    String cText, {
    bool isTotal = false,
    bool isCreditBalance = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.0),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: isTotal || isCreditBalance
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$rText _______',
                style: pw.TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 1,
            child: pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                '$cText _______',
                style: pw.TextStyle(
                  fontWeight: isTotal || isCreditBalance
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

   // Helper for PDF signature rows
  pw.Widget _buildPdfSignatureRow(String role, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4.0),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 2, child: pw.Text('$role:')),
          pw.Expanded(flex: 3, child: pw.Text('$value')),
          pw.SizedBox(width: 10),
          pw.Expanded(flex: 1, child: pw.Text('Signature:')),
          pw.Expanded(flex: 3, child: pw.Text('___________________')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    memberNameController.dispose();
    memberSurnameController.dispose();
    memberEmailController.dispose();
    memberAddressController.dispose();
    memberContactController.dispose();
    super.dispose();
  }
}
