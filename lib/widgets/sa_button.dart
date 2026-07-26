// ============================================================
// SmartAttend — SA Button (v12 Premium)
// Gradient primary + outlined + text variants
// ============================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

// ─── Primary Gradient Button ──────────────────────────────
class SAButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;
  final double height;
  final double fontSize;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final double borderRadius;

  const SAButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
    this.height = 52,
    this.fontSize = 16,
    this.gradient,
    this.shadow,
    this.borderRadius = 14,
  });

  @override
  State<SAButton> createState() => _SAButtonState();
}

class _SAButtonState extends State<SAButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnim = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  bool get _active => !widget.isDisabled && !widget.isLoading && widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _active ? (_) => _pressController.forward() : null,
      onTapUp: _active ? (_) {
        _pressController.reverse();
        widget.onPressed?.call();
      } : null,
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(scale: _scaleAnim.value, child: child),
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: _active
                ? (widget.gradient ?? AppTheme.primaryGradient)
                : null,
            color: _active ? null : AppTheme.border,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _active
                ? (widget.shadow ?? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ])
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              onTap: null, // GestureDetector.onTapUp handles the press
              splashColor: Colors.white.withValues(alpha: 0.2),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: Colors.white, size: widget.fontSize + 2),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.poppins(
                              color: _active ? Colors.white : AppTheme.textHint,
                              fontWeight: FontWeight.w600,
                              fontSize: widget.fontSize,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Outlined Button ──────────────────────────────────────
class SAOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? width;
  final double height;
  final Color? color;

  const SAOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.width,
    this.height = 52,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Text(label),
          ],
        ),
      ),
    );
  }
}

// ─── Small Icon Button ─────────────────────────────────────
class SAIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? bgColor;
  final double size;
  final String? tooltip;

  const SAIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.bgColor,
    this.size = 20,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final w = Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: bgColor ?? AppTheme.bgMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Icon(icon, color: color ?? AppTheme.textSecondary, size: size),
        ),
      ),
    );
    if (tooltip != null) return Tooltip(message: tooltip!, child: w);
    return w;
  }
}
