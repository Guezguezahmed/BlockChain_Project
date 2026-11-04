import 'package:flutter/material.dart';

import '../../domain/models/marketplace_listing.dart';
import '../../domain/utils/eth_formatting.dart';
import '../../domain/utils/nft_metadata.dart';
import '../theme/app_theme.dart';
import 'nft_art.dart';

/// Marketplace grid card: art · title · price ETH · seller.
class ListingCard extends StatelessWidget {
  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.index = 0,
  });

  final MarketplaceListing listing;
  final VoidCallback onTap;
  final int index;

  @override
  Widget build(BuildContext context) {
    final meta = nftDisplayMeta(
      tokenId: listing.tokenId,
      tokenUri: listing.tokenUri,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index % 6) * 40),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.white.withValues(alpha: 0.62),
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.ink.withValues(alpha: 0.07)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: NftArt(
                      tokenId: listing.tokenId,
                      imageUrl: meta.imageUrl,
                      borderRadius: 14,
                      expand: true,
                      heroTag: 'listing-${listing.id}',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    meta.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listing.shortSeller,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.ink.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.diamond_outlined,
                        size: 14,
                        color: AppTheme.accentDim,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${formatWeiAsEth(listing.priceWei)} ETH',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
