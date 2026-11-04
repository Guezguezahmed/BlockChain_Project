import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/repositories/chain_contract_repository.dart';
import '../../data/repositories/chain_marketplace_repository.dart';
import '../../data/repositories/mock_contract_repository.dart';
import '../../data/repositories/mock_marketplace_repository.dart';
import '../../data/wallet/mock_wallet_service.dart';
import '../../data/wallet/reown_wallet_service.dart';
import '../../domain/models/escrow_contract.dart';
import '../../domain/models/marketplace_listing.dart';
import '../../domain/repositories/contract_repository.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../domain/wallet/wallet_session.dart';

final walletServiceProvider = Provider<WalletService>((ref) {
  throw UnimplementedError('Override walletServiceProvider in main()');
});

final chainTxSenderProvider = Provider<ChainTxSender>((ref) {
  throw UnimplementedError('Override chainTxSenderProvider in main()');
});

final walletSessionProvider = StreamProvider<WalletSession?>((ref) {
  return ref.watch(walletServiceProvider).sessionChanges;
});

final connectedAddressProvider = Provider<String?>((ref) {
  final async = ref.watch(walletSessionProvider);
  return async.asData?.value?.address ??
      ref.watch(walletServiceProvider).currentSession?.address;
});

final contractRepositoryProvider = Provider<ContractRepository>((ref) {
  throw UnimplementedError('Override contractRepositoryProvider in main()');
});

final marketplaceRepositoryProvider = Provider<MarketplaceRepository>((ref) {
  throw UnimplementedError('Override marketplaceRepositoryProvider in main()');
});

final myContractsProvider =
    FutureProvider.autoDispose<List<EscrowContract>>((ref) async {
  final address = ref.watch(connectedAddressProvider);
  if (address == null) return const [];
  return ref.watch(contractRepositoryProvider).getContractsByUser(address);
});

final contractDetailProvider =
    FutureProvider.autoDispose.family<EscrowContract, String>((ref, address) {
  return ref.watch(contractRepositoryProvider).getContract(address);
});

final marketplaceListingsProvider =
    FutureProvider.autoDispose<List<MarketplaceListing>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).getListings(activeOnly: true);
});

final listingDetailProvider =
    FutureProvider.autoDispose.family<MarketplaceListing, BigInt>((ref, id) {
  return ref.watch(marketplaceRepositoryProvider).getListing(id);
});

final sdtInfoProvider =
    FutureProvider.autoDispose<SdtMarketInfo?>((ref) async {
  final address = ref.watch(connectedAddressProvider);
  if (address == null) return null;
  return ref.watch(marketplaceRepositoryProvider).getSdtInfo(address);
});

final ownedNftsProvider =
    FutureProvider.autoDispose<List<BigInt>>((ref) async {
  final address = ref.watch(connectedAddressProvider);
  if (address == null) return const [];
  return ref.watch(marketplaceRepositoryProvider).getOwnedTokenIds(address);
});

final myListingsProvider =
    FutureProvider.autoDispose<List<MarketplaceListing>>((ref) async {
  final address = ref.watch(connectedAddressProvider);
  if (address == null) return const [];
  final all = await ref
      .watch(marketplaceRepositoryProvider)
      .getListings(activeOnly: false);
  final want = address.toLowerCase();
  return all
      .where((l) => l.seller.toLowerCase() == want)
      .toList()
    ..sort((a, b) => b.id.compareTo(a.id));
});

final tokenUriProvider =
    FutureProvider.autoDispose.family<String?, BigInt>((ref, tokenId) {
  return ref.watch(marketplaceRepositoryProvider).tokenUri(tokenId);
});

class AppDependencies {
  AppDependencies({
    required this.wallet,
    required this.txSender,
    required this.repository,
    required this.marketplace,
    required this.dispose,
    this.reown,
  });

  final WalletService wallet;
  final ChainTxSender txSender;
  final ContractRepository repository;
  final MarketplaceRepository marketplace;
  final ReownWalletService? reown;
  final void Function() dispose;

  List<Override> get overrides => [
        walletServiceProvider.overrideWithValue(wallet),
        chainTxSenderProvider.overrideWithValue(txSender),
        contractRepositoryProvider.overrideWithValue(repository),
        marketplaceRepositoryProvider.overrideWithValue(marketplace),
      ];
}

/// Builds mock or Sepolia/Reown wiring from [AppConfig].
AppDependencies createAppDependencies() {
  if (AppConfig.useMock) {
    final wallet = MockWalletService();
    final repo = MockContractRepository(txSender: wallet)
      ..seedDemo(
        buyer: wallet.mockAddress,
        seller: '0x2222222222222222222222222222222222222222',
      );
    final market = MockMarketplaceRepository(txSender: wallet);
    return AppDependencies(
      wallet: wallet,
      txSender: wallet,
      repository: repo,
      marketplace: market,
      dispose: wallet.dispose,
    );
  }

  final reown = ReownWalletService();
  final repo = ChainContractRepository(
    factoryAddress: AppConfig.factoryAddress.isEmpty
        ? '0x0000000000000000000000000000000000000000'
        : AppConfig.factoryAddress,
    rpcUrl: AppConfig.sepoliaRpcUrl,
    txSender: reown,
  );
  final market = ChainMarketplaceRepository(
    marketplaceAddress: AppConfig.marketplaceAddress,
    sdtAddress: AppConfig.sdtAddress,
    nftAddress: AppConfig.nftAddress,
    rpcUrl: AppConfig.sepoliaRpcUrl,
    txSender: reown,
  );
  return AppDependencies(
    wallet: reown,
    txSender: reown,
    repository: repo,
    marketplace: market,
    reown: reown,
    dispose: () {
      repo.dispose();
      market.dispose();
      reown.dispose();
    },
  );
}
