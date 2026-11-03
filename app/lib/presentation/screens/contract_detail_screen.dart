import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../widgets/escrow_action_bar.dart';

class ContractDetailScreen extends ConsumerStatefulWidget {
  const ContractDetailScreen({super.key, required this.address});

  final String address;

  @override
  ConsumerState<ContractDetailScreen> createState() =>
      _ContractDetailScreenState();
}

class _ContractDetailScreenState extends ConsumerState<ContractDetailScreen> {
  bool _busy = false;
  String? _txHash;
  String? _txStatus;
  String? _error;

  Future<void> _run(Future<dynamic> Function() action, String label) async {
    setState(() {
      _busy = true;
      _error = null;
      _txHash = null;
      _txStatus = 'pending';
    });
    try {
      await ref.read(walletServiceProvider).ensureSepolia();
      // Re-read is done inside repository before money moves.
      final result = await action();
      setState(() {
        _txHash = result.txHash as String;
        _txStatus = result.status.toString().split('.').last;
      });
      ref.invalidate(contractDetailProvider(widget.address));
      ref.invalidate(myContractsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label · $_txStatus')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _txStatus = 'failed';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractDetailProvider(widget.address));
    final wallet = ref.watch(connectedAddressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escrow detail'),
        actions: [
          IconButton(
            tooltip: 'Refresh from chain',
            onPressed: () =>
                ref.invalidate(contractDetailProvider(widget.address)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text('$e'),
        )),
        data: (c) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _row('Network', AppConfig.networkName),
              _row('State', c.state.label),
              _row('Amount', '${formatWeiAsEth(c.amountWei)} ETH'),
              _row('Buyer', c.buyer),
              _row('Seller', c.seller),
              _row('Deadline', c.deadline.toLocal().toString()),
              _row('Created', c.createdAt.toLocal().toString()),
              _row('Contract', c.address),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.etherscanAddressUrl(c.address)),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open on Etherscan'),
                ),
              ),
              const Divider(height: 32),
              Text(
                'Actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              EscrowActionBar(
                contract: c,
                walletAddress: wallet,
                busy: _busy,
                onFund: () => _run(
                  () => ref
                      .read(contractRepositoryProvider)
                      .fund(c.address),
                  'Fund',
                ),
                onRelease: () => _run(
                  () => ref
                      .read(contractRepositoryProvider)
                      .release(c.address),
                  'Release',
                ),
                onRefundBySeller: () => _run(
                  () => ref
                      .read(contractRepositoryProvider)
                      .refundBySeller(c.address),
                  'Refund',
                ),
                onRefundAfterDeadline: () => _run(
                  () => ref
                      .read(contractRepositoryProvider)
                      .refundAfterDeadline(c.address),
                  'Reclaim',
                ),
              ),
              if (_txHash != null) ...[
                const SizedBox(height: 20),
                Text('Last transaction', style: Theme.of(context).textTheme.titleSmall),
                SelectableText(_txHash!),
                Text('Status: ${_txStatus ?? '—'}'),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.etherscanTxUrl(_txHash!)),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text('View tx on Etherscan'),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'Contracts are public. Anyone can read this address on Etherscan.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          SelectableText(value),
        ],
      ),
    );
  }
}
