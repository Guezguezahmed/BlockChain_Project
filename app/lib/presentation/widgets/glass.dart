import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft frosted panel — Apple Wallet / Health materials, teal/sand brand.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.blurSigma = 22,
    this.tint,
    this.borderColor,
    this.opacity = 0.55,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final Color? tint;
  final Color? borderColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(18);
    final fill = (tint ?? Colors.white).withValues(alpha: opacity);
    final stroke = borderColor ??
        AppTheme.ink.withValues(alpha: 0.08);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: radius,
            border: Border.all(color: stroke),
          ),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      ),
    );
  }
}

/// Frosted top / bottom chrome that sits over scrolling content.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.height,
    this.blurSigma = 28,
    this.opacity = 0.72,
  });

  final Widget child;
  final double? height;
  final double blurSigma;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.shellSurface.withValues(alpha: opacity),
            border: Border(
              top: BorderSide(
                color: AppTheme.ink.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: SizedBox(height: height, child: child),
        ),
      ),
    );
  }
}
