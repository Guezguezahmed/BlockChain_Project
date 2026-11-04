import 'package:flutter/material.dart';

import '../../domain/utils/nft_metadata.dart';
import '../theme/app_theme.dart';

/// Clear “you now own this” confirmation after a successful buy.
class OwnershipCelebration extends StatefulWidget {
  const OwnershipCelebration({
    super.key,
    required this.title,
    required this.ownerAddress,
    this.tokenId,
  });

  final String title;
  final String ownerAddress;
  final BigInt? tokenId;

  @override
  State<OwnershipCelebration> createState() => _OwnershipCelebrationState();
}

class _OwnershipCelebrationState extends State<OwnershipCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  late final Animation<double> _scale =
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: AppTheme.accent.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.verified_rounded,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You now own this',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.ink.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Owner ${shortWallet(widget.ownerAddress)}'
                        '${widget.tokenId != null ? ' · #${widget.tokenId}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.ink.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
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
