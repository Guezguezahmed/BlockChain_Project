import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/models/transaction_result.dart';
import '../theme/app_theme.dart';

enum TxBannerKind { pending, success, error, info }

/// Consistent pending / success / error strip for marketplace txs.
class TxStatusBanner extends StatelessWidget {
  const TxStatusBanner({
    super.key,
    required this.message,
    this.kind = TxBannerKind.info,
    this.txHash,
  });

  factory TxStatusBanner.fromResult({
    required TransactionResult result,
    required String successMessage,
    String? pendingMessage,
  }) {
    if (result.status == TxStatus.failed) {
      return TxStatusBanner(
        message: 'Transaction failed',
        kind: TxBannerKind.error,
        txHash: result.txHash,
      );
    }
    if (result.status == TxStatus.pending) {
      return TxStatusBanner(
        message: pendingMessage ?? 'Waiting for confirmation…',
        kind: TxBannerKind.pending,
        txHash: result.txHash,
      );
    }
    return TxStatusBanner(
      message: successMessage,
      kind: TxBannerKind.success,
      txHash: result.txHash,
    );
  }

  final String message;
  final TxBannerKind kind;
  final String? txHash;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (kind) {
      TxBannerKind.pending => (
          const Color(0xFFFFF4D6),
          const Color(0xFF7A5A00),
          Icons.hourglass_top_rounded,
        ),
      TxBannerKind.success => (
          AppTheme.accent.withValues(alpha: 0.22),
          AppTheme.ink,
          Icons.check_circle_rounded,
        ),
      TxBannerKind.error => (
          const Color(0xFFFFE2E0),
          const Color(0xFF8B1E1A),
          Icons.error_outline_rounded,
        ),
      TxBannerKind.info => (
          Colors.white.withValues(alpha: 0.7),
          AppTheme.ink,
          Icons.info_outline_rounded,
        ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (txHash != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: fg,
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.etherscanTxUrl(txHash!)),
                  ),
                  child: const Text('View on Etherscan'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
