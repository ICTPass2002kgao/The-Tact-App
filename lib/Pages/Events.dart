import 'package:flutter/material.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';
import 'package:intl/intl.dart';

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

  // Helper to parse the event date
  DateTime? _parseEventDate(Map<String, String> event) {
    final now = DateTime.now();
    final year = now.year;

    String? day = event['day'];
    String? month = event['month'];

    // Handle cases like '18' + 'Apr'
    if (day != null && month != null && day.length <= 2 && month.length == 3) {
      try {
        final date = DateFormat('dd MMM yyyy').parse('$day $month $year');
        return date;
      } catch (_) {}
    }

    // Handle cases like '27 - 29' + 'May'
    if (day != null &&
        month != null &&
        day.contains('-') &&
        month.length == 3) {
      try {
        final startDay = day.split('-').first.trim();
        final date = DateFormat('dd MMM yyyy').parse('$startDay $month $year');
        return date;
      } catch (_) {}
    }

    // Handle cases like 'Feb - Mar'
    if (day != null && day.contains('-') && month == '') {
      try {
        final startMonth = day.split('-').first.trim();
        final date = DateFormat('MMM yyyy').parse('$startMonth $year');
        return date;
      } catch (_) {}
    }

    // Handle cases like 'Jul - Oct'
    if (day != null && day.contains('-') && month == '') {
      try {
        final startMonth = day.split('-').first.trim();
        final date = DateFormat('MMM yyyy').parse('$startMonth $year');
        return date;
      } catch (_) {}
    }

    // Handle cases like 'To Be Confirmed'
    if (day != null && day.toLowerCase().contains('to be confirmed')) {
      return null;
    }

    // Handle cases like 'Apr - Jun - Sep - Nov'
    if (day != null && day.contains('-')) {
      try {
        final startMonth = day.split('-').first.trim();
        final date = DateFormat('MMM yyyy').parse('$startMonth $year');
        return date;
      } catch (_) {}
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

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
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'Upcoming Events',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: upcomingEvents.length,
            itemBuilder: (context, index) {
              final event = upcomingEvents[index];
              final eventDate = _parseEventDate(event);

              Color? highlightColor;
              if (eventDate != null) {
                if (eventDate.isBefore(now)) {
                  highlightColor = Colors.red.withOpacity(0.4);
                } else if (index == firstUpcomingIndex) {
                  highlightColor = Colors.green.withOpacity(0.4);
                } else
                  highlightColor = Colors.grey.withOpacity(0.4);
                ;
              }
              final color = Theme.of(context);

              return Stack(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: index == firstUpcomingIndex ? 20 : 0,
                    color: index == firstUpcomingIndex
                        ? color.splashColor
                        : Colors.transparent,
                    child: UpcomingEventsCard(
                      date: event['day'] ?? '',
                      eventMonth: event['month'] ?? '',
                      eventTitle: event['title'] ?? '',
                      eventDescription: 'Details for ${event['title'] ?? ''}',
                      highlightColor: highlightColor,
                    ),
                  ),
                  Positioned(
                    top: 32,
                    bottom: 25,
                    right: 17,
                    child: eventDate != null && eventDate.isBefore(now)
                        ? Icon(Icons.event_busy, size: 30, color: Colors.red)
                        : index == firstUpcomingIndex
                        ? Icon(Icons.star, size: 40, color: color.splashColor)
                        : Icon(
                            Icons.event_available,
                            size: 30,
                            color: Colors.grey,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
