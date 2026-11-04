import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/domain/wallet/wallet_session.dart';
import 'package:blockchain_app/presentation/providers/app_providers.dart';
import 'package:blockchain_app/presentation/theme/app_theme.dart';
import 'package:blockchain_app/presentation/widgets/wallet_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _WrongChainWallet extends MockWalletService {
  @override
  WalletSession? get currentSession => const WalletSession(
        address: '0x1111111111111111111111111111111111111111',
        chainId: 1, // Ethereum mainnet — not Sepolia
        isMock: true,
      );

  @override
  Stream<WalletSession?> get sessionChanges =>
      Stream<WalletSession?>.value(currentSession);
}

void main() {
  testWidgets('wrong chain chip says Switch to Sepolia, not Wrong network Sepolia',
      (tester) async {
    final wallet = _WrongChainWallet();
    addTearDown(wallet.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletServiceProvider.overrideWithValue(wallet),
          chainTxSenderProvider.overrideWithValue(wallet),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Center(child: WalletStatusChip())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Switch to Sepolia'), findsOneWidget);
    expect(find.textContaining('Wrong network'), findsNothing);
    expect(find.text('Wrong net'), findsNothing);
  });
}
