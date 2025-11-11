import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailBottomSheet extends StatelessWidget {
  final String date;
  final String eventMonth;
  final String title;
  final String description;
  final String? posterUrl; // Replace with your actual image path

  const EventDetailBottomSheet({
    Key? key,
    required this.date,
    required this.eventMonth,
    required this.title,
    required this.description,
    this.posterUrl,
  }) : super(key: key);

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
            if (  posterUrl != null)
              Image.network(
                  posterUrl!,
                width: double.infinity, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container( 
                    color: Colors.grey[300],
                    child: Icon(Icons.error, color: Colors.grey),
                  );
                },
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "$title",
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
                      ShareParams(text: posterUrl ?? title),
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
                  Icons.calendar_month_outlined,
                  color: color.scaffoldBackgroundColor,
                ),
                SizedBox(width: 8),
                Text(
                  "$eventMonth $date",
                  style: TextStyle(
                    color: color.scaffoldBackgroundColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 15),
            Text(
              "$description",
              style: TextStyle(
                color: color.scaffoldBackgroundColor,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 20),
            CustomOutlinedButton(
              onPressed: () async {
                final url = Uri.parse('');
                // Replace with your live stream URL
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.inAppBrowserView);
                } else {
                  Api().showMessage(
                    context,
                    'Not live yet Counting down',
                    "Error",
                    color.primaryColorDark,
                  );
                }
              },
              text: 'JOIN LIVE!',
              backgroundColor: color.scaffoldBackgroundColor,
              foregroundColor: color.primaryColor,
              width: double.infinity,
            ),
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
