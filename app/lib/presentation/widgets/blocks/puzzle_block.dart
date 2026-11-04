import 'package:flutter/material.dart';

import '../../../domain/blocks/escrow_block.dart';
import '../../theme/app_theme.dart';

/// Teal/sand Scratch palette — no purple.
Color colorForCategory(EscrowBlockCategory category) {
  switch (category) {
    case EscrowBlockCategory.event:
      return AppTheme.ink;
    case EscrowBlockCategory.role:
      return AppTheme.accentDim;
    case EscrowBlockCategory.money:
      return const Color(0xFF2A6B5E);
    case EscrowBlockCategory.time:
      return const Color(0xFF3D5A54);
    case EscrowBlockCategory.outcome:
      return const Color(0xFF5A7A72);
    case EscrowBlockCategory.stub:
      return const Color(0xFF9AABB0);
  }
}

Color foregroundForCategory(EscrowBlockCategory category) {
  switch (category) {
    case EscrowBlockCategory.event:
    case EscrowBlockCategory.role:
    case EscrowBlockCategory.money:
    case EscrowBlockCategory.time:
    case EscrowBlockCategory.outcome:
      return const Color(0xFFE7F2EE);
    case EscrowBlockCategory.stub:
      return Colors.white.withValues(alpha: 0.85);
  }
}

/// Puzzle-piece silhouette: optional hat top, notch + bump for stacking.
class PuzzleBlockShape extends StatelessWidget {
  const PuzzleBlockShape({
    super.key,
    required this.child,
    required this.color,
    this.isHat = false,
    this.showBottomNotch = true,
    this.width,
    this.minHeight = 44,
    this.opacity = 1,
  });

  final Widget child;
  final Color color;
  final bool isHat;
  final bool showBottomNotch;
  final double? width;
  final double minHeight;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: CustomPaint(
        painter: _PuzzlePainter(
          color: color,
          isHat: isHat,
          showBottomNotch: showBottomNotch,
        ),
        child: Container(
          width: width,
          constraints: BoxConstraints(minHeight: minHeight),
          padding: EdgeInsets.fromLTRB(
            14,
            isHat ? 14 : 18,
            14,
            showBottomNotch ? 18 : 12,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PuzzlePainter extends CustomPainter {
  _PuzzlePainter({
    required this.color,
    required this.isHat,
    required this.showBottomNotch,
  });

  final Color color;
  final bool isHat;
  final bool showBottomNotch;

  static const double _bumpW = 22;
  static const double _bumpH = 8;
  static const double _r = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = w * 0.28;
    final p = Path();

    if (isHat) {
      p.moveTo(0, _bumpH + 6);
      p.quadraticBezierTo(0, _bumpH, 12, _bumpH);
      p.lineTo(w - 12, _bumpH);
      p.quadraticBezierTo(w, _bumpH, w, _bumpH + 6);
    } else {
      p.moveTo(0, _bumpH + _r);
      p.quadraticBezierTo(0, _bumpH, _r, _bumpH);
      p.lineTo(mid - _bumpW / 2, _bumpH);
      p.cubicTo(
        mid - _bumpW / 3,
        _bumpH,
        mid - _bumpW / 3,
        1,
        mid,
        1,
      );
      p.cubicTo(
        mid + _bumpW / 3,
        1,
        mid + _bumpW / 3,
        _bumpH,
        mid + _bumpW / 2,
        _bumpH,
      );
      p.lineTo(w - _r, _bumpH);
      p.quadraticBezierTo(w, _bumpH, w, _bumpH + _r);
    }

    final bottomY = showBottomNotch ? h - _bumpH : h - 4;
    p.lineTo(w, bottomY - _r);
    p.quadraticBezierTo(w, bottomY, w - _r, bottomY);

    if (showBottomNotch) {
      p.lineTo(mid + _bumpW / 2, bottomY);
      p.cubicTo(
        mid + _bumpW / 3,
        bottomY,
        mid + _bumpW / 3,
        h - 1,
        mid,
        h - 1,
      );
      p.cubicTo(
        mid - _bumpW / 3,
        h - 1,
        mid - _bumpW / 3,
        bottomY,
        mid - _bumpW / 2,
        bottomY,
      );
    }

    p.lineTo(_r, bottomY);
    p.quadraticBezierTo(0, bottomY, 0, bottomY - _r);
    p.close();

    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45)),
    );
  }

  @override
  bool shouldRepaint(covariant _PuzzlePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isHat != isHat ||
        oldDelegate.showBottomNotch != showBottomNotch;
  }
}

/// Compact palette tile or workspace piece face.
class PuzzleBlockFace extends StatelessWidget {
  const PuzzleBlockFace({
    super.key,
    required this.label,
    required this.category,
    this.isHat = false,
    this.showBottomNotch = true,
    this.width,
    this.trailing,
    this.dimmed = false,
    this.onTap,
  });

  final String label;
  final EscrowBlockCategory category;
  final bool isHat;
  final bool showBottomNotch;
  final double? width;
  final Widget? trailing;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = colorForCategory(category);
    final fg = foregroundForCategory(category);

    final labelStyle = TextStyle(
      color: fg,
      fontWeight: FontWeight.w700,
      fontSize: 13,
      height: 1.2,
      letterSpacing: -0.2,
    );

    final body = PuzzleBlockShape(
      color: bg,
      isHat: isHat,
      showBottomNotch: showBottomNotch,
      width: width ?? double.infinity,
      opacity: dimmed ? 0.45 : 1,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return GestureDetector(onTap: onTap, child: body);
  }
}
