/// Runtime configuration via `--dart-define` (never commit secrets).
///
/// Live Sepolia [ContractFactory] is the default [factoryAddress]. Mock mode
/// stays the default so UI work does not need Reown credentials. For chain
/// mode you must pass `USE_MOCK=false` and a Reown project id from
/// https://cloud.reown.com (never invent one).
///
/// Example (Sepolia + MetaMask):
/// ```bash
/// flutter run -d macos \
///   --dart-define=USE_MOCK=false \
///   --dart-define=FACTORY_ADDRESS=0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08 \
///   --dart-define=SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY \
///   --dart-define=WALLETCONNECT_PROJECT_ID=your_reown_project_id
/// ```
class AppConfig {
  const AppConfig._();

  /// When true (default), the app uses [MockContractRepository] and a mock
  /// wallet so UI can be developed without Sepolia or Reown credentials.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// Live Sepolia ContractFactory (public address — safe to commit).
  /// Override with `--dart-define=FACTORY_ADDRESS=0x...` only if redeployed.
  static const String factoryAddress = String.fromEnvironment(
    'FACTORY_ADDRESS',
    defaultValue: '0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08',
  );

  /// Live Sepolia Escrow implementation used by the factory (reference only;
  /// clones are created via the factory — the app talks to clone addresses).
  static const String escrowImplementationAddress =
      '0x4bb80444D6669588F7bf1ed6b0EFE71B7Aacf25E';

  /// Sepolia JSON-RPC URL (public or Infura/Alchemy). Prefer Alchemy Sepolia
  /// when you have a key; do not commit the key.
  static const String sepoliaRpcUrl = String.fromEnvironment(
    'SEPOLIA_RPC_URL',
    defaultValue: 'https://rpc.sepolia.org',
  );

  /// Reown / WalletConnect Cloud project id (required when [useMock] is false).
  /// Create at https://cloud.reown.com — never invent or commit a real id.
  static const String walletConnectProjectId = String.fromEnvironment(
    'WALLETCONNECT_PROJECT_ID',
    defaultValue: '',
  );

  static const int sepoliaChainId = 11155111;
  static const String sepoliaChainIdCaip2 = 'eip155:11155111';
  static const String etherscanBaseUrl = 'https://sepolia.etherscan.io';
  static const String networkName = 'Sepolia';

  static bool get hasFactoryAddress =>
      factoryAddress.isNotEmpty && factoryAddress.startsWith('0x');

  static bool get hasWalletConnectProjectId =>
      walletConnectProjectId.isNotEmpty;

  static String etherscanAddressUrl(String address) =>
      '$etherscanBaseUrl/address/$address';

  static String etherscanTxUrl(String txHash) =>
      '$etherscanBaseUrl/tx/$txHash';
}
