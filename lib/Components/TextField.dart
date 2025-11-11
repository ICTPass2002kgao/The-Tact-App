import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String?) onValidate;
  final Function(String?)? onChange;
  final String placeholder;
  final IconData? icon;
  final bool? visible;
  final Widget? suffixIcon;

  const AuthTextField({
    Key? key,
    this.controller,
    required this.onValidate,
    required this.placeholder,
    this.icon,
    this.visible,
    this.onChange,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);

    // Determine the text color for inside the field (should contrast with fillColor)
    final inputTextColor = color.scaffoldBackgroundColor;

    // Determine the icon/hint text color (should be visible but soft)
    final secondaryColor = color.scaffoldBackgroundColor.withOpacity(0.7);

    return TextFormField(
      style: TextStyle(color: inputTextColor),
      onChanged: (value) => onChange?.call(value),
      controller: controller,
      validator: (value) => onValidate(value),
      obscureText: visible ?? false,
      decoration: InputDecoration(
        // Default Border (Unfocused State)
        border: OutlineInputBorder(
          borderSide: BorderSide(color: secondaryColor),
          borderRadius: BorderRadius.circular(15),
        ),

        // Focused Border
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: color.primaryColor,
            width: 2,
          ), // Highlight focus with primary color
          borderRadius: BorderRadius.circular(15),
        ),

        // Background Fill
        fillColor: color.hintColor.withOpacity(
          0.1,
        ), // Soft, subtle background fill
        filled: true,

        suffixIcon: suffixIcon,

        // Prefix Icon Color
        prefixIcon: icon != null
            ? Icon(
                icon,
                color: color.primaryColor,
              ) // Use primary color for clarity
            : null,

        // Hint Text
        hintText: placeholder,
        hintStyle: TextStyle(color: color.scaffoldBackgroundColor),

        contentPadding: const EdgeInsets.symmetric(
          vertical: 16.0,
          horizontal: 16.0,
        ), // Ensure adequate padding
      ),
    );
  }
}
