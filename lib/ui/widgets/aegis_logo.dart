import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Reusable Aegis Sentinel brand logo widget.
/// Renders the official high-resolution Aegis shield logo asset with optional
/// cyber glow, custom sizing, and graceful fallback for tests/environments.
class AegisLogo extends StatelessWidget {
  final double size;
  final BoxFit fit;
  final bool showGlow;
  final Color? glowColor;
  final BorderRadius? borderRadius;

  const AegisLogo({
    super.key,
    this.size = 32,
    this.fit = BoxFit.contain,
    this.showGlow = false,
    this.glowColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlowColor = glowColor ?? AppColors.primary;

    Widget imageWidget = Image.asset(
      'assets/images/aegis_logo.png',
      width: size,
      height: size,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.shield_rounded,
          size: size * 0.8,
          color: effectiveGlowColor,
        );
      },
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (!showGlow) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: imageWidget),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: effectiveGlowColor.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            spreadRadius: size * 0.05,
          ),
        ],
      ),
      child: Center(child: imageWidget),
    );
  }
}
