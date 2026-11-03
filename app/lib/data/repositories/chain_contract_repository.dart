import 'dart:async';

import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../../config/app_config.dart';
import '../../domain/models/escrow_contract.dart';
import '../../domain/models/escrow_state.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/repositories/contract_repository.dart';
import '../../domain/wallet/wallet_session.dart';
import '../abis/contract_factory_abi.dart';
import '../abis/escrow_abi.dart';

/// keccak256("ContractCreated(address,address,uint8,uint256)") — fixed topic.
const String _kContractCreatedTopic =
    '0x3c47a15feacba0aff19d53c5b75f364e5b56f444f76ba392320867afdd41f467';

/// Reads/writes Escrow + Factory on Sepolia via web3dart.
///
/// Writes are signed by the user's wallet through [ChainTxSender]
/// (Reown AppKit) — this class never holds private keys.
class ChainContractRepository implements ContractRepository {
  ChainContractRepository({
    required this.factoryAddress,
    required this.rpcUrl,
    required ChainTxSender txSender,
    Web3Client? client,
  })  : _txSender = txSender,
        _client = client ?? Web3Client(rpcUrl, http.Client()),
        _ownsClient = client == null;

  final String factoryAddress;
  final String rpcUrl;
  final ChainTxSender _txSender;
  final Web3Client _client;
  final bool _ownsClient;

  late final DeployedContract _factory = DeployedContract(
    ContractAbi.fromJson(kContractFactoryAbiJson, 'ContractFactory'),
    EthereumAddress.fromHex(factoryAddress),
  );

  late final ContractAbi _escrowAbi =
      ContractAbi.fromJson(kEscrowAbiJson, 'Escrow');

