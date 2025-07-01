import 'package:flutter/material.dart';

class Buttons extends StatelessWidget {
  final Function() function;
  final String buttonText;
  final Color backgroundcolor;
  final Color foregroundcolor;
  
  const Buttons({super.key, required this.function, required this.buttonText, required this.backgroundcolor, required this.foregroundcolor});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: function,
      child: Text(buttonText),
      style: ButtonStyle(
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          backgroundColor: WidgetStatePropertyAll(backgroundcolor),
          foregroundColor: WidgetStatePropertyAll(foregroundcolor),
          minimumSize: WidgetStatePropertyAll(Size(double.infinity, 55))),
    );
  }
}
