import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/blocks/escrow_block.dart';
import '../../../domain/blocks/escrow_block_stack.dart';
import '../../theme/app_theme.dart';
import '../glass.dart';
import 'puzzle_block.dart';

typedef BlockEditCallback = void Function(EscrowBlock block);

/// Vertical snap stack — invalid drops are rejected with gentle feedback.
class BlockWorkspace extends StatefulWidget {
  const BlockWorkspace({
    super.key,
    required this.blocks,
    required this.onChanged,
    required this.onReject,
    this.onEditBlock,
  });

  final List<EscrowBlock> blocks;
  final ValueChanged<List<EscrowBlock>> onChanged;
  final ValueChanged<BlockRejectReason> onReject;
  final BlockEditCallback? onEditBlock;

  @override
  State<BlockWorkspace> createState() => _BlockWorkspaceState();
}

class _BlockWorkspaceState extends State<BlockWorkspace>
    with SingleTickerProviderStateMixin {
  bool _hoverOk = false;
  bool _hoverBad = false;
  late final AnimationController _shake;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  EscrowBlockStack get _stack => EscrowBlockStack(widget.blocks);

  void _flashReject(BlockRejectReason reason) {
    HapticFeedback.lightImpact();
    setState(() {
      _hoverOk = false;
      _hoverBad = true;
    });
    _shake.forward(from: 0);
    widget.onReject(reason);
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _hoverBad = false);
    });
  }

  void _append(EscrowBlockKind kind) {
    final result = _stack.canAccept(kind);
    if (!result.accepted) {
      _flashReject(result.reason ?? BlockRejectReason.invalidAtEnd);
      return;
    }
    HapticFeedback.selectionClick();
    final block = EscrowBlock(
      id: '${kind.name}_${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
    );
    final next = List<EscrowBlock>.from(widget.blocks)..add(block);
    setState(() {
      _hoverOk = false;
      _hoverBad = false;
    });
    widget.onChanged(next);
    // Prompt for fields that map to factory params.
    if (kind == EscrowBlockKind.sellerIs ||
        kind == EscrowBlockKind.lockAmount ||
        kind == EscrowBlockKind.deadlineInDays ||
        kind == EscrowBlockKind.deadlineOnDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onEditBlock?.call(block);
      });
    }
  }

  void _removeAt(int index) {
    final next = List<EscrowBlock>.from(widget.blocks)..removeAt(index);
    widget.onChanged(next);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final active = _hoverOk;
    final bad = _hoverBad;

    return DragTarget<EscrowBlockKind>(
      onWillAcceptWithDetails: (details) {
        final snap = _stack.canAccept(details.data);
        setState(() {
          _hoverOk = snap.accepted;
          _hoverBad = !snap.accepted;
        });
        if (snap.accepted) HapticFeedback.selectionClick();
        // Accept the gesture so onAccept can show gentle reject feedback.
        return true;
      },
      onLeave: (_) => setState(() {
        _hoverOk = false;
        _hoverBad = false;
      }),
      onAcceptWithDetails: (details) => _append(details.data),
      builder: (context, candidate, rejected) {
        final highlight = active || candidate.isNotEmpty;
        final rejectHighlight = bad || rejected.isNotEmpty;

        return AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = t == 0 || t == 1
                ? 0.0
                : (t < 0.25
                        ? t * 16
                        : t < 0.5
                            ? (0.5 - t) * 16
                            : t < 0.75
                                ? (t - 0.5) * -12
                                : (1 - t) * -12);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: rejectHighlight
                    ? const Color(0xFFC45C4A).withValues(alpha: 0.55)
                    : highlight
                        ? AppTheme.accentDim.withValues(alpha: 0.55)
                        : AppTheme.ink.withValues(alpha: 0.1),
                width: highlight || rejectHighlight ? 1.6 : 1,
              ),
              color: rejectHighlight
                  ? const Color(0xFFC45C4A).withValues(alpha: 0.08)
                  : highlight
                      ? AppTheme.accent.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.22),
            ),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(22),
              opacity: 0.32,
              blurSigma: 16,
              borderColor: Colors.transparent,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.view_agenda_rounded,
                        size: 18,
                        color: highlight
                            ? AppTheme.accentDim
                            : AppTheme.ink.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Workspace',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: AppTheme.ink.withValues(alpha: 0.85),
                        ),
                      ),
                      const Spacer(),
                      if (widget.blocks.isNotEmpty)
                        TextButton(
                          onPressed: () => widget.onChanged(const []),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: widget.blocks.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                rejectHighlight
                                    ? 'That block can’t snap here'
                                    : highlight
                                        ? 'Release to snap'
                                        : 'Drag blocks here to build your Escrow',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.ink.withValues(
                                    alpha: highlight || rejectHighlight
                                        ? 0.8
                                        : 0.45,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: widget.blocks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (context, index) {
                              final block = widget.blocks[index];
                              return PuzzleBlockFace(
                                label: block.displayLabel,
                                category: block.kind.category,
                                isHat: block.kind.isHat,
                                showBottomNotch: true,
                                width: double.infinity,
                                onTap: () {
                                  if (block.kind == EscrowBlockKind.sellerIs ||
                                      block.kind ==
                                          EscrowBlockKind.lockAmount ||
                                      block.kind ==
                                          EscrowBlockKind.deadlineInDays ||
                                      block.kind ==
                                          EscrowBlockKind.deadlineOnDate) {
                                    widget.onEditBlock?.call(block);
                                  }
                                },
                                trailing: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: foregroundForCategory(
                                      block.kind.category,
                                    ).withValues(alpha: 0.75),
                                  ),
                                  onPressed: () => _removeAt(index),
                                ),
                              );
                            },
                          ),
                  ),
                  if (widget.blocks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Drop or tap the next block',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.ink.withValues(
                            alpha: highlight ? 0.7 : 0.35,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
