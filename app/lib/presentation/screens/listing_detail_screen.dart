import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/models/marketplace_listing.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/utils/eth_formatting.dart';
import '../../domain/utils/nft_metadata.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/nft_art.dart';
import '../widgets/ownership_celebration.dart';
import '../widgets/public_notice_banner.dart';
import '../widgets/tx_status_banner.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final BigInt listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _busy = false;
  String? _status;
  TxBannerKind _statusKind = TxBannerKind.info;
  String? _lastTx;
  String? _ownerAfter;
  bool _ownedByMe = false;

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _status = 'Confirm buy in your wallet…';
      _statusKind = TxBannerKind.pending;
      _lastTx = null;
      _ownerAfter = null;
      _ownedByMe = false;
    });
    try {
      final market = ref.read(marketplaceRepositoryProvider);
      final me = ref.read(connectedAddressProvider) ??
          ref.read(walletServiceProvider).currentSession?.address;
      final result = await market.buyItem(widget.listingId);
      _lastTx = result.txHash;
      if (result.status == TxStatus.failed) {
        setState(() {
          _status = 'Transaction failed';
          _statusKind = TxBannerKind.error;
        });
      } else {
        final listing = await market.getListing(widget.listingId);
        final owner = listing.currentNftOwner ??
            await market.ownerOf(listing.tokenId);
        final mine = me != null && owner.toLowerCase() == me.toLowerCase();
        setState(() {
          _ownerAfter = owner;
          _ownedByMe = mine;
          if (result.status == TxStatus.pending) {
            _status = 'Pending confirmation on Sepolia…';
            _statusKind = TxBannerKind.pending;
          } else {
            _status = mine
                ? 'Purchase confirmed'
                : 'Purchase sent — ownership updating';
            _statusKind = TxBannerKind.success;
          }
        });
        ref.invalidate(listingDetailProvider(widget.listingId));
        ref.invalidate(marketplaceListingsProvider);
        ref.invalidate(ownedNftsProvider);
        ref.invalidate(myListingsProvider);
      }
    } catch (e) {
      setState(() {
        _status = e.toString();
        _statusKind = TxBannerKind.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _status = 'Confirm cancel in your wallet…';
      _statusKind = TxBannerKind.pending;
    });
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .cancelListing(widget.listingId);
      _lastTx = result.txHash;
      setState(() {
        _status = 'Listing cancelled — NFT returned to you';
        _statusKind = TxBannerKind.success;
      });
      ref.invalidate(listingDetailProvider(widget.listingId));
      ref.invalidate(marketplaceListingsProvider);
      ref.invalidate(ownedNftsProvider);
      ref.invalidate(myListingsProvider);
    } catch (e) {
      setState(() {
        _status = e.toString();
        _statusKind = TxBannerKind.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(connectedAddressProvider);
    final async = ref.watch(listingDetailProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: Column(
        children: [
          const PublicNoticeBanner(),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$e', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(
                          listingDetailProvider(widget.listingId),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (listing) {
                final meta = nftDisplayMeta(
                  tokenId: listing.tokenId,
                  tokenUri: listing.tokenUri,
                );
                final isSeller =
                    address != null && listing.isSellerOf(address);
                final canBuy =
                    listing.active && address != null && !isSeller;
                final canCancel = listing.active && isSeller;

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          NftArt(
                            tokenId: listing.tokenId,
                            imageUrl: meta.imageUrl,
                            borderRadius: 20,
                            aspectRatio: 1.05,
                            heroTag: 'listing-${listing.id}',
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: listing.active
                                      ? AppTheme.accent.withValues(alpha: 0.2)
                                      : AppTheme.ink.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  listing.active ? 'For sale' : 'Sold / closed',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: listing.active
                                        ? AppTheme.accentDim
                                        : AppTheme.ink.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Listing #${listing.id}',
                                style: TextStyle(
                                  color: AppTheme.ink.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            meta.title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${formatWeiAsEth(listing.priceWei)} ETH',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accentDim,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _InfoRow(label: 'Seller', value: listing.seller),
                          _InfoRow(
                            label: 'Token',
                            value: '#${listing.tokenId}',
                          ),
                          _InfoRow(
                            label: 'Current owner',
                            value: listing.currentNftOwner ?? '—',
                          ),
                          _InfoRow(
                            label: 'SDT fee burned',
                            value: '${formatWeiAsEth(listing.feePaid)} SDT',
                          ),
                          _InfoRow(
                            label: 'Seller stake',
                            value:
                                '${formatWeiAsEth(listing.stakeLocked)} SDT',
                          ),
                          if (meta.rawUri != null)
                            _InfoRow(label: 'URI', value: meta.rawUri!),
                          TextButton(
                            onPressed: () => launchUrl(
                              Uri.parse(
                                AppConfig.etherscanAddressUrl(
                                  AppConfig.marketplaceAddress,
                                ),
                              ),
                            ),
                            child: const Text('Marketplace on Etherscan'),
                          ),
                          if (_status != null) ...[
                            const SizedBox(height: 10),
                            TxStatusBanner(
                              message: _status!,
                              kind: _statusKind,
                              txHash: _ownedByMe ? null : _lastTx,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_ownedByMe && _ownerAfter != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: OwnershipCelebration(
                          title: meta.title,
                          ownerAddress: _ownerAfter!,
                          tokenId: listing.tokenId,
                        ),
                      )
                    else if (_ownerAfter != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                        child: TxStatusBanner(
                          message: 'Owner now: $_ownerAfter',
                          kind: TxBannerKind.success,
                          txHash: _lastTx,
                        ),
                      ),
                    _BottomActions(
                      listing: listing,
                      address: address,
                      canBuy: canBuy,
                      canCancel: canCancel,
                      busy: _busy,
                      onBuy: _buy,
                      onCancel: _cancel,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.listing,
    required this.address,
    required this.canBuy,
    required this.canCancel,
    required this.busy,
    required this.onBuy,
    required this.onCancel,
  });

  final MarketplaceListing listing;
  final String? address;
  final bool canBuy;
  final bool canCancel;
  final bool busy;
  final VoidCallback onBuy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      elevation: 8,
      color: AppTheme.shellSurface.withValues(alpha: 0.94),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (address == null)
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Connect wallet on Profile'),
              )
            else if (canBuy)
              FilledButton(
                onPressed: busy ? null : onBuy,
                child: Text(
                  busy
                      ? 'Waiting for wallet…'
                      : 'Buy for ${formatWeiAsEth(listing.priceWei)} ETH',
                ),
              )
            else if (canCancel)
              OutlinedButton(
                onPressed: busy ? null : onCancel,
                child: const Text('Cancel listing'),
              )
            else if (!listing.active)
              Text(
                'Listing closed — check My Items for NFTs you own.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.55),
                ),
              )
            else
              Text(
                'This is your listing. Buyers can purchase with ETH.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.ink.withValues(alpha: 0.45),
              fontWeight: FontWeight.w600,
            ),
          ),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
