import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/create_template_sheet.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';

/// App chrome: Home · center Create FAB · Profile, with pushed flows on top.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  double _fabScale = 1;

  Future<void> _openCreate() async {
    setState(() => _fabScale = 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _fabScale = 1);
    await showCreateTemplateSheet(context);
  }

  void _goHome() => setState(() => _tab = 0);

  void _goProfile() => setState(() => _tab = 1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(
            onOpenCreate: _openCreate,
            onOpenProfile: _goProfile,
          ),
          const WalletScreen(embedded: true),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedScale(
        scale: _fabScale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: FloatingActionButton(
          onPressed: _openCreate,
          tooltip: 'Create contract',
          elevation: 3,
          backgroundColor: AppTheme.accent,
          foregroundColor: AppTheme.ink,
          child: const Icon(Icons.add_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFFF4FAF7),
        elevation: 8,
        shadowColor: AppTheme.ink.withValues(alpha: 0.12),
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: _tab == 0,
                  onTap: _goHome,
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                child: _NavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet_rounded,
                  label: 'Profile',
                  selected: _tab == 1,
                  onTap: _goProfile,
                ),
              ),
            ],
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
        selected ? AppTheme.accentDim : AppTheme.ink.withValues(alpha: 0.45);
    return InkWell(
      onTap: onTap,
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
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
