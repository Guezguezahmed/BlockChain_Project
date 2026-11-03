import 'package:blockchain_app/domain/utils/eth_formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('eth formatting', () {
    test('parse ETH to wei', () {
      expect(tryParseEthToWei('1'), BigInt.from(10).pow(18));
      expect(tryParseEthToWei('0.1'), BigInt.from(10).pow(17));
      expect(tryParseEthToWei('0'), BigInt.zero);
      expect(tryParseEthToWei(''), isNull);
      expect(tryParseEthToWei('abc'), isNull);
    });

    test('format wei as eth', () {
      expect(formatWeiAsEth(BigInt.from(10).pow(18)), '1');
      expect(formatWeiAsEth(BigInt.from(10).pow(17)), '0.1');
    });

    test('address validation', () {
      expect(
        isValidEthereumAddress('0x1111111111111111111111111111111111111111'),
        isTrue,
      );
      expect(isValidEthereumAddress('0x123'), isFalse);
      expect(isValidEthereumAddress('1111111111111111111111111111111111111111'),
          isFalse);
    });
  });
}
