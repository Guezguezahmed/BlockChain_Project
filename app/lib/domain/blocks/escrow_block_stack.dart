import '../models/escrow_contract.dart';
import '../utils/eth_formatting.dart';
import 'escrow_block.dart';

/// Why a block was rejected from the stack (gentle UX feedback).
enum BlockRejectReason {
  comingSoon,
  needsStartFirst,
  duplicateStart,
  duplicateBuyer,
  duplicateSeller,
  duplicateAmount,
  duplicateDeadline,
  duplicateStory,
  invalidAtEnd,
}

extension BlockRejectReasonX on BlockRejectReason {
  String get message {
    switch (this) {
      case BlockRejectReason.comingSoon:
        return 'Coming soon — not buildable yet';
      case BlockRejectReason.needsStartFirst:
        return 'Start with “When buyer creates this deal”';
      case BlockRejectReason.duplicateStart:
        return 'Only one start block';
      case BlockRejectReason.duplicateBuyer:
        return 'Buyer is already set';
      case BlockRejectReason.duplicateSeller:
        return 'Seller is already set';
      case BlockRejectReason.duplicateAmount:
        return 'Amount is already set';
      case BlockRejectReason.duplicateDeadline:
        return 'Deadline is already set';
      case BlockRejectReason.duplicateStory:
        return 'That rule is already in the stack';
      case BlockRejectReason.invalidAtEnd:
        return 'That block doesn’t fit here';
    }
  }
}

/// Result of trying to append a block to the workspace stack.
class BlockSnapResult {
  const BlockSnapResult.accept()
      : accepted = true,
        reason = null;

  const BlockSnapResult.reject(this.reason) : accepted = false;

  final bool accepted;
  final BlockRejectReason? reason;
}

/// Validates Scratch stacks and maps them onto [CreateEscrowParams].
class EscrowBlockStack {
  EscrowBlockStack(List<EscrowBlock> blocks) : blocks = List.unmodifiable(blocks);

  final List<EscrowBlock> blocks;

  bool get isEmpty => blocks.isEmpty;

  bool get hasStart =>
      blocks.isNotEmpty && blocks.first.kind == EscrowBlockKind.whenBuyerCreates;

  EscrowBlock? get _seller =>
      _firstOf(EscrowBlockKind.sellerIs);

  EscrowBlock? get _amount =>
      _firstOf(EscrowBlockKind.lockAmount);

  EscrowBlock? get _deadlineDays =>
      _firstOf(EscrowBlockKind.deadlineInDays);

  EscrowBlock? get _deadlineDate =>
      _firstOf(EscrowBlockKind.deadlineOnDate);

  EscrowBlock? _firstOf(EscrowBlockKind kind) {
    for (final b in blocks) {
      if (b.kind == kind) return b;
    }
    return null;
  }

  bool _has(EscrowBlockKind kind) => _firstOf(kind) != null;

  /// Can this kind snap onto the current stack?
  BlockSnapResult canAccept(EscrowBlockKind kind) {
    if (!kind.isBuildable) {
      return const BlockSnapResult.reject(BlockRejectReason.comingSoon);
    }

    if (kind == EscrowBlockKind.whenBuyerCreates) {
      if (hasStart) {
        return const BlockSnapResult.reject(BlockRejectReason.duplicateStart);
      }
      if (blocks.isNotEmpty) {
        return const BlockSnapResult.reject(BlockRejectReason.needsStartFirst);
      }
      return const BlockSnapResult.accept();
    }

    if (!hasStart) {
      return const BlockSnapResult.reject(BlockRejectReason.needsStartFirst);
    }

    switch (kind) {
      case EscrowBlockKind.buyerIsMe:
        if (_has(EscrowBlockKind.buyerIsMe)) {
          return const BlockSnapResult.reject(BlockRejectReason.duplicateBuyer);
        }
        return const BlockSnapResult.accept();
      case EscrowBlockKind.sellerIs:
        if (_has(EscrowBlockKind.sellerIs)) {
          return const BlockSnapResult.reject(BlockRejectReason.duplicateSeller);
        }
        return const BlockSnapResult.accept();
      case EscrowBlockKind.lockAmount:
        if (_has(EscrowBlockKind.lockAmount)) {
          return const BlockSnapResult.reject(BlockRejectReason.duplicateAmount);
        }
        return const BlockSnapResult.accept();
      case EscrowBlockKind.deadlineInDays:
      case EscrowBlockKind.deadlineOnDate:
        if (_has(EscrowBlockKind.deadlineInDays) ||
            _has(EscrowBlockKind.deadlineOnDate)) {
          return const BlockSnapResult.reject(
            BlockRejectReason.duplicateDeadline,
          );
        }
        return const BlockSnapResult.accept();
      case EscrowBlockKind.buyerCanRelease:
      case EscrowBlockKind.sellerCanRefund:
      case EscrowBlockKind.buyerReclaimAfterDeadline:
        if (_has(kind)) {
          return const BlockSnapResult.reject(BlockRejectReason.duplicateStory);
        }
        return const BlockSnapResult.accept();
      case EscrowBlockKind.whenBuyerCreates:
      case EscrowBlockKind.rentalComingSoon:
      case EscrowBlockKind.milestoneComingSoon:
        return const BlockSnapResult.reject(BlockRejectReason.invalidAtEnd);
    }
  }

