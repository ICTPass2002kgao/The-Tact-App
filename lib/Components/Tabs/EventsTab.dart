import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/BibleVerseRepository.dart';
import 'package:ttact/Components/HomePageHelpers.dart';
import 'package:ttact/Components/Upcoming_events_card.dart' hide isIOSPlatform;
import 'package:ttact/Components/bottomsheet.dart' hide isIOSPlatform;

class EventsTab extends StatefulWidget {
  const EventsTab({super.key});

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  // State for Events
  Future<QuerySnapshot>? _eventsFuture;

  // State for Filters
  int _selectedCategoryIndex = 0;
  final List<String> _categories = [
    "All",
    "Youth",
    "Awards", 
    "Academic",
    "Gala",
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  void _loadEvents() {
    setState(() {
      // NOTE: In a real app, you would add .where('category', isEqualTo: _categories[_selectedCategoryIndex])
      // For now, we reload the standard list to simulate the refresh behavior.
      _eventsFuture = FirebaseFirestore.instance
          .collection('upcoming_events')
          .where(
            'parsedDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
          )
          .orderBy('parsedDate', descending: false)
          .limit(10) // Increased limit slightly
          .get();
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final dailyVerse = BibleVerseRepository.getDailyVerse();

    return RefreshIndicator(
      onRefresh: () async => _loadEvents(),
      child: ListView(
        padding: const EdgeInsets.all(15.0),
        children: [
          // 1. Daily Verse Card
          _buildDailyVerseCard(color, dailyVerse),

          const SizedBox(height: 25),

          // 2. Beautiful Opportunity Banner
          _buildOpportunityBanner(context),

          const SizedBox(height: 25),

          // 3. NEW: Category Filter Chips
          _buildCategoryFilters(color),

          const SizedBox(height: 20),

          // 4. Section Title
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: color.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Upcoming Events',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // 5. Events List
          FutureBuilder<QuerySnapshot>(
            future: _eventsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: isIOSPlatform
                      ? const CupertinoActivityIndicator()
                      : const CircularProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              // Empty State Check
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildInteractiveEmptyState(color);
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
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          scrollControlDisabledMaxHeightRatio: 0.9,
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => EventDetailBottomSheet(
                            date: date,
                            eventMonth: eventMonth,
                            title: eventTitle,
                            description: eventDescription,
                            posterUrl: posterUrl.isNotEmpty ? posterUrl : null,
                          ),
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

          // Bottom padding
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // --- WIDGET HELPERS ---

  // ⭐️ NEW: Category Filter Chips
  Widget _buildCategoryFilters(ThemeData color) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                  // Trigger reload when category changes
                  _loadEvents();
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color.primaryColor
                        : Colors.grey.withOpacity(0.3),
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ⭐️ Opportunity Banner
  Widget _buildOpportunityBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.white.withOpacity(0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "NEW OPPORTUNITIES",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Bursaries & Internships",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Boost your career today!",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 15),
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Navigating to Opportunities..."),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            "Check Now",
                            style: TextStyle(
                              color: Color(0xFF0D47A1),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.school_rounded,
                  size: 80,
                  color: Colors.white.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⭐️ Interactive Empty State
  Widget _buildInteractiveEmptyState(ThemeData color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        decoration: BoxDecoration(
          color: color.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.primaryColor.withOpacity(0.05),
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 60,
                color: color.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "All Caught Up!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "There are no upcoming events scheduled right now. We are planning something big!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _loadEvents,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text("Refresh"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton.icon(
                  onPressed: () {
                    
                  },
                  icon: const Icon(
                    Icons.lightbulb_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Suggest Event",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ⭐️ Error State
  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 10),
          Text("Something went wrong.\n$error", textAlign: TextAlign.center),
          TextButton(onPressed: _loadEvents, child: const Text("Try Again")),
        ],
      ),
    );
  }

  // ⭐️ Daily Verse Card
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
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Verse',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color.primaryColor,
                      ),
                    ),
                  ],
                ),
                Divider(
                  height: 25,
                  thickness: 1,
                  color: color.primaryColor.withOpacity(0.2),
                ),
                Text(
                  '"${verseData['text']}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- ${verseData['ref']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color.primaryColor.withOpacity(0.7),
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
