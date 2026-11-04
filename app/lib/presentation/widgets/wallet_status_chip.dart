import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class WalletStatusChip extends ConsumerWidget {
  const WalletStatusChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(walletSessionProvider).asData?.value ??
        ref.watch(walletServiceProvider).currentSession;

    final label = session == null
        ? 'Connect wallet'
        : session.isSepolia
            ? session.shortAddress
            : 'Wrong network';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.ink.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.ink.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              session == null
                  ? Icons.account_balance_wallet_outlined
                  : Icons.circle,
              size: session == null ? 15 : 9,
              color: session == null
                  ? AppTheme.ink
                  : session.isSepolia
                      ? AppTheme.accent
                      : Colors.orange.shade800,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (session != null) ...[
              const SizedBox(width: 5),
              Text(
                AppConfig.networkName,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.ink.withValues(alpha: 0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
