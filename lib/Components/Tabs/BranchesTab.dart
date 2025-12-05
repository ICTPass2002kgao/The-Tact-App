import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:ttact/Components/HomePageHelpers.dart'; // Import helpers
import 'package:ttact/Components/Tactso_Branch_Details.dart' hide isIOSPlatform;
import 'package:ttact/Components/UniversityCard.dart';

class BranchesTab extends StatefulWidget {
  final bool isDesktop;
  const BranchesTab({super.key, required this.isDesktop});

  @override
  State<BranchesTab> createState() => _BranchesTabState();
}

class _BranchesTabState extends State<BranchesTab> {
  final TextEditingController _branchSearchController = TextEditingController();
  String _branchSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _branchSearchController.addListener(() {
      setState(() {
        _branchSearchQuery = _branchSearchController.text;
      });
    });
  }

  @override
  void dispose() {
    _branchSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection('tactso_branches')
          .orderBy('createdAt', descending: true)
          .get(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: isIOSPlatform
                ? CupertinoActivityIndicator()
                : CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading branches'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No branches found'));
        }

        final branchList = snapshot.data!.docs;

        // Group campuses by University Name
        Map<String, List<Map<String, dynamic>>> groupedUniversities = {};
        for (var doc in branchList) {
          final data = doc.data() as Map<String, dynamic>;
          final universityName =
              (data['universityName'] as String? ?? 'Unknown University')
                  .toLowerCase();

          // Filter by search query
          if (_branchSearchQuery.isEmpty ||
              universityName.contains(_branchSearchQuery.toLowerCase())) {
            if (!groupedUniversities.containsKey(universityName)) {
              groupedUniversities[universityName] = [];
            }
            groupedUniversities[universityName]!.add(data);
          }
        }

        // Render List/Grid based on platform
        return ListView(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isDesktop ? 0 : 8.0,
                vertical: widget.isDesktop ? 20.0 : 10.0,
              ),
              child: buildPlatformTextField(
                controller: _branchSearchController,
                placeholder: 'Search branch by name...',
                prefixIcon: isIOSPlatform ? CupertinoIcons.search : Icons.search,
                context: context,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: widget.isDesktop ? 20.0 : 6.0,
              runSpacing: widget.isDesktop ? 20.0 : 12.0,
              children: groupedUniversities.entries.map((entry) {
                final String universityName = entry.key;
                final List<Map<String, dynamic>> campuses = entry.value;
                final Map<String, dynamic> representativeCampusData =
                    campuses.first;
                final bool anyCampusApplicationOpen = campuses.any(
                  (campus) => campus['isApplicationOpen'] == true,
                );

                // Responsive Card Width
                final cardWidth = widget.isDesktop
                    ? (MediaQuery.of(context).size.width * 0.8) / 4 - 40
                    : MediaQuery.of(context).size.width / 2 - 12;

                return SizedBox(
                  width: cardWidth,
                  child: GestureDetector(
                    onTap: () {
                      final widgetDetail = TactsoBranchDetails(
                        universityDetails: representativeCampusData,
                        campusListForUniversity:
                            representativeCampusData['campuses'],
                      );

                      showModalBottomSheet(
                        scrollControlDisabledMaxHeightRatio: double.infinity,
                        context: context,
                        builder: (context) {
                          return widgetDetail;
                        },
                      );
                    },
                    child: UniversityCard(
                      imageUrl: representativeCampusData['imageUrl'] != null &&
                              representativeCampusData['imageUrl'].isNotEmpty
                          ? representativeCampusData['imageUrl'][0]
                          : null,
                      UniName: universityName,
                      uniAddress: representativeCampusData['address'] ?? '',
                      applicationLink:
                          representativeCampusData['applicationLink'] ?? '',
                      onPressed: () {
                        showModalBottomSheet(
                          scrollControlDisabledMaxHeightRatio: double.infinity,
                          context: context,
                          builder: (context) {
                            return TactsoBranchDetails(
                              universityDetails: campuses as dynamic,
                              campusListForUniversity:
                                  representativeCampusData['campuses'],
                            );
                          },
                        );
                      },
                      applicationIsOpen: anyCampusApplicationOpen,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}