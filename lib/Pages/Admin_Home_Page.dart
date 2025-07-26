import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart'; // Import for DateFormat
import 'package:ttact/Components/upcoming_events_card.dart'; // Import your custom card

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  // --- Helper Functions for Date Parsing and Filtering (Duplicated for standalone example) ---
  // You should ideally move this to a shared utility file.
  static DateTime? _parseEventStartDate(Map<String, dynamic> event) {
    final now = DateTime.now();
    final currentYear = now.year;

    String? dayPart = event['day'];
    String? monthPart = event['month'];

    // Prioritize 'parsedDate' field from Firestore if it exists and is a Timestamp
    if (event.containsKey('parsedDate') && event['parsedDate'] is Timestamp) {
      return (event['parsedDate'] as Timestamp).toDate();
    }

    // Handle single day events: '18' + 'Apr'
    if (dayPart != null &&
        monthPart != null &&
        dayPart.length <= 2 &&
        monthPart.length == 3) {
      try {
        final date = DateFormat(
          'dd MMM yyyy',
        ).parse('$dayPart $monthPart $currentYear');
        // If the parsed date is in the past, try next year (for annual events)
        // This heuristic handles cases where events repeat annually.
        if (date.isBefore(now) && date.month < now.month) {
          return DateFormat(
            'dd MMM yyyy',
          ).parse('$dayPart $monthPart ${currentYear + 1}');
        }
        return date;
      } on FormatException {
        return null;
      }
    }

    // Handle date ranges: '27 - 29' + 'May'
    if (dayPart != null &&
        dayPart.contains('-') &&
        monthPart != null &&
        monthPart.length == 3) {
      try {
        final startDay = dayPart.split('-').first.trim();
        final date = DateFormat(
          'dd MMM yyyy',
        ).parse('$startDay $monthPart $currentYear');
        if (date.isBefore(now) && date.month < now.month) {
          return DateFormat(
            'dd MMM yyyy',
          ).parse('$startDay $monthPart ${currentYear + 1}');
        }
        return date;
      } on FormatException {
        return null;
      }
    }

    // Handle month ranges: 'Feb - Mar', 'Jul - Oct', 'Apr - Jun - Sep - Nov'
    if (dayPart != null && dayPart.contains('-') && monthPart == '') {
      final parts = dayPart.split('-').map((s) => s.trim()).toList();
      for (var part in parts) {
        if (part.length == 3) {
          // Assume it's a month abbreviation
          try {
            DateTime date = DateFormat('MMM yyyy').parse('$part $currentYear');
            if (date.isBefore(now)) {
              if (date.month < now.month ||
                  (date.month == now.month && date.day < now.day)) {
                date = DateFormat('MMM yyyy').parse('$part ${currentYear + 1}');
              }
            }
            return date; // Return the first relevant date
          } on FormatException {
            continue;
          }
        }
      }
    }

    // Handle 'To Be Confirmed' or other unparseable cases
    return null;
  }
  // --- End of Helper Functions ---

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(14.0),
      child: ListView(
        children: [
          const Text(
            'TACT DASHBOARD',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Welcome!, Here\'s a summary of our church\'s activities and status.',
          ),
          const SizedBox(height: 20),

          // Total TACTSO Branches Card
          _buildDashboardCard(
            context: context,
            title: "TOTAL TACTSO BRANCHES",
            icon: Icons.location_city_outlined,
            future: FirebaseFirestore.instance
                .collection('tactso_branches')
                .get(),
            backgroundColor: color.primaryColor.withOpacity(0.7),
          ),
          const SizedBox(height: 10),

          // Total TACT Songs Card
          _buildDashboardCard(
            context: context,
            title: "TOTAL TACT Songs",
            icon: Ionicons.musical_notes_outline,
            future: FirebaseFirestore.instance.collection('tact_music').get(),
            backgroundColor: color.splashColor.withOpacity(0.7).withRed(150),
          ),
          const SizedBox(height: 10),

          // Total TACT Sellers Card
          _buildDashboardCard(
            context: context,
            title: "TOTAL TACT SELLERS",
            icon: Ionicons.people_outline,
            future: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'Seller')
                .get(),
            backgroundColor: color.splashColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          const Divider(), // Separator
          const SizedBox(height: 20),

          // Upcoming Events Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'UPCOMING EVENTS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color.primaryColor,
                ),
              ),
              Icon(Icons.event, color: color.primaryColor),
            ],
          ),
          const SizedBox(height: 10),
          _buildUpcomingEventsList(context),
          const SizedBox(height: 20), // Add some space at the bottom
        ],
      ),
    );
  }

  // Reusable widget for dashboard cards
  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Future<QuerySnapshot> future,
    required Color backgroundColor,
  }) {
    final color = Theme.of(context);
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: color.splashColor),
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
                baseColor: color.scaffoldBackgroundColor.withOpacity(
                  0.8,
                ), // Adjust shimmer colors
                highlightColor: color.hintColor.withOpacity(
                  0.8,
                ), // Adjust shimmer colors
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 180,
                          height: 20,
                          color: Colors.white, // Shimmer over white placeholder
                        ),
                        Container(width: 30, height: 30, color: Colors.white),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(width: 80, height: 60, color: Colors.white),
                        const SizedBox(width: 20),
                        Container(width: 50, height: 50, color: Colors.white),
                      ],
                    ),
                  ],
                ),
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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        color: color.scaffoldBackgroundColor,
                      ),
                    ),
                    Icon(icon, color: color.scaffoldBackgroundColor),
                  ],
                ),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${data!.docs.length}',
                        style: TextStyle(
                          fontSize: 60,
                          color: color.scaffoldBackgroundColor,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Icon(
                        icon, // Using the primary icon for consistency
                        size: 50,
                        color: color.scaffoldBackgroundColor,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // New Widget to build the Upcoming Events List
  Widget _buildUpcomingEventsList(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('upcoming_events')
          .orderBy('parsedDate', descending: false) // Order by date
          .limit(10) // Fetch a few more than 3 to ensure we get 3 future events
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            children: List.generate(
              3, // Show 3 shimmer placeholders
              (index) => Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: UpcomingEventsCard(
                  date: 'XX',
                  eventMonth: 'MON',
                  eventTitle: 'Loading Event Title',
                  eventDescription: 'Loading event description details...',
                  highlightColor: Colors.grey[200], // Placeholder color
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

        // Filter for truly upcoming events (including today) and take the first 3
        List<Map<String, dynamic>> upcomingEvents = [];
        for (var doc in allEvents) {
          Map<String, dynamic> eventData = doc.data() as Map<String, dynamic>;
          eventData['id'] = doc.id; // Add ID for potential future use

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
                break; // We only need the first 3 upcoming events
              }
            }
          } else {
            // Optionally, handle "To Be Confirmed" events here if you want them always shown
            // or in a separate section. For now, we'll exclude them from strict date count.
            if (eventData['day']?.toLowerCase()?.contains('to be confirmed') ??
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

            // Adjust date format for ranges if necessary, e.g., "Feb - Mar"
            if (dateDisplay.contains('-') && monthDisplay.isEmpty) {
              // For month ranges, perhaps combine them or show the first month
              monthDisplay = dateDisplay; // Use full string for month display
              dateDisplay = ''; // Clear day
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
              // You can add logic here to pass highlightColor based on event type or status
              highlightColor:
                  event['parsedDate'] ==
                      null // Highlight TBC events
                  ? Colors.orange.withOpacity(0.5)
                  : null,
            );
          }).toList(),
        );
      },
    );
  }
}
