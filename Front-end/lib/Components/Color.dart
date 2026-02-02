import 'package:flutter/material.dart';

class AppColor extends StatelessWidget {
  final Color color;
  const AppColor({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color:color
    );
  }
}
