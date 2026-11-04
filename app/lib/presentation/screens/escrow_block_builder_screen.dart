import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/blocks/escrow_block.dart';
import '../../domain/blocks/escrow_block_stack.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/blocks/block_palette.dart';
import '../widgets/blocks/block_workspace.dart';
import '../widgets/glass.dart';
import 'create_escrow_screen.dart';

/// Scratch-like Escrow sur mesure — maps blocks → existing factory params.
class EscrowBlockBuilderScreen extends ConsumerStatefulWidget {
  const EscrowBlockBuilderScreen({super.key});

  @override
  ConsumerState<EscrowBlockBuilderScreen> createState() =>
      _EscrowBlockBuilderScreenState();
}

class _EscrowBlockBuilderScreenState
    extends ConsumerState<EscrowBlockBuilderScreen> {
  List<EscrowBlock> _blocks = [];
  String? _toast;

  EscrowBlockStack get _stack => EscrowBlockStack(_blocks);

  void _showToast(String message) {
    setState(() => _toast = message);
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _toast == message) setState(() => _toast = null);
    });
  }

  void _addKind(EscrowBlockKind kind) {
    final stack = _stack;
    final snap = stack.canAccept(kind);
    if (!snap.accepted) {
      _showToast(snap.reason?.message ?? 'That block doesn’t fit here');
      HapticFeedback.lightImpact();
      return;
    }
    HapticFeedback.selectionClick();
    final block = EscrowBlock(
      id: '${kind.name}_${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
    );
    setState(() => _blocks = [..._blocks, block]);
    if (kind == EscrowBlockKind.sellerIs ||
        kind == EscrowBlockKind.lockAmount ||
        kind == EscrowBlockKind.deadlineInDays ||
        kind == EscrowBlockKind.deadlineOnDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editBlock(block));
    }
  }

  Future<void> _editBlock(EscrowBlock block) async {
    final updated = await showModalBottomSheet<EscrowBlock>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BlockEditSheet(block: block),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _blocks = [
        for (final b in _blocks) b.id == updated.id ? updated : b,
      ];
    });
  }

  void _deploy() {
    final buyer = ref.read(connectedAddressProvider);
    final stack = _stack;
    if (!stack.isValidForDeploy(connectedBuyer: buyer)) {
      final msgs = [
        ...stack.missingRequirements,
        ...stack.fieldErrors(connectedBuyer: buyer),
      ];
      _showToast(msgs.isEmpty ? 'Stack incomplete' : msgs.first);
      HapticFeedback.lightImpact();
      return;
    }

    final params = stack.toCreateParams(connectedBuyer: buyer);
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateEscrowScreen(
          initialSeller: params.seller,
          initialAmountEth: formatWeiAsEth(params.amountWei),
          initialDeadline: params.deadline,
          fromBlockBuilder: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyer = ref.watch(connectedAddressProvider);
    final ready = _stack.isValidForDeploy(connectedBuyer: buyer);
    final missing = _stack.missingRequirements;
    final fieldErrs = _stack.fieldErrors(connectedBuyer: buyer);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppTheme.shellSurface,
      appBar: AppBar(
        title: const Text('Escrow sur mesure'),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              color: AppTheme.shellSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(16),
                  opacity: 0.45,
                  blurSigma: 14,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Text(
                    'Snap plain-English blocks into a stack. Deploy maps them '
                    'onto the real Escrow factory (seller · amount · deadline) '
                    '— no custom Solidity.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.ink.withValues(alpha: 0.68),
                          height: 1.35,
                        ),
                  ),
                ),
              ),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const BlockPaletteHeader(title: 'BLOCKS'),
                                Expanded(
                                  child: BlockPalette(
                                    axis: Axis.vertical,
                                    onAddKind: _addKind,
                                    onStubTap: (_) => _showToast(
                                      'Coming soon — not buildable yet',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                              child: BlockWorkspace(
                                blocks: _blocks,
                                onChanged: (b) => setState(() => _blocks = b),
                                onReject: (r) => _showToast(r.message),
                                onEditBlock: _editBlock,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const BlockPaletteHeader(title: 'BLOCKS'),
                          BlockPalette(
                            axis: Axis.horizontal,
                            onAddKind: _addKind,
                            onStubTap: (_) =>
                                _showToast('Coming soon — not buildable yet'),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 0),
                              child: BlockWorkspace(
                                blocks: _blocks,
                                onChanged: (b) =>
                                    setState(() => _blocks = b),
                                onReject: (r) => _showToast(r.message),
                                onEditBlock: _editBlock,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              GlassBar(
                opacity: 0.82,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!ready) ...[
                        Text(
                          missing.isNotEmpty
                              ? 'Still need: ${missing.join(' · ')}'
                              : fieldErrs.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: AppTheme.ink.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        Text(
                          'Ready · maps to seller / amount / deadline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentDim,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      FilledButton(
                        onPressed: ready ? _deploy : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.ink,
                          disabledBackgroundColor:
                              AppTheme.ink.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.shellSurface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Deploy'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_toast != null)
            Positioned(
              left: 24,
              right: 24,
              bottom: 100 + bottomInset,
              child: Material(
                color: Colors.transparent,
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(14),
                  opacity: 0.88,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    _toast!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BlockEditSheet extends StatefulWidget {
  const _BlockEditSheet({required this.block});

  final EscrowBlock block;

  @override
  State<_BlockEditSheet> createState() => _BlockEditSheetState();
}

class _BlockEditSheetState extends State<_BlockEditSheet> {
  late final TextEditingController _seller;
  late final TextEditingController _amount;
  late final TextEditingController _days;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _seller = TextEditingController(text: widget.block.sellerAddress);
    _amount = TextEditingController(text: widget.block.amountEth);
    _days = TextEditingController(text: '${widget.block.deadlineDays}');
    _date = widget.block.deadlineDate;
  }

  @override
  void dispose() {
    _seller.dispose();
    _amount.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toLocal().isAfter(DateTime.now())
          ? _date.toLocal()
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(minutes: 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day, 23, 59)
          .toUtc();
    });
  }

  void _save() {
    final kind = widget.block.kind;
    EscrowBlock next = widget.block;
    switch (kind) {
      case EscrowBlockKind.sellerIs:
        next = widget.block.copyWith(sellerAddress: _seller.text.trim());
      case EscrowBlockKind.lockAmount:
        next = widget.block.copyWith(amountEth: _amount.text.trim());
      case EscrowBlockKind.deadlineInDays:
        next = widget.block.copyWith(
          deadlineDays: int.tryParse(_days.text.trim()) ?? 7,
        );
      case EscrowBlockKind.deadlineOnDate:
        next = widget.block.copyWith(deadlineDate: _date);
      default:
        break;
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final kind = widget.block.kind;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          opacity: 0.9,
          blurSigma: 24,
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const SizedBox(height: 14),
              Text(
                'Edit block',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
              ),
              const SizedBox(height: 14),
              if (kind == EscrowBlockKind.sellerIs)
                TextField(
                  controller: _seller,
                  decoration: const InputDecoration(
                    labelText: 'Seller address',
                    hintText: '0x…',
                  ),
                  autofocus: true,
                ),
              if (kind == EscrowBlockKind.lockAmount)
                TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (ETH)',
                    hintText: '0.1',
                  ),
                  autofocus: true,
                ),
              if (kind == EscrowBlockKind.deadlineInDays)
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Days from now',
                    hintText: '7',
                  ),
                  autofocus: true,
                ),
              if (kind == EscrowBlockKind.deadlineOnDate)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Deadline date'),
                  subtitle: Text(_date.toLocal().toString().split('.').first),
                  trailing: TextButton(
                    onPressed: _pickDate,
                    child: const Text('Pick'),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
