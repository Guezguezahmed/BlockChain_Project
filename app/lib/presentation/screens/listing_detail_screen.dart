import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/public_notice_banner.dart';

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
  String? _lastTx;
  String? _ownerAfter;

  Future<void> _buy() async {
    setState(() {
      _busy = true;
      _status = 'Confirm buy in your wallet…';
      _lastTx = null;
      _ownerAfter = null;
    });
    try {
      final market = ref.read(marketplaceRepositoryProvider);
      final result = await market.buyItem(widget.listingId);
      _lastTx = result.txHash;
      if (result.status == TxStatus.failed) {
        setState(() => _status = 'Transaction failed');
      } else {
        final listing = await market.getListing(widget.listingId);
        final owner = listing.currentNftOwner ??
            await market.ownerOf(listing.tokenId);
        setState(() {
          _ownerAfter = owner;
          _status = result.status == TxStatus.pending
              ? 'Pending confirmation…'
              : 'Purchased — NFT ownership updated';
        });
        ref.invalidate(listingDetailProvider(widget.listingId));
        ref.invalidate(marketplaceListingsProvider);
        ref.invalidate(ownedNftsProvider);
      }
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _busy = true;
      _status = 'Confirm cancel in your wallet…';
    });
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .cancelListing(widget.listingId);
      _lastTx = result.txHash;
      setState(() => _status = 'Listing cancelled');
      ref.invalidate(listingDetailProvider(widget.listingId));
      ref.invalidate(marketplaceListingsProvider);
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = ref.watch(connectedAddressProvider);
    final async = ref.watch(listingDetailProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: Text('Listing #${widget.listingId}')),
      body: Column(
        children: [
          const PublicNoticeBanner(),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (listing) {
                final isSeller =
                    address != null && listing.isSellerOf(address);
                final canBuy =
                    listing.active && address != null && !isSeller;
                final canCancel = listing.active && isSeller;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      listing.active ? 'Active' : 'Closed',
                      style: TextStyle(
                        color: listing.active
                            ? AppTheme.accentDim
                            : AppTheme.ink.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatWeiAsEth(listing.priceWei)} ETH',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    _row('NFT', '#${listing.tokenId}'),
                    _row('Collection', listing.nft),
                    _row('Seller', listing.seller),
                    if (listing.tokenUri != null)
                      _row('URI', listing.tokenUri!),
                    _row(
                      'Current owner',
                      listing.currentNftOwner ?? '—',
                    ),
                    _row(
                      'SDT fee paid',
                      '${formatWeiAsEth(listing.feePaid)} SDT',
                    ),
                    _row(
                      'Stake locked',
                      '${formatWeiAsEth(listing.stakeLocked)} SDT',
                    ),
                    const SizedBox(height: 8),
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
                    if (_ownerAfter != null) ...[
                      const SizedBox(height: 12),
                      Material(
                        color: AppTheme.accent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Ownership now: $_ownerAfter',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                    if (_status != null) ...[
                      const SizedBox(height: 12),
                      Text(_status!, style: const TextStyle(fontSize: 13)),
                    ],
                    if (_lastTx != null)
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(AppConfig.etherscanTxUrl(_lastTx!)),
                        ),
                        child: const Text('View transaction'),
                      ),
                    const SizedBox(height: 20),
                    if (address == null)
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Connect wallet on Profile'),
                      )
                    else ...[
                      if (canBuy)
                        FilledButton(
                          onPressed: _busy ? null : _buy,
                          child: Text(
                            _busy
                                ? 'Working…'
                                : 'Buy for ${formatWeiAsEth(listing.priceWei)} ETH',
                          ),
                        ),
                      if (canCancel) ...[
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _busy ? null : _cancel,
                          child: const Text('Cancel listing'),
                        ),
                      ],
                      if (!listing.active)
                        Text(
                          'This listing is closed. NFT ownership is on-chain.',
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: 0.55),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
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
