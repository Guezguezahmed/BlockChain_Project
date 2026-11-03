/// Connected wallet snapshot (never holds private keys).
class WalletSession {
  const WalletSession({
    required this.address,
    required this.chainId,
    this.isMock = false,
  });

  final String address;
  final int chainId;
  final bool isMock;

  bool get isSepolia => chainId == 11155111;

  String get shortAddress {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
  }
}

/// Wallet connect / disconnect / switch-network. Screens use this only for
/// wallet UX; contract reads/writes go through [ContractRepository].
abstract class WalletService {
  Stream<WalletSession?> get sessionChanges;
  WalletSession? get currentSession;
  bool get isConnected => currentSession != null;

  /// Opens the connect flow (Reown modal, or mock auto-connect).
  Future<void> connect();

  Future<void> disconnect();

  /// Prompt wallet to switch to Sepolia when on the wrong chain.
  Future<void> ensureSepolia();
}

/// Sends a raw EVM transaction (used by [ChainContractRepository]).
abstract class ChainTxSender {
  String? get fromAddress;

  Future<String> sendTransaction({
    required String to,
    required String dataHex,
    BigInt? valueWei,
  });
}
