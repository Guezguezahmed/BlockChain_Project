import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/transaction_result.dart';
import '../../domain/utils/nft_metadata.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/nft_art.dart';
import '../widgets/tx_status_banner.dart';
import 'list_nft_screen.dart';

/// Mint a demo SmartDealNFT, then optionally jump to list.
class MintNftScreen extends ConsumerStatefulWidget {
  const MintNftScreen({super.key});

  @override
  ConsumerState<MintNftScreen> createState() => _MintNftScreenState();
}

class _MintNftScreenState extends ConsumerState<MintNftScreen> {
  final _uri = TextEditingController(text: 'Teal Horizon Pass');
  bool _busy = false;
  String? _status;
  TxBannerKind _kind = TxBannerKind.info;
  String? _tx;
  BigInt? _mintedId;

  @override
  void dispose() {
    _uri.dispose();
    super.dispose();
  }

  Future<void> _mint() async {
    final uri = _uri.text.trim();
    if (uri.isEmpty) {
      setState(() {
        _status = 'Enter a title or metadata URI';
        _kind = TxBannerKind.error;
      });
      return;
    }
    final address = ref.read(connectedAddressProvider);
    if (address == null) {
      setState(() {
        _status = 'Connect a wallet on Profile first';
        _kind = TxBannerKind.error;
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Confirm mint in your wallet…';
      _kind = TxBannerKind.pending;
      _tx = null;
      _mintedId = null;
    });
    try {
      final market = ref.read(marketplaceRepositoryProvider);
      final before = await market.nextTokenId();
      final result = await market.mintNft(uri);
      _tx = result.txHash;
      if (result.status == TxStatus.failed) {
        setState(() {
          _status = 'Mint failed';
          _kind = TxBannerKind.error;
        });
      } else {
        // Mock stores id in contractAddress; chain uses sequential nextTokenId.
        final parsed = BigInt.tryParse(result.contractAddress ?? '');
        setState(() {
          _mintedId = parsed ?? before;
          _status = 'Minted — list it for ETH next';
          _kind = TxBannerKind.success;
        });
      }
      ref.invalidate(ownedNftsProvider);
    } catch (e) {
      setState(() {
        _status = e.toString();
        _kind = TxBannerKind.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(ownedNftsProvider);
    final previewId = _mintedId ?? BigInt.from(0);
    final previewMeta = nftDisplayMeta(
      tokenId: previewId == BigInt.zero ? BigInt.one : previewId,
      tokenUri: _uri.text.trim(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Mint demo NFT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Anyone can mint on SmartDealNFT. No admin can seize tokens. '
            'Use a short title or an ipfs/https URI.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 180,
              child: NftArt(
                tokenId: previewId == BigInt.zero ? BigInt.one : previewId,
                imageUrl: previewMeta.imageUrl,
                borderRadius: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _uri,
            decoration: const InputDecoration(
              labelText: 'Title or metadata URI',
              hintText: 'Teal Horizon Pass  or  ipfs://…',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _mint,
            child: Text(_busy ? 'Minting…' : 'Mint NFT'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            TxStatusBanner(message: _status!, kind: _kind, txHash: _tx),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ListNftScreen(initialTokenId: _mintedId),
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
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final id in ids)
                    SizedBox(
                      width: 100,
                      child: Column(
                        children: [
                          NftArt(tokenId: id, borderRadius: 12),
                          const SizedBox(height: 4),
                          Text(
                            '#$id',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
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
