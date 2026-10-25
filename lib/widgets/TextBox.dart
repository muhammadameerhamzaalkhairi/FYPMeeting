import 'package:flutter/material.dart';

class TextBox extends StatelessWidget {
  final String? hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const TextBox({super.key, this.hintText, this.controller, this.obscureText=false, this.keyboardType, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          fillColor: Colors.white,
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(50),
          )
      ),
    );
  }
}