import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/blocks/escrow_block.dart';
import '../../theme/app_theme.dart';
import 'puzzle_block.dart';

/// Horizontal (phone) or vertical (wide) palette of draggable puzzle blocks.
class BlockPalette extends StatelessWidget {
  const BlockPalette({
    super.key,
    required this.axis,
    this.onStubTap,
    this.onAddKind,
  });

  final Axis axis;
  final void Function(EscrowBlockKind kind)? onStubTap;
  /// Tap-to-add (in addition to long-press drag) — helpful on web/desktop.
  final void Function(EscrowBlockKind kind)? onAddKind;

  @override
  Widget build(BuildContext context) {
    final kinds = escrowPaletteKinds;
    if (axis == Axis.horizontal) {
      return SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: kinds.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _PaletteItem(
            kind: kinds[i],
            width: 168,
            onStubTap: onStubTap,
            onAddKind: onAddKind,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
      itemCount: kinds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PaletteItem(
        kind: kinds[i],
        width: double.infinity,
        onStubTap: onStubTap,
        onAddKind: onAddKind,
      ),
    );
  }
}

class _PaletteItem extends StatelessWidget {
  const _PaletteItem({
    required this.kind,
    required this.width,
    this.onStubTap,
    this.onAddKind,
  });

  final EscrowBlockKind kind;
  final double width;
  final void Function(EscrowBlockKind kind)? onStubTap;
  final void Function(EscrowBlockKind kind)? onAddKind;

  @override
  Widget build(BuildContext context) {
    final face = PuzzleBlockFace(
      label: kind.paletteLabel,
      category: kind.category,
      isHat: kind.isHat,
      width: width == double.infinity ? null : width,
      dimmed: !kind.isBuildable,
      onTap: kind.isBuildable
          ? () {
              HapticFeedback.selectionClick();
              onAddKind?.call(kind);
            }
          : () {
              HapticFeedback.lightImpact();
              onStubTap?.call(kind);
            },
    );

    if (!kind.isBuildable) {
      return Stack(
        children: [
          face,
          Positioned(
            right: 10,
            top: kind.isHat ? 10 : 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return LongPressDraggable<EscrowBlockKind>(
      data: kind,
      delay: const Duration(milliseconds: 140),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.rotate(
          angle: -0.03,
          child: PuzzleBlockFace(
            label: kind.paletteLabel,
            category: kind.category,
            isHat: kind.isHat,
            width: 180,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: face),
      child: Tooltip(
        message: 'Tap to add, or long-press to drag',
        child: face,
      ),
    );
  }
}

/// Small section header for the palette rail.
class BlockPaletteHeader extends StatelessWidget {
  const BlockPaletteHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
          color: AppTheme.ink.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
