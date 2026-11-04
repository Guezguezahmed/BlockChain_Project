import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/escrow_contract.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'contract_detail_screen.dart';
import 'wallet_screen.dart';

class CreateEscrowScreen extends ConsumerStatefulWidget {
  const CreateEscrowScreen({
    super.key,
    this.initialSeller,
    this.initialAmountEth,
    this.initialDeadline,
    this.fromBlockBuilder = false,
  });

  /// Prefill from the Scratch block builder (mapped factory params).
  final String? initialSeller;
  final String? initialAmountEth;
  final DateTime? initialDeadline;
  final bool fromBlockBuilder;

  @override
  ConsumerState<CreateEscrowScreen> createState() => _CreateEscrowScreenState();
}

class _CreateEscrowScreenState extends ConsumerState<CreateEscrowScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sellerCtrl;
  late final TextEditingController _amountCtrl;
  late DateTime _deadline;
  bool _busy = false;
  String? _error;
  String? _lastTx;

  @override
  void initState() {
    super.initState();
    _sellerCtrl = TextEditingController(text: widget.initialSeller ?? '');
    _amountCtrl =
        TextEditingController(text: widget.initialAmountEth ?? '0.1');
    _deadline = widget.initialDeadline ??
        DateTime.now().toUtc().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _sellerCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline.toLocal(),
      firstDate: DateTime.now().add(const Duration(minutes: 5)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline.toLocal()),
    );
    if (time == null || !mounted) return;
    setState(() {
      _deadline = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final address = ref.read(connectedAddressProvider);
    if (address == null) {
      final nav = Navigator.of(context);
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _lastTx = null;
    });

    try {
      await ref.read(walletServiceProvider).ensureSepolia();
      final amountWei = tryParseEthToWei(_amountCtrl.text)!;
      final seller = checksumAddress(_sellerCtrl.text);
      final result = await ref.read(contractRepositoryProvider).createEscrow(
            CreateEscrowParams(
              seller: seller,
              amountWei: amountWei,
              deadline: _deadline,
            ),
          );
      if (!mounted) return;
      setState(() => _lastTx = result.txHash);
      ref.invalidate(myContractsProvider);
      final created = result.contractAddress;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.status.name == 'failed'
                ? 'Transaction failed'
                : 'Escrow created · tx ${result.txHash.substring(0, 10)}…',
          ),
        ),
      );
      if (created != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ContractDetailScreen(address: created),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(connectedAddressProvider);

    return Scaffold(
      extendBodyBehindAppBar: false,
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              widget.fromBlockBuilder
                  ? 'Review mapped Escrow'
                  : 'Custom Escrow',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppTheme.ink,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.fromBlockBuilder
                  ? 'Filled from your block stack (seller · amount · deadline). '
                      'You (the connected wallet) become the buyer. Funds move '
                      'only when you Deposit on the contract detail screen.'
                  : 'Set seller, amount, and deadline. You (the connected wallet) '
                      'become the buyer. Funds move only when you Deposit on the '
                      'contract detail screen.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.65),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _sellerCtrl,
              decoration: const InputDecoration(
                labelText: 'Seller address',
                hintText: '0x…',
              ),
              validator: (v) {
                if (v == null || !isValidEthereumAddress(v)) {
                  return 'Enter a valid Ethereum address';
                }
                final connectedAddr = ref.read(connectedAddressProvider);
                if (connectedAddr != null &&
                    v.trim().toLowerCase() == connectedAddr.toLowerCase()) {
                  return 'Seller must differ from buyer (you)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (ETH)',
                hintText: '0.1',
              ),
              validator: (v) {
                final wei = tryParseEthToWei(v ?? '');
                if (wei == null || wei <= BigInt.zero) {
                  return 'Enter a positive ETH amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deadline'),
              subtitle: Text(_deadline.toLocal().toString()),
              trailing: TextButton(
                onPressed: _pickDeadline,
                child: const Text('Change'),
              ),
            ),
            if (_deadline.isBefore(DateTime.now().toUtc()))
              Text(
                'Deadline must be in the future',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(
                _busy
                    ? 'Submitting…'
                    : connected == null
                        ? 'Connect wallet to deploy'
                        : 'Deploy escrow',
              ),
            ),
            if (_lastTx != null) ...[
              const SizedBox(height: 12),
              SelectableText('Tx: $_lastTx'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
