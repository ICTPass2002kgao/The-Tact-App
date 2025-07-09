// ... previous code

import 'package:flutter/material.dart';

class UpcomingEventsCard extends StatelessWidget {
  final String date;
  final String eventMonth;
  final String eventTitle;
  final String eventDescription;
  final Color? highlightColor;
  const UpcomingEventsCard({
    super.key,
    required this.date,
    required this.eventTitle,
    required this.eventDescription,
    required this.eventMonth,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Column(
      children: [
        Stack(
          children: [
            Row(
              children: [
                Card(
                  elevation: 10,
                  color: Colors.transparent,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: color.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: color.primaryColor, width: 0.5),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: color.primaryColor,
                              ),
                            ),
                            Text(
                              eventMonth,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: color.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Card(
                    elevation: 10,
                    color: Colors.transparent,
                    child: Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: color.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: color.primaryColor,
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              eventTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: color.primaryColor.withOpacity(0.8),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              eventDescription,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w300,
                                fontStyle: FontStyle.italic,
                                color: color.primaryColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Draw diagonal line if highlightColor is provided
            if (highlightColor != null)
              Positioned.fill(
                bottom: 40,
                top: 40,
                child: CustomPaint(
                  size: Size(2, 40),
                  painter: _DiagonalLinePainter(highlightColor!),
                  child: Text('Past'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DiagonalLinePainter extends CustomPainter {
  final Color color;
  _DiagonalLinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 20.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
