import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/Aduit_Logs/Overseer_Audit_Logs.dart';
import 'overseer_widgets.dart'; // Ensure this contains buildPlatformTextField

class AllMembersTab extends StatefulWidget {
  final String? committeeMemberName;
  final String? committeeMemberRole;
  final String? faceUrl;
  final bool isLargeScreen;
  const AllMembersTab({super.key, required this.isLargeScreen, required this.committeeMemberName, required this.committeeMemberRole, required this.faceUrl});

  @override
  State<AllMembersTab> createState() => _AllMembersTabState();
}

class _AllMembersTabState extends State<AllMembersTab> {
  // --- STATE VARIABLES ---
  final TextEditingController _searchController = TextEditingController();
  
  // Tithe Editing Controllers
  final TextEditingController week1Controller = TextEditingController();
  final TextEditingController week2Controller = TextEditingController();
  final TextEditingController week3Controller = TextEditingController();
  final TextEditingController week4Controller = TextEditingController();

  // Filter & Pagination State
  String? _filterDistrict;
  String? _filterCommunity;
  int _currentPage = 0;
  final int _rowsPerPage = 30;

  @override
  void initState() {
    super.initState();
    // Reset pagination when searching
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _currentPage = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    week1Controller.dispose();
    week2Controller.dispose();
    week3Controller.dispose();
    week4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- SEARCH & FILTER SECTION ---
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            children: [
              // 1. Search Bar
              Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: buildPlatformTextField(
                  context,
                  controller: _searchController,
                  placeholder: "Search by Name, Surname or Email",
                  prefixIcon: Icons.search,
                ),
              ),
              const SizedBox(height: 12),
              // 2. Filter Dropdowns
              _buildFilterSection(),
            ],
          ),
        ),

        // --- DATA LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where(
                  'overseerUid',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No members found"));
              }

              final query = _searchController.text.toLowerCase();

              // --- 1. FILTERING LOGIC ---
              final allFilteredMembers = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                final matchesSearch =
                    (data['name'] ?? '').toString().toLowerCase().contains(query) ||
                    (data['surname'] ?? '').toString().toLowerCase().contains(query) ||
                    (data['email'] ?? '').toString().toLowerCase().contains(query);

                final matchesDistrict =
                    _filterDistrict == null ||
                    (data['districtElderName'] ?? '') == _filterDistrict;

                final matchesCommunity =
                    _filterCommunity == null ||
                    (data['communityName'] ?? '') == _filterCommunity;

                return matchesSearch && matchesDistrict && matchesCommunity;
              }).toList();

              if (allFilteredMembers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 10),
                      const Text("No members match current filters"),
                      TextButton(
                        onPressed: () => setState(() {
                          _filterDistrict = null;
                          _filterCommunity = null;
                          _searchController.clear();
                          _currentPage = 0; // Reset page
                        }),
                        child: const Text("Clear Filters"),
                      ),
                    ],
                  ),
                );
              }

              // --- 2. PAGINATION LOGIC ---
              int totalItems = allFilteredMembers.length;
              int totalPages = (totalItems / _rowsPerPage).ceil();

              // Safety check: if filters reduce count significantly, reset current page
              if (_currentPage >= totalPages) {
                _currentPage = (totalPages > 0) ? totalPages - 1 : 0;
              }

              int startIndex = _currentPage * _rowsPerPage;
              int endIndex = startIndex + _rowsPerPage;
              if (endIndex > totalItems) endIndex = totalItems;

              // Slice the list
              final paginatedMembers = allFilteredMembers.sublist(
                startIndex,
                endIndex,
              );

              return Column(
                children: [
                  // --- THE LIST/TABLE ---
                  Expanded(
                    child: widget.isLargeScreen
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    Colors.grey[200],
                                  ),
                                  columns: const [
                                    DataColumn(label: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Surname", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("District", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Contact", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Week 1", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Week 2", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Week 3", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Week 4", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: paginatedMembers.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return DataRow(
                                      cells: [
                                        DataCell(Text(data['name'] ?? '')),
                                        DataCell(Text(data['surname'] ?? '')),
                                        DataCell(Text("${data['districtElderName'] ?? ''}")),
                                        DataCell(Text(data['phone'] ?? '')),
                                        DataCell(Text("R${data['week1'] ?? 0}")),
                                        DataCell(Text("R${data['week2'] ?? 0}")),
                                        DataCell(Text("R${data['week3'] ?? 0}")),
                                        DataCell(Text("R${data['week4'] ?? 0}")),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, color: Colors.blue),
                                                onPressed: () => _showEditTitheDialog(doc),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _deleteMember(doc),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: paginatedMembers.length,
                            itemBuilder: (context, index) {
                              final doc = paginatedMembers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text((data['name'] ?? 'U').substring(0, 1)),
                                  ),
                                  title: Text("${data['name']} ${data['surname']}"),
                                  subtitle: Text("${data['districtElderName']} | ${data['communityName']}"),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showEditTitheDialog(doc),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _deleteMember(doc),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // --- PAGINATION CONTROLS ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          "Showing ${startIndex + 1}-${endIndex} of $totalItems",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                          tooltip: "Previous Page",
                        ),
                        Text(
                          "Page ${_currentPage + 1} of $totalPages",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: _currentPage < totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          tooltip: "Next Page",
                        ),
                      ],
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

  // --- HELPER METHODS ---

  Widget _buildFilterSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('overseers')
          .where('uid', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        List districts = data['districts'] ?? [];
        List<String> elderNames = districts
            .map((e) => e['districtElderName'].toString())
            .toList();

        List<String> communityNames = [];
        if (_filterDistrict != null) {
          var dist = districts.firstWhere(
            (e) => e['districtElderName'] == _filterDistrict,
            orElse: () => null,
          );
          if (dist != null) {
            communityNames = (dist['communities'] as List)
                .map((c) => c['communityName'].toString())
                .toList();
          }
        }

        return Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterDistrict,
                  decoration: InputDecoration(
                    labelText: "Filter by District",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    isDense: true,
                  ),
                  items: elderNames.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterDistrict = val;
                      _filterCommunity = null;
                      _currentPage = 0; // RESET PAGE
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterCommunity,
                  decoration: InputDecoration(
                    labelText: "Filter by Community",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    isDense: true,
                  ),
                  items: communityNames.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    setState(() {
                      _filterCommunity = val;
                      _currentPage = 0; // RESET PAGE
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                tooltip: "Clear Filters",
                onPressed: () {
                  setState(() {
                    _filterDistrict = null;
                    _filterCommunity = null;
                    _searchController.clear();
                    _currentPage = 0; // RESET PAGE
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTitheDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    week1Controller.text = data['week1']?.toString() ?? '0';
    week2Controller.text = data['week2']?.toString() ?? '0';
    week3Controller.text = data['week3']?.toString() ?? '0';
    week4Controller.text = data['week4']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit Offering for ${data['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildPlatformTextField(context, controller: week1Controller, placeholder: "Week 1", keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            buildPlatformTextField(context, controller: week2Controller, placeholder: "Week 2", keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            buildPlatformTextField(context, controller: week3Controller, placeholder: "Week 3", keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            buildPlatformTextField(context, controller: week4Controller, placeholder: "Week 4", keyboardType: const TextInputType.numberWithOptions(decimal: true)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {

              Api().showLoading(context);
              await doc.reference.update({
                'week1': double.tryParse(week1Controller.text) ?? 0,
                'week2': double.tryParse(week2Controller.text) ?? 0,
                'week3': double.tryParse(week3Controller.text) ?? 0,
                'week4': double.tryParse(week4Controller.text) ?? 0,
              });
              OverseerAuditLogs.logAction(action: "UPDATED", details: "Updated offerings for ${data['name']}' weekly tithe",   committeeMemberName: widget.committeeMemberName, committeeMemberRole: widget.committeeMemberRole);
              if (mounted) Navigator.pop(context); // Loading
              if (mounted) Navigator.pop(ctx); // Dialog
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteMember(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this member?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await doc.reference.delete();

              OverseerAuditLogs.logAction(action: "DELETE", details: "Deleted member ${data['name']} ${data['surname']}",   committeeMemberName: widget.committeeMemberName, committeeMemberRole: widget.committeeMemberRole ,universityCommitteeFace: widget.faceUrl);
            
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}