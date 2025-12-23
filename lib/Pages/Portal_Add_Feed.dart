// ignore_for_file: prefer_const_constructors, sized_box_for_whitespace, use_build_context_synchronously, avoid_print, unused_import, unnecessary_null_comparison

import 'package:flutter/foundation.dart'; // REQUIRED for kIsWeb
import 'dart:io' as io show File;
import 'dart:async';
import 'package:flutter/cupertino.dart'; // Import Cupertino
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ttact/Components/API.dart';

// ⭐️ IMPORTS
import 'package:ttact/Components/BibleVerseRepository.dart';
import 'package:ttact/Components/Upcoming_events_card.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 700.0;

bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class PortalAddFeed extends StatefulWidget {
  const PortalAddFeed({super.key});

  @override
  State<PortalAddFeed> createState() => _PortalAddFeedState();
}

class _PortalAddFeedState extends State<PortalAddFeed>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isWeb = kIsWeb;

  // Controllers for Add Event Form
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDate;
  XFile? _pickedPoster;
  String? _selectedProvince;
  String? _selectedCategoryForAdd; // ⭐️ For adding new event

  // Controllers for EDIT Event Sheet
  final TextEditingController _editDescriptionController =
      TextEditingController();
  final TextEditingController _liveStreamLinkController =
      TextEditingController();
  XFile? _editPickedPoster;
  String? _selectedCategoryForEdit; // ⭐️ For editing event

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

  // ⭐️ CATEGORIES LIST (Consistent across app)
  final List<String> _eventCategories = [
    "Youth",
    "Worship",
    "Outreach",
    "Academic",
    "Gala",
    "General",
  ];

  List<Map<String, dynamic>> _allFetchedEvents = []; // Store ALL events here
  List<Map<String, dynamic>> _filteredEvents = []; // Store FILTERED events here
  bool _isLoadingEvents = true;

  // Helper to track segmented control index for iOS
  int _currentSegment = 0;

  // ⭐️ FILTER STATE (For Viewing)
  int _selectedCategoryFilterIndex = 0;
  // "All" is index 0 for filters, followed by the actual categories
  List<String> get _filterCategories => ["All", ..._eventCategories];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchAndFilterEvents();
  }

  void _handleTabSelection() {
    setState(() {
      _currentSegment = _tabController.index;
    });
    if (_tabController.index == 0) {
      _fetchAndFilterEvents();
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

  // --- CORE FUNCTIONALITY ---

  Future<String> _uploadFile(XFile file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    UploadTask uploadTask;

    if (_isWeb) {
      final bytes = await file.readAsBytes();
      uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
    } else {
      uploadTask = ref.putFile(io.File(file.path));
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _fetchAndFilterEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });

    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('upcoming_events')
          .orderBy('parsedDate', descending: false)
          .get();

      // 1. Parse all documents
      List<Map<String, dynamic>> fetchedEvents = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>..['id'] = doc.id)
          .toList();

      final DateTime now = DateTime.now();

      // 2. Filter by Date (Future only)
      _allFetchedEvents = fetchedEvents.where((event) {
        final DateTime? eventDate = _parseEventStartDate(event);
        if (eventDate == null) {
          return event['day']?.toLowerCase()?.contains('to be confirmed') ??
              false;
        }
        final DateTime today = DateTime(now.year, now.month, now.day);
        final DateTime eventDay = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
        );
        return eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
      }).toList();

      // 3. Apply Category Filter
      _applyCategoryFilter();
    } catch (e) {
      print('Error fetching events: $e');
      if (mounted) {
        Api().showMessage(
          context,
          "Failed to load: ${e.toString()}",
          '',
          Theme.of(context).primaryColorDark,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingEvents = false);
      }
    }
  }

  // ⭐️ NEW: Apply Filter Logic
  void _applyCategoryFilter() {
    String selectedCategory = _filterCategories[_selectedCategoryFilterIndex];

    setState(() {
      if (selectedCategory == "All") {
        _filteredEvents = List.from(_allFetchedEvents);
      } else {
        _filteredEvents = _allFetchedEvents.where((event) {
          // Check if event has 'category' field and matches
          String? eventCat = event['category'];
          return eventCat == selectedCategory;
        }).toList();
      }

      // Sort by date
      _filteredEvents.sort((a, b) {
        final DateTime? dateA = _parseEventStartDate(a);
        final DateTime? dateB = _parseEventStartDate(b);

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      });
    });
  }

  Future<void> _addEvent() async {
    // ⭐️ Validation Check including Category
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDate == null ||
        _selectedProvince == null ||
        _selectedCategoryForAdd == null) {
      Api().showMessage(
        context,
        "Please fill all fields (Name, Desc, Date, Province, Category)",
        '',
        Theme.of(context).colorScheme.error,
      );
      return;
    }

    Api().showLoading(context);

    try {
      String? posterUrl;
      if (_pickedPoster != null) {
        final String fileName =
            'event_posters/${DateTime.now().millisecondsSinceEpoch}_${_titleController.text.replaceAll(' ', '_')}.jpg';
        posterUrl = await _uploadFile(_pickedPoster!, fileName);
      }

      await FirebaseFirestore.instance.collection('upcoming_events').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'day': DateFormat('dd').format(_selectedDate!),
        'month': DateFormat('MMM').format(_selectedDate!),
        'year': DateFormat('yyyy').format(_selectedDate!),
        'parsedDate': Timestamp.fromDate(_selectedDate!),
        'posterUrl': posterUrl ?? '',
        'province': _selectedProvince,
        'category': _selectedCategoryForAdd, // ⭐️ Save Category
        'liveStreamLink': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context);
      Api().showMessage(
        context,
        "Event added successfully!",
        '',
        Theme.of(context).splashColor,
      );

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedDate = null;
        _pickedPoster = null;
        _selectedProvince = null;
        _selectedCategoryForAdd = null; // Reset
      });

      if (isIOSPlatform) {
        setState(() => _currentSegment = 0);
        _tabController.animateTo(0);
      } else {
        _tabController.animateTo(0);
      }
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        "Failed to add event: ${e.toString()}",
        '',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  Future<void> _updateEventDetails({
    required String documentId,
    required String newDescription,
    required String newLink,
    required String? newCategory, // ⭐️ Update Category
    required XFile? newPosterFile,
    required String? currentPosterUrl,
  }) async {
    Api().showLoading(context);

    try {
      String updatedPosterUrl = currentPosterUrl ?? '';

      if (newPosterFile != null) {
        final String fileName =
            'event_posters/${documentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        updatedPosterUrl = await _uploadFile(newPosterFile, fileName);
      }

      await FirebaseFirestore.instance
          .collection('upcoming_events')
          .doc(documentId)
          .update({
            'description': newDescription.trim(),
            'liveStreamLink': newLink.trim(),
            'category': newCategory, // ⭐️ Save Update
            'posterUrl': updatedPosterUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context); // Close Loading
      Navigator.pop(context); // Close Sheet

      Api().showMessage(
        context,
        "Event updated successfully!",
        '',
        Theme.of(context).splashColor,
      );

      _fetchAndFilterEvents();
    } catch (e) {
      Navigator.pop(context);
      Api().showMessage(
        context,
        "Failed to update event: ${e.toString()}",
        '',
        Theme.of(context).primaryColorDark,
      );
    }
  }

  // --- EDIT SHEET (Adaptive) ---
  void _showEditEventSheet(Map<String, dynamic> event) {
    final String documentId = event['id'] as String;
    final String currentPosterUrl = event['posterUrl'] as String? ?? '';
    final String currentTitle = event['title'] as String? ?? 'N/A';

    // Initialize Controllers
    _editDescriptionController.text = event['description'] as String? ?? '';
    _liveStreamLinkController.text = event['liveStreamLink'] as String? ?? '';

    // ⭐️ Initialize Category for Edit
    String? currentCat = event['category'] as String?;
    if (currentCat != null && _eventCategories.contains(currentCat)) {
      _selectedCategoryForEdit = currentCat;
    } else {
      _selectedCategoryForEdit = _eventCategories.last; // Default to 'General'
    }

    _editPickedPoster = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isIOSPlatform ? Colors.transparent : null,
      builder: (context) {
        final color = Theme.of(context);
        final childContent = Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: StatefulBuilder(
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
                        if (isIOSPlatform)
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              margin: const EdgeInsets.only(bottom: 15),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        Text(
                          'Edit: $currentTitle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color.primaryColor,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 16),
                        _buildPlatformTextField(
                          controller: _editDescriptionController,
                          label: 'Update Description',
                          maxLines: 5,
                          minLines: 3,
                          keyboardType: TextInputType.multiline,
                        ),
                        const SizedBox(height: 16),

                        // ⭐️ EDIT CATEGORY DROPDOWN
                        _buildPlatformDropdown(
                          value: _selectedCategoryForEdit,
                          items: _eventCategories,
                          hint: "Event Category",
                          onChanged: (val) {
                            setModalState(() => _selectedCategoryForEdit = val);
                          },
                        ),

                        const SizedBox(height: 16),
                        _buildPlatformTextField(
                          controller: _liveStreamLinkController,
                          label: 'Live Stream/URL Link',
                          prefixIcon: isIOSPlatform
                              ? CupertinoIcons.link
                              : Icons.link,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPlatformButton(
                                onPressed: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                  );
                                  if (image != null) {
                                    setModalState(
                                      () => _editPickedPoster = image,
                                    );
                                  }
                                },
                                text: _editPickedPoster == null
                                    ? 'Change Poster'
                                    : 'New Selected',
                                icon: isIOSPlatform
                                    ? CupertinoIcons.photo
                                    : Icons.image,
                                color: color.splashColor,
                              ),
                            ),
                            if (currentPosterUrl.isNotEmpty ||
                                _editPickedPoster != null) ...[
                              const SizedBox(width: 8),
                              isIOSPlatform
                                  ? CupertinoButton(
                                      child: const Text('Clear'),
                                      onPressed: () => setModalState(
                                        () => _editPickedPoster = null,
                                      ),
                                    )
                                  : TextButton(
                                      onPressed: () => setModalState(
                                        () => _editPickedPoster = null,
                                      ),
                                      child: const Text('Clear'),
                                    ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_editPickedPoster != null)
                          _buildImagePreview(
                            _editPickedPoster!,
                            150,
                            setModalState,
                          )
                        else if (currentPosterUrl.isNotEmpty)
                          _buildNetworkImagePreview(currentPosterUrl),
                        const SizedBox(height: 24),
                        _buildPlatformButton(
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
                              newCategory: _selectedCategoryForEdit, // ⭐️ Pass
                              newPosterFile: _editPickedPoster,
                              currentPosterUrl: currentPosterUrl,
                            );
                          },
                          text: 'Save Updates',
                          icon: isIOSPlatform
                              ? CupertinoIcons.floppy_disk
                              : Icons.save,
                        ),
                        const SizedBox(height: 8),
                        if (isIOSPlatform)
                          CupertinoButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );

        if (isIOSPlatform) {
          return Container(
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: childContent,
          );
        } else {
          return childContent;
        }
      },
    );
  }

  // --- UI WIDGETS ---

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

  // ⭐️ MERGED: Category Filter Chips
  Widget _buildCategoryFilters(ThemeData color) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterCategories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryFilterIndex = index;
                  _applyCategoryFilter(); // Apply Filter locally without fetch
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
                    _filterCategories[index],
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

  // ⭐️ MERGED: Interactive Empty State (Admin Version)
  Widget _buildInteractiveEmptyState(ThemeData color) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        margin: const EdgeInsets.only(top: 20),
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
                Icons.event_note,
                size: 60,
                color: color.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No Events Found",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color.primaryColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "There are no events in this category.\nTry clearing the filter or add one!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 25),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategoryFilterIndex = 0; // Reset to "All"
                      _applyCategoryFilter();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text("Clear Filter"),
                ),
                const SizedBox(width: 15),
                // Admin specific "Add Event" button
                ElevatedButton.icon(
                  onPressed: () {
                    // Switch to Add Tab
                    setState(() => _currentSegment = 1);
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    "Add Event",
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- PLATFORM BUILDER HELPERS ---

  Widget _buildPlatformLoader() {
    return Center(
      child: isIOSPlatform
          ? const CupertinoActivityIndicator()
          : const CircularProgressIndicator(),
    );
  }

  Widget _buildPlatformButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    Color? color,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: onPressed,
          disabledColor: CupertinoColors.quaternarySystemFill,
          borderRadius: BorderRadius.circular(10),
          padding: const EdgeInsets.symmetric(vertical: 14),
          minSize: 45,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: textColor ?? Colors.white),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: textColor ?? Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: color ?? theme.primaryColor,
          foregroundColor: textColor ?? Colors.white,
        ),
      );
    }
  }

  Widget _buildPlatformTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? minLines,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
  }) {
    if (isIOSPlatform) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Text(
              label,
              style: TextStyle(
                color: CupertinoColors.systemGrey,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          CupertinoTextField(
            controller: controller,
            placeholder: 'Enter $label',
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: keyboardType,
            padding: const EdgeInsets.all(12),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Icon(prefixIcon, color: CupertinoColors.systemGrey),
                  )
                : null,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              border: Border.all(color: CupertinoColors.systemGrey4),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      );
    } else {
      return TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: minLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: OutlineInputBorder(),
          alignLabelWithHint: maxLines > 1,
        ),
      );
    }
  }

  Future<void> _handleDateSelection() async {
    final now = DateTime.now();
    if (isIOSPlatform) {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? now,
                  minimumDate: now,
                  maximumDate: DateTime(now.year + 5),
                  onDateTimeChanged: (newDate) {
                    setState(() => _selectedDate = newDate);
                  },
                ),
              ),
              CupertinoButton(
                child: const Text('Done'),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? now,
        firstDate: now,
        lastDate: DateTime(now.year + 5),
      );
      if (picked != null && picked != _selectedDate) {
        setState(() => _selectedDate = picked);
      }
    }
  }

  Widget _buildPlatformDatePickerSelector() {
    final text = _selectedDate == null
        ? 'Select Date'
        : DateFormat('dd MMM yyyy').format(_selectedDate!);
    final icon = isIOSPlatform ? CupertinoIcons.calendar : Icons.calendar_today;

    if (isIOSPlatform) {
      return GestureDetector(
        onTap: _handleDateSelection,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8),
            color: CupertinoColors.systemBackground,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: _selectedDate == null
                      ? CupertinoColors.placeholderText
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
              Icon(icon, color: CupertinoColors.systemGrey),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        onTap: _handleDateSelection,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Select Date',
            border: OutlineInputBorder(),
            suffixIcon: Icon(icon),
          ),
          child: Text(
            text,
            style: _selectedDate == null
                ? const TextStyle(color: Colors.grey)
                : null,
          ),
        ),
      );
    }
  }

  // ⭐️ Reusable Dropdown for Province AND Category
  Widget _buildPlatformDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    if (isIOSPlatform) {
      return GestureDetector(
        onTap: () {
          showCupertinoModalPopup(
            context: context,
            builder: (ctx) => Container(
              height: 250,
              color: CupertinoColors.systemBackground.resolveFrom(context),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: CupertinoPicker(
                      itemExtent: 32,
                      onSelectedItemChanged: (int index) {
                        onChanged(items[index]);
                      },
                      children: items
                          .map((e) => Center(child: Text(e)))
                          .toList(),
                    ),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
          );
          if (value == null && items.isNotEmpty) {
            onChanged(items[0]);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey4),
            borderRadius: BorderRadius.circular(8),
            color: CupertinoColors.systemBackground,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ?? hint,
                style: TextStyle(
                  color: value == null
                      ? CupertinoColors.placeholderText
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_down,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
            ],
          ),
        ),
      );
    } else {
      return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(),
        ),
        hint: Text(hint),
        items: items
            .map(
              (String item) =>
                  DropdownMenuItem<String>(value: item, child: Text(item)),
            )
            .toList(),
        onChanged: onChanged,
      );
    }
  }

  Widget _buildImagePreview(
    XFile file,
    double height,
    StateSetter setModalState,
  ) {
    if (_isWeb) {
      return Container(
        height: height,
        color: Colors.grey.shade200,
        child: const Center(
          child: Text(
            "Image Ready (Web Preview Unavailable)",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.file(
        io.File(file.path),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildNetworkImagePreview(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Image.network(
        url,
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
        errorBuilder: (context, error, stackTrace) => Container(
          height: 150,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  // ⭐️ MERGED: The New Hybrid Upcoming Events Tab
  Widget _buildUpcomingEventsTab() {
    final dailyVerse = BibleVerseRepository.getDailyVerse();
    final color = Theme.of(context);

    if (_isLoadingEvents) return _buildPlatformLoader();

    return RefreshIndicator(
      onRefresh: _fetchAndFilterEvents,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Verse Card
          _buildDailyVerseCard(color, dailyVerse),
          const SizedBox(height: 25),

          // 2. Banner
          _buildOpportunityBanner(context),
          const SizedBox(height: 25),

          // 3. Filters
          _buildCategoryFilters(color),
          const SizedBox(height: 20),

          // 4. Section Title
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: color.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Manage Events',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // 5. The List
          if (_filteredEvents.isEmpty)
            _buildInteractiveEmptyState(color)
          else
            Column(
              children: _filteredEvents.map((event) {
                // Extract Data safely
                final String date = event['day'] ?? '';
                final String eventMonth = event['month'] ?? '';
                final String eventTitle = event['title'] ?? 'No Title';
                final String eventDescription =
                    event['description'] ?? 'No Description';
                final String? posterUrl = event['posterUrl'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 15.0),
                  child: GestureDetector(
                    onTap: () {
                      // ⭐️ IMPORTANT: TAP OPENS ADMIN EDIT SHEET
                      _showEditEventSheet(event);
                    },
                    // Use the beautiful card for display
                    child: UpcomingEventsCard(
                      posterUrl: (posterUrl != null && posterUrl.isNotEmpty)
                          ? posterUrl
                          : null,
                      date: date,
                      eventMonth: eventMonth,
                      eventTitle: eventTitle,
                      eventDescription: eventDescription,
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildAddEventTab() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add New Event',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.none,
                ),
              ),
              const Divider(height: 20),
              _buildPlatformTextField(
                controller: _titleController,
                label: 'Event Name',
              ),
              const SizedBox(height: 16),
              _buildPlatformTextField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 5,
                minLines: 3,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: 16),
              _buildPlatformDatePickerSelector(),
              const SizedBox(height: 16),

              // ⭐️ PROVINCE DROPDOWN
              _buildPlatformDropdown(
                value: _selectedProvince,
                items: _southAfricanProvinces,
                hint: "Select Province",
                onChanged: (val) => setState(() => _selectedProvince = val),
              ),
              const SizedBox(height: 16),

              // ⭐️ CATEGORY DROPDOWN
              _buildPlatformDropdown(
                value: _selectedCategoryForAdd,
                items: _eventCategories,
                hint: "Select Category",
                onChanged: (val) =>
                    setState(() => _selectedCategoryForAdd = val),
              ),

              const SizedBox(height: 16),
              _buildPlatformButton(
                onPressed: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) setState(() => _pickedPoster = image);
                },
                text: _pickedPoster == null
                    ? 'Pick Poster (Optional)'
                    : 'Poster Selected',
                icon: isIOSPlatform ? CupertinoIcons.photo : Icons.image,
                color: Theme.of(context).scaffoldBackgroundColor,
                textColor: Theme.of(context).primaryColor,
              ),
              if (_pickedPoster != null) ...[
                const SizedBox(height: 10),
                _buildImagePreview(_pickedPoster!, 150, (_) {}),
                const SizedBox(height: 10),
                if (isIOSPlatform)
                  CupertinoButton(
                    onPressed: () => setState(() => _pickedPoster = null),
                    child: const Text('Remove Poster'),
                  )
                else
                  TextButton(
                    onPressed: () => setState(() => _pickedPoster = null),
                    child: const Text('Remove Poster'),
                  ),
              ],
              const SizedBox(height: 24),
              _buildPlatformButton(
                onPressed: _addEvent,
                text: 'Add Event',
                icon: isIOSPlatform ? CupertinoIcons.add : Icons.add,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isIOSPlatform) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: CupertinoSegmentedControl<int>(
                children: {
                  0: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("Upcoming Events"),
                  ),
                  1: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text("Add Event"),
                  ),
                },
                onValueChanged: (int val) {
                  setState(() {
                    _currentSegment = val;
                    _tabController.animateTo(val);
                  });
                  if (val == 0) _fetchAndFilterEvents();
                },
                groupValue: _currentSegment,
                borderColor: Theme.of(context).primaryColor,
                selectedColor: Theme.of(context).primaryColor,
                pressedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              ),
            ),
          ),
          Expanded(
            child: _currentSegment == 0
                ? _buildUpcomingEventsTab()
                : _buildAddEventTab(),
          ),
        ],
      );
    } else {
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
              children: [_buildUpcomingEventsTab(), _buildAddEventTab()],
            ),
          ),
        ],
      );
    }
  }

  static DateTime? _parseEventStartDate(Map<String, dynamic> event) {
    final now = DateTime.now();
    final currentYear = now.year;
    String? dayPart = event['day'];
    String? monthPart = event['month'];

    if (event.containsKey('parsedDate') && event['parsedDate'] is Timestamp) {
      return (event['parsedDate'] as Timestamp).toDate();
    }
    if (dayPart != null &&
        monthPart != null &&
        dayPart.length <= 2 &&
        monthPart.length == 3) {
      try {
        final date = DateFormat(
          'dd MMM yyyy',
        ).parse('$dayPart $monthPart $currentYear');
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
    if (dayPart != null && dayPart.contains('-') && monthPart == '') {
      final parts = dayPart.split('-').map((s) => s.trim()).toList();
      for (var part in parts) {
        if (part.length == 3) {
          try {
            DateTime date = DateFormat('MMM yyyy').parse('$part $currentYear');
            if (date.isBefore(now) && date.month < now.month) {
              date = DateFormat('MMM yyyy').parse('$part ${currentYear + 1}');
            }
            return date;
          } on FormatException {
            continue;
          }
        }
      }
    }
    return null;
  }
}
