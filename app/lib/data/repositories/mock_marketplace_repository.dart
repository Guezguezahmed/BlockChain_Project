import '../../domain/models/marketplace_listing.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/repositories/marketplace_repository.dart';
import '../../domain/wallet/wallet_session.dart';

/// In-memory marketplace for UI development and widget tests.
class MockMarketplaceRepository implements MarketplaceRepository {
  MockMarketplaceRepository({required ChainTxSender txSender})
      : _txSender = txSender {
    seedDemo();
  }

  final ChainTxSender _txSender;

  static final BigInt _oneEth = BigInt.from(10).pow(18);
  static final BigInt _listingFee = BigInt.from(10) * _oneEth;
  static final BigInt _sellerStake = BigInt.from(50) * _oneEth;

  final Map<BigInt, MarketplaceListing> _listings = {};
  final Map<BigInt, String> _owners = {};
  final Map<BigInt, String> _uris = {};
  final Map<String, BigInt> _sdtBalances = {};
  final Map<String, BigInt> _sdtAllowance = {};

  BigInt _nextListingId = BigInt.one;
  BigInt _nextTokenId = BigInt.from(3);

  static const String demoNft =
      '0x14D7811438c6638096BfefB029A22CBeAEF86F57';
  static const String demoSeller =
      '0x2222222222222222222222222222222222222222';
  static const String demoBuyer =
      '0x1111111111111111111111111111111111111111';

  String get _from {
    final a = _txSender.fromAddress;
    if (a == null) {
      throw StateError('Connect a wallet before marketplace actions.');
    }
    return a;
  }

  void seedDemo() {
    _sdtBalances[demoSeller.toLowerCase()] = BigInt.from(1000) * _oneEth;
    _sdtBalances[demoBuyer.toLowerCase()] = BigInt.from(200) * _oneEth;

    // Token 1 stays with seller (inventory); 2–4 are listed (marketplace custody).
    _owners[BigInt.one] = demoSeller;
    _uris[BigInt.one] = 'Aurora Pack';
    _owners[BigInt.two] = demoNft;
    _uris[BigInt.two] = 'Teal Relic';
    _owners[BigInt.from(3)] = demoNft;
    _uris[BigInt.from(3)] = 'Sand Wave Pass';
    _owners[BigInt.from(4)] = demoNft;
    _uris[BigInt.from(4)] = 'Glass Key #04';
    _owners[BigInt.from(5)] = demoBuyer;
    _uris[BigInt.from(5)] = 'Collector Badge';

    void addListing({
      required BigInt id,
      required BigInt tokenId,
      required BigInt priceWei,
    }) {
      _listings[id] = MarketplaceListing(
        id: id,
        seller: demoSeller,
        nft: demoNft,
        tokenId: tokenId,
        priceWei: priceWei,
        stakeLocked: _sellerStake,
        feePaid: _listingFee,
        active: true,
        tokenUri: _uris[tokenId],
        currentNftOwner: demoNft,
      );
    }

    addListing(
      id: BigInt.one,
      tokenId: BigInt.two,
      priceWei: BigInt.from(5) * BigInt.from(10).pow(16), // 0.05
    );
    addListing(
      id: BigInt.two,
      tokenId: BigInt.from(3),
      priceWei: BigInt.from(12) * BigInt.from(10).pow(16), // 0.12
    );
    addListing(
      id: BigInt.from(3),
      tokenId: BigInt.from(4),
      priceWei: BigInt.from(8) * BigInt.from(10).pow(16), // 0.08
    );
    _nextListingId = BigInt.from(4);
    _nextTokenId = BigInt.from(6);
  }

  void ensureConnectedHasSdt({BigInt? amount}) {
    final from = _txSender.fromAddress;
    if (from == null) return;
    _sdtBalances.putIfAbsent(
      from.toLowerCase(),
      () => amount ?? BigInt.from(500) * _oneEth,
    );
  }

  @override
  Future<List<MarketplaceListing>> getListings({bool activeOnly = true}) async {
    final list = _listings.values.toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    if (activeOnly) {
      return list.where((l) => l.active).toList();
    }
    return list;
  }

  @override
  Future<MarketplaceListing> getListing(BigInt listingId) async {
    final l = _listings[listingId];
    if (l == null) throw StateError('Unknown listing $listingId');
    return l.copyWith(
      tokenUri: _uris[l.tokenId],
      currentNftOwner: _owners[l.tokenId],
    );
  }

  @override
  Future<SdtMarketInfo> getSdtInfo(String userAddress) async {
    final key = userAddress.toLowerCase();
    ensureConnectedHasSdt();
    final bal = _sdtBalances[key] ?? BigInt.zero;
    final allow = _sdtAllowance[key] ?? BigInt.zero;
    final discounted = bal >= BigInt.from(100) * _oneEth;
    final fee = discounted ? _listingFee ~/ BigInt.two : _listingFee;
    return SdtMarketInfo(
      balance: bal,
      allowance: allow,
      quotedFee: fee,
      sellerStake: _sellerStake,
      lockedStake: BigInt.zero,
    );
  }

