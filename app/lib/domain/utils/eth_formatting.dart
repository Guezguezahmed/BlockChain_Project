import 'package:wallet/wallet.dart';

/// Display helpers — UI always shows ETH, never raw wei (AGENTS.md §5).
String formatWeiAsEth(BigInt wei, {int fractionDigits = 6}) {
  final eth = EtherAmount.inWei(wei).getValueInUnit(EtherUnit.ether);
  var s = eth.toStringAsFixed(fractionDigits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

BigInt? tryParseEthToWei(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  try {
    final normalized = trimmed.contains('.') ? trimmed : '$trimmed.0';
    final parts = normalized.split('.');
    if (parts.length != 2) return null;
    final whole = BigInt.parse(parts[0].isEmpty ? '0' : parts[0]);
    var frac = parts[1];
    if (frac.length > 18) return null;
    frac = frac.padRight(18, '0');
    final fracWei = BigInt.parse(frac.isEmpty ? '0' : frac);
    return whole * BigInt.from(10).pow(18) + fracWei;
  } catch (_) {
    return null;
  }
}

bool isValidEthereumAddress(String value) {
  final v = value.trim();
  if (!RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(v)) return false;
  try {
    EthereumAddress.fromHex(v);
    return true;
  } catch (_) {
    return false;
  }
}

String checksumAddress(String value) {
  return EthereumAddress.fromHex(value.trim()).eip55With0x;
}
