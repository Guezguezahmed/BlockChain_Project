/// Mirrors `TemplateType` in `contracts/interfaces/IContracts.sol`.
enum TemplateType {
  escrow(0),
  rental(1),
  milestone(2);

  const TemplateType(this.onChainValue);
  final int onChainValue;

  static TemplateType fromOnChain(int value) {
    return TemplateType.values.firstWhere(
      (e) => e.onChainValue == value,
      orElse: () => throw ArgumentError('Unknown TemplateType: $value'),
    );
  }

  String get label {
    switch (this) {
      case TemplateType.escrow:
        return 'Escrow';
      case TemplateType.rental:
        return 'Rental';
      case TemplateType.milestone:
        return 'Milestone';
    }
  }
}