  @override
  Future<BigInt> nextTokenId() async => _nextTokenId;

  @override
  Future<List<BigInt>> getOwnedTokenIds(String owner) async {
    final o = owner.toLowerCase();
    return _owners.entries
        .where((e) => e.value.toLowerCase() == o)
        .map((e) => e.key)
        .toList()
      ..sort();
  }

  @override
  Future<String?> tokenUri(BigInt tokenId) async => _uris[tokenId];

  @override
  Future<String> ownerOf(BigInt tokenId) async {
    final o = _owners[tokenId];
    if (o == null) throw StateError('Unknown token $tokenId');
    return o;
  }

  @override
  Future<TransactionResult> mintNft(String tokenUri) async {
    final from = _from;
    final id = _nextTokenId;
    _nextTokenId += BigInt.one;
    _owners[id] = from;
    _uris[id] = tokenUri;
    final hash = await _txSender.sendTransaction(
      to: demoNft,
      dataHex: '0xmint',
    );
    return TransactionResult(
      txHash: hash,
      contractAddress: id.toString(),
      status: TxStatus.confirmed,
    );
  }

  @override
  Future<TransactionResult> approveSdt(BigInt amount) async {
    final from = _from;
    ensureConnectedHasSdt();
    _sdtAllowance[from.toLowerCase()] = amount;
    final hash = await _txSender.sendTransaction(
      to: '0xSDT',
      dataHex: '0xapprove',
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  @override
  Future<TransactionResult> approveNft(BigInt tokenId) async {
    final from = _from;
    final owner = await ownerOf(tokenId);
    if (owner.toLowerCase() != from.toLowerCase()) {
      throw StateError('Only the NFT owner can approve');
    }
    final hash = await _txSender.sendTransaction(
      to: demoNft,
      dataHex: '0xapproveNft',
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  @override
  Future<TransactionResult> listItem(ListNftParams params) async {
    final from = _from;
    ensureConnectedHasSdt();
    final info = await getSdtInfo(from);
    if (!info.hasEnoughSdt) {
      throw StateError(
        'Need ${info.requiredForList} SDT wei (fee+stake). '
        'Demo SDT sits with the deployer — ask for a transfer.',
      );
    }
    if (!info.hasEnoughAllowance) {
      throw StateError('Approve SDT first');
    }
    final owner = await ownerOf(params.tokenId);
    if (owner.toLowerCase() != from.toLowerCase()) {
      throw StateError('Not NFT owner');
    }

    final key = from.toLowerCase();
    _sdtBalances[key] = (_sdtBalances[key] ?? BigInt.zero) - info.requiredForList;
    _sdtAllowance[key] =
        (_sdtAllowance[key] ?? BigInt.zero) - info.requiredForList;
    // NFT goes into marketplace custody (use nft contract address as stand-in).
    _owners[params.tokenId] = demoNft;

    final id = _nextListingId;
    _nextListingId += BigInt.one;
    _listings[id] = MarketplaceListing(
      id: id,
      seller: from,
      nft: params.nft,
      tokenId: params.tokenId,
      priceWei: params.priceWei,
      stakeLocked: info.sellerStake,
      feePaid: info.quotedFee,
      active: true,
      tokenUri: _uris[params.tokenId],
      currentNftOwner: demoNft,
    );

    final hash = await _txSender.sendTransaction(
      to: '0xMarketplace',
      dataHex: '0xlist',
    );
    return TransactionResult(
      txHash: hash,
      contractAddress: id.toString(),
      status: TxStatus.confirmed,
    );
  }

  @override
  Future<TransactionResult> buyItem(BigInt listingId) async {
    final from = _from;
    final listing = await getListing(listingId);
    if (!listing.active) throw StateError('Listing not active');
    if (listing.isSellerOf(from)) {
      throw StateError('Cannot buy your own listing');
    }

    _listings[listingId] = listing.copyWith(
      active: false,
      currentNftOwner: from,
    );
    _owners[listing.tokenId] = from;

    final hash = await _txSender.sendTransaction(
      to: '0xMarketplace',
      dataHex: '0xbuy',
      valueWei: listing.priceWei,
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }

  @override
  Future<TransactionResult> cancelListing(BigInt listingId) async {
    final from = _from;
    final listing = await getListing(listingId);
    if (!listing.active) throw StateError('Listing not active');
    if (!listing.isSellerOf(from)) throw StateError('Only seller can cancel');

    _listings[listingId] = listing.copyWith(
      active: false,
      currentNftOwner: from,
    );
    _owners[listing.tokenId] = from;

    final hash = await _txSender.sendTransaction(
      to: '0xMarketplace',
      dataHex: '0xcancel',
    );
    return TransactionResult(txHash: hash, status: TxStatus.confirmed);
  }
}
