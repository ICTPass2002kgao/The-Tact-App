import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
// Assuming CustomOutlinedButton is defined elsewhere,
// but we will use a local builder to ensure platform styling.
// import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/User/Ask_For_Assistance.dart';
import 'package:url_launcher/url_launcher.dart';

// --- PLATFORM UTILITIES ---
bool get isIOSPlatform {
  return defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

class TactsoBranchDetails extends StatelessWidget {
  final Map<String, dynamic> universityDetails;
  final dynamic campusListForUniversity;

  const TactsoBranchDetails({
    Key? key,
    required this.universityDetails,
    required this.campusListForUniversity,
  }) : super(key: key);

  // --- HELPER: Build Platform Specific Button ---
  Widget _buildPlatformButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
    bool isOutlined = false,
  }) {
    if (isIOSPlatform) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton(
          // iOS buttons usually don't have outlines, they are filled or text.
          // We simulate the look using color.
          color: isOutlined ? Theme.of(context).cardColor : backgroundColor,
          disabledColor: CupertinoColors.quaternarySystemFill,
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: BorderRadius.circular(12),
          onPressed: onPressed,

          child: Text(
            text,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      // Android Material Button
      return SizedBox(
        width: double.infinity,
        child: isOutlined
            ? OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: foregroundColor,
                  side: BorderSide(color: foregroundColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              )
            : ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: foregroundColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Handle Colors based on Platform preference
    final primaryColor = theme.primaryColor;
    final scaffoldColor = theme.scaffoldBackgroundColor;

    // Helper to check if the university has multiple campuses
    final bool hasMultipleCampuses =
        universityDetails['hasMultipleCampuses'] ?? false;

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: primaryColor,
          // iOS usually prefers rounded rectangles or full sheets
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.hintColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- IMAGE SECTION ---
            if (universityDetails['imageUrl'] == null ||
                (universityDetails['imageUrl'] as List).isEmpty ||
                (universityDetails['imageUrl'][0] as String).isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Center(
                  child: CircleAvatar(
                    radius: 100,
                    backgroundColor: theme.hintColor,
                    child: Icon(
                      isIOSPlatform
                          ? CupertinoIcons.building_2_fill
                          : Icons.location_city,
                      size: 100,
                      color: scaffoldColor,
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
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: theme.hintColor,
                            child: Icon(
                              Icons.broken_image,
                              size: 100,
                              color: scaffoldColor,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 15),

            // --- TITLE & SHARE ---
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
                      color: scaffoldColor,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                isIOSPlatform
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Share.share(
                            "Check out ${universityDetails['universityName'] ?? 'this university'}'s application page: ${universityDetails['applicationLink'] ?? ''}",
                          );
                        },
                        child: Icon(CupertinoIcons.share, color: scaffoldColor),
                      )
                    : IconButton(
                        onPressed: () {
                          Share.share(
                            "Check out ${universityDetails['universityName'] ?? 'this university'}'s application page: ${universityDetails['applicationLink'] ?? ''}",
                          );
                        },
                        icon: Icon(Icons.share, color: scaffoldColor),
                      ),
              ],
            ),
            const SizedBox(height: 10),

            // --- ADDRESS & MAPS ---
            Row(
              children: [
                Icon(
                  isIOSPlatform
                      ? CupertinoIcons.location_solid
                      : Icons.location_on_outlined,
                  color: scaffoldColor,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: () async {
                      final address = universityDetails['address'] ?? '';
                      if (address.isNotEmpty) {
                        // Platform specific map URLs
                        Uri mapUrl;
                        if (isIOSPlatform) {
                          mapUrl = Uri.parse(
                            'https://maps.apple.com/?q=${Uri.encodeComponent(address)}',
                          );
                        } else {
                          mapUrl = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
                          );
                        }

                        if (await canLaunchUrl(mapUrl)) {
                          await launchUrl(
                            mapUrl,
                            mode: LaunchMode.externalApplication,
                          );
                        } else {
                          Api().showMessage(
                            context,
                            'Cannot launch Maps',
                            "Error",
                            theme.primaryColorDark,
                          );
                        }
                      } else {
                        Api().showMessage(
                          context,
                          'No address provided.',
                          "Error",
                          theme.primaryColorDark,
                        );
                      }
                    },
                    child: Text(
                      universityDetails['address'] ?? 'Address not available',
                      style: TextStyle(
                        decorationColor: scaffoldColor,
                        decoration: TextDecoration.underline,
                        color: scaffoldColor,
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

            // --- STATUS ---
            Text(
              (universityDetails['isApplicationOpen'] ?? false)
                  ? 'Applications Open'
                  : 'Applications Closed',
              style: TextStyle(
                color: (universityDetails['isApplicationOpen'] ?? false)
                    ? theme.splashColor
                    : theme.primaryColorDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 20),

            // --- APPLY BUTTON ---
            (universityDetails['isApplicationOpen'] ?? false)
                ? _buildPlatformButton(
                    context: context,
                    onPressed: () async {
                      final url = Uri.parse(
                        universityDetails['applicationLink'] ?? 'about:blank',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                      } else {
                        Api().showMessage(
                          context,
                          'Cannot open application link.',
                          "Error",
                          theme.primaryColorDark,
                        );
                      }
                    },
                    text: 'Apply for yourself',
                    backgroundColor: scaffoldColor, // Inverted for contrast
                    foregroundColor: primaryColor,
                  )
                : _buildPlatformButton(
                    context: context,
                    onPressed: () {
                      Api().showMessage(
                        context,
                        'Applications are currently closed.',
                        "Information",
                        theme.primaryColorDark,
                      );
                    },
                    text: 'Applications closed',
                    backgroundColor: theme.primaryColorDark,
                    foregroundColor: scaffoldColor,
                  ),
            const SizedBox(height: 10),

            // --- ASK FOR HELP BUTTON ---
            _buildPlatformButton(
              context: context,
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
                  // BRANCHED LOGIC FOR CAMPUS SELECTION
                  if (isIOSPlatform) {
                    _showiOSCampusSelection(context, theme, actualCampusList);
                  } else {
                    _showAndroidCampusSelection(
                      context,
                      theme,
                      actualCampusList,
                    );
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UniversityApplicationScreen(
                        universityData: universityDetails,
                        selectedCampus: actualCampusList.isNotEmpty
                            ? actualCampusList.first
                            : null,
                      ),
                    ),
                  );
                }
              },
              text: 'Ask for Help!',
              backgroundColor: Colors.transparent,
              foregroundColor: scaffoldColor,
              isOutlined: true,
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --- ANDROID/MATERIAL BOTTOM SHEET ---
  void _showAndroidCampusSelection(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> campuses,
  ) {
    Navigator.pop(context); // Close current detail sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (BuildContext context) {
        Map<String, dynamic>? _selectedCampus;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 60,
                        height: 5,
                        decoration: BoxDecoration(
                          color: theme.hintColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select a Campus',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.scaffoldBackgroundColor,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: campuses.length,
                      itemBuilder: (context, index) {
                        final campus = campuses[index];
                        if (campus['campusName'] != null &&
                            campus['campusName'].isNotEmpty) {
                          return RadioListTile<Map<String, dynamic>>(
                            title: Text(
                              campus['campusName'],
                              style: TextStyle(
                                color: theme.scaffoldBackgroundColor,
                              ),
                            ),
                            value: campus,
                            groupValue: _selectedCampus,
                            onChanged: (Map<String, dynamic>? value) {
                              setModalState(() {
                                _selectedCampus = value;
                              });
                            },
                            activeColor: theme.splashColor,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildPlatformButton(
                      context: context,
                      onPressed: () {
                        if (_selectedCampus != null) {
                          Navigator.pop(context);
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
                            'Select a campus first.',
                            "Warning",
                            theme.hintColor,
                          );
                        }
                      },
                      text: 'Proceed',
                      backgroundColor: theme.scaffoldBackgroundColor,
                      foregroundColor: theme.primaryColor,
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

  // --- IOS CUPERTINO PICKER / SHEET ---
  void _showiOSCampusSelection(
    BuildContext context,
    ThemeData theme,
    List<Map<String, dynamic>> campuses,
  ) {
    // Using CupertinoActionSheet for selection as it adheres to HIG
    // better than a modal with radio buttons for short lists.
    // If list is very long, CupertinoPicker is better, but ActionSheet is safer for overlay contexts.

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Select Campus'),
        message: const Text('Which campus do you need assistance with?'),
        actions: campuses.map((campus) {
          return CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context); // Close popup
              // Navigate
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UniversityApplicationScreen(
                    universityData: universityDetails,
                    selectedCampus: campus,
                  ),
                ),
              );
            },
            child: Text(campus['campusName'] ?? 'Unknown Campus'),
          );
        }).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
