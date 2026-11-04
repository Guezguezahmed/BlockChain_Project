import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/utils/eth_formatting.dart';
import '../providers/app_providers.dart';
import 'contract_detail_screen.dart';
import 'wallet_screen.dart';

class MyContractsScreen extends ConsumerWidget {
  const MyContractsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(connectedAddressProvider);
    final async = ref.watch(myContractsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My contracts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(myContractsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: address == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Connect a wallet to see your escrows.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const WalletScreen(embedded: false),
                        ),
                      );
                    },
                    child: const Text('Connect wallet'),
                  ),
                ],
              ),
            )
          : async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No contracts yet for this wallet.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final role = c.isBuyerOf(address)
                        ? 'Buyer'
                        : c.isSellerOf(address)
                            ? 'Seller'
                            : '';
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      title: Text(
                        '${c.templateType.label} · ${c.state.label}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${formatWeiAsEth(c.amountWei)} ETH · $role\n'
                        '${c.address}',
                      ),
                      isThreeLine: true,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ContractDetailScreen(address: c.address),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
