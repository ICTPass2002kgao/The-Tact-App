// ignore_for_file: prefer_const_constructors, unused_local_variable, unnecessary_null_comparison, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
// Assuming UpcomingEventsCard is correctly implemented locally
import 'package:ttact/Components/Upcoming_events_card.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 1000.0;
const int _desktopGridColumns = 3;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700;
// --------------------------

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  // --- Helper Functions for Date Parsing and Filtering (Kept as is) ---
  static DateTime? _parseEventStartDate(Map<String, dynamic> event) {
    final now = DateTime.now();
    final currentYear = now.year;

    String? dayPart = event['day'];
    String? monthPart = event['month'];

    if (event.containsKey('parsedDate') && event['parsedDate'] is Timestamp) {
      return (event['parsedDate'] as Timestamp).toDate();
    }

    if (dayPart != null && dayPart.toLowerCase().contains('to be confirmed')) {
      return null;
    }

    // Attempt to parse explicit date (dd MMM)
    if (dayPart != null && monthPart != null && monthPart.length == 3) {
      try {
        final dayComponent = dayPart.split('-').first.trim();
        DateTime date = DateFormat(
          'dd MMM yyyy',
        ).parse('$dayComponent $monthPart $currentYear');
        // Annual event heuristic
        if (date.isBefore(now) && date.month < now.month) {
          date = DateFormat(
            'dd MMM yyyy',
          ).parse('$dayComponent $monthPart ${currentYear + 1}');
        }
        return date;
      } on FormatException {
        /* continue to next logic */
      }
    }

    // Handle month ranges
    if (dayPart != null && dayPart.contains('-')) {
      final parts = dayPart.split('-').map((s) => s.trim()).toList();
      for (var part in parts) {
        if (part.length == 3) {
          // Assume month abbreviation
          try {
            DateTime date = DateFormat('MMM yyyy').parse('$part $currentYear');
            // Annual event heuristic
            if (date.isBefore(now) && date.month < now.month) {
              date = DateFormat('MMM yyyy').parse('$part ${currentYear + 1}');
            }
            return date; // Return the first relevant date
          } on FormatException {
            continue;
          }
        }
      }
    }

    return null;
  }
  // --- End of Helper Functions ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // Define the list of metric items
    final List<Map<String, dynamic>> metricItems = [
      {
        'title': "TOTAL TACTSO BRANCHES",
        'icon': Icons.location_city_outlined,
        'future': FirebaseFirestore.instance
            .collection('tactso_branches')
            .get(),
        'backgroundColor': color.primaryColor.withOpacity(0.7),
      },
      {
        'title': "TOTAL TACT Songs",
        'icon': Ionicons.musical_notes_outline,
        'future': FirebaseFirestore.instance.collection('tact_music').get(),
        'backgroundColor': color.splashColor.withOpacity(0.7).withRed(150),
      },
      {
        'title': "TOTAL TACT SELLERS",
        'icon': Ionicons.people_outline,
        'future': FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Seller')
            .get(),
        'backgroundColor': color.splashColor.withOpacity(0.5),
      },
    ];

    return Center(
      // FIX 1: Constrain the content width for desktop
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: ListView(
            children: [
              Text(
                'TACT DASHBOARD',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color.primaryColor,
                ),
              ),
              Text(
                'Welcome!, Here\'s a summary of our church\'s activities and status.',
                style: TextStyle(color: color.hintColor),
              ),
              const SizedBox(height: 20),

              // FIX 2: Responsive Dashboard Grid/Wrap
              LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing = isDesktop ? 20.0 : 10.0;
                  final double itemWidth = isDesktop
                      ? (constraints.maxWidth -
                                (spacing * (_desktopGridColumns - 1))) /
                            _desktopGridColumns
                      : constraints.maxWidth; // Full width on mobile

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: metricItems.map((item) {
                      return _buildDashboardCard(
                        context: context,
                        title: item['title'],
                        icon: item['icon'],
                        future: item['future'],
                        backgroundColor: item['backgroundColor'],
                        itemWidth: itemWidth, // Pass calculated width
                        isDesktop: isDesktop,
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              // Upcoming Events Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'UPCOMING EVENTS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color.primaryColor,
                    ),
                  ),
                  Icon(Icons.event, color: color.primaryColor),
                ],
              ),
              const SizedBox(height: 15),
              _buildUpcomingEventsList(context),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable widget for dashboard cards - MODIFIED for responsiveness
  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Future<QuerySnapshot> future,
    required Color backgroundColor,
    required double itemWidth,
    required bool isDesktop,
  }) {
    final color = Theme.of(context);
    return Container(
      width: itemWidth, // Use calculated width
      height: 180, // Fixed height looks better on dashboard
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: backgroundColor,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder(
          future: future,
          builder: (context, snapshots) {
            if (snapshots.connectionState == ConnectionState.waiting) {
              return Shimmer.fromColors(
                baseColor: color.scaffoldBackgroundColor.withOpacity(0.8),
                highlightColor: color.hintColor.withOpacity(0.8),
                child: Container(color: Colors.white),
              );
            }

            if (snapshots.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshots.error}',
                  style: TextStyle(color: color.scaffoldBackgroundColor),
                ),
              );
            }

            final data = snapshots.data;
            final count = data!.docs.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Use space between for clean separation
              children: [
                // Top Row: Title and Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: isDesktop
                            ? 2
                            : 3, // Allow more lines on mobile if needed
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: color.scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    Icon(icon, color: color.scaffoldBackgroundColor, size: 28),
                  ],
                ),

                // Bottom Row: Count
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Widget to build the Upcoming Events List
  Widget _buildUpcomingEventsList(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('upcoming_events')
          .orderBy('parsedDate', descending: false)
          .limit(10)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(
              3,
              (index) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: UpcomingEventsCard(
                  date: 'XX',
                  eventMonth: 'MON',
                  eventTitle: 'Loading Event Title',
                  eventDescription: 'Loading event description details...',
                  highlightColor: Colors.grey[200],
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading events: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No upcoming events found.'));
        }

        final DateTime now = DateTime.now();
        final List<DocumentSnapshot> allEvents = snapshot.data!.docs;

        List<Map<String, dynamic>> upcomingEvents = [];
        for (var doc in allEvents) {
          Map<String, dynamic> eventData = doc.data() as Map<String, dynamic>;
          eventData['id'] = doc.id;

          final DateTime? eventDate = _parseEventStartDate(eventData);

          if (eventDate != null) {
            final DateTime today = DateTime(now.year, now.month, now.day);
            final DateTime eventDay = DateTime(
              eventDate.year,
              eventDate.month,
              eventDate.day,
            );

            if (eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today)) {
              upcomingEvents.add(eventData);
              if (upcomingEvents.length >= 3) {
                break;
              }
            }
          } else {
            if (eventData['day']?.toLowerCase().contains('to be confirmed') ??
                false) {
              upcomingEvents.add(eventData);
              if (upcomingEvents.length >= 3) {
                break;
              }
            }
          }
        }

        if (upcomingEvents.isEmpty) {
          return const Center(child: Text('No upcoming events found.'));
        }

        return Column(
          children: upcomingEvents.map((event) {
            String dateDisplay = event['day'] ?? '';
            String monthDisplay = event['month'] ?? '';
            String title = event['title'] ?? 'No Title';
            String description =
                event['description'] ?? 'No description available.';

            if (dateDisplay.contains('-') && monthDisplay.isEmpty) {
              monthDisplay = dateDisplay;
              dateDisplay = '';
            }
            if (dateDisplay.toLowerCase().contains('to be confirmed')) {
              dateDisplay = 'TBC';
              monthDisplay = '';
            }

            return UpcomingEventsCard(
              date: dateDisplay,
              eventMonth: monthDisplay,
              eventTitle: title,
              eventDescription: description,
              highlightColor: event['parsedDate'] == null
                  ? Colors.orange.withOpacity(0.5)
                  : null,
            );
          }).toList(),
        );
      },
    );
  }
}
