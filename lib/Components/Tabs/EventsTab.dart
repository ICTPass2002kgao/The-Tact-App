import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/BibleVerseRepository.dart'; // ⭐️ IMPORT THE NEW FILE
import 'package:ttact/Components/HomePageHelpers.dart'; 
import 'package:ttact/Components/Upcoming_events_card.dart' hide isIOSPlatform;
import 'package:ttact/Components/bottomsheet.dart' hide isIOSPlatform;

class EventsTab extends StatelessWidget {
  const EventsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    
    // 1. Get the verse from the separate class
    final dailyVerse = BibleVerseRepository.getDailyVerse();

    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ListView(
        children: [
          // 2. Pass the verse map to the card
          _buildDailyVerseCard(color, dailyVerse),
          
          SizedBox(height: 20),
          Text(
            'Upcoming Events',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color.primaryColor,
            ),
          ),
          SizedBox(height: 10),

          // Upcoming Events List
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('upcoming_events')
                .where(
                  'parsedDate',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
                )
                .orderBy('parsedDate', descending: false)
                .limit(5)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: isIOSPlatform
                      ? CupertinoActivityIndicator()
                      : CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text('Error loading events: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No upcoming events found.'));
              }

              final events = snapshot.data!.docs;

              return Column(
                children: events.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String date = data['day'] ?? '';
                  final String eventMonth = data['month'] ?? '';
                  final String eventTitle = data['title'] ?? 'No Title';
                  final String eventDescription =
                      data['description'] ?? 'No Description';
                  final String posterUrl = data['posterUrl'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: GestureDetector(
                      onTap: () {
                        final widget = EventDetailBottomSheet(
                          date: date,
                          eventMonth: eventMonth,
                          title: eventTitle,
                          description: eventDescription,
                          posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
                        );

                        showModalBottomSheet(
                          scrollControlDisabledMaxHeightRatio: double.infinity,
                          context: context,
                          builder: (context) {
                            return widget;
                          },
                        );
                      },
                      child: UpcomingEventsCard(
                        posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
                        date: date,
                        eventMonth: eventMonth,
                        eventTitle: eventTitle,
                        eventDescription: eventDescription,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // 3. Updated widget to accept the verseData Map
  Widget _buildDailyVerseCard(ThemeData color, Map<String, String> verseData) {
    return Card(
      elevation: 8,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color.primaryColor, color.primaryColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              color: color.scaffoldBackgroundColor,
            ),
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Verse',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: color.primaryColor,
                      ),
                    ),
                    // Optional: Display the Category (e.g. "HOPE")
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        verseData['category']!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(
                  thickness: 1,
                  color: color.primaryColor.withOpacity(0.5),
                ),
                Text(
                  '"${verseData['text']}"', // Dynamic Text
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: color.primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- ${verseData['ref']}', // Dynamic Reference
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color.primaryColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}