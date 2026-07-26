// ============================================================
// SmartAttend — White Card Widget (v12 Premium Light)
// Replaces GlassmorphismCard with white card + soft shadow.
// Same API — all existing usages work without modification.
// ============================================================

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Premium white card with soft shadow and optional border.
/// Replaces the old dark glassmorphism card.
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? borderColor;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const GlassmorphismCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 20,
    this.borderColor,
    this.onTap,
    this.width,
    this.height,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: onTap != null ? null : padding,
      decoration: BoxDecoration(
        color: color ?? AppTheme.bgCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppTheme.border,
          width: 1,
        ),
        boxShadow: boxShadow ?? AppTheme.cardShadow,
      ),
      child: onTap != null
          ? null
          : child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          margin: margin,
          decoration: BoxDecoration(
            color: color ?? AppTheme.bgCard,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor ?? AppTheme.border,
              width: 1,
            ),
            boxShadow: boxShadow ?? AppTheme.cardShadow,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onTap,
              child: Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return card;
  }
}
