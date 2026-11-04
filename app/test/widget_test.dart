import 'package:blockchain_app/data/repositories/mock_contract_repository.dart';
import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/presentation/providers/app_providers.dart';
import 'package:blockchain_app/presentation/screens/home_screen.dart';
import 'package:blockchain_app/presentation/screens/main_shell.dart';
import 'package:blockchain_app/presentation/theme/app_theme.dart';
import 'package:blockchain_app/presentation/widgets/create_template_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderScope _scope({required Widget home}) {
  final wallet = MockWalletService();
  final repo = MockContractRepository(txSender: wallet);
  addTearDown(wallet.dispose);
  return ProviderScope(
    overrides: [
      walletServiceProvider.overrideWithValue(wallet),
      chainTxSenderProvider.overrideWithValue(wallet),
      contractRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: home,
    ),
  );
}

void main() {
  testWidgets('Home shows brand and create CTA', (tester) async {
    await tester.pumpWidget(_scope(home: const HomeScreen()));

    expect(find.text('Contract Builder'), findsOneWidget);
    expect(find.text('Create a contract'), findsOneWidget);
    expect(find.text('My contracts'), findsOneWidget);
  });

  testWidgets('Main shell shows Home / Profile and create FAB', (tester) async {
    await tester.pumpWidget(_scope(home: const MainShell()));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byTooltip('Create contract'), findsOneWidget);

    await tester.tap(find.byTooltip('Create contract'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a template'), findsOneWidget);
    expect(find.text('Escrow'), findsOneWidget);
    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Milestone payment'),
      40,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Milestone payment'), findsOneWidget);
    expect(find.text('Soon'), findsWidgets);
  });

  testWidgets('Create template sheet opens Escrow form', (tester) async {
    await tester.pumpWidget(
      _scope(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCreateTemplateSheet(context),
                child: const Text('Open sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escrow'));
    await tester.pumpAndSettle();

    expect(find.text('Create Escrow'), findsOneWidget);
    expect(find.text('Seller address'), findsOneWidget);
  });
}
