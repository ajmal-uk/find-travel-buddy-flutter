import 'package:flutter/material.dart';

class FloatingChatButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData? icon;
  final ImageProvider? imageIcon;
  final Color buttonColor;
  final Color iconColor;
  final double? buttonHeight;
  final double? buttonWidth;
  final double? iconHeight;
  final double? iconWidth;
  final String heroTag;

  const FloatingChatButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.imageIcon,
    this.buttonColor = Colors.blue,
    this.iconColor = Colors.white,
    this.buttonHeight = 70,
    this.buttonWidth = 70,
    this.iconHeight = 80,
    this.iconWidth = 80,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: buttonWidth,
        height: buttonHeight,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.rectangle,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(35),
            topRight: Radius.circular(35),
            bottomLeft: Radius.circular(35),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Center(
          child: imageIcon != null
              ? Image(
                  image: imageIcon!,
                  width: iconWidth,
                  height: iconWidth,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null)
                      Icon(
                        icon,
                        color: iconColor, 
                        size: 24,
                      ),
                    if (icon != null) const SizedBox(width: 5),
                  ],
                ),
        ),
      ),
    );
  }
}
