import 'package:blockchain_app/data/repositories/mock_contract_repository.dart';
import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/presentation/providers/app_providers.dart';
import 'package:blockchain_app/presentation/screens/home_screen.dart';
import 'package:blockchain_app/presentation/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home shows brand and create CTA', (tester) async {
    final wallet = MockWalletService();
    final repo = MockContractRepository(txSender: wallet);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletServiceProvider.overrideWithValue(wallet),
          chainTxSenderProvider.overrideWithValue(wallet),
          contractRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const HomeScreen(),
        ),
      ),
    );

    expect(find.text('Contract Builder'), findsOneWidget);
    expect(find.text('Create a contract'), findsOneWidget);
    expect(find.textContaining('My contracts'), findsOneWidget);

    wallet.dispose();
  });
}
