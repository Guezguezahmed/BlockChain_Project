import 'package:flutter/material.dart';

import '../../domain/utils/nft_metadata.dart';
import '../theme/app_theme.dart';

/// NFT cover: remote image when available, else teal-family placeholder art.
class NftArt extends StatelessWidget {
  const NftArt({
    super.key,
    required this.tokenId,
    this.imageUrl,
    this.borderRadius = 16,
    this.aspectRatio = 1,
    this.expand = false,
    this.heroTag,
  });

  final BigInt tokenId;
  final String? imageUrl;
  final double borderRadius;
  final double aspectRatio;

  /// When true, fill parent constraints (use inside [Expanded]).
  final bool expand;
  final Object? heroTag;

  static const _palettes = <List<Color>>[
    [Color(0xFF0F1C1A), Color(0xFF1A9B7A), Color(0xFF2DD4A8)],
    [Color(0xFF16302C), Color(0xFF0E7C6B), Color(0xFF7ED9C0)],
    [Color(0xFF0B3D36), Color(0xFF1F6F5B), Color(0xFFA8E6CF)],
    [Color(0xFF12261F), Color(0xFF2A6F6A), Color(0xFF4ECDC4)],
    [Color(0xFF1A3A32), Color(0xFF3D8B7A), Color(0xFFB8E0D2)],
    [Color(0xFF0D2822), Color(0xFF248A72), Color(0xFF66C2A5)],
  ];

  @override
  Widget build(BuildContext context) {
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageUrl == null || imageUrl!.isEmpty
          ? _Placeholder(tokenId: tokenId)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => _Placeholder(tokenId: tokenId),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _Placeholder(tokenId: tokenId),
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                );
              },
            ),
    );

    final child = expand
        ? SizedBox.expand(child: art)
        : AspectRatio(aspectRatio: aspectRatio, child: art);

    if (heroTag == null) return child;
    return Hero(tag: heroTag!, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.tokenId});

  final BigInt tokenId;

  @override
  Widget build(BuildContext context) {
    final colors = NftArt._palettes[nftPlaceholderPaletteIndex(tokenId)];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  '#$tokenId',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft shimmer-ish loading tile for grids.
class ListingCardSkeleton extends StatelessWidget {
  const ListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.ink.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: 90,
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