  DeployedContract _escrowAt(String address) => DeployedContract(
        _escrowAbi,
        EthereumAddress.fromHex(address),
      );

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }

  void _requireFactory() {
    if (!AppConfig.hasFactoryAddress &&
        (factoryAddress.isEmpty ||
            factoryAddress ==
                '0x0000000000000000000000000000000000000000')) {
      throw StateError(
        'FACTORY_ADDRESS is not set. Deploy ContractFactory to Sepolia, then '
        'pass --dart-define=FACTORY_ADDRESS=0x...',
      );
    }
  }

  String get _from {
    final a = _txSender.fromAddress;
    if (a == null) {
      throw StateError('Connect a wallet before sending transactions.');
    }
    return a;
  }

  Future<EscrowContract> _readEscrow(EthereumAddress address) async {
    final c = _escrowAt(address.with0x);
    final buyer = (await _client.call(
      contract: c,
      function: c.function('buyer'),
      params: const [],
    ))
        .first as EthereumAddress;
    final seller = (await _client.call(
      contract: c,
      function: c.function('seller'),
      params: const [],
    ))
        .first as EthereumAddress;
    final amount = (await _client.call(
      contract: c,
      function: c.function('amount'),
      params: const [],
    ))
        .first as BigInt;
    final deadline = (await _client.call(
      contract: c,
      function: c.function('deadline'),
      params: const [],
    ))
        .first as BigInt;
    final stateRaw = (await _client.call(
      contract: c,
      function: c.function('state'),
      params: const [],
    ))
        .first as BigInt;
    final createdAt = (await _client.call(
      contract: c,
      function: c.function('createdAt'),
      params: const [],
    ))
        .first as BigInt;

    return EscrowContract(
      address: address.eip55With0x,
      buyer: buyer.eip55With0x,
      seller: seller.eip55With0x,
      amountWei: amount,
      deadline: DateTime.fromMillisecondsSinceEpoch(
        deadline.toInt() * 1000,
        isUtc: true,
      ),
      state: EscrowState.fromOnChain(stateRaw.toInt()),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        createdAt.toInt() * 1000,
        isUtc: true,
      ),
    );
  }

  @override
  Future<EscrowContract> getContract(String address) async {
    return _readEscrow(EthereumAddress.fromHex(address));
  }

  @override
  Future<List<EscrowContract>> getContractsByUser(String userAddress) async {
    _requireFactory();
    final raw = await _client.call(
      contract: _factory,
      function: _factory.function('getContractsByUser'),
      params: [EthereumAddress.fromHex(userAddress)],
    );
    final addresses = (raw.first as List).cast<EthereumAddress>();
    final out = <EscrowContract>[];
    for (final a in addresses) {
      try {
        out.add(await _readEscrow(a));
      } catch (_) {}
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<List<EscrowContract>> getAllContracts() async {
    _requireFactory();
    final raw = await _client.call(
      contract: _factory,
      function: _factory.function('getAllContracts'),
      params: const [],
    );
    final addresses = (raw.first as List).cast<EthereumAddress>();
    final out = <EscrowContract>[];
    for (final a in addresses) {
      try {
        out.add(await _readEscrow(a));
      } catch (_) {}
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<TransactionResult> _sendAndWait({
    required DeployedContract contract,
    required String functionName,
    required List<dynamic> params,
    EtherAmount? value,
    String? Function(TransactionReceipt receipt)? parseAddress,
  }) async {
    final fn = contract.function(functionName);
    final data = fn.encodeCall(params);
    final dataHex = '0x${hex.encode(data)}';
    final txHash = await _txSender.sendTransaction(
      to: contract.address.with0x,
      dataHex: dataHex,
      valueWei: value?.getInWei,
    );

    TransactionReceipt? receipt;
    for (var i = 0; i < 40; i++) {
      receipt = await _client.getTransactionReceipt(txHash);
      if (receipt != null) break;
      await Future<void>.delayed(const Duration(seconds: 3));
    }

    if (receipt == null) {
      return TransactionResult(txHash: txHash, status: TxStatus.pending);
    }
    if (!(receipt.status ?? false)) {
      return TransactionResult(txHash: txHash, status: TxStatus.failed);
    }

    final created = parseAddress?.call(receipt);
    return TransactionResult(
      txHash: txHash,
      contractAddress: created,
      status: TxStatus.confirmed,
    );
  }

  /// ContractCreated(address indexed creator, address indexed contractAddress, ...)
  String? _parseCreatedAddress(TransactionReceipt receipt) {
    for (final log in receipt.logs) {
      final topics = log.topics;
      if (topics == null || topics.isEmpty) continue;
      final t0 = topics.first;
      if (t0 == null) continue;
      if (t0.toLowerCase() != _kContractCreatedTopic.toLowerCase()) continue;
      if (topics.length < 3 || topics[2] == null) continue;
      final topic = topics[2]!;
      final h = topic.startsWith('0x') ? topic.substring(2) : topic;
      final addrHex = h.length >= 40 ? h.substring(h.length - 40) : h;
      return EthereumAddress.fromHex('0x$addrHex').eip55With0x;
    }
    return null;
  }

  @override
  Future<TransactionResult> createEscrow(CreateEscrowParams params) async {
    _requireFactory();
    // Ensure wallet is connected.
    // ignore: unnecessary_statements
    _from;
    return _sendAndWait(
      contract: _factory,
      functionName: 'createEscrow',
      params: [
        EthereumAddress.fromHex(params.seller),
        params.amountWei,
        BigInt.from(params.deadline.toUtc().millisecondsSinceEpoch ~/ 1000),
      ],
      parseAddress: _parseCreatedAddress,
    );
  }

  @override
  Future<TransactionResult> fund(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.created) {
      throw StateError(
        'fund() only allowed in Created (on-chain state: ${fresh.state.label})',
      );
    }
    if (!fresh.isBuyerOf(_from)) {
      throw StateError('Only the buyer can fund this escrow');
    }
    return _sendAndWait(
      contract: _escrowAt(contractAddress),
      functionName: 'fund',
      params: const [],
      value: EtherAmount.inWei(fresh.amountWei),
    );
  }

  @override
  Future<TransactionResult> release(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.funded) {
      throw StateError('release() only allowed in Funded');
    }
    if (!fresh.isBuyerOf(_from)) {
      throw StateError('Only the buyer can release');
    }
    return _sendAndWait(
      contract: _escrowAt(contractAddress),
      functionName: 'release',
      params: const [],
    );
  }

  @override
  Future<TransactionResult> refundBySeller(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.funded) {
      throw StateError('refundBySeller() only allowed in Funded');
    }
    if (!fresh.isSellerOf(_from)) {
      throw StateError('Only the seller can refundBySeller');
    }
    return _sendAndWait(
      contract: _escrowAt(contractAddress),
      functionName: 'refundBySeller',
      params: const [],
    );
  }

  @override
  Future<TransactionResult> refundAfterDeadline(String contractAddress) async {
    final fresh = await getContract(contractAddress);
    if (fresh.state != EscrowState.funded) {
      throw StateError('refundAfterDeadline() only allowed in Funded');
    }
    if (!fresh.isBuyerOf(_from)) {
      throw StateError('Only the buyer can reclaim after deadline');
    }
    final now = DateTime.now().toUtc();
    if (now.isBefore(fresh.deadline)) {
      throw StateError('Deadline has not passed yet');
    }
    return _sendAndWait(
      contract: _escrowAt(contractAddress),
      functionName: 'refundAfterDeadline',
      params: const [],
    );
  }
}
