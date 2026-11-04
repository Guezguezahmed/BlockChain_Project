/// Scratch-like plain-English block kinds for Escrow sur mesure.
///
/// Maps onto existing factory params only — not a Solidity generator.
enum EscrowBlockKind {
  /// Hat / start: "When buyer creates this deal"
  whenBuyerCreates,

  /// "Buyer is me" (caller becomes buyer on-chain)
  buyerIsMe,

  /// "Seller is [address]"
  sellerIs,

  /// "Lock [amount] ETH"
  lockAmount,

  /// "Deadline in [N] days"
  deadlineInDays,

  /// "Deadline on [date]"
  deadlineOnDate,

  /// Story / informational — matches real Escrow rules, not params
  buyerCanRelease,
  sellerCanRefund,
  buyerReclaimAfterDeadline,

  /// Palette stubs — never buildable
  rentalComingSoon,
  milestoneComingSoon,
}

enum EscrowBlockCategory {
  event,
  role,
  money,
  time,
  outcome,
  stub,
}

extension EscrowBlockKindX on EscrowBlockKind {
  EscrowBlockCategory get category {
    switch (this) {
      case EscrowBlockKind.whenBuyerCreates:
        return EscrowBlockCategory.event;
      case EscrowBlockKind.buyerIsMe:
      case EscrowBlockKind.sellerIs:
        return EscrowBlockCategory.role;
      case EscrowBlockKind.lockAmount:
        return EscrowBlockCategory.money;
      case EscrowBlockKind.deadlineInDays:
      case EscrowBlockKind.deadlineOnDate:
        return EscrowBlockCategory.time;
      case EscrowBlockKind.buyerCanRelease:
      case EscrowBlockKind.sellerCanRefund:
      case EscrowBlockKind.buyerReclaimAfterDeadline:
        return EscrowBlockCategory.outcome;
      case EscrowBlockKind.rentalComingSoon:
      case EscrowBlockKind.milestoneComingSoon:
        return EscrowBlockCategory.stub;
    }
  }

  /// Whether this kind can sit in a deployable Escrow stack.
  bool get isBuildable => category != EscrowBlockCategory.stub;

  /// Display-only story blocks — never map to factory params.
  bool get isStory => category == EscrowBlockCategory.outcome;

  /// Must be the first block in a valid stack.
  bool get isHat => this == EscrowBlockKind.whenBuyerCreates;

  String get paletteLabel {
    switch (this) {
      case EscrowBlockKind.whenBuyerCreates:
        return 'When buyer creates this deal';
      case EscrowBlockKind.buyerIsMe:
        return 'Buyer is me';
      case EscrowBlockKind.sellerIs:
        return 'Seller is …';
      case EscrowBlockKind.lockAmount:
        return 'Lock … ETH';
      case EscrowBlockKind.deadlineInDays:
        return 'Deadline in … days';
      case EscrowBlockKind.deadlineOnDate:
        return 'Deadline on …';
      case EscrowBlockKind.buyerCanRelease:
        return 'Buyer can release to seller';
      case EscrowBlockKind.sellerCanRefund:
        return 'Seller can refund';
      case EscrowBlockKind.buyerReclaimAfterDeadline:
        return 'After deadline buyer reclaim';
      case EscrowBlockKind.rentalComingSoon:
        return 'Rental — Coming soon';
      case EscrowBlockKind.milestoneComingSoon:
        return 'Milestone — Coming soon';
    }
  }
}

/// One placed (or palette) block instance with editable fields.
class EscrowBlock {
  EscrowBlock({
    required this.id,
    required this.kind,
    this.sellerAddress = '',
    this.amountEth = '0.1',
    this.deadlineDays = 7,
    DateTime? deadlineDate,
  }) : deadlineDate =
            deadlineDate ?? DateTime.now().toUtc().add(const Duration(days: 7));

  final String id;
  final EscrowBlockKind kind;
  final String sellerAddress;
  final String amountEth;
  final int deadlineDays;
  final DateTime deadlineDate;

  EscrowBlock copyWith({
    String? sellerAddress,
    String? amountEth,
    int? deadlineDays,
    DateTime? deadlineDate,
  }) {
    return EscrowBlock(
      id: id,
      kind: kind,
      sellerAddress: sellerAddress ?? this.sellerAddress,
      amountEth: amountEth ?? this.amountEth,
      deadlineDays: deadlineDays ?? this.deadlineDays,
      deadlineDate: deadlineDate ?? this.deadlineDate,
    );
  }

  /// Plain-English line shown on the puzzle piece.
  String get displayLabel {
    switch (kind) {
      case EscrowBlockKind.sellerIs:
        final a = sellerAddress.trim();
        if (a.isEmpty) return 'Seller is [address]';
        if (a.length <= 12) return 'Seller is $a';
        return 'Seller is ${a.substring(0, 6)}…${a.substring(a.length - 4)}';
      case EscrowBlockKind.lockAmount:
        final amt = amountEth.trim().isEmpty ? '…' : amountEth.trim();
        return 'Lock $amt ETH';
      case EscrowBlockKind.deadlineInDays:
        return 'Deadline in $deadlineDays days';
      case EscrowBlockKind.deadlineOnDate:
        final local = deadlineDate.toLocal();
        final y = local.year.toString().padLeft(4, '0');
        final m = local.month.toString().padLeft(2, '0');
        final d = local.day.toString().padLeft(2, '0');
        return 'Deadline on $y-$m-$d';
      default:
        return kind.paletteLabel;
    }
  }
}

/// Catalog shown in the left/bottom palette.
List<EscrowBlockKind> get escrowPaletteKinds => const [
      EscrowBlockKind.whenBuyerCreates,
      EscrowBlockKind.buyerIsMe,
      EscrowBlockKind.sellerIs,
      EscrowBlockKind.lockAmount,
      EscrowBlockKind.deadlineInDays,
      EscrowBlockKind.deadlineOnDate,
      EscrowBlockKind.buyerCanRelease,
      EscrowBlockKind.sellerCanRefund,
      EscrowBlockKind.buyerReclaimAfterDeadline,
      EscrowBlockKind.rentalComingSoon,
      EscrowBlockKind.milestoneComingSoon,
    ];
