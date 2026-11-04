import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/public_notice_banner.dart';
import '../widgets/wallet_status_chip.dart';
import 'contract_detail_screen.dart';

/// Home tab: compact brand header + contracts overview.
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
    final address = ref.watch(connectedAddressProvider);
    final async = ref.watch(myContractsProvider);
    // Extra bottom padding so list content clears the notched bar + FAB.
    final bottomInset = MediaQuery.paddingOf(context).bottom + 88;

    return Scaffold(
      body: Column(
        children: [
          const PublicNoticeBanner(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _HomeHero(onOpenCreate: onOpenCreate)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'My contracts',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                        ),
                        const Spacer(),
                        WalletStatusChip(onTap: onOpenProfile),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () =>
                              ref.invalidate(myContractsProvider),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                if (address == null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 8, 24, bottomInset),
                      child: _EmptyConnect(onOpenProfile: onOpenProfile),
                    ),
                  )
                else
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
                            child: _EmptyContracts(onOpenCreate: onOpenCreate),
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
                            final c = items[i];
                            final role = c.isBuyerOf(address)
                                ? 'Buyer'
                                : c.isSellerOf(address)
                                    ? 'Seller'
                                    : '';
                            return Material(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(14),
                              child: ListTile(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: AppTheme.ink.withValues(alpha: 0.08),
                                  ),
                                ),
                                title: Text(
                                  '${c.templateType.label} · ${c.state.label}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  '${formatWeiAsEth(c.amountWei)} ETH · $role\n'
                                  '${c.address}',
                                ),
                                isThreeLine: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ContractDetailScreen(
                                        address: c.address,
                                      ),
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
  const _HomeHero({this.onOpenCreate});

  final VoidCallback? onOpenCreate;

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
                'Contract Builder',
                style: TextStyle(
                  color: Color(0xFFE7F2EE),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No-code smart contracts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap + to pick a template. You sign; Sepolia enforces the rules.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: AppTheme.ink,
                    ),
                    onPressed: onOpenCreate,
                    child: const Text('Create a contract'),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      AppConfig.useMock
                          ? 'Mock mode'
                          : AppConfig.hasFactoryAddress
                              ? 'Sepolia · live'
                              : 'Sepolia · factory missing',
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

class _EmptyConnect extends StatelessWidget {
  const _EmptyConnect({this.onOpenProfile});

  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 40,
          color: AppTheme.ink.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 14),
        Text(
          'Connect a wallet to see your escrows.',
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
    );
  }
}

class _EmptyContracts extends StatelessWidget {
  const _EmptyContracts({this.onOpenCreate});

  final VoidCallback? onOpenCreate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 40,
          color: AppTheme.ink.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 14),
        Text(
          'No contracts yet for this wallet.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Use the + button to deploy an Escrow.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onOpenCreate,
          child: const Text('Create Escrow'),
        ),
      ],
    );
  }
}
