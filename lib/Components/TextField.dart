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
        onChanged: (value) => onChange?.call(value),
        controller: controller,
        validator: (value) => onValidate(value),
        obscureText: visible ?? false,
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderSide: BorderSide(color: color.hintColor),
            borderRadius: BorderRadius.circular(15),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: color.hintColor),
            borderRadius: BorderRadius.circular(15),
          ),
          focusColor: color.hintColor,
          fillColor: color.scaffoldBackgroundColor,
          filled: true,
          suffixIcon: suffixIcon,
          prefixIcon: icon != null ? Icon(icon, color: color.hintColor) : null,
          hintText: placeholder,
          hintStyle: TextStyle(color: color.hintColor),
        ),
      ),
    );
  }
}
