import 'package:flutter/material.dart';
import 'package:ttact/Components/Color.dart';

class Tabs extends StatelessWidget {
  final String tabName;
  const Tabs({super.key, required this.tabName});
  @override
  Widget build(BuildContext context) {
    final color = AppColor(color: const Color.fromARGB(255, 15, 76, 167));
    return TextButton(
        child: Padding(
          padding:
              const EdgeInsets.only(top: 2, bottom: 2, left: 10, right: 10),
          child: Text(tabName),
        ),
        onPressed: () {},
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(Colors.white),
          backgroundColor: WidgetStatePropertyAll(color.color),
        ));
  }
}
