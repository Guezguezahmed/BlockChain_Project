import 'dart:async';

import 'package:convert/convert.dart';
import 'package:http/http.dart' as http;
import 'package:wallet/wallet.dart';
import 'package:web3dart/web3dart.dart';

import '../../config/app_config.dart';
import '../../domain/models/marketplace_listing.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../domain/wallet/wallet_session.dart';
import '../abis/marketplace_abi.dart';
import '../abis/sdt_abi.dart';
import '../abis/smart_deal_nft_abi.dart';

/// Reads/writes Marketplace + SDT + SmartDealNFT on Sepolia via web3dart.
///
/// Writes are signed by the user's wallet through [ChainTxSender] —
/// this class never holds private keys.
class ChainMarketplaceRepository implements MarketplaceRepository {
  ChainMarketplaceRepository({
    required this.marketplaceAddress,
    required this.sdtAddress,
    required this.nftAddress,
    required this.rpcUrl,
    required ChainTxSender txSender,
    Web3Client? client,
  })  : _txSender = txSender,
        _client = client ?? Web3Client(rpcUrl, http.Client()),
        _ownsClient = client == null;

  final String marketplaceAddress;
  final String sdtAddress;
  final String nftAddress;
  final String rpcUrl;
  final ChainTxSender _txSender;
  final Web3Client _client;
  final bool _ownsClient;

  late final DeployedContract _market = DeployedContract(
    ContractAbi.fromJson(kMarketplaceAbiJson, 'Marketplace'),
    EthereumAddress.fromHex(marketplaceAddress),
  );

  late final DeployedContract _sdt = DeployedContract(
    ContractAbi.fromJson(kSdtAbiJson, 'SDT'),
    EthereumAddress.fromHex(sdtAddress),
  );

