import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/create_escrow_screen.dart';
import '../screens/escrow_block_builder_screen.dart';
import '../theme/app_theme.dart';
import 'glass.dart';

/// Springy glass create sheet: quick Escrow form + Scratch block builder.
Future<void> showCreateTemplateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppTheme.ink.withValues(alpha: 0.28),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.68;
      return _SpringSheetFrame(
        height: height,
        child: const _CreateTemplateSheetBody(),
      );
    },
  );
}

void _openEscrowForm(BuildContext context) {
  HapticFeedback.mediumImpact();
  Navigator.of(context).pop();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const CreateEscrowScreen(),
    ),
  );
}

void _openEscrowBlocks(BuildContext context) {
  HapticFeedback.mediumImpact();
  Navigator.of(context).pop();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const EscrowBlockBuilderScreen(),
    ),
  );
}

class _SpringSheetFrame extends StatelessWidget {
  const _SpringSheetFrame({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: height,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppTheme.shellSurface.withValues(alpha: 0.78),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateSpec {
  const _TemplateSpec({
    required this.id,
    required this.title,
    required this.icon,
    required this.badge,
    required this.enabled,
  });

  final String id;
  final String title;
  final IconData icon;
  final String badge;
  final bool enabled;
}

const _kTemplates = <_TemplateSpec>[
  _TemplateSpec(
    id: 'escrow',
    title: 'Escrow',
    icon: Icons.lock_outline_rounded,
    badge: 'Live',
    enabled: true,
  ),
  _TemplateSpec(
    id: 'rental',
    title: 'Rental',
    icon: Icons.home_work_outlined,
    badge: 'Soon',
    enabled: false,
  ),
  _TemplateSpec(
    id: 'milestone',
    title: 'Milestone',
    icon: Icons.flag_outlined,
    badge: 'Soon',
    enabled: false,
  ),
];

class _CreateTemplateSheetBody extends StatefulWidget {
  const _CreateTemplateSheetBody();

  @override
  State<_CreateTemplateSheetBody> createState() =>
      _CreateTemplateSheetBodyState();
}

class _CreateTemplateSheetBodyState extends State<_CreateTemplateSheetBody> {
  late List<_TemplateSpec> _order = List<_TemplateSpec>.from(_kTemplates);
  bool _buildHover = false;
  String? _flashId;

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    HapticFeedback.selectionClick();
  }

  void _acceptEscrow() {
    setState(() {
      _flashId = 'escrow';
      _buildHover = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      // Drop on Build → Scratch block canvas (tap chip still opens quick form).
      _openEscrowBlocks(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.ink.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create a contract',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppTheme.ink,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Quick form, or build with plain-English blocks '
            '(Escrow sur mesure).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.62),
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'Templates',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink.withValues(alpha: 0.55),
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, _) {
                    final t = Curves.easeOut.transform(animation.value);
                    return Transform.scale(
                      scale: 1.04 + (0.02 * t),
                      child: child,
                    );
                  },
                );
              },
              onReorder: _onReorder,
              itemCount: _order.length,
              itemBuilder: (context, index) {
                final spec = _order[index];
                return Padding(
                  key: ValueKey(spec.id),
                  padding: EdgeInsets.only(
                    right: index == _order.length - 1 ? 0 : 10,
                  ),
                  child: _TemplateChip(
                    spec: spec,
                    index: index,
                    highlighted: _flashId == spec.id,
                    onTap:
                        spec.enabled ? () => _openEscrowForm(context) : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DragTarget<_TemplateSpec>(
              onWillAcceptWithDetails: (details) {
                final ok = details.data.enabled;
                setState(() => _buildHover = ok);
                if (ok) HapticFeedback.selectionClick();
                return ok;
              },
              onLeave: (_) => setState(() => _buildHover = false),
              onAcceptWithDetails: (details) {
                if (details.data.id == 'escrow') {
                  _acceptEscrow();
                } else {
                  setState(() => _buildHover = false);
                }
              },
              builder: (context, candidate, rejected) {
                final active = _buildHover || candidate.isNotEmpty;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: active
                          ? AppTheme.accentDim.withValues(alpha: 0.55)
                          : AppTheme.ink.withValues(alpha: 0.1),
                      width: active ? 1.6 : 1,
                    ),
                    color: active
                        ? AppTheme.accent.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.28),
                  ),
                  child: GlassSurface(
                    borderRadius: BorderRadius.circular(22),
                    opacity: 0.35,
                    blurSigma: 18,
                    borderColor: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: IntrinsicHeight(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.construction_rounded,
                                        size: 18,
                                        color: active
                                            ? AppTheme.accentDim
                                            : AppTheme.ink
                                                .withValues(alpha: 0.45),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Build',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: AppTheme.ink.withValues(
                                            alpha: active ? 0.9 : 0.7,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      if (active)
                                        Text(
                                          'Release to open',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accentDim,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Spacer(),
                                  Text(
                                    active
                                        ? 'Drop Escrow to open blocks'
                                        : 'Drop Escrow for block builder',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.ink.withValues(
                                        alpha: active ? 0.85 : 0.48,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Snap plain-English blocks → deploy',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.ink
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppTheme.ink,
                                      foregroundColor: AppTheme.shellSurface,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => _openEscrowBlocks(context),
                                    child: const Text(
                                      'Escrow sur mesure (blocks)',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.ink,
                                      side: BorderSide(
                                        color: AppTheme.ink
                                            .withValues(alpha: 0.22),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: () => _openEscrowForm(context),
                                    child: const Text('Quick Escrow form'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  const _TemplateChip({
    required this.spec,
    required this.index,
    required this.highlighted,
    required this.onTap,
  });

  final _TemplateSpec spec;
  final int index;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chip = _ChipFace(
      spec: spec,
      index: index,
      highlighted: highlighted,
      onTap: onTap,
    );

    if (!spec.enabled) return chip;

    return LongPressDraggable<_TemplateSpec>(
      data: spec,
      delay: const Duration(milliseconds: 180),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        shadowColor: AppTheme.ink.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
        child: Transform.rotate(
          angle: -0.04,
          child: SizedBox(
            width: 128,
            height: 76,
            child: _ChipFace(
              spec: spec,
              index: index,
              highlighted: true,
              onTap: null,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }
}

class _ChipFace extends StatelessWidget {
  const _ChipFace({
    required this.spec,
    required this.index,
    required this.highlighted,
    required this.onTap,
  });

  final _TemplateSpec spec;
  final int index;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = spec.enabled;
    final border = highlighted
        ? AppTheme.accentDim
        : enabled
            ? AppTheme.ink.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.06);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 128,
          height: 76,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: enabled
                ? Colors.white.withValues(alpha: 0.72)
                : Colors.black.withValues(alpha: 0.04),
            border: Border.all(color: border, width: highlighted ? 1.6 : 1),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppTheme.ink.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 16,
                      color: AppTheme.ink.withValues(
                        alpha: enabled ? 0.35 : 0.2,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _Badge(label: spec.badge, live: enabled),
                ],
              ),
              Row(
                children: [
                  Icon(
                    spec.icon,
                    size: 16,
                    color: enabled ? AppTheme.accentDim : Colors.black38,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: enabled ? AppTheme.ink : Colors.black45,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                enabled ? 'Drag or tap' : 'Coming soon',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: enabled
                      ? AppTheme.ink.withValues(alpha: 0.45)
                      : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: live
            ? AppTheme.accent.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: live ? AppTheme.accentDim : Colors.black45,
        ),
      ),
    );
  }
}
