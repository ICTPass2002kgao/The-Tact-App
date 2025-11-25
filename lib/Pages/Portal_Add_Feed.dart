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

  // Controllers for EDIT Event Sheet
  final TextEditingController _editDescriptionController =
      TextEditingController();
  final TextEditingController _liveStreamLinkController =
      TextEditingController();
  XFile? _editPickedPoster;

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

  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoadingEvents = true;

  // Helper to track segmented control index for iOS
  int _currentSegment = 0;

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
          // Use provided color or default primary
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
              )
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

  Widget _buildPlatformDropdown() {
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
                        setState(() {
                          _selectedProvince = _southAfricanProvinces[index];
                        });
                      },
                      children: _southAfricanProvinces
                          .map((e) => Center(child: Text(e)))
                          .toList(),
                    ),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
            ),
          );
          // Set default if null when opening
          if (_selectedProvince == null) {
            setState(() {
              _selectedProvince = _southAfricanProvinces[0];
            });
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
                _selectedProvince ?? 'Select Province',
                style: TextStyle(
                  color: _selectedProvince == null
                      ? CupertinoColors.placeholderText
                      : CupertinoColors.label.resolveFrom(context),
                ),
              ),
              const Icon(CupertinoIcons.chevron_down,
                  size: 16, color: CupertinoColors.systemGrey),
            ],
          ),
        ),
      );
    } else {
      return DropdownButtonFormField<String>(
        value: _selectedProvince,
        decoration: const InputDecoration(
          labelText: 'Province',
          border: OutlineInputBorder(),
        ),
        hint: const Text('Select Province'),
        items: _southAfricanProvinces
            .map(
              (String province) => DropdownMenuItem<String>(
                value: province,
                child: Text(province),
              ),
            )
            .toList(),
        onChanged: (String? newValue) =>
            setState(() => _selectedProvince = newValue),
      );
    }
  }

  // --- CORE FUNCTIONALITY (Unchanged Logic) ---

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

      List<Map<String, dynamic>> fetchedEvents = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>..['id'] = doc.id)
          .toList();

      final DateTime now = DateTime.now();
      _filteredEvents = fetchedEvents.where((event) {
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
        setState(() => _isLoadingEvents = false);
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
      });

      // Platform aware tab switching
      if (isIOSPlatform) {
        setState(() {
          _currentSegment = 0;
        });
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

        if (currentPosterUrl != null && currentPosterUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance
                .refFromURL(currentPosterUrl)
                .delete();
          } catch (e) {
            print('Error deleting old poster: $e');
          }
        }
      }

      await FirebaseFirestore.instance
          .collection('upcoming_events')
          .doc(documentId)
          .update({
            'description': newDescription.trim(),
            'liveStreamLink': newLink.trim(),
            'posterUrl': updatedPosterUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      Navigator.pop(context);
      Navigator.pop(context);

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

    _editDescriptionController.text = event['description'] as String? ?? '';
    _liveStreamLinkController.text = event['liveStreamLink'] as String? ?? '';
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
                        // Drag handle for iOS style
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
                          'Edit Details for: $currentTitle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: color.primaryColor,
                            decoration: TextDecoration.none,
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

                        _buildPlatformTextField(
                          controller: _liveStreamLinkController,
                          label: 'Live Stream/URL Link (Optional)',
                          prefixIcon:
                              isIOSPlatform ? CupertinoIcons.link : Icons.link,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 24),

                        // Poster Management
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
                                    setModalState(() {
                                      _editPickedPoster = image;
                                    });
                                  }
                                },
                                text: _editPickedPoster == null
                                    ? 'Pick New Poster'
                                    : 'Poster Selected',
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
                                      onPressed: () {
                                        setModalState(() {
                                          _editPickedPoster = null;
                                        });
                                      },
                                    )
                                  : TextButton(
                                      onPressed: () {
                                        setModalState(() {
                                          _editPickedPoster = null;
                                        });
                                      },
                                      child: const Text('Clear New Pick'),
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

  Widget _buildUpcomingEventsTab() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: _isLoadingEvents
            ? _buildPlatformLoader()
            : _filteredEvents.isEmpty
            ? const Center(child: Text('No upcoming events found.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: _filteredEvents.length,
                itemBuilder: (context, index) {
                  final event = _filteredEvents[index];
                  final String dayMonthYear =
                      '${event['day']} ${event['month']} ${event['year'] ?? ''}'
                          .trim();
                  final String? posterUrl = event['posterUrl'] as String?;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (event['id'] != null) {
                          _showEditEventSheet(event);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
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
                                (event['liveStreamLink'] as String)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    isIOSPlatform
                                        ? CupertinoIcons.link
                                        : Icons.link,
                                    size: 16,
                                  ),
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
                                Icon(
                                  isIOSPlatform
                                      ? CupertinoIcons.calendar
                                      : Icons.calendar_today,
                                  size: 16,
                                ),
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
                                  Icon(
                                    isIOSPlatform
                                        ? CupertinoIcons.location_solid
                                        : Icons.location_on,
                                    size: 16,
                                  ),
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
                              _buildNetworkImagePreview(posterUrl),
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
              ),
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
              // Platform Adaptive Date Picker
              _buildPlatformDatePickerSelector(),

              const SizedBox(height: 16),
              // Platform Adaptive Dropdown
              _buildPlatformDropdown(),

              const SizedBox(height: 16),
              // Platform Adaptive Poster Button
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
    // iOS uses Segmented Control instead of TabBar for better UX
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
                // Using system colors for native look
                borderColor: Theme.of(context).primaryColor,
                selectedColor: Theme.of(context).primaryColor,
                pressedColor:
                    Theme.of(context).primaryColor.withOpacity(0.2),
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
      // Android / Web / Windows Standard TabBar
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
                _buildUpcomingEventsTab(),
                _buildAddEventTab(),
              ],
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