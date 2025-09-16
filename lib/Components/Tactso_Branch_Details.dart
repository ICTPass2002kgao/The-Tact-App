import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/Ask_For_Assistance.dart';
import 'package:url_launcher/url_launcher.dart';

class TactsoBranchDetails extends StatelessWidget {
  final Map<String, dynamic> universityDetails;
  final dynamic campusListForUniversity;

  const TactsoBranchDetails({
    Key? key,
    required this.universityDetails,
    required this.campusListForUniversity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    // Helper to check if the university has multiple campuses based on the stored data
    final bool hasMultipleCampuses =
        universityDetails['hasMultipleCampuses'] ?? false;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.primaryColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: color.hintColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Image display
            if (universityDetails['imageUrl'] == null ||
                (universityDetails['imageUrl'] as List).isEmpty ||
                (universityDetails['imageUrl'][0] as String).isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: CircleAvatar(
                    radius: 100,
                    backgroundColor: color.hintColor,
                    child: Icon(
                      Icons.location_city,
                      size: 100,
                      color: color.scaffoldBackgroundColor,
                    ),
                  ),
                ),
              )
            else
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.network(
                    universityDetails['imageUrl'][0],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: color.hintColor,
                            child: Icon(
                              Icons.broken_image,
                              size: 100,
                              color: color.scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    universityDetails['universityName'] ?? 'University Name',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color.scaffoldBackgroundColor,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Share.share(
                      "Check out ${universityDetails['universityName'] ?? 'this university'}'s application page: ${universityDetails['applicationLink'] ?? ''}",
                    );
                  },
                  icon: Icon(Icons.share, color: color.scaffoldBackgroundColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: color.scaffoldBackgroundColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: () async {
                      final address = universityDetails['address'] ?? '';
                      if (address.isNotEmpty) {
                        final encodedAddress = Uri.encodeComponent(address);
                        // Corrected Google Maps URL for launching
                        final googleMapsUrl = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
                        );
                        if (await canLaunchUrl(googleMapsUrl)) {
                          await launchUrl(
                            googleMapsUrl,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          Api().showMessage(
                            context,
                            'Cannot launch address on Google Maps',
                            "Error",
                            color.primaryColorDark,
                          );
                        }
                      } else {
                        Api().showMessage(
                          context,
                          'No address provided for the main university.',
                          "Error",
                          color.primaryColorDark,
                        );
                      }
                    },
                    child: Text(
                      universityDetails['address'] ?? 'Address not available',
                      style: TextStyle(
                        decorationColor: color.scaffoldBackgroundColor,
                        decoration: TextDecoration.underline,
                        color: color.scaffoldBackgroundColor,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            Text(
              (universityDetails['isApplicationOpen'] ?? false)
                  ? 'Applications Open'
                  : 'Applications Closed',
              style: TextStyle(
                color: (universityDetails['isApplicationOpen'] ?? false)
                    ? color.splashColor
                    : color.primaryColorDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            (universityDetails['isApplicationOpen'] ?? false)
                ? CustomOutlinedButton(
                    onPressed: () async {
                      final url = Uri.parse(
                        universityDetails['applicationLink'] ?? 'about:blank',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                      } else {
                        Api().showMessage(
                          context,
                          'Cannot open the application link. Please check the URL.',
                          "Error",
                          color.primaryColorDark,
                        );
                      }
                    },
                    text: 'Apply for yourself',
                    backgroundColor: color.primaryColor,
                    foregroundColor: color.scaffoldBackgroundColor,
                    width: double.infinity,
                  )
                : CustomOutlinedButton(
                    onPressed: () {
                      Api().showMessage(
                        context,
                        'Applications are currently closed for this university.',
                        "Information",
                        color.primaryColorDark,
                      );
                    },
                    text: 'Applications closed',
                    backgroundColor: color.primaryColorDark,
                    foregroundColor: color.scaffoldBackgroundColor,
                    width: double.infinity,
                  ),
            const SizedBox(height: 10),

            // **UPDATED: Ask for Help Button Logic**
            CustomOutlinedButton(
              onPressed: () {
                // Ensure campusListForUniversity is a List<Map<String, dynamic>>
                List<Map<String, dynamic>> actualCampusList = [];
                if (campusListForUniversity is List) {
                  for (var item in campusListForUniversity) {
                    if (item is Map<String, dynamic>) {
                      actualCampusList.add(item);
                    }
                  }
                }

                if (hasMultipleCampuses && actualCampusList.isNotEmpty) {
                  _showCampusSelectionBottomSheet(
                    context,
                    color,
                    actualCampusList,
                  );
                } else {
                  // Navigate directly if no multiple campuses or no campus data
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UniversityApplicationScreen(
                        universityData: universityDetails,
                        selectedCampus: actualCampusList.isNotEmpty
                            ? actualCampusList
                                  .first // Pass the first/only campus if exists
                            : null, // No specific campus selected
                      ),
                    ),
                  );
                }
              },
              text: 'Ask for Help!',
              backgroundColor: color.scaffoldBackgroundColor,
              foregroundColor: color.primaryColor,
              width: double.infinity,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // NEW: Method to show campus selection bottom sheet
  void _showCampusSelectionBottomSheet(
    BuildContext context,
    ThemeData color,
    List<Map<String, dynamic>> campuses,
  ) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: color.primaryColor, // Match your theme
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        // Corrected: _selectedCampus needs to live here to persist its state
        // throughout the modal's lifecycle, managed by StatefulBuilder.
        Map<String, dynamic>? _selectedCampus;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Use min to wrap content
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.hintColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select a Campus for Assistance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color.scaffoldBackgroundColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    // Removed Expanded here to avoid forcing height if content is short
                    // and using ListView.builder with shrinkWrap.
                    ListView.builder(
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true, // Important for ListView in Column
                      itemCount:
                          campuses.length, // Use the passed 'campuses' list
                      itemBuilder: (context, index) {
                        final campus = campuses[index];

                        // Only show RadioListTile if campusName is not empty
                        if (campus['campusName'] != null &&
                            campus['campusName'].isNotEmpty) {
                          return RadioListTile<Map<String, dynamic>>(
                            title: Text(
                              campus['campusName'] ?? 'Unknown Campus',
                              style: TextStyle(
                                color: color.scaffoldBackgroundColor,
                              ),
                            ),
                            value: campus,
                            groupValue: _selectedCampus,
                            onChanged: (Map<String, dynamic>? value) {
                              setModalState(() {
                                _selectedCampus = value;
                              });
                            },
                            activeColor:
                                color.splashColor, // Active radio button color
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        } else {
                          return const SizedBox.shrink(); // Hide if campus name is empty
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    CustomOutlinedButton(
                      onPressed: () {
                        if (_selectedCampus != null) {
                          Navigator.pop(context); // Close the bottom sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UniversityApplicationScreen(
                                universityData: universityDetails,
                                selectedCampus: _selectedCampus,
                              ),
                            ),
                          );
                        } else {
                          Api().showMessage(
                            context,
                            'Please select a campus to proceed.',
                            "Warning",
                            color.hintColor,
                          );
                        }
                      },
                      text: 'Proceed with Selected Campus',
                      backgroundColor: color.scaffoldBackgroundColor,
                      foregroundColor: color.primaryColor,
                      width: double.infinity,
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
}
