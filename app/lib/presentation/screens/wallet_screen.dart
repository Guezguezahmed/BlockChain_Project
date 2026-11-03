import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../data/wallet/reown_wallet_service.dart';
import '../providers/app_providers.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String? _error;
  bool _busy = false;

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final wallet = ref.read(walletServiceProvider);
      await wallet.connect();
      await wallet.ensureSepolia();
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await ref.read(walletServiceProvider).disconnect();
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('rejected') || s.contains('User rejected')) {
      return 'Request rejected in the wallet.';
    }
    if (s.contains('PROJECT_ID')) {
      return 'Missing WALLETCONNECT_PROJECT_ID. See app/README.md.';
    }
    if (s.contains('Sepolia') || s.contains('network')) {
      return 'Wrong network — switch MetaMask to Sepolia.';
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(walletSessionProvider).asData?.value ??
        ref.watch(walletServiceProvider).currentSession;
    final wallet = ref.watch(walletServiceProvider);
    final reown = wallet is ReownWalletService ? wallet : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Connect with MetaMask via Reown AppKit (WalletConnect). '
            'Private keys never leave your wallet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (AppConfig.useMock)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.science_outlined),
              title: Text('Mock wallet mode'),
              subtitle: Text(
                'USE_MOCK=true — tap Connect to use a fake Sepolia address.',
              ),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(
                AppConfig.hasWalletConnectProjectId
                    ? 'Reown project configured'
                    : 'WALLETCONNECT_PROJECT_ID missing',
              ),
              subtitle: const Text('Network locked to Sepolia in AppKit config.'),
            ),
            if (reown?.modal != null) ...[
              const SizedBox(height: 8),
              AppKitModalNetworkSelectButton(appKit: reown!.modal!),
              const SizedBox(height: 8),
              AppKitModalConnectButton(appKit: reown.modal!),
              if (reown.modal!.isConnected) ...[
                const SizedBox(height: 8),
                AppKitModalAccountButton(appKitModal: reown.modal!),
              ],
            ],
          ],
          const SizedBox(height: 20),
          if (session == null)
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: Text(_busy ? 'Connecting…' : 'Connect wallet'),
            )
          else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Address'),
              subtitle: SelectableText(session.address),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Network'),
              subtitle: Text(
                session.isSepolia
                    ? '${AppConfig.networkName} (${session.chainId})'
                    : 'Chain ${session.chainId} — switch to Sepolia',
              ),
              trailing: session.isSepolia
                  ? null
                  : TextButton(
                      onPressed: () async {
                        try {
                          await wallet.ensureSepolia();
                        } catch (e) {
                          setState(() => _error = _friendly(e));
                        }
                      },
                      child: const Text('Switch'),
                    ),
            ),
            OutlinedButton(
              onPressed: _disconnect,
              child: const Text('Disconnect'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(AppConfig.etherscanAddressUrl(session.address)),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('View on Etherscan'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
