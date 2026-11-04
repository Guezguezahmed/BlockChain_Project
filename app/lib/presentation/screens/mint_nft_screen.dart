import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/models/transaction_result.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'list_nft_screen.dart';

/// Mint a demo SmartDealNFT, then optionally jump to list.
class MintNftScreen extends ConsumerStatefulWidget {
  const MintNftScreen({super.key});

  @override
  ConsumerState<MintNftScreen> createState() => _MintNftScreenState();
}

class _MintNftScreenState extends ConsumerState<MintNftScreen> {
  final _uri = TextEditingController(
    text: 'ipfs://smart-deal/demo-pack.json',
  );
  bool _busy = false;
  String? _status;
  String? _tx;

  @override
  void dispose() {
    _uri.dispose();
    super.dispose();
  }

  Future<void> _mint() async {
    final uri = _uri.text.trim();
    if (uri.isEmpty) {
      setState(() => _status = 'Enter a metadata URI');
      return;
    }
    final address = ref.read(connectedAddressProvider);
    if (address == null) {
      setState(() => _status = 'Connect a wallet on Profile first');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Confirm mint in your wallet…';
      _tx = null;
    });
    try {
      final result =
          await ref.read(marketplaceRepositoryProvider).mintNft(uri);
      _tx = result.txHash;
      setState(() {
        _status = result.status == TxStatus.failed
            ? 'Mint failed'
            : 'Minted — you can list this NFT next';
      });
      ref.invalidate(ownedNftsProvider);
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(ownedNftsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mint demo NFT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Anyone can mint on SmartDealNFT. No admin can seize tokens. '
            'After mint, approve SDT + the NFT, then list for ETH.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uri,
            decoration: const InputDecoration(
              labelText: 'Metadata URI',
              hintText: 'ipfs://… or https://…',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _mint,
            child: Text(_busy ? 'Minting…' : 'Mint NFT'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!),
          ],
          if (_tx != null)
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse(AppConfig.etherscanTxUrl(_tx!))),
              child: const Text('View mint tx'),
            ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ListNftScreen(),
                ),
              );
            },
            child: const Text('Continue to list NFT'),
          ),
          const SizedBox(height: 24),
          Text(
            'Your NFTs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          owned.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (ids) {
              if (ids.isEmpty) {
                return Text(
                  'None yet on this wallet.',
                  style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.5),
                  ),
                );
              }
              return Column(
                children: [
                  for (final id in ids)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Token #$id'),
                      subtitle: Text(AppConfig.nftAddress),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
