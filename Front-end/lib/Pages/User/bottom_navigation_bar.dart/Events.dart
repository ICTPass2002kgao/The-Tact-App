// ignore_for_file: prefer_const_constructors, unused_field, unnecessary_null_comparison

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ⭐️ IMPORT YOUR NEUMORPHIC COMPONENT
import 'package:ttact/Components/NeuDesign.dart';

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

  DateTime? _parseEventDate(Map<String, String> event) {
    final now = DateTime.now();
    final year = now.year;
    String? day = event['day'];
    String? month = event['month'];

    if (day == null || day.toLowerCase().contains('confirmed')) return null;

    try {
      if (month != null && month.isNotEmpty) {
        final dayPart = day.split('-').first.trim();
        return DateFormat('dd MMM yyyy').parse('$dayPart $month $year');
      }
      if (day.contains('-') && month!.isEmpty) {
        final startMonth = day.split('-').first.trim();
        return DateFormat('MMM yyyy').parse('$startMonth $year');
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final theme = Theme.of(context);

    // ⭐️ NEUMORPHIC TINT
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.08),
      theme.scaffoldBackgroundColor,
    );

    int? firstUpcomingIndex;
    for (int i = 0; i < upcomingEvents.length; i++) {
      final eventDate = _parseEventDate(upcomingEvents[i]);
      if (eventDate != null && eventDate.isAfter(now)) {
        firstUpcomingIndex = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: neumoBaseColor, // Set background
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: upcomingEvents.length,
                  itemBuilder: (context, index) {
                    final event = upcomingEvents[index];
                    final eventDate = _parseEventDate(event);

                    bool isPast = eventDate != null && eventDate.isBefore(now);
                    bool isNextUpcoming = index == firstUpcomingIndex;
                    bool isConfirmed =
                        event['day']?.toLowerCase().contains('confirmed') ==
                        false;

                    // Styles based on state
                    Color textColor = theme.primaryColor;
                    Color iconColor = theme.hintColor;
                    IconData statusIcon = Icons.event_available_rounded;

                    if (!isConfirmed) {
                      iconColor = Colors.orange;
                      statusIcon = Icons.hourglass_empty_rounded;
                    } else if (isPast) {
                      textColor = theme.hintColor.withOpacity(0.6);
                      iconColor = theme.hintColor.withOpacity(0.3);
                      statusIcon = Icons.check_circle_outline;
                    } else if (isNextUpcoming) {
                      iconColor = theme.primaryColor;
                      statusIcon = Icons.star_rounded;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: NeumorphicContainer(
                        // ⭐️ The Card Container
                        color: neumoBaseColor,
                        isPressed: false, // Pop out
                        borderRadius: 20,
                        padding: EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ⭐️ LEFT: DATE BUBBLE (Sunken/Pressed)
                            NeumorphicContainer(
                              color: isNextUpcoming
                                  ? theme.primaryColor.withOpacity(0.1)
                                  : neumoBaseColor,
                              isPressed: true, // Sunken look for date
                              borderRadius: 15,
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    event['day']?.split('-')[0].trim() ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: isNextUpcoming
                                          ? theme.primaryColor
                                          : textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (event['month'] != null &&
                                      event['month']!.isNotEmpty)
                                    Text(
                                      event['month']!.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isNextUpcoming
                                            ? theme.primaryColor
                                            : theme.hintColor,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            SizedBox(width: 16),

                            // ⭐️ MIDDLE: TITLE
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['title'] ?? '',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isNextUpcoming
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                  if (event['day']!.contains('-'))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "Duration: ${event['day']}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            SizedBox(width: 10),

                            // ⭐️ RIGHT: STATUS ICON (Small Convex Button)
                            NeumorphicContainer(
                              color: neumoBaseColor,
                              isPressed: false,
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                statusIcon,
                                color: iconColor,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
