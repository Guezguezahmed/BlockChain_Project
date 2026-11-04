import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../domain/models/marketplace_listing.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/sdt_faucet_note.dart';

/// Approve SDT + NFT, then list on Marketplace for ETH.
class ListNftScreen extends ConsumerStatefulWidget {
  const ListNftScreen({super.key});

  @override
  ConsumerState<ListNftScreen> createState() => _ListNftScreenState();
}

class _ListNftScreenState extends ConsumerState<ListNftScreen> {
  final _price = TextEditingController(text: '0.05');
  BigInt? _selectedToken;
  bool _busy = false;
  String? _status;
  String? _tx;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _approveSdt() async {
    final info = ref.read(sdtInfoProvider).asData?.value;
    if (info == null) {
      setState(() => _status = 'Connect wallet / load SDT info first');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Approve SDT in wallet…';
    });
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .approveSdt(info.requiredForList);
      _tx = result.txHash;
      setState(() => _status = 'SDT approved for marketplace');
      ref.invalidate(sdtInfoProvider);
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approveNft() async {
    final token = _selectedToken;
    if (token == null) {
      setState(() => _status = 'Pick an NFT first');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Approve NFT in wallet…';
    });
    try {
      final result =
          await ref.read(marketplaceRepositoryProvider).approveNft(token);
      _tx = result.txHash;
      setState(() => _status = 'NFT approved for marketplace');
    } catch (e) {
      setState(() => _status = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _list() async {
    final token = _selectedToken;
    final wei = tryParseEthToWei(_price.text);
    if (token == null) {
      setState(() => _status = 'Pick an NFT first');
      return;
    }
    if (wei == null || wei <= BigInt.zero) {
      setState(() => _status = 'Enter a valid ETH price');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Confirm list in wallet…';
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
        _status = result.status == TxStatus.failed
            ? 'List failed'
            : 'Listed — home feed will show it after refresh';
      });
      ref.invalidate(marketplaceListingsProvider);
      ref.invalidate(ownedNftsProvider);
      ref.invalidate(sdtInfoProvider);
    } catch (e) {
      setState(() => _status = e.toString());
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
            'Listing burns an SDT fee and locks seller stake until sale '
            'or cancel. Buyers pay the price in ETH; the NFT transfers '
            'to them on purchase.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 12),
          const SdtFaucetNote(),
          const SizedBox(height: 16),
          sdt.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e'),
            data: (info) {
              if (info == null) {
                return const Text('Connect a wallet to see SDT balances.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your SDT: ${formatWeiAsEth(info.balance)} · '
                    'fee ${formatWeiAsEth(info.quotedFee)} + '
                    'stake ${formatWeiAsEth(info.sellerStake)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (!info.hasEnoughSdt)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Need ${formatWeiAsEth(info.requiredForList)} SDT '
                        'to list (fee + stake).',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Your NFTs',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          owned.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Text('$e'),
            data: (ids) {
              if (ids.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Mint an NFT first — none owned on this wallet.'),
                );
              }
              return Column(
                children: [
                  for (final id in ids)
                    RadioListTile<BigInt>(
                      contentPadding: EdgeInsets.zero,
                      value: id,
                      groupValue: _selectedToken,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _selectedToken = v),
                      title: Text('Token #$id'),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Price (ETH)',
              hintText: '0.05',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _busy ? null : _approveSdt,
            child: const Text('1 · Approve SDT'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _approveNft,
            child: const Text('2 · Approve NFT'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _list,
            child: Text(_busy ? 'Working…' : '3 · List for ETH'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!),
          ],
          if (_tx != null)
            TextButton(
              onPressed: () =>
                  launchUrl(Uri.parse(AppConfig.etherscanTxUrl(_tx!))),
              child: const Text('View transaction'),
            ),
        ],
      ),
    );
  }
}
