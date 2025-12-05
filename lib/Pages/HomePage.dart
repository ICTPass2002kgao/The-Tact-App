// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/AdBanner.dart';
import 'package:ttact/Components/HomePageHelpers.dart';
import 'package:ttact/Components/Tabs/BranchesTab.dart';
import 'package:ttact/Components/Tabs/Career_Opportunities.dart'
    hide isLargeScreen;
import 'package:ttact/Components/Tabs/EventsTab.dart';
import 'package:ttact/Components/Tabs/MusicTab.dart';
import 'package:ttact/Pages/MotherPage.dart' hide isLargeScreen;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;
  AdManager adManager = AdManager();

  // Global Key to access Music Tab logic for Deep Linking
  final GlobalKey<MusicTabState> _musicTabKey = GlobalKey<MusicTabState>();

  void _onDeepLinkReceived() async {
    const int musicTabIndex = 1;

    final songUrlId = MotherPage.deepLinkSongIdNotifier.value;

    if (songUrlId == null) return;

    debugPrint("🎵 HomePage received deep link request: $songUrlId");

    // 1. Switch TabBar to Music Tab
    if (_tabController.index != musicTabIndex) {
      _tabController.animateTo(musicTabIndex);
      // Wait for tab animation to complete
      await Future.delayed(Duration(milliseconds: 500));
    }

    // 2. Reset the notifier value immediately to prevent repeated calls
    MotherPage.deepLinkSongIdNotifier.value = null;

    // 3. Trigger play on the MusicTab using the GlobalKey
    if (_musicTabKey.currentState != null) {
      _musicTabKey.currentState!.playDeepLinkedSong(songUrlId);
    }
  }

  @override
  void initState() {
    super.initState();
    // Length is 4 (Events, Music, Branches, Career)
    _tabController = TabController(length: 4, vsync: this);

    // Subscribe to the deep link notifier with delay to ensure widgets are built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MotherPage.deepLinkSongIdNotifier.addListener(_onDeepLinkReceived);

      // Check if there's already a pending deep link
      if (MotherPage.deepLinkSongIdNotifier.value != null) {
        Future.delayed(Duration(milliseconds: 1000), _onDeepLinkReceived);
      }
    });

    // Initialize rewarded ad manager
    adManager.loadRewardedInterstitialAd();
  }

  @override
  void dispose() {
    MotherPage.deepLinkSongIdNotifier.removeListener(_onDeepLinkReceived);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);
    final tabHeight = isDesktop ? 70.0 : 48.0;

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
          // 1. TabBar
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
                  isScrollable: true,
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
                      text: 'TACT MUSIC',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Ionicons.musical_note_outline,
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
                      text: 'CAREER AND OPPORTUNITIES',
                      icon: isDesktop
                          ? null
                          : Icon(
                              Ionicons.briefcase_outline,
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
                contentWrapper(child: EventsTab()),
                contentWrapper(
                  child: MusicTab(key: _musicTabKey, isDesktop: isDesktop),
                ),
                contentWrapper(child: BranchesTab(isDesktop: isDesktop)),
                contentWrapper(child: CareerOpportunities()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
