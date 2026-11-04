import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/listing_card.dart';
import '../widgets/nft_art.dart';
import '../widgets/public_notice_banner.dart';
import '../widgets/wallet_status_chip.dart';
import '../widgets/wrong_network_banner.dart';
import 'listing_detail_screen.dart';

/// Home tab: Smart Deal marketplace grid.
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
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2;

    return Scaffold(
      body: Column(
        children: [
          const PublicNoticeBanner(),
          const WrongNetworkBanner(),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.accentDim,
              onRefresh: () async {
                ref.invalidate(marketplaceListingsProvider);
                ref.invalidate(sdtInfoProvider);
                await ref.read(marketplaceListingsProvider.future);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _HomeHero(
                      onOpenCreate: onOpenCreate,
                      onOpenProfile: onOpenProfile,
                      sdtBalanceLabel: sdt == null
                          ? null
                          : '${formatWeiAsEth(sdt.balance, fractionDigits: 2)} SDT',
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 8, 4),
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
                            ),
                          ),
                          WalletStatusChip(
                            onTap: onOpenProfile,
                            showSdt: true,
                          ),
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
                    loading: () => SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, __) => const ListingCardSkeleton(),
                          childCount: 4,
                        ),
                      ),
                    ),
                    error: (e, _) => SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        message: '$e',
                        onRetry: () =>
                            ref.invalidate(marketplaceListingsProvider),
                      ),
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
                        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.68,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final l = items[i];
                              return ListingCard(
                                listing: l,
                                index: i,
                                onTap: () {
                                  Navigator.of(context).push(
                                    PageRouteBuilder<void>(
                                      transitionDuration:
                                          const Duration(milliseconds: 320),
                                      reverseTransitionDuration:
                                          const Duration(milliseconds: 240),
                                      pageBuilder: (_, anim, __) {
                                        return FadeTransition(
                                          opacity: anim,
                                          child: ListingDetailScreen(
                                            listingId: l.id,
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      );
                    },
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

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    this.onOpenCreate,
    this.onOpenProfile,
    this.sdtBalanceLabel,
  });

  final VoidCallback? onOpenCreate;
  final VoidCallback? onOpenProfile;
  final String? sdtBalanceLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: AppTheme.heroGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Smart Deal',
                      style: TextStyle(
                        color: Color(0xFFE7F2EE),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  if (sdtBalanceLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Text(
                        sdtBalanceLabel!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Discover & trade digital goods',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Browse listings, buy with ETH, sell with SDT fee + stake. '
                'Ownership moves on-chain — no middleman.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                    icon: const Icon(Icons.sell_rounded, size: 18),
                    label: const Text('Sell an NFT'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onOpenProfile,
                    child: const Text('Connect wallet'),
                  ),
                  Text(
                    AppConfig.useMock ? 'Mock mode' : 'Sepolia · live',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
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
          size: 44,
          color: AppTheme.ink.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 14),
        Text(
          'No active listings yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Be the first — mint a demo NFT and list it for ETH.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onOpenCreate,
          child: const Text('Sell or mint'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 40, color: AppTheme.ink.withValues(alpha: 0.35)),
          const SizedBox(height: 12),
          Text(
            'Couldn’t load listings',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
