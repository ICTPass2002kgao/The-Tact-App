import 'package:flutter/material.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<Map<String, String>> upcomingEvents = [
    {'day': 'Feb - Mar', 'month': '', 'title': 'Sealing Services'},
    {'day': '18', 'month': 'Apr', 'title': 'Joint Executive Meeting'},
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
    {
      'day': 'Jul - Oct',
      'month': '',
      'title': 'CYC Provincial & Global Visits',
    },
    {'day': 'To Be Confirmed', 'month': '', 'title': 'CYC Youth Seminars'},
    {
      'day': 'Apr - Jun - Sep - Nov',
      'month': '',
      'title': 'NEC Meetings (3 times + JEC)',
    },
  ];

  @override
  Widget build(BuildContext context) {
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
              return UpcomingEventsCard(
                date: upcomingEvents[index]['day'] ?? '',
                eventMonth: upcomingEvents[index]['month'] ?? '',
                eventTitle: upcomingEvents[index]['title'] ?? '',
                eventDescription:
                    'Details for ${upcomingEvents[index]['title'] ?? ''}',
              );
            },
          ),
        ),
      ],
    );
  }
}
