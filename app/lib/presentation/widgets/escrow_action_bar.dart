import 'package:flutter/material.dart';

import '../../domain/models/escrow_contract.dart';
import '../../domain/models/escrow_state.dart';

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
  });

  final EscrowContract contract;
  final String? walletAddress;
  final bool busy;
  final VoidCallback onFund;
  final VoidCallback onRelease;
  final VoidCallback onRefundBySeller;
  final VoidCallback onRefundAfterDeadline;

  @override
  Widget build(BuildContext context) {
    if (walletAddress == null) {
      return const Text('Connect a wallet to act on this contract.');
    }
    if (contract.state.isTerminal) {
      return Text(
        'This escrow is ${contract.state.label.toLowerCase()} (final).',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final isBuyer = contract.isBuyerOf(walletAddress);
    final isSeller = contract.isSellerOf(walletAddress);
    final deadlinePassed =
        DateTime.now().toUtc().isAfter(contract.deadline) ||
            DateTime.now().toUtc().isAtSameMomentAs(contract.deadline);

    final buttons = <Widget>[];

    if (contract.state == EscrowState.created && isBuyer) {
      buttons.add(
        FilledButton(
          onPressed: busy ? null : onFund,
          child: const Text('Deposit (fund)'),
        ),
      );
    }

    if (contract.state == EscrowState.funded && isBuyer) {
      buttons.add(
        FilledButton(
          onPressed: busy ? null : onRelease,
          child: const Text('Release to seller'),
        ),
      );
      if (deadlinePassed) {
        buttons.add(
          OutlinedButton(
            onPressed: busy ? null : onRefundAfterDeadline,
            child: const Text('Reclaim after deadline'),
          ),
        );
      }
    }

    if (contract.state == EscrowState.funded && isSeller) {
      buttons.add(
        OutlinedButton(
          onPressed: busy ? null : onRefundBySeller,
          child: const Text('Refund buyer'),
        ),
      );
    }

    if (buttons.isEmpty) {
      final role = isBuyer
          ? 'buyer'
          : isSeller
              ? 'seller'
              : 'neither party';
      return Text(
        'No actions available for you as $role in state ${contract.state.label}.',
      );
    }

    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }
}
