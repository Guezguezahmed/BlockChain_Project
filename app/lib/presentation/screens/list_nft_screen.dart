import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/models/marketplace_listing.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/utils/eth_formatting.dart';
import '../../domain/utils/nft_metadata.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/nft_art.dart';
import '../widgets/sdt_faucet_note.dart';
import '../widgets/tx_status_banner.dart';

/// Approve SDT + NFT, then list on Marketplace for ETH.
class ListNftScreen extends ConsumerStatefulWidget {
  const ListNftScreen({super.key, this.initialTokenId});

  final BigInt? initialTokenId;

  @override
  ConsumerState<ListNftScreen> createState() => _ListNftScreenState();
}

class _ListNftScreenState extends ConsumerState<ListNftScreen> {
  final _price = TextEditingController(text: '0.05');
  BigInt? _selectedToken;
  bool _busy = false;
  String? _status;
  TxBannerKind _kind = TxBannerKind.info;
  String? _tx;
  int _stepDone = 0; // 0 none, 1 sdt, 2 nft, 3 listed

  @override
  void initState() {
    super.initState();
    _selectedToken = widget.initialTokenId;
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _approveSdt() async {
    final info = ref.read(sdtInfoProvider).asData?.value;
    if (info == null) {
      setState(() {
        _status = 'Connect wallet / load SDT info first';
        _kind = TxBannerKind.error;
      });
      return;
    }
    if (!info.hasEnoughSdt) {
      setState(() {
        _status =
            'Need ${formatWeiAsEth(info.requiredForList)} SDT (fee + stake).';
        _kind = TxBannerKind.error;
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Approve SDT in wallet…';
      _kind = TxBannerKind.pending;
    });
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .approveSdt(info.requiredForList);
      _tx = result.txHash;
      setState(() {
        _stepDone = 1;
        _status = result.status == TxStatus.failed
            ? 'SDT approve failed'
            : 'SDT approved for fee + stake';
        _kind = result.status == TxStatus.failed
            ? TxBannerKind.error
            : TxBannerKind.success;
      });
      ref.invalidate(sdtInfoProvider);
    } catch (e) {
      setState(() {
        _status = e.toString();
        _kind = TxBannerKind.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveNft() async {
    final token = _selectedToken;
    if (token == null) {
      setState(() {
        _status = 'Pick an NFT first';
        _kind = TxBannerKind.error;
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Approve NFT in wallet…';
      _kind = TxBannerKind.pending;
    });
    try {
      final result =
          await ref.read(marketplaceRepositoryProvider).approveNft(token);
      _tx = result.txHash;
      setState(() {
        _stepDone = 2;
        _status = result.status == TxStatus.failed
            ? 'NFT approve failed'
            : 'NFT approved — marketplace can custody it';
        _kind = result.status == TxStatus.failed
            ? TxBannerKind.error
            : TxBannerKind.success;
      });
    } catch (e) {
      setState(() {
        _status = e.toString();
        _kind = TxBannerKind.error;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _list() async {
    final token = _selectedToken;
    final wei = tryParseEthToWei(_price.text);
    if (token == null) {
      setState(() {
        _status = 'Pick an NFT first';
        _kind = TxBannerKind.error;
      });
      return;
    }
    if (wei == null || wei <= BigInt.zero) {
      setState(() {
        _status = 'Enter a valid ETH price';
        _kind = TxBannerKind.error;
      });
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Confirm list in wallet…';
      _kind = TxBannerKind.pending;
    });
    try {
      final result = await ref.read(marketplaceRepositoryProvider).listItem(
            ListNftParams(
              nft: AppConfig.nftAddress,
              tokenId: token,
              priceWei: wei,
            ),
          );
      _tx = result.txHash;
      setState(() {
        _stepDone = 3;
        _status = result.status == TxStatus.failed
            ? 'List failed'
            : 'Listed! Pull to refresh Market to see your card.';
        _kind = result.status == TxStatus.failed
            ? TxBannerKind.error
            : TxBannerKind.success;
      });
      ref.invalidate(marketplaceListingsProvider);
      ref.invalidate(ownedNftsProvider);
      ref.invalidate(myListingsProvider);
      ref.invalidate(sdtInfoProvider);
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
    final sdt = ref.watch(sdtInfoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('List NFT')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(
            'Sell flow: approve SDT (fee + stake) → approve NFT → list for ETH. '
            'Fee is burned; stake unlocks on sale or cancel.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 12),
          const SdtFaucetNote(),
          const SizedBox(height: 16),
          sdt.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => TxStatusBanner(
              message: '$e',
              kind: TxBannerKind.error,
            ),
            data: (info) {
              if (info == null) {
                return const TxStatusBanner(
                  message: 'Connect a wallet to see SDT balances.',
                );
              }
              return _FeeStakePanel(info: info);
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Choose NFT',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          owned.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('$e'),
            data: (ids) {
              if (ids.isEmpty) {
                return const TxStatusBanner(
                  message: 'Mint an NFT first — none owned on this wallet.',
                  kind: TxBannerKind.info,
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final id in ids)
                    _TokenPick(
                      tokenId: id,
                      selected: _selectedToken == id,
                      onTap: _busy
                          ? null
                          : () => setState(() => _selectedToken = id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (ETH)',
              hintText: '0.05',
            ),
          ),
          const SizedBox(height: 18),
          _StepButton(
            step: 1,
            label: 'Approve SDT (fee + stake)',
            done: _stepDone >= 1,
            onPressed: _busy ? null : _approveSdt,
          ),
          const SizedBox(height: 8),
          _StepButton(
            step: 2,
            label: 'Approve NFT',
            done: _stepDone >= 2,
            onPressed: _busy ? null : _approveNft,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _list,
            child: Text(_busy ? 'Working…' : '3 · List for ETH'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            TxStatusBanner(message: _status!, kind: _kind, txHash: _tx),
          ],
        ],
      ),
    );
  }
}

class _FeeStakePanel extends StatelessWidget {
  const _FeeStakePanel({required this.info});

  final SdtMarketInfo info;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your SDT: ${formatWeiAsEth(info.balance)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Listing fee ${formatWeiAsEth(info.quotedFee)} SDT (burned) + '
              'stake ${formatWeiAsEth(info.sellerStake)} SDT (locked)',
              style: TextStyle(
                height: 1.35,
                color: AppTheme.ink.withValues(alpha: 0.65),
              ),
            ),
            Text(
              'Total needed: ${formatWeiAsEth(info.requiredForList)} SDT',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: info.hasEnoughSdt
                    ? AppTheme.accentDim
                    : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TokenPick extends ConsumerWidget {
  const _TokenPick({
    required this.tokenId,
    required this.selected,
    this.onTap,
  });

  final BigInt tokenId;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uri = ref.watch(tokenUriProvider(tokenId)).asData?.value;
    final meta = nftDisplayMeta(tokenId: tokenId, tokenUri: uri);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 108,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.6),
          border: Border.all(
            color: selected
                ? AppTheme.accentDim
                : AppTheme.ink.withValues(alpha: 0.08),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            NftArt(
              tokenId: tokenId,
              imageUrl: meta.imageUrl,
              borderRadius: 10,
            ),
            const SizedBox(height: 6),
            Text(
              meta.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.step,
    required this.label,
    required this.done,
    this.onPressed,
  });

  final int step;
  final String label;
  final bool done;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: done ? AppTheme.accentDim : null,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text('$step · $label')),
        ],
      ),
    );
  }
}
