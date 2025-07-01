// ignore_for_file: prefer_const_constructors

import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/ApostleCards.dart';
import 'package:ttact/Components/Color.dart';
import 'package:ttact/Components/Tab.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';
import 'package:ttact/Components/bottomsheet.dart';

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
                  text: 'Recent Events',
                  icon: Icon(Icons.event, color: color.scaffoldBackgroundColor),
                ),
                Tab(
                  text: 'Overseers',
                  icon: Icon(
                    Icons.people,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
                Tab(
                  text: 'TACTSO',
                  icon: Icon(Icons.group, color: color.scaffoldBackgroundColor),
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ApostleCard(
                                name: 'S.D Ndlovu',
                                age: '78',
                                potforlio: 'President',
                              ),
                              ApostleCard(
                                name: 'S.D Ndlovu',
                                age: '78',
                                potforlio: 'President',
                              ),
                              ApostleCard(
                                name: 'S.D Ndlovu',
                                age: '78',
                                potforlio: 'President',
                              ),
                              ApostleCard(
                                name: 'S.D Ndlovu',
                                age: '78',
                                potforlio: 'President',
                              ),
                            ],
                          ),
                        ),

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
                                child: Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                            color: color.primaryColor
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                        GestureDetector(
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
                Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ApostleCard(
                            name: 'S.D Ndlovu',
                            age: '78',
                            potforlio: 'President',
                            imageUrl: 'assets/image3.jpeg',
                          ),
                          ApostleCard(
                            name: 'S.D Ndlovu',
                            age: '78',
                            potforlio: 'President',
                            imageUrl: 'assets/image3.jpeg',
                          ),
                          ApostleCard(
                            name: 'S.D Ndlovu',
                            age: '78',
                            potforlio: 'President',
                            imageUrl: 'assets/image3.jpeg',
                          ),
                          ApostleCard(
                            name: 'S.D Ndlovu',
                            age: '78',
                            potforlio: 'President',
                            imageUrl: 'assets/image3.jpeg',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
