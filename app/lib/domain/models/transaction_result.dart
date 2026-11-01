/// Result of a state-changing on-chain action.
class TransactionResult {
  const TransactionResult({
    required this.txHash,
    this.contractAddress,
    this.status = TxStatus.pending,
  });

  final String txHash;
  final String? contractAddress;
  final TxStatus status;

  TransactionResult copyWith({
    String? txHash,
    String? contractAddress,
    TxStatus? status,
  }) {
    return TransactionResult(
      txHash: txHash ?? this.txHash,
      contractAddress: contractAddress ?? this.contractAddress,
      status: status ?? this.status,
    );
  }
}

enum TxStatus { pending, confirmed, failed }
