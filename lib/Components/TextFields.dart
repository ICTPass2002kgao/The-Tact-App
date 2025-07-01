import 'package:flutter/material.dart';
import 'package:ttact/Components/Color.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController? controller;
  final Function(String?) onValidate;
  final Function(bool?)? onChange;
  final String placeholder;
  final IconData? icon;
  final bool? visible;

  const AuthTextField({
    Key? key,
    this.controller,
    required this.onValidate,
    required this.placeholder,
    this.icon,
    this.visible,
    this.onChange,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    
  final color = AppColor(color: const Color.fromARGB(255, 15, 76, 167));
    return TextFormField(
      onChanged: (value) => onChange?.call,
      controller: controller,
      validator: (value) => onValidate(value),
      obscureText: visible ?? false,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue),
          borderRadius: BorderRadius.circular(10),
        ),
        focusColor: Colors.blue,
        fillColor: Colors.blue[50],
        filled: true,
        prefixIcon: icon != null ? Icon(icon, color: color.color) : null,
        labelText: placeholder,
      ),
    );
  }
}
