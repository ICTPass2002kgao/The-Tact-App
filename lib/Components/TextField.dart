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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        style: TextStyle(color: color.scaffoldBackgroundColor),
        onChanged: (value) => onChange?.call(value),
        controller: controller,
        validator: (value) => onValidate(value),
        obscureText: visible ?? false,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: color.scaffoldBackgroundColor),
            borderRadius: BorderRadius.circular(15),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: color.scaffoldBackgroundColor),
            borderRadius: BorderRadius.circular(15),
          ),
          focusColor: color.scaffoldBackgroundColor,
          fillColor: color.hintColor.withOpacity(0.2),
          filled: true,
          suffixIcon: suffixIcon,
          prefixIcon: icon != null
              ? Icon(icon, color: color.scaffoldBackgroundColor)
              : null,
          hintText: placeholder,
          hintStyle: TextStyle(color: color.scaffoldBackgroundColor),
        ),
      ),
    );
  }
}
