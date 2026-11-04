import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

/// Shown when wallet is connected but not on Sepolia.
class WrongNetworkBanner extends ConsumerStatefulWidget {
  const WrongNetworkBanner({super.key});

  @override
  ConsumerState<WrongNetworkBanner> createState() => _WrongNetworkBannerState();
}

class _WrongNetworkBannerState extends ConsumerState<WrongNetworkBanner> {
  bool _busy = false;
  String? _error;

  Future<void> _switch() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(walletServiceProvider).ensureSepolia();
    } catch (e) {
      setState(() {
        _error =
            'Open MetaMask and select Sepolia, then tap Switch again. ($e)';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(walletSessionProvider).asData?.value ??
        ref.watch(walletServiceProvider).currentSession;
    if (session == null || session.isSepolia) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xFFFFF4D6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade900, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MetaMask is on the wrong chain (id ${session.chainId}). '
                    'Smart Deal only works on Sepolia.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _busy ? null : _switch,
                  child: Text(_busy ? '…' : 'Switch'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
