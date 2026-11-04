import 'package:blockchain_app/data/repositories/mock_marketplace_repository.dart';
import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/domain/models/marketplace_listing.dart';
import 'package:blockchain_app/domain/models/transaction_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MockWalletService wallet;
  late MockMarketplaceRepository repo;

  setUp(() {
    wallet = MockWalletService();
    repo = MockMarketplaceRepository(txSender: wallet);
  });

  tearDown(() => wallet.dispose());

  test('seeded listing is active and buyable after connect', () async {
    final listings = await repo.getListings();
    expect(listings, isNotEmpty);
    expect(listings.first.active, isTrue);

    await wallet.connect();
    repo.ensureConnectedHasSdt();

    final before = await repo.getListing(BigInt.one);
    final result = await repo.buyItem(BigInt.one);
    expect(result.status, TxStatus.confirmed);

    final after = await repo.getListing(BigInt.one);
    expect(after.active, isFalse);
    expect(after.currentNftOwner?.toLowerCase(),
        wallet.mockAddress.toLowerCase());
    expect(before.active, isTrue);
  });

  test('mint → approve → list flow', () async {
    await wallet.connect();
    repo.ensureConnectedHasSdt();

    final mint = await repo.mintNft('ipfs://test.json');
    expect(mint.status, TxStatus.confirmed);

    final owned = await repo.getOwnedTokenIds(wallet.mockAddress);
    expect(owned, isNotEmpty);
    final tokenId = owned.last;

    final info = await repo.getSdtInfo(wallet.mockAddress);
    expect(await repo.isNftApprovedForMarketplace(tokenId), isFalse);
    await repo.approveSdt(info.requiredForList);
    await repo.approveNft(tokenId);
    expect(await repo.isNftApprovedForMarketplace(tokenId), isTrue);

    final listed = await repo.listItem(
      ListNftParams(
        nft: MockMarketplaceRepository.demoNft,
        tokenId: tokenId,
        priceWei: BigInt.from(10).pow(17),
      ),
    );
    expect(listed.status, TxStatus.confirmed);

    final active = await repo.getListings(activeOnly: true);
    expect(
      active.any((l) => l.tokenId == tokenId && l.active),
      isTrue,
    );

    final owner = await repo.ownerOf(tokenId);
    expect(owner.toLowerCase(),
        MockMarketplaceRepository.demoNft.toLowerCase());
  });
}
