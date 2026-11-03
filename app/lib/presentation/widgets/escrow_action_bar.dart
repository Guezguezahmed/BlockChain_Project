import 'package:flutter/material.dart';

import '../../domain/models/escrow_actions.dart';
import '../../domain/models/escrow_contract.dart';

/// State- and role-aware action buttons (AGENTS.md §5).
class EscrowActionBar extends StatelessWidget {
  const EscrowActionBar({
    super.key,
    required this.contract,
    required this.walletAddress,
    required this.busy,
    required this.onFund,
    required this.onRelease,
    required this.onRefundBySeller,
    required this.onRefundAfterDeadline,
    this.nowUtc,
  });

  final EscrowContract contract;
  final String? walletAddress;
  final bool busy;
  final VoidCallback onFund;
  final VoidCallback onRelease;
  final VoidCallback onRefundBySeller;
  final VoidCallback onRefundAfterDeadline;

  /// Injectable clock for tests (deadline reclaim).
  final DateTime? nowUtc;

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      return const Text('Connect a wallet to act on this contract.');
    }
    if (contract.state.isTerminal) {
      return Text(
        'No further actions — this escrow is ${contract.state.label} (final).',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final actions = availableEscrowActions(
      contract: contract,
      walletAddress: walletAddress,
      nowUtc: nowUtc,
    );

    if (actions.isEmpty) {
      final isBuyer = contract.isBuyerOf(walletAddress);
      final isSeller = contract.isSellerOf(walletAddress);
      final role = isBuyer
          ? 'buyer'
          : isSeller
              ? 'seller'
              : 'neither party';
      return Text(
        'No actions available for you as $role in state ${contract.state.label}.',
      );
    }

    final buttons = <Widget>[];
    for (final action in actions) {
      switch (action) {
        case EscrowActionKind.fund:
          buttons.add(
            FilledButton(
              onPressed: busy ? null : onFund,
              child: const Text('Deposit (fund)'),
            ),
          );
        case EscrowActionKind.release:
          buttons.add(
            FilledButton(
              onPressed: busy ? null : onRelease,
              child: const Text('Release to seller'),
            ),
          );
        case EscrowActionKind.refundAfterDeadline:
          buttons.add(
            OutlinedButton(
              onPressed: busy ? null : onRefundAfterDeadline,
              child: const Text('Reclaim after deadline'),
            ),
          );
        case EscrowActionKind.refundBySeller:
          buttons.add(
            OutlinedButton(
              onPressed: busy ? null : onRefundBySeller,
              child: const Text('Refund buyer'),
            ),
          );
      }
    }

    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }
}
