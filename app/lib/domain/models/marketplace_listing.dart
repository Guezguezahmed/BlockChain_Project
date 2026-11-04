/// On-chain Marketplace listing (IMarketplace.Listing).
class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.seller,
    required this.nft,
    required this.tokenId,
    required this.priceWei,
    required this.stakeLocked,
    required this.feePaid,
    required this.active,
    this.tokenUri,
    this.currentNftOwner,
  });

  final BigInt id;
  final String seller;
  final String nft;
  final BigInt tokenId;
  final BigInt priceWei;
  final BigInt stakeLocked;
  final BigInt feePaid;
  final bool active;

  /// Optional metadata URI from SmartDealNFT.tokenURI (best-effort).
  final String? tokenUri;

  /// Current ERC-721 owner (marketplace while listed; buyer after sale).
  final String? currentNftOwner;

  bool isSellerOf(String address) =>
      seller.toLowerCase() == address.toLowerCase();

  String get shortNft {
    if (nft.length < 10) return nft;
    return '${nft.substring(0, 6)}…${nft.substring(nft.length - 4)}';
  }

  String get shortSeller {
    if (seller.length < 10) return seller;
    return '${seller.substring(0, 6)}…${seller.substring(seller.length - 4)}';
  }

  MarketplaceListing copyWith({
    String? tokenUri,
    String? currentNftOwner,
    bool? active,
  }) {
    return MarketplaceListing(
      id: id,
      seller: seller,
      nft: nft,
      tokenId: tokenId,
      priceWei: priceWei,
      stakeLocked: stakeLocked,
      feePaid: feePaid,
      active: active ?? this.active,
      tokenUri: tokenUri ?? this.tokenUri,
      currentNftOwner: currentNftOwner ?? this.currentNftOwner,
    );
  }
}

/// Params for listing an owned NFT.
class ListNftParams {
  const ListNftParams({
    required this.nft,
    required this.tokenId,
    required this.priceWei,
  });

  final String nft;
  final BigInt tokenId;
  final BigInt priceWei;
}

/// Snapshot of SDT balances / fee quote for the connected wallet.
class SdtMarketInfo {
  const SdtMarketInfo({
    required this.balance,
    required this.allowance,
    required this.quotedFee,
    required this.sellerStake,
    required this.lockedStake,
  });

  final BigInt balance;
  final BigInt allowance;
  final BigInt quotedFee;
  final BigInt sellerStake;
  final BigInt lockedStake;

  BigInt get requiredForList => quotedFee + sellerStake;

  bool get hasEnoughSdt => balance >= requiredForList;
  bool get hasEnoughAllowance => allowance >= requiredForList;
}
