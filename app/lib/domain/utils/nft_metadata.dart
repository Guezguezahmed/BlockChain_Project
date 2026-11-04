/// Best-effort display helpers for NFT tokenURI values.
///
/// Demo URIs are often plain strings (`ipfs://…`, `https://…`, or a title).
/// We never block the UI waiting on remote JSON.
class NftDisplayMeta {
  const NftDisplayMeta({
    required this.title,
    this.imageUrl,
    this.rawUri,
  });

  final String title;
  final String? imageUrl;
  final String? rawUri;
}

NftDisplayMeta nftDisplayMeta({
  required BigInt tokenId,
  String? tokenUri,
  String fallbackPrefix = 'Smart Deal',
}) {
  final uri = tokenUri?.trim();
  if (uri == null || uri.isEmpty) {
    return NftDisplayMeta(
      title: '$fallbackPrefix #$tokenId',
      rawUri: uri,
    );
  }

  if (_looksLikeImageUrl(uri)) {
    return NftDisplayMeta(
      title: '$fallbackPrefix #$tokenId',
      imageUrl: _toHttp(uri),
      rawUri: uri,
    );
  }

  if (uri.startsWith('ipfs://') ||
      uri.startsWith('http://') ||
      uri.startsWith('https://')) {
    final name = _basename(uri);
    return NftDisplayMeta(
      title: name.isEmpty ? '$fallbackPrefix #$tokenId' : _humanize(name),
      imageUrl: _guessImageFromMetaUri(uri),
      rawUri: uri,
    );
  }

  return NftDisplayMeta(title: uri, rawUri: uri);
}

String shortWallet(String address) {
  if (address.length < 10) return address;
  return '${address.substring(0, 6)}…${address.substring(address.length - 4)}';
}

bool _looksLikeImageUrl(String uri) {
  final lower = uri.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.svg');
}

String? _toHttp(String uri) {
  if (uri.startsWith('ipfs://')) {
    final path = uri.substring('ipfs://'.length);
    return 'https://ipfs.io/ipfs/$path';
  }
  if (uri.startsWith('http://') || uri.startsWith('https://')) return uri;
  return null;
}

String _basename(String uri) {
  final cleaned = uri.split('?').first;
  final parts = cleaned.split('/');
  var last = parts.isEmpty ? cleaned : parts.last;
  if (last.endsWith('.json')) {
    last = last.substring(0, last.length - 5);
  }
  return last;
}

String _humanize(String raw) {
  return raw
      .replaceAll('-', ' ')
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
      .join(' ');
}

String? _guessImageFromMetaUri(String uri) {
  if (_looksLikeImageUrl(uri)) return _toHttp(uri);
  return null;
}

/// Palette index 0–5 for placeholder art (presentation maps to colors).
int nftPlaceholderPaletteIndex(BigInt tokenId) => tokenId.toInt() % 6;