  /// Missing pieces before Deploy can enable (human-readable).
  List<String> get missingRequirements {
    final missing = <String>[];
    if (!hasStart) missing.add('Start: When buyer creates this deal');
    if (!_has(EscrowBlockKind.buyerIsMe)) missing.add('Buyer is me');
    if (!_has(EscrowBlockKind.sellerIs)) missing.add('Seller address');
    if (!_has(EscrowBlockKind.lockAmount)) missing.add('Lock amount');
    if (!_has(EscrowBlockKind.deadlineInDays) &&
        !_has(EscrowBlockKind.deadlineOnDate)) {
      missing.add('Deadline');
    }
    return missing;
  }

  /// Field-level issues on otherwise present blocks.
  List<String> fieldErrors({
    String? connectedBuyer,
    DateTime? nowUtc,
  }) {
    final now = nowUtc ?? DateTime.now().toUtc();
    final errors = <String>[];

    final seller = _seller;
    if (seller != null) {
      final addr = seller.sellerAddress.trim();
      if (addr.isEmpty || !isValidEthereumAddress(addr)) {
        errors.add('Enter a valid seller address');
      } else if (connectedBuyer != null &&
          addr.toLowerCase() == connectedBuyer.toLowerCase()) {
        errors.add('Seller must differ from buyer (you)');
      }
    }

    final amount = _amount;
    if (amount != null) {
      final wei = tryParseEthToWei(amount.amountEth);
      if (wei == null || wei <= BigInt.zero) {
        errors.add('Enter a positive ETH amount');
      }
    }

    if (_deadlineDays != null) {
      final days = _deadlineDays!.deadlineDays;
      if (days < 1) {
        errors.add('Deadline must be at least 1 day');
      }
    }

    if (_deadlineDate != null) {
      if (!_deadlineDate!.deadlineDate.isAfter(now)) {
        errors.add('Deadline must be in the future');
      }
    }

    return errors;
  }

  /// True when structure + fields are ready to map → Deploy.
  bool isValidForDeploy({
    String? connectedBuyer,
    DateTime? nowUtc,
  }) {
    return missingRequirements.isEmpty &&
        fieldErrors(connectedBuyer: connectedBuyer, nowUtc: nowUtc).isEmpty;
  }

  /// Maps a valid stack onto factory `createEscrow` params.
  ///
  /// Throws [StateError] if the stack is not deployable — call
  /// [isValidForDeploy] first in UI code.
  CreateEscrowParams toCreateParams({
    String? connectedBuyer,
    DateTime? nowUtc,
  }) {
    final now = nowUtc ?? DateTime.now().toUtc();
    if (!isValidForDeploy(connectedBuyer: connectedBuyer, nowUtc: now)) {
      throw StateError(
        'Stack is not ready to deploy: '
        '${[...missingRequirements, ...fieldErrors(connectedBuyer: connectedBuyer, nowUtc: now)].join('; ')}',
      );
    }

    final seller = checksumAddress(_seller!.sellerAddress);
    final amountWei = tryParseEthToWei(_amount!.amountEth)!;

    final DateTime deadline;
    if (_deadlineDays != null) {
      deadline = now.add(Duration(days: _deadlineDays!.deadlineDays));
    } else {
      deadline = _deadlineDate!.deadlineDate.toUtc();
    }

    return CreateEscrowParams(
      seller: seller,
      amountWei: amountWei,
      deadline: deadline,
    );
  }
}
