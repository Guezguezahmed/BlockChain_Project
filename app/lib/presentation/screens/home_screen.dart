import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/public_notice_banner.dart';
import '../widgets/wallet_status_chip.dart';
import 'listing_detail_screen.dart';

/// Home tab: Smart Deal marketplace listings (primary product surface).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    this.onOpenCreate,
    this.onOpenProfile,
  });

  final VoidCallback? onOpenCreate;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceListingsProvider);
    final sdt = ref.watch(sdtInfoProvider).asData?.value;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;

    return Scaffold(
      body: Column(
        children: [
          const PublicNoticeBanner(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _HomeHero(
                    onOpenCreate: onOpenCreate,
                    sdtBalanceLabel: sdt == null
                        ? null
                        : '${formatWeiAsEth(sdt.balance, fractionDigits: 2)} SDT',
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Marketplace',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.ink,
                                  letterSpacing: -0.2,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        WalletStatusChip(onTap: onOpenProfile),
                        IconButton(
                          tooltip: 'Refresh',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            ref.invalidate(marketplaceListingsProvider);
                            ref.invalidate(sdtInfoProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                async.when(
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('$e')),
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding:
                              EdgeInsets.fromLTRB(24, 8, 24, bottomInset),
                          child: _EmptyListings(onOpenCreate: onOpenCreate),
                        ),
                      );
                    }
                    return SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final l = items[i];
                          return Material(
                            color: Colors.white.withValues(alpha: 0.55),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: AppTheme.ink.withValues(alpha: 0.07),
                                ),
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    AppTheme.accent.withValues(alpha: 0.25),
                                foregroundColor: AppTheme.ink,
                                child: Text(
                                  '#${l.tokenId}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                'Listing #${l.id} · NFT #${l.tokenId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${formatWeiAsEth(l.priceWei)} ETH · '
                                'seller ${l.shortSeller}\n'
                                '${l.tokenUri ?? l.shortNft}',
                              ),
                              isThreeLine: true,
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ListingDetailScreen(listingId: l.id),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({this.onOpenCreate, this.sdtBalanceLabel});

  final VoidCallback? onOpenCreate;
  final String? sdtBalanceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Smart Deal',
                style: TextStyle(
                  color: Color(0xFFE7F2EE),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Peer NFT marketplace',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  height: 1.08,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'List digital goods with an SDT fee + stake. Buyers pay ETH. '
                'Ownership moves on-chain — no middleman custody.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onOpenCreate,
                    icon: const Icon(Icons.storefront_rounded, size: 20),
                    label: const Text('Sell or mint'),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      [
                        if (sdtBalanceLabel != null) sdtBalanceLabel!,
                        AppConfig.useMock
                            ? 'Mock mode'
                            : 'Sepolia · live',
                      ].join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyListings extends StatelessWidget {
  const _EmptyListings({this.onOpenCreate});

  final VoidCallback? onOpenCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 40,
          color: AppTheme.ink.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 14),
        Text(
          'No active listings yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Mint a demo NFT, approve SDT, then list it for ETH.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onOpenCreate,
          child: const Text('Sell or mint'),
        ),
      ],
    );
  }
}
