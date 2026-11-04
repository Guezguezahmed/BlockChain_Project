import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/utils/eth_formatting.dart';
import '../../domain/utils/nft_metadata.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/nft_art.dart';
import '../widgets/public_notice_banner.dart';
import '../widgets/wrong_network_banner.dart';
import 'list_nft_screen.dart';
import 'listing_detail_screen.dart';
import 'mint_nft_screen.dart';

/// Inventory: owned NFTs + my active listings.
class MyItemsScreen extends ConsumerWidget {
  const MyItemsScreen({
    super.key,
    this.onOpenCreate,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenCreate;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(connectedAddressProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;
    final owned = ref.watch(ownedNftsProvider);
    final mine = ref.watch(myListingsProvider);
    final sdt = ref.watch(sdtInfoProvider).asData?.value;

    return Scaffold(
      body: Column(
        children: [
          const PublicNoticeBanner(),
          const WrongNetworkBanner(),
          Expanded(
            child: address == null
                ? _ConnectPrompt(
                    bottomInset: bottomInset,
                    onOpenProfile: onOpenProfile,
                  )
                : RefreshIndicator(
                    color: AppTheme.accentDim,
                    onRefresh: () async {
                      ref.invalidate(ownedNftsProvider);
                      ref.invalidate(myListingsProvider);
                      ref.invalidate(sdtInfoProvider);
                      await Future.wait([
                        ref.read(ownedNftsProvider.future),
                        ref.read(myListingsProvider.future),
                      ]);
                    },
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset),
                      children: [
                        SafeArea(
                          bottom: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'My items',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                      ),
                                ),
                              ),
                              if (sdt != null)
                                Text(
                                  '${formatWeiAsEth(sdt.balance, fractionDigits: 1)} SDT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentDim,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          shortWallet(address),
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const MintNftScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: const Text('Mint'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const ListNftScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.sell_rounded),
                                label: const Text('List'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Owned NFTs',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        owned.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          error: (e, _) => Text('$e'),
                          data: (ids) {
                            if (ids.isEmpty) {
                              return _SoftEmpty(
                                message: 'No NFTs in this wallet yet.',
                                actionLabel: 'Mint demo NFT',
                                onAction: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const MintNftScreen(),
                                    ),
                                  );
                                },
                              );
                            }
                            return SizedBox(
                              height: 168,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: ids.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 10),
                                itemBuilder: (context, i) {
                                  final id = ids[i];
                                  return _OwnedTile(
                                    tokenId: id,
                                    onList: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ListNftScreen(),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'My listings',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        mine.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('$e'),
                          data: (listings) {
                            if (listings.isEmpty) {
                              return _SoftEmpty(
                                message: 'No active listings from you.',
                                actionLabel: 'List an NFT',
                                onAction: onOpenCreate,
                              );
                            }
                            return Column(
                              children: [
                                for (final l in listings)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Material(
                                      color: Colors.white.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(16),
                                      child: ListTile(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          side: BorderSide(
                                            color: AppTheme.ink
                                                .withValues(alpha: 0.07),
                                          ),
                                        ),
                                        leading: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: NftArt(
                                            tokenId: l.tokenId,
                                            imageUrl: nftDisplayMeta(
                                              tokenId: l.tokenId,
                                              tokenUri: l.tokenUri,
                                            ).imageUrl,
                                            borderRadius: 10,
                                          ),
                                        ),
                                        title: Text(
                                          nftDisplayMeta(
                                            tokenId: l.tokenId,
                                            tokenUri: l.tokenUri,
                                          ).title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${formatWeiAsEth(l.priceWei)} ETH · '
                                          '${l.active ? 'Active' : 'Closed'}',
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) =>
                                                  ListingDetailScreen(
                                                listingId: l.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Collection ${AppConfig.nftAddress}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.ink.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OwnedTile extends ConsumerWidget {
  const _OwnedTile({required this.tokenId, required this.onList});

  final BigInt tokenId;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uriAsync = ref.watch(tokenUriProvider(tokenId));
    final uri = uriAsync.asData?.value;
    final meta = nftDisplayMeta(tokenId: tokenId, tokenUri: uri);

    return SizedBox(
      width: 132,
      child: Material(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onList,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: NftArt(
                    tokenId: tokenId,
                    imageUrl: meta.imageUrl,
                    borderRadius: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  meta.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'List →',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.accentDim,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectPrompt extends StatelessWidget {
  const _ConnectPrompt({required this.bottomInset, this.onOpenProfile});

  final double bottomInset;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 44,
            color: AppTheme.ink.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 14),
          Text(
            'Connect a wallet to see your NFTs and listings.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onOpenProfile,
            child: const Text('Open Profile'),
          ),
        ],
      ),
    );
  }
}

class _SoftEmpty extends StatelessWidget {
  const _SoftEmpty({
    required this.message,
    required this.actionLabel,
    this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(
            message,
            style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 10),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
