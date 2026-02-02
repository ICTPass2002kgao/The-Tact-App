import 'package:flutter/material.dart';

class ApostleCard extends StatelessWidget {
  final String name;
  final String age;
  final String? imageUrl;
  final String potforlio;
  const ApostleCard({
    super.key,
    required this.name,
    required this.age,
    required this.potforlio,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(1),
      decoration: BoxDecoration(
        border: Border.all(color: color.primaryColor),
        borderRadius: BorderRadius.circular(19.5),
        color: color.scaffoldBackgroundColor,
      ),
      child: Column(
        children: [
          if (imageUrl == null || imageUrl!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: color.hintColor,
                child: Icon(
                  Icons.person_2_outlined,
                  size: 70,
                  color: color.scaffoldBackgroundColor,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Image.network(
                  imageUrl!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.cover,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  age,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  potforlio,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
