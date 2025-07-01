import 'package:flutter/material.dart';

class ImagesPage extends StatelessWidget {
  final String imageName;
  const ImagesPage({super.key, required this.imageName});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(imageName, height: 350, fit: BoxFit.cover));
  }
}
