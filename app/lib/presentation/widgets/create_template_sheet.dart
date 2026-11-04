import 'package:flutter/material.dart';

import '../screens/create_escrow_screen.dart';
import '../theme/app_theme.dart';

/// Half-height create sheet: template blocks for Escrow (live) and later presets.
Future<void> showCreateTemplateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF4FAF7),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.52;
      return SizedBox(
        height: height,
        child: const _CreateTemplateSheetBody(),
      );
    },
  );
}

class _CreateTemplateSheetBody extends StatelessWidget {
  const _CreateTemplateSheetBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a template',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Fill a short form — the factory deploys a real contract on Sepolia.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                _TemplateBlock(
                  title: 'Escrow',
                  subtitle:
                      'Buyer locks ETH, releases to seller when satisfied, or gets refunded.',
                  icon: Icons.lock_outline_rounded,
                  badge: 'Live',
                  enabled: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CreateEscrowScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const _TemplateBlock(
                  title: 'Rental',
                  subtitle: 'Fee + deposit, return rules, lateness penalty.',
                  icon: Icons.home_work_outlined,
                  badge: 'Soon',
                  enabled: false,
                ),
                const SizedBox(height: 10),
                const _TemplateBlock(
                  title: 'Milestone payment',
                  subtitle: 'Client funds a project; pay per approved milestone.',
                  icon: Icons.flag_outlined,
                  badge: 'Soon',
                  enabled: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateBlock extends StatelessWidget {
  const _TemplateBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.badge,
    required this.enabled,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String badge;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink;
    final border = enabled
        ? ink.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.06);
    final bg = enabled
        ? Colors.white.withValues(alpha: 0.92)
        : Colors.black.withValues(alpha: 0.04);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: enabled
                      ? AppTheme.accent.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? AppTheme.accentDim : Colors.black38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: enabled ? ink : Colors.black45,
                                ),
                          ),
                        ),
                        _Badge(label: badge, live: enabled),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: enabled
                                ? ink.withValues(alpha: 0.7)
                                : Colors.black38,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: ink.withValues(alpha: 0.35)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: live
            ? AppTheme.accent.withValues(alpha: 0.22)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: live ? AppTheme.accentDim : Colors.black45,
        ),
      ),
    );
  }
}
