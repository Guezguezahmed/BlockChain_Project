/// Runtime configuration via `--dart-define` (never commit secrets).
///
/// Live Sepolia Smart Deal marketplace is the primary product surface.
/// Factory / Escrow remain wired for the advanced custom-escrow path.
/// Mock mode stays the default so UI work does not need Reown credentials.
///
/// Example (Sepolia + MetaMask on Chrome):
/// ```bash
/// flutter run -d chrome \
///   --dart-define=USE_MOCK=false \
///   --dart-define=SDT_ADDRESS=0x6dBA1A76E8fAF697b8E4392b565021fd0038C0Ab \
///   --dart-define=NFT_ADDRESS=0x14D7811438c6638096BfefB029A22CBeAEF86F57 \
///   --dart-define=MARKETPLACE_ADDRESS=0x910e480723a0Ed7bf7f22d5e01CcF8db2E2fA97B \
///   --dart-define=SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY \
///   --dart-define=WALLETCONNECT_PROJECT_ID=your_reown_project_id
/// ```
class AppConfig {
  const AppConfig._();

  /// When true (default), the app uses mock repositories and a mock wallet.
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  /// Live Sepolia ContractFactory (escrow advanced path).
  static const String factoryAddress = String.fromEnvironment(
    'FACTORY_ADDRESS',
    defaultValue: '0x0E847b5Dccd09e73199e3689fC4D0D25A0133F08',
  );

  /// Live Sepolia Escrow implementation (reference only).
  static const String escrowImplementationAddress =
      '0x4bb80444D6669588F7bf1ed6b0EFE71B7Aacf25E';

  /// Live Sepolia Smart Deal Token (SDT).
  static const String sdtAddress = String.fromEnvironment(
    'SDT_ADDRESS',
    defaultValue: '0x6dBA1A76E8fAF697b8E4392b565021fd0038C0Ab',
  );

  /// Live Sepolia SmartDealNFT collection.
  static const String nftAddress = String.fromEnvironment(
    'NFT_ADDRESS',
    defaultValue: '0x14D7811438c6638096BfefB029A22CBeAEF86F57',
  );

  /// Live Sepolia Marketplace.
  static const String marketplaceAddress = String.fromEnvironment(
    'MARKETPLACE_ADDRESS',
    defaultValue: '0x910e480723a0Ed7bf7f22d5e01CcF8db2E2fA97B',
  );

  /// Deployer that holds the demo SDT supply (faucet note for sellers).
  static const String sdtDeployerAddress =
      '0x41362C8936Cce0587e7C431877148DBDb23df399';

  /// Marketplace params as deployed (human-readable for UI copy).
  static const String listingFeeSdtLabel = '10 SDT';
  static const String sellerStakeSdtLabel = '50 SDT';
  static const String discountHoldSdtLabel = '100 SDT';
  static const String feeDiscountLabel = '50%';

  /// Sepolia JSON-RPC URL (public or Infura/Alchemy). Prefer Alchemy Sepolia
  /// when you have a key; do not commit the key.
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
  static const String brandName = 'Smart Deal';

  static bool get hasFactoryAddress =>
      factoryAddress.isNotEmpty && factoryAddress.startsWith('0x');

  static bool get hasMarketplaceAddress =>
      marketplaceAddress.isNotEmpty && marketplaceAddress.startsWith('0x');

  static bool get hasWalletConnectProjectId =>
      walletConnectProjectId.isNotEmpty;

  static String etherscanAddressUrl(String address) =>
      '$etherscanBaseUrl/address/$address';

  static String etherscanTxUrl(String txHash) =>
      '$etherscanBaseUrl/tx/$txHash';
}
