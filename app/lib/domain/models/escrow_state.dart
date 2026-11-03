/// Mirrors `IEscrow.State` in `contracts/interfaces/IContracts.sol`.
enum EscrowState {
  created(0),
  funded(1),
  released(2),
  refunded(3);

  const EscrowState(this.onChainValue);
  final int onChainValue;

  static EscrowState fromOnChain(int value) {
    return EscrowState.values.firstWhere(
      (e) => e.onChainValue == value,
      orElse: () => throw ArgumentError('Unknown EscrowState: $value'),
    );
  }

  String get label {
    switch (this) {
      case EscrowState.created:
        return 'Created';
      case EscrowState.funded:
        return 'Funded';
      case EscrowState.released:
        return 'Released';
      case EscrowState.refunded:
        return 'Refunded';
    }
  }

  bool get isTerminal =>
      this == EscrowState.released || this == EscrowState.refunded;
}
