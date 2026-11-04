import 'package:blockchain_app/domain/utils/nft_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain title is used as display name', () {
    final m = nftDisplayMeta(tokenId: BigInt.two, tokenUri: 'Teal Relic');
    expect(m.title, 'Teal Relic');
    expect(m.imageUrl, isNull);
  });

  test('ipfs json basename is humanized', () {
    final m = nftDisplayMeta(
      tokenId: BigInt.one,
      tokenUri: 'ipfs://demo/sand-wave-pass.json',
    );
    expect(m.title, 'Sand Wave Pass');
  });

  test('fallback title uses token id', () {
    final m = nftDisplayMeta(tokenId: BigInt.from(9), tokenUri: null);
    expect(m.title, 'Smart Deal #9');
  });
}
