import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/models/escrow_actions.dart';
import '../../domain/models/escrow_contract.dart';
import '../../domain/models/escrow_state.dart';
import '../../domain/models/transaction_result.dart';
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

  /// After a confirmed money-moving tx, re-read until on-chain state advances
  /// (RPC can lag behind the receipt). Keeps Actions disabled via [_busy].
  Future<EscrowContract> _refreshUntilState({
    required EscrowState previous,
    EscrowState? expected,
  }) async {
    const attempts = 12;
    const delay = Duration(seconds: 2);
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        final fresh =
            await ref.refresh(contractDetailProvider(widget.address).future);
        if (fresh.state != previous) return fresh;
        if (expected != null && fresh.state == expected) return fresh;
        if (fresh.state.isTerminal && previous != fresh.state) return fresh;
      } catch (e) {
        lastError = e;
      }
      await Future<void>.delayed(delay);
    }
    // Last attempt — surface whatever we have (or rethrow).
    try {
      return await ref.refresh(contractDetailProvider(widget.address).future);
    } catch (e) {
      throw lastError ?? e;
    }
  }

  Future<void> _run(
    Future<TransactionResult> Function() action,
    String label,
    EscrowActionKind kind,
    EscrowState previousState,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
      _txHash = null;
      _txStatus = 'pending';
    });
    try {
      await ref.read(walletServiceProvider).ensureSepolia();
      // Repository also re-reads on-chain state before sending.
      final result = await action();
      setState(() {
        _txHash = result.txHash;
        _txStatus = result.status.name;
      });

      if (result.status == TxStatus.confirmed) {
        await _refreshUntilState(
          previous: previousState,
          expected: expectedStateAfter(kind),
        );
      } else if (result.status == TxStatus.pending) {
        // Receipt not seen yet — still force a read so UI is not stuck on a
        // stale snapshot forever; Actions stay disabled until finally.
        await ref.refresh(contractDetailProvider(widget.address).future);
      } else {
        await ref.refresh(contractDetailProvider(widget.address).future);
      }

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
      // Best-effort: pull latest chain view even after failure.
      try {
        await ref.refresh(contractDetailProvider(widget.address).future);
        ref.invalidate(myContractsProvider);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(contractDetailProvider(widget.address));
    final wallet = ref.watch(connectedAddressProvider);
    // While Riverpod reloads after invalidate/refresh it keeps prior data
    // (skipLoadingOnRefresh). Treat that as busy so Actions stay disabled.
    final refreshing = async.isLoading && async.hasValue;
    final actionsLocked = _busy || refreshing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escrow detail'),
        actions: [
          IconButton(
            tooltip: 'Refresh from chain',
            onPressed: actionsLocked
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref.refresh(
                        contractDetailProvider(widget.address).future,
                      );
                      ref.invalidate(myContractsProvider);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        // Prefer last known escrow while reloading so we don't flash a spinner
        // that re-enables stale Funded buttons via a different code path.
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('$e'),
          ),
        ),
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
              if (actionsLocked && !c.state.isTerminal) ...[
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
                Text(
                  _busy
                      ? 'Waiting for transaction / on-chain state…'
                      : 'Refreshing on-chain state…',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              EscrowActionBar(
                contract: c,
                walletAddress: wallet,
                busy: actionsLocked,
                onFund: () => _run(
                  () => ref.read(contractRepositoryProvider).fund(c.address),
                  'Fund',
                  EscrowActionKind.fund,
                  c.state,
                ),
                onRelease: () => _run(
                  () =>
                      ref.read(contractRepositoryProvider).release(c.address),
                  'Release',
                  EscrowActionKind.release,
                  c.state,
                ),
                onRefundBySeller: () => _run(
                  () => ref
                      .read(contractRepositoryProvider)
                      .refundBySeller(c.address),
                  'Refund',
                  EscrowActionKind.refundBySeller,
                  c.state,
                ),
                onRefundAfterDeadline: () => _run(
                  () => ref
                      .read(contractRepositoryProvider)
                      .refundAfterDeadline(c.address),
                  'Reclaim',
                  EscrowActionKind.refundAfterDeadline,
                  c.state,
                ),
              ),
              if (_txHash != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Last transaction',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
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
