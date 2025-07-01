import 'package:flutter/material.dart';
import 'package:ttact/Components/CustomOutlinedButton.dart';

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
            if (posterUrl != null)
              Image.asset(
                posterUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Text(
              "$title",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color.scaffoldBackgroundColor,
              ),
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
              onPressed: () {},
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
