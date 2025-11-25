// ignore_for_file: prefer_const_constructors, unused_local_variable, unnecessary_null_comparison, avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:shimmer/shimmer.dart';

// --- PLATFORM UTILITIES ---
const double _desktopContentMaxWidth = 1000.0;
const int _desktopGridColumns = 3;
bool isLargeScreen(BuildContext context) =>
    MediaQuery.of(context).size.width >= 700;
// --------------------------

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  // --- State for Overseer Management ---
  bool _isLoadingOverseers = true;
  List<DocumentSnapshot> _allOverseers = [];
  List<DocumentSnapshot> _filteredOverseers = [];

  final TextEditingController _searchController = TextEditingController();

  // Region Filter
  final List<String> _filterOptions = ['All Regions']; // Will be populated
  String _selectedFilter = 'All Regions';

  // NEW: Province Filter
  final List<String> _provinceFilterOptions = [
    'All Provinces',
  ]; // Will be populated
  String _selectedProvinceFilter = 'All Provinces';

  // --- Pagination State ---
  int _pageSize = 20;
  int _currentPage = 0; // 0-indexed

  // --- End of State ---

  @override
  void initState() {
    super.initState();
    _fetchAndSortOverseers();
    _searchController.addListener(_runFilters);
  }

  @override
  void dispose() {
    _searchController.removeListener(_runFilters);
    _searchController.dispose();
    super.dispose();
  }

  /// Fetches, sorts, and sets up the overseer data and filters.
  Future<void> _fetchAndSortOverseers() async {
    setState(() {
      _isLoadingOverseers = true;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('overseers')
          .get();

      final docs = snapshot.docs;

      // 1. SORTING: Sort by most districts first
      docs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aDistricts = (aData['districts'] as List? ?? []).length;
        final bDistricts = (bData['districts'] as List? ?? []).length;
        return bDistricts.compareTo(aDistricts); // b vs a for descending
      });

      // 2. POPULATE FILTERS: Get unique regions and provinces
      final Set<String> regions = {'All Regions'};
      final Set<String> provinces = {'All Provinces'}; // NEW
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;

        final region = data['region'] as String?;
        if (region != null && region.isNotEmpty) {
          regions.add(region);
        }

        // NEW: Populate provinces
        final province = data['province'] as String?;
        if (province != null && province.isNotEmpty) {
          provinces.add(province);
        }
      }

      // 3. SET STATE
      setState(() {
        _allOverseers = docs;
        _filteredOverseers = docs;

        _filterOptions.clear();
        _filterOptions.addAll(regions.toList()..sort());
        _selectedFilter = 'All Regions'; // Reset

        _provinceFilterOptions.clear(); // NEW
        _provinceFilterOptions.addAll(provinces.toList()..sort()); // NEW
        _selectedProvinceFilter = 'All Provinces'; // NEW

        _isLoadingOverseers = false;
        _currentPage = 0; // Reset page on fetch
      });
    } catch (e) {
      print("Error fetching overseers: $e");
      setState(() {
        _isLoadingOverseers = false;
        // Optionally, show an error message
      });
    }
  }

  /// Applies search and filter criteria to the master list.
  void _runFilters() {
    List<DocumentSnapshot> temp = _allOverseers;
    final searchQuery = _searchController.text.toLowerCase();

    // 1. Apply Search Query
    if (searchQuery.isNotEmpty) {
      temp = temp.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['overseerInitialsAndSurname'] ?? '').toLowerCase();
        final region = (data['region'] ?? '').toLowerCase();
        final code = (data['code'] ?? '').toLowerCase();
        return name.contains(searchQuery) ||
            region.contains(searchQuery) ||
            code.contains(searchQuery);
      }).toList();
    }

    // 2. Apply Region Filter
    if (_selectedFilter != 'All Regions') {
      temp = temp.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['region'] == _selectedFilter;
      }).toList();
    }

    // 3. NEW: Apply Province Filter
    if (_selectedProvinceFilter != 'All Provinces') {
      temp = temp.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['province'] == _selectedProvinceFilter;
      }).toList();
    }

    setState(() {
      _filteredOverseers = temp;
      _currentPage = 0; // Reset to first page on new filter
    });
  }

  /// Shows the dialog to edit an overseer's districts.
  /// This has been upgraded from AlertDialog to a more professional Dialog.
  void _showEditDialog(DocumentSnapshot overseerDoc) {
    final docData = overseerDoc.data() as Map<String, dynamic>;

    // --- ALIGNED DATA STRUCTURE ---
    final List<Map<String, dynamic>> currentDistricts =
        List<Map<String, dynamic>>.from(
          (docData['districts'] as List? ?? []).map(
            (d) => Map<String, dynamic>.from(d),
          ),
        );

    // --- Controllers for the dialog ---
    final TextEditingController emailController = TextEditingController(
      text: docData['email'] ?? '',
    );
    // NEW: Controllers for Region and Code
    final TextEditingController regionController = TextEditingController(
      text: docData['region'] ?? '',
    );
    final TextEditingController codeController = TextEditingController(
      text: docData['code'] ?? '',
    );
    final TextEditingController newDistrictController = TextEditingController();
    final TextEditingController newCommunityController =
        TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // NEW: State variable to track the last added district
        String? _lastAddedDistrictName;

        // Use StatefulBuilder to manage the dialog's internal state
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              // Constrain the size for web and mobile
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Dialog Header ---
                      Text(
                        'Edit ${docData['overseerInitialsAndSurname']}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),

                      // --- Email Field ---
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      SizedBox(height: 16),

                      // --- NEW: Region and Code Fields ---
                      TextField(
                        controller: regionController,
                        decoration: InputDecoration(
                          labelText: 'Region',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: 'Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      Divider(height: 24),

                      // --- District Management Section ---
                      Text(
                        'Manage Districts & Communities',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),

                      // --- List of Districts (Scrollable) ---
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Map each district to an ExpansionTile
                              ...currentDistricts.map((district) {
                                final districtName =
                                    district['districtElderName'] as String? ??
                                    'Unnamed';
                                final List<dynamic> communities =
                                    List<dynamic>.from(
                                      district['communities'] as List? ?? [],
                                    );

                                return ExpansionTile(
                                  // NEW: Auto-expand when just added
                                  initiallyExpanded:
                                      districtName == _lastAddedDistrictName,
                                  title: Text(districtName),
                                  subtitle: Text(
                                    '${communities.length} ${communities.length == 1 ? "community" : "communities"}',
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.delete_forever,
                                      color: Colors.red[700],
                                    ),
                                    tooltip: 'Delete this district',
                                    onPressed: () {
                                      setDialogState(() {
                                        currentDistricts.remove(district);
                                      });
                                    },
                                  ),
                                  children: [
                                    // --- List of communities ---
                                    ...communities.map((community) {
                                      final commName =
                                          community['communityName']
                                              as String? ??
                                          'Unnamed';
                                      return ListTile(
                                        title: Text(commName),
                                        dense: true,
                                        leading: Icon(Icons.circle, size: 8),
                                        trailing: IconButton(
                                          icon: Icon(Icons.close, size: 18),
                                          tooltip: 'Remove this community',
                                          onPressed: () {
                                            setDialogState(() {
                                              communities.remove(community);
                                            });
                                          },
                                        ),
                                      );
                                    }).toList(),

                                    // --- Add Community Form ---
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16.0,
                                        vertical: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  newCommunityController,
                                              decoration: InputDecoration(
                                                labelText: 'Add Community',
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              Icons.add_circle,
                                              color: Theme.of(
                                                context,
                                              ).primaryColor,
                                            ),
                                            onPressed: () {
                                              final newCommName =
                                                  newCommunityController.text
                                                      .trim();
                                              if (newCommName.isNotEmpty) {
                                                setDialogState(() {
                                                  communities.add({
                                                    'communityName':
                                                        newCommName,
                                                  });
                                                });
                                                newCommunityController.clear();
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),

                      Divider(height: 24),

                      // --- Add New District Form ---
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: newDistrictController,
                              decoration: InputDecoration(
                                labelText: 'Add New District Elder',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            child: Text('Add'),
                            onPressed: () {
                              final newDistrictName = newDistrictController.text
                                  .trim();
                              if (newDistrictName.isNotEmpty) {
                                setDialogState(() {
                                  // NEW: Set the last added name
                                  _lastAddedDistrictName = newDistrictName;
                                  currentDistricts.add({
                                    'districtElderName': newDistrictName,
                                    'communities': [],
                                  });
                                });
                                newDistrictController.clear();
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),

                      // --- Dialog Actions ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text('Cancel'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            child: Text('Save Changes'),
                            onPressed: () async {
                              final newEmail = emailController.text.trim();
                              // NEW: Get region and code values
                              final newRegion = regionController.text.trim();
                              final newCode = codeController.text.trim();

                              // Store updates in a Map to send to Firestore
                              final Map<String, dynamic> updates = {};

                              // 1. Check if email changed
                              if (newEmail.isNotEmpty &&
                                  newEmail != docData['email']) {
                                updates['email'] = newEmail;
                                // As noted, this only updates Firestore.
                                print(
                                  'NOTE: Updating email in Firestore. FirebaseAuth email update requires a Cloud Function.',
                                );
                              }

                              // NEW: Check if region changed
                              if (newRegion.isNotEmpty &&
                                  newRegion != docData['region']) {
                                updates['region'] = newRegion;
                              }

                              // NEW: Check if code changed
                              if (newCode.isNotEmpty &&
                                  newCode != docData['code']) {
                                updates['code'] = newCode;
                              }

                              // 2. Add the modified districts list
                              // We update this even if it's the same, to catch all
                              // the in-dialog modifications (add/remove)
                              updates['districts'] = currentDistricts;

                              // 3. Update in Firestore with all changes
                              try {
                                await overseerDoc.reference.update(updates);
                                Navigator.of(context).pop();
                                // 4. Refresh all data to show changes
                                // This will re-fetch AND reset pagination
                                _fetchAndSortOverseers();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Overseer updated successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } catch (e) {
                                print("Error updating overseer: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error updating overseer.'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final isDesktop = isLargeScreen(context);

    // --- Pagination Logic ---
    final int totalItems = _filteredOverseers.length;
    final int totalPages = (totalItems / _pageSize)
        .ceil(); // Calculate total pages
    final int startIndex = _currentPage * _pageSize;
    final int endIndex = (startIndex + _pageSize > totalItems)
        ? totalItems
        : startIndex + _pageSize;

    // Create the list for the current page
    final List<DocumentSnapshot> _pagedOverseers = (totalItems > 0)
        ? _filteredOverseers.sublist(startIndex, endIndex)
        : [];
    // --- End Pagination Logic ---

    // Define the list of metric items (kept as is)
    final List<Map<String, dynamic>> metricItems = [
      {
        'title': "TOTAL TACTSO BRANCHES",
        'icon': Icons.location_city_outlined,
        'future': FirebaseFirestore.instance
            .collection('tactso_branches')
            .get(),
        'backgroundColor': color.primaryColorLight,
      },
      {
        'title': "TOTAL TACT Songs",
        'icon': Ionicons.musical_notes_outline,
        'future': FirebaseFirestore.instance.collection('tact_music').get(),
        'backgroundColor': color.primaryColorDark,
      },
      {
        'title': "TOTAL TACT SELLERS",
        'icon': Ionicons.people_outline,
        'future': FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Seller')
            .get(),
        'backgroundColor': color.splashColor,
      },
      {
        'title': "TOTAL TACT OVERSEERS",
        'icon': Ionicons.people_outline,
        'future': FirebaseFirestore.instance
            .collection('overseers')
            .where('role', isEqualTo: 'overseer')
            .get(),
        'backgroundColor': color.primaryColor,
      },
    ];

    return Center(
      // 1. Constrain the content width
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _desktopContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: ListView(
            children: [
              Text(
                'TACT DASHBOARD',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: color.primaryColor,
                ),
              ),
              Text(
                'Welcome!, Here\'s a summary of our church\'s activities and status.',
                style: TextStyle(color: color.hintColor),
              ),
              const SizedBox(height: 20),

              // 2. Responsive Dashboard Grid (Kept as is)
              LayoutBuilder(
                builder: (context, constraints) {
                  final double spacing = isDesktop ? 20.0 : 10.0;
                  final double itemWidth = isDesktop
                      ? (constraints.maxWidth -
                                (spacing * (_desktopGridColumns - 1))) /
                            _desktopGridColumns
                      : constraints.maxWidth;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: metricItems.map((item) {
                      return _buildDashboardCard(
                        context: context,
                        title: item['title'],
                        icon: item['icon'],
                        future: item['future'],
                        backgroundColor: item['backgroundColor'],
                        itemWidth: itemWidth,
                        isDesktop: isDesktop,
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 20),

              // --- MODIFIED SECTION: Overseer Management ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'OVERSEER MANAGEMENT',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: color.primaryColor,
                    ),
                  ),
                  Icon(
                    Ionicons.people_circle_outline,
                    color: color.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // --- Search and Filter UI ---
              Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by Name, Region, or Code',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // NEW: Row for filters
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedFilter,
                          items: _filterOptions.map((region) {
                            return DropdownMenuItem<String>(
                              value: region,
                              child: Text(region),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedFilter = value;
                              });
                              _runFilters(); // Re-run filters
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Filter by Region',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      // NEW: Province Filter
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedProvinceFilter,
                          items: _provinceFilterOptions.map((province) {
                            return DropdownMenuItem<String>(
                              value: province,
                              child: Text(province),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedProvinceFilter = value;
                              });
                              _runFilters(); // Re-run filters
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Filter by Province',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      // "Add New" button
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text('Add New'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            // TODO: Implement navigation to an 'Add Overseer' page
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Navigation to Add New page not implemented yet.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- Overseer Table ---
              _isLoadingOverseers
                  ? Center(child: CircularProgressIndicator())
                  : _filteredOverseers.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'No overseers found matching your criteria.',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    )
                  : Table(
                      border: TableBorder.all(
                        color: color.hintColor.withOpacity(0.4),
                        width: 1,
                      ),
                      // Use FlexColumnWidth to make the table fill the section
                      columnWidths: const {
                        0: FlexColumnWidth(2.5), // Name
                        1: FlexColumnWidth(1.5), // Region
                        2: FlexColumnWidth(1), // Code
                        3: FlexColumnWidth(1), // District Count
                        4: FlexColumnWidth(1), // Edit Button
                      },
                      children: [
                        // --- STYLED HEADER ROW ---
                        TableRow(
                          decoration: BoxDecoration(
                            color: color.primaryColor.withOpacity(0.1),
                          ),
                          children: [
                            _buildHeaderCell('Overseer Name'),
                            _buildHeaderCell('Region'),
                            _buildHeaderCell('Code'),
                            _buildHeaderCell('Districts'),
                            _buildHeaderCell('Edit'),
                          ],
                        ),

                        // --- DYNAMIC DATA ROWS ---
                        ..._pagedOverseers.map((doc) {
                          // <-- UPDATED
                          final data = doc.data() as Map<String, dynamic>;
                          final districts = data['districts'] as List?;
                          final districtCount =
                              districts?.length.toString() ?? '0';

                          return TableRow(
                            decoration: BoxDecoration(
                              color: Colors.transparent, // Default row color
                            ),
                            children: [
                              _buildTableCell(
                                data['overseerInitialsAndSurname'] ?? 'N/A',
                              ),
                              _buildTableCell(data['region'] ?? 'N/A'),
                              _buildTableCell(data['code'] ?? 'N/A'),
                              // Center the district count
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  districtCount,
                                  style: TextStyle(fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              // Add Edit Button Cell
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Center(
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit_note,
                                      color: color.primaryColor,
                                    ),
                                    tooltip: 'Edit Districts',
                                    onPressed: () {
                                      _showEditDialog(doc);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
              // --- PAGINATION CONTROLS ---
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: Icon(Icons.chevron_left),
                        label: Text('Previous'),
                        // Disable button on the first page
                        onPressed: _currentPage == 0
                            ? null
                            : () {
                                setState(() {
                                  _currentPage--;
                                });
                              },
                      ),
                      Text(
                        'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                      ),
                      TextButton.icon(
                        label: Text('Next'),
                        icon: Icon(Icons.chevron_right),
                        // Disable button on the last page
                        onPressed: _currentPage >= totalPages - 1
                            ? null
                            : () {
                                setState(() {
                                  _currentPage++;
                                });
                              },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS FOR TABLE ---

  // Helper for table data cells
  Widget _buildTableCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(text, style: TextStyle(fontSize: 14)),
    );
  }

  // Helper for table header cells
  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }

  // --- END HELPER WIDGETS ---

  // Reusable widget for dashboard cards - (Kept as is)
  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Future<QuerySnapshot> future,
    required Color backgroundColor,
    required double itemWidth,
    required bool isDesktop,
  }) {
    final color = Theme.of(context);
    return Container(
      width: itemWidth,
      height: 180,
      decoration: BoxDecoration(
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
                baseColor: color.scaffoldBackgroundColor.withOpacity(0.8),
                highlightColor: color.hintColor.withOpacity(0.8),
                child: Container(color: Colors.white),
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
            final count = data!.docs.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: isDesktop ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: color.scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    Icon(icon, color: color.scaffoldBackgroundColor, size: 28),
                  ],
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.w900,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
