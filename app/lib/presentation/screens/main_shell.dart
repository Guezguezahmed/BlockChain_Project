import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sell_flow_store.dart';
import '../theme/app_theme.dart';
import '../widgets/create_template_sheet.dart';
import 'home_screen.dart';
import 'list_nft_screen.dart';
import 'my_items_screen.dart';
import 'wallet_screen.dart';

/// App chrome: Market · My Items · center Sell FAB · Profile.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tab = 0;
  double _fabScale = 1;

  Future<void> _openCreate() async {
    HapticFeedback.lightImpact();
    setState(() => _fabScale = 0.88);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _fabScale = 1);
    await showCreateTemplateSheet(context);
  }

  void _resumeListing() {
    final snap = ref.read(sellFlowProvider);
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListNftScreen(initialTokenId: snap.tokenId),
      ),
    );
  }

  Future<void> _dismissResume() async {
    await ref.read(sellFlowProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final flow = ref.watch(sellFlowProvider);

    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          if (flow.canResume)
            SafeArea(
              bottom: false,
              child: Material(
                color: AppTheme.accent.withValues(alpha: 0.92),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.playlist_add_check_rounded, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          flow.tokenId == null
                              ? 'Continue listing (step ${flow.stepDone + 1} of 3)'
                              : 'Continue listing #${flow.tokenId} · step ${flow.stepDone + 1}/3',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _resumeListing,
                        child: const Text('Resume'),
                      ),
                      IconButton(
                        tooltip: 'Dismiss',
                        onPressed: _dismissResume,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                HomeScreen(
                  onOpenCreate: _openCreate,
                  onOpenProfile: () => setState(() => _tab = 2),
                ),
                MyItemsScreen(
                  onOpenCreate: _openCreate,
                  onOpenProfile: () => setState(() => _tab = 2),
                ),
                const WalletScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedScale(
        scale: _fabScale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: FloatingActionButton(
          onPressed: _openCreate,
          tooltip: 'Sell or mint',
          elevation: 2,
          highlightElevation: 4,
          backgroundColor: AppTheme.accent,
          foregroundColor: AppTheme.ink,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: BottomAppBar(
            color: AppTheme.shellSurface.withValues(alpha: 0.72),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 64 + bottomInset,
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.storefront_outlined,
                        selectedIcon: Icons.storefront_rounded,
                        label: 'Market',
                        selected: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.inventory_2_outlined,
                        selectedIcon: Icons.inventory_2_rounded,
                        label: 'My Items',
                        selected: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ),
                    const SizedBox(width: 72),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.account_balance_wallet_outlined,
                        selectedIcon: Icons.account_balance_wallet_rounded,
                        label: 'Profile',
                        selected: _tab == 2,
                        onTap: () => setState(() => _tab = 2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? AppTheme.accentDim : AppTheme.ink.withValues(alpha: 0.42);
    return InkWell(
      onTap: onTap,
      splashColor: AppTheme.accent.withValues(alpha: 0.12),
      highlightColor: AppTheme.accent.withValues(alpha: 0.06),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              selected ? selectedIcon : icon,
              key: ValueKey(selected),
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: -0.1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