  late final DeployedContract _nft = DeployedContract(
    ContractAbi.fromJson(kSmartDealNftAbiJson, 'SmartDealNFT'),
    EthereumAddress.fromHex(nftAddress),
  );

  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
  }

  void _requireMarket() {
    if (!AppConfig.hasMarketplaceAddress &&
        (marketplaceAddress.isEmpty ||
            marketplaceAddress ==
                '0x0000000000000000000000000000000000000000')) {
      throw StateError(
        'MARKETPLACE_ADDRESS is not set. Pass the live Sepolia address '
        'via --dart-define=MARKETPLACE_ADDRESS=0x...',
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

  Future<TransactionResult> _sendAndWait({
    required DeployedContract contract,
    required String functionName,
    required List<dynamic> params,
    EtherAmount? value,
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
    return TransactionResult(txHash: txHash, status: TxStatus.confirmed);
  }

  MarketplaceListing _parseListing(BigInt id, List<dynamic> raw) {
    // struct Listing decoded as tuple / list
    final tuple = raw.first as List;
    return MarketplaceListing(
      id: id,
      seller: (tuple[0] as EthereumAddress).eip55With0x,
      nft: (tuple[1] as EthereumAddress).eip55With0x,
      tokenId: tuple[2] as BigInt,
      priceWei: tuple[3] as BigInt,
      stakeLocked: tuple[4] as BigInt,
      feePaid: tuple[5] as BigInt,
      active: tuple[6] as bool,
    );
  }

  Future<MarketplaceListing> _enrich(MarketplaceListing listing) async {
    String? uri;
    String? owner;
    try {
      uri = await tokenUri(listing.tokenId);
    } catch (_) {}
    try {
      // Prefer NFT contract ownerOf for the listing's token.
      final nft = DeployedContract(
        ContractAbi.fromJson(kSmartDealNftAbiJson, 'SmartDealNFT'),
        EthereumAddress.fromHex(listing.nft),
      );
      final raw = await _client.call(
        contract: nft,
        function: nft.function('ownerOf'),
        params: [listing.tokenId],
      );
      owner = (raw.first as EthereumAddress).eip55With0x;
    } catch (_) {}
    return listing.copyWith(tokenUri: uri, currentNftOwner: owner);
  }

  @override
  Future<List<MarketplaceListing>> getListings({bool activeOnly = true}) async {
    _requireMarket();
    final nextRaw = await _client.call(
      contract: _market,
      function: _market.function('nextListingId'),
      params: const [],
    );
    final next = nextRaw.first as BigInt;
    final out = <MarketplaceListing>[];
    // Ids start at 1.
    for (var i = BigInt.one; i < next; i += BigInt.one) {
      try {
        final listing = await getListing(i);
        if (!activeOnly || listing.active) {
          out.add(listing);
        }
      } catch (_) {}
    }
    out.sort((a, b) => b.id.compareTo(a.id));
    return out;
  }

  @override
  Future<MarketplaceListing> getListing(BigInt listingId) async {
    _requireMarket();
    final raw = await _client.call(
      contract: _market,
      function: _market.function('getListing'),
      params: [listingId],
    );
    return _enrich(_parseListing(listingId, raw));
  }

  @override
  Future<SdtMarketInfo> getSdtInfo(String userAddress) async {
    _requireMarket();
    final user = EthereumAddress.fromHex(userAddress);
    final market = EthereumAddress.fromHex(marketplaceAddress);

    final bal = (await _client.call(
      contract: _sdt,
      function: _sdt.function('balanceOf'),
      params: [user],
    ))
        .first as BigInt;

    final allow = (await _client.call(
      contract: _sdt,
      function: _sdt.function('allowance'),
      params: [user, market],
    ))
        .first as BigInt;

    final fee = (await _client.call(
      contract: _market,
      function: _market.function('quoteListingFee'),
      params: [user],
    ))
        .first as BigInt;

    final stake = (await _client.call(
      contract: _market,
      function: _market.function('sellerStake'),
      params: const [],
    ))
        .first as BigInt;

    final locked = (await _client.call(
      contract: _market,
      function: _market.function('lockedStake'),
      params: [user],
    ))
        .first as BigInt;

    return SdtMarketInfo(
      balance: bal,
      allowance: allow,
      quotedFee: fee,
      sellerStake: stake,
      lockedStake: locked,
    );
  }

  @override
  Future<BigInt> nextTokenId() async {
    final raw = await _client.call(
      contract: _nft,
      function: _nft.function('nextTokenId'),
      params: const [],
    );
    return raw.first as BigInt;
  }

  @override
  Future<List<BigInt>> getOwnedTokenIds(String owner) async {
    final next = await nextTokenId();
    final want = owner.toLowerCase();
    final out = <BigInt>[];
    for (var i = BigInt.one; i < next; i += BigInt.one) {
      try {
        final o = await ownerOf(i);
        if (o.toLowerCase() == want) out.add(i);
      } catch (_) {}
    }
    return out;
  }

  @override
  Future<String?> tokenUri(BigInt tokenId) async {
    final raw = await _client.call(
      contract: _nft,
      function: _nft.function('tokenURI'),
      params: [tokenId],
    );
    return raw.first as String;
  }

  @override
  Future<String> ownerOf(BigInt tokenId) async {
    final raw = await _client.call(
      contract: _nft,
      function: _nft.function('ownerOf'),
      params: [tokenId],
    );
    return (raw.first as EthereumAddress).eip55With0x;
  }

  @override
  Future<TransactionResult> mintNft(String tokenUri) async {
    // ignore: unnecessary_statements
    _from;
    return _sendAndWait(
      contract: _nft,
      functionName: 'mint',
      params: [tokenUri],
    );
  }

  @override
  Future<TransactionResult> approveSdt(BigInt amount) async {
    // ignore: unnecessary_statements
    _from;
    return _sendAndWait(
      contract: _sdt,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(marketplaceAddress), amount],
    );
  }

  @override
  Future<TransactionResult> approveNft(BigInt tokenId) async {
    // ignore: unnecessary_statements
    _from;
    return _sendAndWait(
      contract: _nft,
      functionName: 'approve',
      params: [EthereumAddress.fromHex(marketplaceAddress), tokenId],
    );
  }

  @override
  Future<bool> isNftApprovedForMarketplace(BigInt tokenId) async {
    final market = EthereumAddress.fromHex(marketplaceAddress);
    final approved = (await _client.call(
      contract: _nft,
      function: _nft.function('getApproved'),
      params: [tokenId],
    ))
        .first as EthereumAddress;
    if (approved == market) return true;

    final ownerHex = await ownerOf(tokenId);
    final isOperator = (await _client.call(
      contract: _nft,
      function: _nft.function('isApprovedForAll'),
      params: [EthereumAddress.fromHex(ownerHex), market],
    ))
        .first as bool;
    return isOperator;
  }

  @override
  Future<TransactionResult> listItem(ListNftParams params) async {
    // ignore: unnecessary_statements
    _from;
    return _sendAndWait(
      contract: _market,
      functionName: 'listItem',
      params: [
        EthereumAddress.fromHex(params.nft),
        params.tokenId,
        params.priceWei,
      ],
    );
  }

  @override
  Future<TransactionResult> buyItem(BigInt listingId) async {
    final fresh = await getListing(listingId);
    if (!fresh.active) {
      throw StateError('Listing is not active');
    }
    if (fresh.isSellerOf(_from)) {
      throw StateError('Cannot buy your own listing');
    }
    return _sendAndWait(
      contract: _market,
      functionName: 'buyItem',
      params: [listingId],
      value: EtherAmount.inWei(fresh.priceWei),
    );
  }

  @override
  Future<TransactionResult> cancelListing(BigInt listingId) async {
    final fresh = await getListing(listingId);
    if (!fresh.active) {
      throw StateError('Listing is not active');
    }
    if (!fresh.isSellerOf(_from)) {
      throw StateError('Only the seller can cancel');
    }
    return _sendAndWait(
      contract: _market,
      functionName: 'cancelListing',
      params: [listingId],
    );
  }
}
