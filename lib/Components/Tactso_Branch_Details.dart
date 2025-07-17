import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:ttact/Pages/Ask_For_Assistance.dart';
import 'package:url_launcher/url_launcher.dart';

class TactsoBranchDetails extends StatelessWidget {
  final Map<String, dynamic> universityDetails;
  const TactsoBranchDetails({Key? key, required this.universityDetails})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.primaryColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
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
            SizedBox(height: 20),

            /*
             'institutionName': nameController.text,
      'applicationLink': applicationLinkController.text,
      'address': address.text,
      'imageUrl': imageUrls,
      'isOpplicationOpen': isOpplicationOpen,
            */
            if (universityDetails['imageUrl'][0] == null ||
                (universityDetails['imageUrl'][0] as String).isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 200,
                  backgroundColor: color.hintColor,
                  child: Icon(
                    Icons.location_city,
                    size: 200,
                    color: color.scaffoldBackgroundColor,
                  ),
                ),
              )
            else
              Center(
                child: Image.network(
                  universityDetails['imageUrl'][0],
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    universityDetails['institutionName'] ??
                        'Vaal University of technology',
                    maxLines: 1,
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
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            universityDetails['applicationLink'] ??
                            'https://www.vut.ac.za',
                      ),
                    );
                  },
                  icon: Icon(Icons.share, color: color.scaffoldBackgroundColor),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: color.scaffoldBackgroundColor,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: () async {
                      final address = universityDetails['address'] ?? '';
                      if (address.isNotEmpty) {
                        final encodedAddress = Uri.encodeComponent(address);
                        final googleMapsUrl = Uri.parse(
                          'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
                        );
                        if (await canLaunchUrl(googleMapsUrl)) {
                          await launchUrl(
                            googleMapsUrl,
                            mode: LaunchMode.inAppBrowserView,
                            webViewConfiguration: WebViewConfiguration(),
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
                          'No address provided',
                          "Error",
                          color.primaryColorDark,
                        );
                      }
                    },
                    child: Text(
                      universityDetails['address'] ?? '',
                      style: TextStyle(
                        decorationColor: color.scaffoldBackgroundColor,
                        decoration: TextDecoration.underline,
                        color: color.scaffoldBackgroundColor,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              universityDetails['isApplicationOpen'] ?? true == true
                  ? 'Applications Open'
                  : 'Application Closed',
              style: TextStyle(
                color: universityDetails['isApplicationOpen'] ?? true == true
                    ? color.splashColor
                    : color.primaryColorDark,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: () async {
                final url = Uri.parse(
                  "${universityDetails['applicationLink']}" ??
                      'https://www.vut.ac.za',
                ); 
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                } else {
                  Api().showMessage(
                    context,
                    'Cannot join live',
                    "Error",
                    color.primaryColorDark,
                  );
                }
              },
              text: 'Apply for yourself',
              backgroundColor: color.scaffoldBackgroundColor,
              foregroundColor: color.primaryColor,
              width: double.infinity,
            ),
            SizedBox(height: 10),

            CustomOutlinedButton(
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UploadApplicationDocumentsPage(
                      universityName: universityDetails['institutionName'],
                    ),
                  ),
                );
              },
              text: 'Ask for Help!',
              backgroundColor: color.primaryColor,
              foregroundColor: color.scaffoldBackgroundColor,
              width: double.infinity,
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
