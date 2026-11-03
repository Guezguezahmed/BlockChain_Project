import '../../domain/models/escrow_contract.dart';
import '../../domain/models/escrow_state.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/repositories/contract_repository.dart';
import '../../domain/wallet/wallet_session.dart';

/// In-memory escrow store for UI development without Sepolia.
class MockContractRepository implements ContractRepository {
  MockContractRepository({required ChainTxSender txSender})
      : _txSender = txSender;

  final ChainTxSender _txSender;
  final Map<String, EscrowContract> _byAddress = {};
  int _id = 0;

  String get _buyer {
    final from = _txSender.fromAddress;
    if (from == null) {
      throw StateError('Connect a wallet before creating or acting on escrows.');
    }
    return from;
  }

  @override
  Future<List<EscrowContract>> getAllContracts() async {
    final list = _byAddress.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<List<EscrowContract>> getContractsByUser(String userAddress) async {
    final u = userAddress.toLowerCase();
    return (await getAllContracts())
        .where(
          (c) =>
              c.buyer.toLowerCase() == u || c.seller.toLowerCase() == u,
        )
        .toList();
  }

  @override
  Future<EscrowContract> getContract(String address) async {
    final c = _byAddress[address.toLowerCase()];
    if (c == null) {
      throw StateError('Unknown contract $address');
    }
    return c;
  }

  @override
  Future<TransactionResult> createEscrow(CreateEscrowParams params) async {
    final buyer = _buyer;
    _id++;
    final address =
        '0x${_id.toRadixString(16).padLeft(40, 'a')}'.substring(0, 42);
    final contract = EscrowContract(
      address: address,
      buyer: buyer,
      seller: params.seller,
      amountWei: params.amountWei,
      deadline: params.deadline,
      state: EscrowState.created,
      createdAt: DateTime.now().toUtc(),
    );
    _byAddress[address.toLowerCase()] = contract;
    final hash = await _txSender.sendTransaction(
      to: '0xFactoryMock',
      dataHex: '0xcreate',
    );
    return TransactionResult(
      txHash: hash,
      contractAddress: address,
      status: TxStatus.confirmed,
    );
  }

  @override
  Future<TransactionResult> fund(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.created) {
      throw StateError('Can only fund in Created state');
    }
    if (!fresh.isBuyerOf(_buyer)) throw StateError('Only buyer can fund');
    _byAddress[contractAddress.toLowerCase()] =
        fresh.copyWith(state: EscrowState.funded);
    final hash = await _txSender.sendTransaction(
      to: contractAddress,
      dataHex: '0xfund',
      valueWei: fresh.amountWei,
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  @override
  Future<TransactionResult> release(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.funded) {
      throw StateError('Can only release when Funded');
    }
    if (!fresh.isBuyerOf(_buyer)) throw StateError('Only buyer can release');
    _byAddress[contractAddress.toLowerCase()] =
        fresh.copyWith(state: EscrowState.released);
    final hash = await _txSender.sendTransaction(
      to: contractAddress,
      dataHex: '0xrelease',
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  @override
  Future<TransactionResult> refundBySeller(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.funded) {
      throw StateError('Can only refund when Funded');
    }
    if (!fresh.isSellerOf(_buyer)) {
      throw StateError('Only seller can refundBySeller');
    }
    _byAddress[contractAddress.toLowerCase()] =
        fresh.copyWith(state: EscrowState.refunded);
    final hash = await _txSender.sendTransaction(
      to: contractAddress,
      dataHex: '0xrefundBySeller',
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  @override
  Future<TransactionResult> refundAfterDeadline(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.funded) {
      throw StateError('Can only reclaim when Funded');
    }
    if (!fresh.isBuyerOf(_buyer)) {
      throw StateError('Only buyer can refundAfterDeadline');
    }
    if (DateTime.now().toUtc().isBefore(fresh.deadline)) {
      throw StateError('Deadline has not passed');
    }
    _byAddress[contractAddress.toLowerCase()] =
        fresh.copyWith(state: EscrowState.refunded);
    final hash = await _txSender.sendTransaction(
      to: contractAddress,
      dataHex: '0xrefundAfterDeadline',
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  /// Seed demo rows for screenshots / widget tests.
  void seedDemo({required String buyer, required String seller}) {
    final now = DateTime.now().toUtc();
    _byAddress['0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'] = EscrowContract(
      address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      buyer: buyer,
      seller: seller,
      amountWei: BigInt.from(10).pow(17), // 0.1 ETH
      deadline: now.add(const Duration(days: 7)),
      state: EscrowState.created,
      createdAt: now.subtract(const Duration(hours: 1)),
    );
    _byAddress['0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'] = EscrowContract(
      address: '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      buyer: buyer,
      seller: seller,
      amountWei: BigInt.from(5) * BigInt.from(10).pow(17), // 0.5 ETH
      deadline: now.add(const Duration(days: 3)),
      state: EscrowState.funded,
      createdAt: now.subtract(const Duration(days: 1)),
    );
  }
}
