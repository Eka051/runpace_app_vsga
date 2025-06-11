import 'package:flutter/material.dart';

class BackButton extends StatelessWidget {
  final ButtonStyle? style;
  final VoidCallback? onPressed;
  final IconData icon;
  final double iconSize;
  final EdgeInsets containerPadding;
  final Color? iconColor;
  const BackButton({super.key,
    this.style,
    this.onPressed,
    this.icon = Icons.arrow_back_ios_new,
    this.iconSize = 24,
    this.containerPadding = const EdgeInsets.all(8.0),
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(padding: containerPadding,
      child: IconButton(
        style: style,
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        icon: Icon(icon, size: iconSize, color: iconColor ?? Theme.of(context).iconTheme.color),
      ),
    );
  }
}