// ignore_for_file: prefer_const_constructors, unused_field, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';
import 'package:intl/intl.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 800.0;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 800;
// --------------------------

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<Map<String, String>> upcomingEvents = [
    {'day': 'Feb - Mar', 'month': '', 'title': 'Sealing Services'},
    {'day': '18', 'month': 'Apr', 'title': 'Joint Executive Meeting'},
    {
      'day': 'Apr - Jun - Sep - Nov',
      'month': '',
      'title': 'NEC Meetings (3 times + JEC)',
    },
    {'day': '27', 'month': 'Apr', 'title': "Annual Officers' Opening Meeting"},
    {
      'day': '03',
      'month': 'May',
      'title': 'TTACTSO Opening – Nelson Mandela University, Ggeberha',
    },
    {'day': '25', 'month': 'May', 'title': 'Apostle Day'},
    {'day': '27 - 29', 'month': 'May', 'title': 'Senior Testify Sisters'},
    {'day': '31', 'month': 'May', 'title': 'Junior Testify Sisters'},
    {'day': '08', 'month': 'Jun', 'title': 'General Officers & Tithes Meeting'},
    {
      'day': 'Jul - Oct',
      'month': '',
      'title': 'CYC Provincial & Global Visits',
    },
    {
      'day': '07',
      'month': 'Sep',
      'title': 'Old Age & Physically Challenged Day',
    },
    {'day': '14', 'month': 'Sep', 'title': 'General Officers & Tithes Meeting'},
    {
      'day': '05',
      'month': 'Oct',
      'title': 'Pre-Examination Services & TTACTSO Closing',
    },
    {'day': '11 - 12', 'month': 'Oct', 'title': 'Sunday School Weekend'},
    {
      'day': '15 - 16',
      'month': 'Nov',
      'title': 'Cluster Thanksgiving (Gauteng, Limpopo, North West, etc.)',
    },
    {
      'day': '29 - 30',
      'month': 'Nov',
      'title': 'Cluster Thanksgiving (KZN, EC, WC, FS, Lesotho)',
    },
    {'day': '14', 'month': 'Dec', 'title': "Annual Officers' Closing Meeting"},
    {'day': 'To Be Confirmed', 'month': '', 'title': 'CYC Youth Seminars'},
  ];

  // Helper to parse the event date - CLEANED UP FOR READABILITY
  DateTime? _parseEventDate(Map<String, String> event) {
    final now = DateTime.now();
    final year = now.year;

    String? day = event['day'];
    String? month = event['month'];

    if (day == null || day.toLowerCase().contains('confirmed')) {
      return null;
    }

    try {
      // Case 1: Specific Date (e.g., '18', 'Apr') or Start of Range (e.g., '27 - 29', 'May')
      if (month != null && month.isNotEmpty) {
        final dayPart = day.split('-').first.trim();
        return DateFormat('dd MMM yyyy').parse('$dayPart $month $year');
      }

      // Case 2: Month Range/Quarter (e.g., 'Feb - Mar', 'Apr - Jun - Sep - Nov')
      if (day.contains('-') && month!.isEmpty) {
        final startMonth = day.split('-').first.trim();
        // Attempt to parse just the month and assume the start of that month
        return DateFormat('MMM yyyy').parse('$startMonth $year');
      }
    } catch (_) {
      // Parsing failed for this event
      return null;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final color = Theme.of(context);

    // Find the index of the first upcoming event
    int? firstUpcomingIndex;
    for (int i = 0; i < upcomingEvents.length; i++) {
      final eventDate = _parseEventDate(upcomingEvents[i]);
      if (eventDate != null && eventDate.isAfter(now)) {
        firstUpcomingIndex = i;
        break;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(1.0),
          child: Text(
            'Organizational Calendar',
            style: TextStyle(
              fontSize: 28, // Slightly larger title
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
        ),
        Expanded(
          // FIX: Center and constrain the list view for desktop/web
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
              child: ListView.builder(
                itemCount: upcomingEvents.length,
                itemBuilder: (context, index) {
                  final event = upcomingEvents[index];
                  final eventDate = _parseEventDate(event);

                  bool isPast = eventDate != null && eventDate.isBefore(now);
                  bool isNextUpcoming = index == firstUpcomingIndex;
                  bool isConfirmed =
                      event['day']?.toLowerCase().contains('to be confirmed') ==
                      false;

                  Color highlightColor;
                  IconData icon;
                  Color iconColor;
                  double cardElevation;

                  if (!isConfirmed) {
                    highlightColor = Colors.grey.withOpacity(0.2);
                    icon = Icons.pending_actions_outlined;
                    iconColor = Colors.grey;
                    cardElevation = 0;
                  } else if (isPast) {
                    highlightColor = Colors.red.withOpacity(0.1);
                    icon = Icons.event_busy;
                    iconColor = Colors.red;
                    cardElevation = 0;
                  } else if (isNextUpcoming) {
                    highlightColor = color.splashColor.withOpacity(
                      0.2,
                    ); // Brighter highlight
                    icon = Icons.star;
                    iconColor = color.splashColor;
                    cardElevation = 8; // Higher elevation for focus
                  } else {
                    highlightColor = Colors.grey.withOpacity(0.1);
                    icon = Icons.event_available;
                    iconColor = color.primaryColor.withOpacity(0.6);
                    cardElevation = 2;
                  }

                  return Stack(
                    children: [
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isNextUpcoming
                                ? color.primaryColor
                                : Colors.transparent,
                            width: isNextUpcoming ? 2 : 0,
                          ),
                        ),
                        elevation: cardElevation,
                        color: color.scaffoldBackgroundColor,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: UpcomingEventsCard(
                          date: event['day'] ?? '',
                          eventMonth: event['month'] ?? '',
                          eventTitle: event['title'] ?? '',
                          eventDescription:
                              'Details for ${event['title'] ?? ''}',
                          highlightColor: highlightColor,
                        ),
                      ),
                      Positioned(
                        top: 15,
                        right: 25,
                        child: Icon(icon, size: 30, color: iconColor),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
