/// Runtime configuration via `--dart-define` (never commit secrets).
///
/// After Sepolia deploy, set `FACTORY_ADDRESS` to the printed ContractFactory
/// address. Get a free WalletConnect/Reown project id at https://cloud.reown.com
///
/// Example:
/// ```bash
/// flutter run -d chrome \
///   --dart-define=USE_MOCK=false \
///   --dart-define=FACTORY_ADDRESS=0xYourFactory \
///   --dart-define=SEPOLIA_RPC_URL=https://rpc.sepolia.org \
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

  /// ContractFactory address on Sepolia. Empty until you deploy — do not invent.
  static const String factoryAddress = String.fromEnvironment(
    'FACTORY_ADDRESS',
    defaultValue: '',
  );

  /// Sepolia JSON-RPC URL (public or Infura/Alchemy).
  static const String sepoliaRpcUrl = String.fromEnvironment(
    'SEPOLIA_RPC_URL',
    defaultValue: 'https://rpc.sepolia.org',
  );

  /// Reown / WalletConnect Cloud project id (required when [useMock] is false).
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
