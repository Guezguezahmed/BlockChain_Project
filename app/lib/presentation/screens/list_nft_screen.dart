import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../domain/models/marketplace_listing.dart';
import '../../domain/models/transaction_result.dart';
import '../../domain/utils/eth_formatting.dart';
import '../../domain/utils/nft_metadata.dart';
import '../providers/app_providers.dart';
import '../providers/sell_flow_store.dart';
import '../theme/app_theme.dart';
import '../widgets/nft_art.dart';
import '../widgets/sdt_faucet_note.dart';
import '../widgets/tx_status_banner.dart';

/// Approve SDT + NFT, then list on Marketplace for ETH.
///
/// Survives MetaMask app-switches: progress is persisted locally and
/// re-synced from chain (allowance / NFT approval) when the app resumes.
class ListNftScreen extends ConsumerStatefulWidget {
  const ListNftScreen({super.key, this.initialTokenId});

  final BigInt? initialTokenId;

  @override
  ConsumerState<ListNftScreen> createState() => _ListNftScreenState();
}

class _ListNftScreenState extends ConsumerState<ListNftScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _price;
  BigInt? _selectedToken;
  bool _busy = false;
  bool _syncing = false;
  String? _status;
  TxBannerKind _kind = TxBannerKind.info;
  String? _tx;
  int _stepDone = 0; // 0 none, 1 sdt, 2 nft, 3 listed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final snap = ref.read(sellFlowProvider);
    _selectedToken = widget.initialTokenId ?? snap.tokenId;
    _price = TextEditingController(text: snap.priceEth);
    _stepDone = snap.stepDone.clamp(0, 2);
    // ignore: discarded_futures
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final snap = ref.read(sellFlowProvider);
    if (snap.canResume) {
      // Restore token/price/step from the interrupted MetaMask session.
      if (_selectedToken == null && snap.tokenId != null) {
        setState(() => _selectedToken = snap.tokenId);
      }
      if (_price.text != snap.priceEth) {
        _price.text = snap.priceEth;
      }
      setState(() => _stepDone = snap.stepDone.clamp(0, 2));
    }
    await _syncFromChain(reason: 'Opened list flow');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _price.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // MetaMask returns here — re-read on-chain approvals.
      // ignore: discarded_futures
      _syncFromChain(reason: 'Back from wallet');
    }
  }

  Future<void> _persistDraft() async {
    final ctrl = ref.read(sellFlowProvider.notifier);
    await ctrl.begin(
      tokenId: _selectedToken,
      priceEth: _price.text,
      stepDone: _stepDone.clamp(0, 2),
    );
  }

  /// Source of truth is the chain — local stepDone is a cache.
  Future<void> _syncFromChain({String? reason}) async {
    if (!mounted || _busy) return;
    setState(() => _syncing = true);
    try {
      ref.invalidate(sdtInfoProvider);
      final info = await ref.read(sdtInfoProvider.future);
      var chainStep = 0;
      if (info != null && info.hasEnoughAllowance) {
        chainStep = 1;
      }

      final token = _selectedToken;
      if (token != null && chainStep >= 1) {
        try {
          final approved = await ref
              .read(marketplaceRepositoryProvider)
              .isNftApprovedForMarketplace(token);
          if (approved) chainStep = 2;
        } catch (_) {
          // Keep SDT step if NFT check fails (RPC blip).
        }
      }

      if (!mounted) return;
      // Prefer the further-along of cache vs chain (RPC can lag right after tx).
      final next = chainStep > _stepDone ? chainStep : _stepDone;
      final advanced = next > _stepDone;
      setState(() {
        _stepDone = next;
        if (advanced) {
          _status = reason == null
              ? 'Synced: step $_stepDone of 3 ready'
              : '$reason — step $_stepDone of 3 ready';
          _kind = TxBannerKind.success;
        } else if (reason == 'Back from wallet') {
          _status =
              'Wallet returned. Approvals on-chain: step $_stepDone of 3.';
          _kind = TxBannerKind.info;
        }
      });

      // Activate resume banner only once we have real progress.
      if (_stepDone > 0 || ref.read(sellFlowProvider).canResume) {
        await ref.read(sellFlowProvider.notifier).begin(
              tokenId: _selectedToken,
              priceEth: _price.text,
              stepDone: _stepDone,
            );
      } else if (_selectedToken != null) {
        await ref.read(sellFlowProvider.notifier).setToken(_selectedToken);
        await ref.read(sellFlowProvider.notifier).setPrice(_price.text);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Could not sync approvals: $e';
        _kind = TxBannerKind.error;
      });
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
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
    if (info.hasEnoughAllowance) {
      setState(() {
        _stepDone = _stepDone < 1 ? 1 : _stepDone;
        _status = 'SDT already approved on-chain — continue to NFT approve';
        _kind = TxBannerKind.success;
      });
      await ref.read(sellFlowProvider.notifier).setStepDone(_stepDone);
      return;
    }

    await _persistDraft();
    setState(() {
      _busy = true;
      _status =
          'Approve SDT in MetaMask… You can switch apps; progress is saved.';
      _kind = TxBannerKind.pending;
    });
    try {
      final result = await ref
          .read(marketplaceRepositoryProvider)
          .approveSdt(info.requiredForList);
      _tx = result.txHash;
      if (result.status == TxStatus.failed) {
        setState(() {
          _status = 'SDT approve failed';
          _kind = TxBannerKind.error;
        });
      } else {
        setState(() {
          _stepDone = 1;
          _status = result.status == TxStatus.pending
              ? 'SDT approve submitted — waiting for confirmation'
              : 'SDT approved for fee + stake';
          _kind = result.status == TxStatus.pending
              ? TxBannerKind.pending
              : TxBannerKind.success;
        });
        await ref.read(sellFlowProvider.notifier).setStepDone(1);
      }
      ref.invalidate(sdtInfoProvider);
    } catch (e) {
      setState(() {
        _status = e.toString();
        _kind = TxBannerKind.error;
      });
      // Still sync — user may have confirmed in MetaMask while we timed out.
      await _syncFromChain(reason: 'Checking if approve landed');
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

    try {
      final already = await ref
          .read(marketplaceRepositoryProvider)
          .isNftApprovedForMarketplace(token);
      if (already) {
        setState(() {
          _stepDone = _stepDone < 2 ? 2 : _stepDone;
          _status = 'NFT already approved — you can list for ETH';
          _kind = TxBannerKind.success;
        });
        await ref.read(sellFlowProvider.notifier).setStepDone(_stepDone);
        return;
      }
    } catch (_) {}

    await _persistDraft();
    setState(() {
      _busy = true;
      _status =
          'Approve NFT in MetaMask… Progress is saved if the app switches.';
      _kind = TxBannerKind.pending;
    });
    try {
      final result =
          await ref.read(marketplaceRepositoryProvider).approveNft(token);
      _tx = result.txHash;
      if (result.status == TxStatus.failed) {
        setState(() {
          _status = 'NFT approve failed';
          _kind = TxBannerKind.error;
        });
      } else {
        setState(() {
          _stepDone = 2;
          _status = result.status == TxStatus.pending
              ? 'NFT approve submitted — waiting for confirmation'
              : 'NFT approved — marketplace can custody it';
          _kind = result.status == TxStatus.pending
              ? TxBannerKind.pending
              : TxBannerKind.success;
        });
        await ref.read(sellFlowProvider.notifier).setStepDone(2);
      }
    } catch (e) {
      setState(() {
        _status = e.toString();
        _kind = TxBannerKind.error;
      });
      await _syncFromChain(reason: 'Checking if NFT approve landed');
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

    await _persistDraft();
    setState(() {
      _busy = true;
      _status = 'Confirm list in MetaMask…';
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
      if (result.status == TxStatus.failed) {
        setState(() {
          _status = 'List failed';
          _kind = TxBannerKind.error;
        });
      } else {
        setState(() {
          _stepDone = 3;
          _status = result.status == TxStatus.pending
              ? 'List submitted — pull to refresh Market when confirmed'
              : 'Listed! Pull to refresh Market to see your card.';
          _kind = result.status == TxStatus.pending
              ? TxBannerKind.pending
              : TxBannerKind.success;
        });
        await ref.read(sellFlowProvider.notifier).setStepDone(3);
      }
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

  void _onTokenPicked(BigInt id) {
    setState(() {
      _selectedToken = id;
      // Changing NFT may invalidate NFT-approval step.
      if (_stepDone >= 2) _stepDone = 1;
    });
    // ignore: discarded_futures
    () async {
      await ref.read(sellFlowProvider.notifier).setToken(id);
      await ref.read(sellFlowProvider.notifier).setStepDone(_stepDone);
      await _syncFromChain();
    }();
  }

  @override
  Widget build(BuildContext context) {
    final owned = ref.watch(ownedNftsProvider);
    final sdt = ref.watch(sdtInfoProvider);
    final flow = ref.watch(sellFlowProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('List NFT'),
        actions: [
          if (_syncing || flow.canResume)
            IconButton(
              tooltip: 'Sync approvals from chain',
              onPressed: _busy ? null : () => _syncFromChain(reason: 'Manual sync'),
              icon: _syncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
        ],
      ),
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
          const SizedBox(height: 8),
          Text(
            'Switching to MetaMask is fine — this screen saves your progress, '
            'and approvals live on-chain even if the app restarts.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.ink.withValues(alpha: 0.55),
                  height: 1.35,
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
                      onTap: _busy ? null : () => _onTokenPicked(id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              // ignore: discarded_futures
              ref.read(sellFlowProvider.notifier).setPrice(v);
            },
            decoration: const InputDecoration(
              labelText: 'Price (ETH)',
              hintText: '0.05',
            ),
          ),
          const SizedBox(height: 18),
          _StepButton(
            step: 1,
            label: _stepDone >= 1
                ? 'SDT approved'
                : 'Approve SDT (fee + stake)',
            done: _stepDone >= 1,
            onPressed: _busy ? null : _approveSdt,
          ),
          const SizedBox(height: 8),
          _StepButton(
            step: 2,
            label: _stepDone >= 2 ? 'NFT approved' : 'Approve NFT',
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
            if (info.hasEnoughAllowance) ...[
              const SizedBox(height: 6),
              Text(
                'Marketplace allowance OK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentDim,
                ),
              ),
            ],
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
