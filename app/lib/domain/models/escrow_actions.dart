import 'escrow_contract.dart';
import 'escrow_state.dart';

/// Money-moving actions the connected wallet may take on an escrow.
enum EscrowActionKind {
  fund,
  release,
  refundBySeller,
  refundAfterDeadline,
}

/// Pure rules for which Actions buttons to show (AGENTS.md §5 / Escrow state machine).
///
/// Terminal states ([EscrowState.released], [EscrowState.refunded]) never yield
/// money-moving actions — callers should show a read-only message instead.
List<EscrowActionKind> availableEscrowActions({
  required EscrowContract contract,
  required String? walletAddress,
  DateTime? nowUtc,
}) {
  if (walletAddress == null) return const [];
  if (contract.state.isTerminal) return const [];

  final isBuyer = contract.isBuyerOf(walletAddress);
  final isSeller = contract.isSellerOf(walletAddress);
  final now = nowUtc ?? DateTime.now().toUtc();
  final deadlinePassed =
      !now.isBefore(contract.deadline); // now >= deadline

  final out = <EscrowActionKind>[];

  if (contract.state == EscrowState.created && isBuyer) {
    out.add(EscrowActionKind.fund);
  }

  if (contract.state == EscrowState.funded && isBuyer) {
    out.add(EscrowActionKind.release);
    if (deadlinePassed) {
      out.add(EscrowActionKind.refundAfterDeadline);
    }
  }

  if (contract.state == EscrowState.funded && isSeller) {
    out.add(EscrowActionKind.refundBySeller);
  }

  return out;
}

/// Expected on-chain state after a successful money-moving action.
EscrowState? expectedStateAfter(EscrowActionKind action) {
  switch (action) {
    case EscrowActionKind.fund:
      return EscrowState.funded;
    case EscrowActionKind.release:
      return EscrowState.released;
    case EscrowActionKind.refundBySeller:
    case EscrowActionKind.refundAfterDeadline:
      return EscrowState.refunded;
  }
}
