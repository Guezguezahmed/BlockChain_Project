import 'package:blockchain_app/data/repositories/mock_contract_repository.dart';
import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/domain/models/escrow_contract.dart';
import 'package:blockchain_app/domain/models/escrow_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockWalletService wallet;
  late MockContractRepository repo;

  setUp(() async {
    wallet = MockWalletService();
    await wallet.connect();
    repo = MockContractRepository(txSender: wallet);
  });

  tearDown(() => wallet.dispose());

  test('create → fund → release happy path', () async {
    final created = await repo.createEscrow(
      CreateEscrowParams(
        seller: '0x2222222222222222222222222222222222222222',
        amountWei: BigInt.from(10).pow(17),
        deadline: DateTime.now().toUtc().add(const Duration(days: 3)),
      ),
    );
    expect(created.contractAddress, isNotNull);

    var c = await repo.getContract(created.contractAddress!);
    expect(c.state, EscrowState.created);
    expect(c.buyer.toLowerCase(), wallet.mockAddress.toLowerCase());

    await repo.fund(c.address);
    c = await repo.getContract(c.address);
    expect(c.state, EscrowState.funded);

    await repo.release(c.address);
    c = await repo.getContract(c.address);
    expect(c.state, EscrowState.released);
  });

  test('seller can refund while funded', () async {
    final buyerWallet = MockWalletService();
    await buyerWallet.connect();
    final buyerRepo = MockContractRepository(txSender: buyerWallet);
    final created = await buyerRepo.createEscrow(
      CreateEscrowParams(
        seller: '0x3333333333333333333333333333333333333333',
        amountWei: BigInt.from(10).pow(16),
        deadline: DateTime.now().toUtc().add(const Duration(days: 1)),
      ),
    );
    await buyerRepo.fund(created.contractAddress!);

    final sellerWallet = MockWalletService(
      mockAddress: '0x3333333333333333333333333333333333333333',
    );
    await sellerWallet.connect();
    // Reuse same in-memory store by acting through buyerRepo with swapped sender —
    // instead, mutate via a shared pattern: use buyerRepo but call refund with seller
    // by constructing a second repo that points at a copy. For mock, simplest:
    // expose refund via a repo that uses seller as txSender against same map is hard.
    // So: transfer ownership of map by funding then using seller-connected service
    // on the same repository instance after swapping tx sender is not supported.
    // Create dedicated flow on one repo where seller address equals connected after reconnect.
    buyerWallet.dispose();

    // Dedicated single-repo flow: create as buyer, then simulate seller via new repo seed.
    final shared = MockContractRepository(txSender: sellerWallet);
    shared.seedDemo(
      buyer: '0x1111111111111111111111111111111111111111',
      seller: sellerWallet.mockAddress,
    );
    final funded = (await shared.getContractsByUser(sellerWallet.mockAddress))
        .firstWhere((e) => e.state == EscrowState.funded);
    await shared.refundBySeller(funded.address);
    final after = await shared.getContract(funded.address);
    expect(after.state, EscrowState.refunded);

    sellerWallet.dispose();
  });

  test('getContractsByUser filters buyer/seller', () async {
    repo.seedDemo(
      buyer: wallet.mockAddress,
      seller: '0x2222222222222222222222222222222222222222',
    );
    final mine = await repo.getContractsByUser(wallet.mockAddress);
    expect(mine.length, greaterThanOrEqualTo(2));
  });
}
