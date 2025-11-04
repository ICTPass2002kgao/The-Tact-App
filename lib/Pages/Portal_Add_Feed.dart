import 'dart:io'; // Required for File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart'; // Import for shimmer effect
import 'package:ttact/Components/API.dart'; // Assuming this provides showLoading/showMessage

class PortalAddFeed extends StatefulWidget {
  const PortalAddFeed({super.key});

  @override
  State<PortalAddFeed> createState() => _PortalAddFeedState();
}

class _PortalAddFeedState extends State<PortalAddFeed>
    with SingleTickerProviderStateMixin {
  // Tab Controller
  late TabController _tabController;

  // Controllers for Add Event Form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  File? _pickedPoster;
  String? _selectedProvince;

  // Controllers for EDIT Event Sheet
  final TextEditingController _editDescriptionController =
      TextEditingController();
  final TextEditingController _liveStreamLinkController =
      TextEditingController();
  File? _editPickedPoster; // Stores the newly picked poster file during editing

  // List of South African Provinces
  final List<String> _southAfricanProvinces = [
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  // List to hold events fetched from Firestore for "Upcoming Events" tab
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoadingEvents = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchAndFilterEvents(); // Initial fetch for the first tab
  }

  void _handleTabSelection() {
    if (_tabController.index == 0) {
      _fetchAndFilterEvents(); // Refresh events when switching to Upcoming Events tab
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _editDescriptionController.dispose();
    _liveStreamLinkController.dispose();
    super.dispose();
  }

  // --- Helper Functions for Date Parsing and Filtering (Kept original logic) ---

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
        if (date.isBefore(now) && date.month < now.month) {
          // More precise check for past months
          return DateFormat(
            'dd MMM yyyy',
          ).parse('$dayPart $monthPart ${currentYear + 1}');
        }
        return date;
      } on FormatException {
        // Fallback for parsing errors
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
            // Try current year
            DateTime date = DateFormat('MMM yyyy').parse('$part $currentYear');
            // If the start of the range is in the past, but the event conceptually extends to future
            if (date.isBefore(now)) {
              // If the month is still in the future of the current year (e.g., now is Jan, event is Feb-Mar)
              // Or if we need to consider next year for annual events that span across year end.
              // For simplicity for filtering, we just check if it's past "now".
              // If the month itself is in the past, try next year.
              if (date.month < now.month ||
                  (date.month == now.month && date.day < now.day)) {
                date = DateFormat('MMM yyyy').parse('$part ${currentYear + 1}');
              }
            }
            return date; // Return the first relevant date
          } on FormatException {
            continue; // Try next part
          }
        }
      }
    }

    // Handle 'To Be Confirmed' or other unparseable cases
    return null;
  }

  // Hardcoded events, ignored for the live list display but kept as a reminder
  List<Map<String, String>> upcomingEvents = [
    // ... your list of hardcoded events ...
  ];

  // --- Firestore Operations ---

  Future<void> _fetchAndFilterEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('upcoming_events')
          .orderBy('parsedDate', descending: false) // Order by date
          .get();

      List<Map<String, dynamic>> fetchedEvents = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>..['id'] = doc.id)
          .toList();

      // Filter events to only show future events (including today)
      final DateTime now = DateTime.now();
      _filteredEvents = fetchedEvents.where((event) {
        final DateTime? eventDate = _parseEventStartDate(event);
        if (eventDate == null) {
          // For events like 'To Be Confirmed', show them
          return event['day']?.toLowerCase()?.contains('to be confirmed') ??
              false;
        }
        // Compare dates, ignoring time for "today" check
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime eventDay = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
        );
        return eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
      }).toList();

      // Sort with TBC events pushed to the end
      _filteredEvents.sort((a, b) {
        final DateTime? dateA = _parseEventStartDate(a);
        final DateTime? dateB = _parseEventStartDate(b);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });
    } catch (e) {
      print('Error fetching and filtering events: $e');
      if (mounted) {
        Api().showMessage(
          context,
          "Failed to load events: ${e.toString()}",
          '',
          Theme.of(context).primaryColorDark,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingEvents = false;
        });
      }
    }
  }

  Future<void> _addEvent() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDate == null ||
        _selectedProvince == null) {
      Api().showMessage(
        context,
        "Please fill all required fields (Name, Description, Date, Province)",
        '',
        Theme.of(context).colorScheme.error,
      );
      return;
    }

    Api().showLoading(context);

    try {
      String? posterUrl;
      if (_pickedPoster != null) {
        final storageRef = FirebaseStorage.instance.ref();
        final String fileName =
            'event_posters/${DateTime.now().millisecondsSinceEpoch}_${_titleController.text.replaceAll(' ', '_')}.jpg';
        final UploadTask uploadTask = storageRef
            .child(fileName)
            .putFile(_pickedPoster!);
        final TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
        posterUrl = await snapshot.ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('upcoming_events').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'day': DateFormat('dd').format(_selectedDate!),
        'month': DateFormat('MMM').format(_selectedDate!),
        'year': DateFormat(
          'yyyy',
        ).format(_selectedDate!), // Store year explicitly
        'parsedDate': Timestamp.fromDate(_selectedDate!),
        'posterUrl': posterUrl ?? '', // Use uploaded URL or empty string
        'province': _selectedProvince,
        'liveStreamLink': '', // Initialize new field
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context); // Pop loading dialog
      Api().showMessage(
        context,
        "Event added successfully!",
        '',
        Theme.of(context).splashColor,
      );

      // Clear form fields
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedDate = null;
        _pickedPoster = null;
        _selectedProvince = null;
      });

      _tabController.animateTo(
        0,
      ); // Switch to Upcoming Events tab to see the new event
    } catch (e) {
      print('Error adding event: $e');
      Navigator.pop(context); // Pop loading dialog
      Api().showMessage(
        context,
        "Failed to add event: ${e.toString()}",
        '',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  // --- NEW: Update Event Details ---
  Future<void> _updateEventDetails({
    required String documentId,
    required String newDescription,
    required String newLink,
    required File? newPosterFile,
    required String? currentPosterUrl,
  }) async {
    Api().showLoading(context);

    try {
      String updatedPosterUrl = currentPosterUrl ?? '';

      // 1. Handle Poster Upload/Update
      if (newPosterFile != null) {
        final storageRef = FirebaseStorage.instance.ref();
        final String fileName =
            'event_posters/${documentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final UploadTask uploadTask = storageRef
            .child(fileName)
            .putFile(newPosterFile);
        final TaskSnapshot snapshot = await uploadTask.whenComplete(() => {});
        updatedPosterUrl = await snapshot.ref.getDownloadURL();

        // 2. Delete old poster from storage if a new one was successfully uploaded
        if (currentPosterUrl != null && currentPosterUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance
                .refFromURL(currentPosterUrl)
                .delete();
          } catch (e) {
            print('Error deleting old poster: $e');
            // Log error but don't stop the update
          }
        }
      }

      // 3. Update Firestore Document
      await FirebaseFirestore.instance
          .collection('upcoming_events')
          .doc(documentId)
          .update({
            'description': newDescription.trim(),
            'liveStreamLink': newLink.trim(),
            'posterUrl': updatedPosterUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context); // Pop loading dialog
      Navigator.pop(context); // Pop the bottom sheet

      Api().showMessage(
        context,
        "Event updated successfully!",
        '',
        Theme.of(context).splashColor,
      );

      _fetchAndFilterEvents(); // Refresh the list
    } catch (e) {
      print('Error updating event: $e');
      Navigator.pop(context); // Pop loading dialog
      Api().showMessage(
        context,
        "Failed to update event: ${e.toString()}",
        '',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  // --- NEW: Edit Event Bottom Sheet UI ---
  void _showEditEventSheet(Map<String, dynamic> event) {
    final String documentId = event['id'] as String;
    final String currentPosterUrl = event['posterUrl'] as String? ?? '';
    final String currentTitle = event['title'] as String? ?? 'N/A';

    // Initialize controllers with current values
    _editDescriptionController.text = event['description'] as String? ?? '';
    _liveStreamLinkController.text = event['liveStreamLink'] as String? ?? '';
    _editPickedPoster = null; // Clear local picked file before opening

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        // Use StatefulBuilder to manage local state changes within the sheet (like picking a new image)
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Details for: ${currentTitle}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Description Update
                    TextField(
                      controller: _editDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Update Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      minLines: 3,
                      keyboardType: TextInputType.multiline,
                    ),
                    const SizedBox(height: 16),
                    // Live Stream Link Update
                    TextField(
                      controller: _liveStreamLinkController,
                      decoration: const InputDecoration(
                        labelText: 'Live Stream/URL Link (Optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),

                    // Poster Management Section
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null) {
                                setModalState(() {
                                  _editPickedPoster = File(image.path);
                                });
                              }
                            },
                            icon: const Icon(Icons.image),
                            label: Text(
                              _editPickedPoster == null
                                  ? 'Pick New Poster'
                                  : 'Poster Selected',
                            ),
                          ),
                        ),
                        if (currentPosterUrl.isNotEmpty ||
                            _editPickedPoster != null) ...[
                          const SizedBox(width: 8),
                          // Option to remove/revert poster
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _editPickedPoster = null;
                                // Clearing the URL will rely on the server logic or be a separate button
                                // Here, we only clear the new pick. The "Update" button handles deletion of old poster if a new one is selected.
                              });
                              // Implement logic to remove the existing poster if needed
                            },
                            child: const Text('Clear New Pick'),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 16),
                    // Display Current or New Poster
                    if (_editPickedPoster != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.file(
                          _editPickedPoster!,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (currentPosterUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          currentPosterUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                height: 150,
                                width: double.infinity,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Update Button
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_editDescriptionController.text.isEmpty) {
                          Api().showMessage(
                            context,
                            "Description cannot be empty.",
                            '',
                            Theme.of(context).colorScheme.error,
                          );
                          return;
                        }
                        _updateEventDetails(
                          documentId: documentId,
                          newDescription: _editDescriptionController.text,
                          newLink: _liveStreamLinkController.text,
                          newPosterFile: _editPickedPoster,
                          currentPosterUrl: currentPosterUrl,
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save Updates'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Cancel Button
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- UI Widgets ---

  Widget _buildUpcomingEventsTab() {
    return _isLoadingEvents
        ? const Center(child: CircularProgressIndicator())
        : _filteredEvents.isEmpty
        ? const Center(child: Text('No upcoming events found.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _filteredEvents.length,
            itemBuilder: (context, index) {
              final event = _filteredEvents[index];
              final String dayMonthYear =
                  '${event['day']} ${event['month']} ${event['year'] ?? ''}'
                      .trim(); // Use year
              final String? posterUrl = event['posterUrl'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 16.0),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    // NEW: Tap on the card opens the edit bottom sheet
                    if (event['id'] != null) {
                      _showEditEventSheet(event);
                    } else {
                      Api().showMessage(
                        context,
                        "Cannot edit a dynamically generated event.",
                        '',
                        Theme.of(context).colorScheme.error,
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event['description'] ?? 'No Description',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        if (event['liveStreamLink'] != null &&
                            (event['liveStreamLink'] as String).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.link, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live Link Available',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).primaryColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              dayMonthYear.isNotEmpty
                                  ? dayMonthYear
                                  : 'Date To Be Confirmed',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (event['province'] != null &&
                            (event['province'] as String).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                event['province'] as String,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (posterUrl != null && posterUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              posterUrl,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(
                                        height: 180,
                                        width: double.infinity,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 180,
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        size: 50,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            'Tap Card to Edit/Update Details',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildAddEventTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Event Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 5,
            minLines: 3,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 16),
          // Date Picker
          InkWell(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(DateTime.now().year + 5), // 5 years from now
              );
              if (picked != null && picked != _selectedDate) {
                setState(() {
                  _selectedDate = picked;
                });
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Select Date',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _selectedDate == null
                    ? 'No date selected'
                    : DateFormat('dd MMM yyyy').format(_selectedDate!),
                style: _selectedDate == null
                    ? const TextStyle(color: Colors.grey)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Province Dropdown
          DropdownButtonFormField<String>(
            value: _selectedProvince,
            decoration: const InputDecoration(
              labelText: 'Province',
              border: OutlineInputBorder(),
            ),
            hint: const Text('Select Province'),
            items: _southAfricanProvinces.map((String province) {
              return DropdownMenuItem<String>(
                value: province,
                child: Text(province),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedProvince = newValue;
              });
            },
          ),
          const SizedBox(height: 16),
          // Poster Upload
          ElevatedButton.icon(
            onPressed: () async {
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
              );
              if (image != null) {
                setState(() {
                  _pickedPoster = File(image.path);
                });
              }
            },
            icon: const Icon(Icons.image),
            label: Text(
              _pickedPoster == null
                  ? 'Pick Poster (Optional)'
                  : 'Poster Selected',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          if (_pickedPoster != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.file(_pickedPoster!, height: 150, fit: BoxFit.cover),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _pickedPoster = null;
                });
              },
              child: const Text('Remove Poster'),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addEvent,
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming Events', icon: Icon(Icons.event)),
            Tab(text: 'Add Event', icon: Icon(Icons.add_circle)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUpcomingEventsTab(), // Content for "Upcoming Events"
              _buildAddEventTab(), // Content for "Add Event"
            ],
          ),
        ),
      ],
    );
  }
}
