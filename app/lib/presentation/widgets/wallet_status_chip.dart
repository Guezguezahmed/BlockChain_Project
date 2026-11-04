import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class WalletStatusChip extends ConsumerWidget {
  const WalletStatusChip({
    super.key,
    this.onTap,
    this.showSdt = false,
  });

  final VoidCallback? onTap;
  final bool showSdt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(walletSessionProvider).asData?.value ??
        ref.watch(walletServiceProvider).currentSession;
    final sdt = showSdt ? ref.watch(sdtInfoProvider).asData?.value : null;

    final label = session == null
        ? 'Connect'
        : session.isSepolia
            ? session.shortAddress
            : 'Wrong net';

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
            if (session != null && sdt != null) ...[
              const SizedBox(width: 6),
              Text(
                '${formatWeiAsEth(sdt.balance, fractionDigits: 1)} SDT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentDim,
                ),
              ),
            ] else if (session != null) ...[
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
