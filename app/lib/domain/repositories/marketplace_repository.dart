import '../models/marketplace_listing.dart';
import '../models/transaction_result.dart';

/// Marketplace + SDT + SmartDealNFT surface for screens.
///
/// Implementations:
/// - [MockMarketplaceRepository] — in-memory for UI / widget tests
/// - [ChainMarketplaceRepository] — web3dart against Sepolia
abstract class MarketplaceRepository {
  /// Active + recently closed listings (id ascending, newest last).
  Future<List<MarketplaceListing>> getListings({bool activeOnly = true});

  Future<MarketplaceListing> getListing(BigInt listingId);

  Future<SdtMarketInfo> getSdtInfo(String userAddress);

  Future<BigInt> nextTokenId();

  /// Tokens currently owned by [owner] in the SmartDealNFT collection
  /// (best-effort scan of minted ids — fine for demo scale).
  Future<List<BigInt>> getOwnedTokenIds(String owner);

  Future<String?> tokenUri(BigInt tokenId);

  Future<String> ownerOf(BigInt tokenId);

  /// Mint a demo NFT to the connected wallet.
  Future<TransactionResult> mintNft(String tokenUri);

  /// Approve Marketplace to move SDT (fee + stake).
  Future<TransactionResult> approveSdt(BigInt amount);

  /// Approve Marketplace for a specific NFT token id.
  Future<TransactionResult> approveNft(BigInt tokenId);

  /// True if Marketplace can transfer [tokenId] (getApproved / operator).
  Future<bool> isNftApprovedForMarketplace(BigInt tokenId);

  /// List after SDT + NFT approvals.
  Future<TransactionResult> listItem(ListNftParams params);

  /// Buy with exact ETH (`priceWei`).
  Future<TransactionResult> buyItem(BigInt listingId);

  /// Seller cancels an active listing.
  Future<TransactionResult> cancelListing(BigInt listingId);
}
