import 'package:flutter/material.dart';

class Button extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? foreColor;
  final VoidCallback? onTap;
  final bool enabled;

  const Button({super.key, required this.text, this.color, this.foreColor, this.onTap, this.enabled=true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Center(
            child: Text(
              text, 
              style: TextStyle(color: color == null ? Colors.white : Colors.black, fontSize: 18),
              textAlign: TextAlign.center, 
            )),
        ),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          color: color == null ? const Color(0xFF111111) : color,
          borderRadius: BorderRadius.circular(50)
        ),
      ),
    );
  }
}