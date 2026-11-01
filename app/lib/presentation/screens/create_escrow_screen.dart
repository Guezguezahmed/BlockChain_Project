import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/escrow_contract.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import 'contract_detail_screen.dart';
import 'wallet_screen.dart';

class CreateEscrowScreen extends ConsumerStatefulWidget {
  const CreateEscrowScreen({super.key});

  @override
  ConsumerState<CreateEscrowScreen> createState() => _CreateEscrowScreenState();
}

class _CreateEscrowScreenState extends ConsumerState<CreateEscrowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _sellerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '0.1');
  DateTime _deadline = DateTime.now().toUtc().add(const Duration(days: 7));
  bool _busy = false;
  String? _error;
  String? _lastTx;

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
      appBar: AppBar(title: const Text('Create Escrow')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'You (the connected wallet) become the buyer. Money is not moved '
              'until you tap Deposit on the contract detail screen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
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
