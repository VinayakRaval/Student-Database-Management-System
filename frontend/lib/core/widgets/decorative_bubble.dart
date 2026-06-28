import 'package:flutter/material.dart';

class DecorativeBubble extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  final double strokeWidth;

  const DecorativeBubble({
    super.key,
    required this.size,
    this.color = const Color.fromARGB(255, 63, 45, 197),
    this.opacity = 0.2,
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withOpacity(opacity),
          width: strokeWidth,
        ),
      ),
    );
  }
}