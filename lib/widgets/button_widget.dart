import 'package:flutter/material.dart';
import 'package:s256_wallet/widgets/app_background.dart';

/// Primary: amber fill with dark text. Secondary: hairline outline.
/// Square corners, like the website's buttons.
class ButtonWidget extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final bool isCompact;
  final bool isPrimary;
  final VoidCallback? onPressed; // Made nullable to support disabled state

  const ButtonWidget({
    super.key,
    this.text,
    this.icon,
    this.isCompact = false,
    this.isPrimary = true,
    required this.onPressed, // Still required, but can be null
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null;

    final Color fill = isDisabled
        ? S256Colors.surface2
        : (isPrimary ? S256Colors.primary : Colors.transparent);
    final Color content = isDisabled
        ? S256Colors.textLight
        : (isPrimary ? S256Colors.onPrimary : S256Colors.text);
    final BorderSide border = isPrimary && !isDisabled
        ? BorderSide.none
        : const BorderSide(color: S256Colors.lineStrong);

    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.all(fill),
      foregroundColor: WidgetStateProperty.all(content),
      elevation: WidgetStateProperty.all(0),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: border,
        ),
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return content.withValues(alpha: 0.12);
        }
        return null;
      }),
    );

    if (isCompact && icon != null) {
      return Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(2),
          border: border == BorderSide.none ? null : Border.all(color: S256Colors.lineStrong),
        ),
        child: IconButton(
          icon: Icon(icon, color: content),
          onPressed: onPressed,
        ),
      );
    }

    return ElevatedButton(
      style: buttonStyle,
      onPressed: onPressed, // ElevatedButton handles null properly
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // Added to prevent button from expanding unnecessarily
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(icon, color: content),
            ),
          Text(
            (text ?? 'Button').toUpperCase(),
            style: TextStyle(
              fontFamily: 'ChakraPetch',
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: content,
            ),
          ),
        ],
      ),
    );
  }
}
