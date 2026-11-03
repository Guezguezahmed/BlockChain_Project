import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../data/repositories/chain_contract_repository.dart';
import '../../data/repositories/mock_contract_repository.dart';
import '../../data/wallet/mock_wallet_service.dart';
import '../../data/wallet/reown_wallet_service.dart';
import '../../domain/models/escrow_contract.dart';
import '../../domain/repositories/contract_repository.dart';
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

class AppDependencies {
  AppDependencies({
    required this.wallet,
    required this.txSender,
    required this.repository,
    required this.dispose,
    this.reown,
  });

  final WalletService wallet;
  final ChainTxSender txSender;
  final ContractRepository repository;
  final ReownWalletService? reown;
  final void Function() dispose;

  List<Override> get overrides => [
        walletServiceProvider.overrideWithValue(wallet),
        chainTxSenderProvider.overrideWithValue(txSender),
        contractRepositoryProvider.overrideWithValue(repository),
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
    return AppDependencies(
      wallet: wallet,
      txSender: wallet,
      repository: repo,
      dispose: wallet.dispose,
    );
  }

  final reown = ReownWalletService();
  if (!AppConfig.hasFactoryAddress) {
    // Still construct a chain repo so the UI can show a clear config error;
    // calls will throw with a helpful message.
  }
  final repo = ChainContractRepository(
    factoryAddress: AppConfig.factoryAddress.isEmpty
        ? '0x0000000000000000000000000000000000000000'
        : AppConfig.factoryAddress,
    rpcUrl: AppConfig.sepoliaRpcUrl,
    txSender: reown,
  );
  return AppDependencies(
    wallet: reown,
    txSender: reown,
    repository: repo,
    reown: reown,
    dispose: () {
      repo.dispose();
      reown.dispose();
    },
  );
}
