import 'package:blockchain_app/data/repositories/mock_contract_repository.dart';
import 'package:blockchain_app/data/repositories/mock_marketplace_repository.dart';
import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/presentation/providers/app_providers.dart';
import 'package:blockchain_app/presentation/screens/escrow_block_builder_screen.dart';
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
  final market = MockMarketplaceRepository(txSender: wallet);
  addTearDown(wallet.dispose);
  return ProviderScope(
    overrides: [
      walletServiceProvider.overrideWithValue(wallet),
      chainTxSenderProvider.overrideWithValue(wallet),
      contractRepositoryProvider.overrideWithValue(repo),
      marketplaceRepositoryProvider.overrideWithValue(market),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: home,
    ),
  );
}

void _iphoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Home shows Smart Deal marketplace brand', (tester) async {
    _iphoneSurface(tester);
    await tester.pumpWidget(_scope(home: const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Smart Deal'), findsOneWidget);
    expect(find.text('Sell or mint'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.textContaining('Peer NFT marketplace'), findsOneWidget);
    // Seeded mock listing appears.
    expect(find.textContaining('Listing #1'), findsOneWidget);
  });

  testWidgets('Main shell shows Home / Profile and sell FAB', (tester) async {
    _iphoneSurface(tester);
    await tester.pumpWidget(_scope(home: const MainShell()));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byTooltip('Sell or mint'), findsOneWidget);

    await tester.tap(find.byTooltip('Sell or mint'));
    await tester.pumpAndSettle();

    expect(find.text('Sell on Smart Deal'), findsOneWidget);
    expect(find.text('Mint demo NFT'), findsOneWidget);
    expect(find.text('List NFT for ETH'), findsOneWidget);
    expect(find.text('Escrow sur mesure (blocks)'), findsOneWidget);
    expect(find.text('Quick Escrow form'), findsOneWidget);
    expect(find.text('Escrow'), findsOneWidget);
    expect(find.text('Rental'), findsOneWidget);
    expect(find.text('Milestone'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Soon'), findsWidgets);
    expect(find.text('Build'), findsOneWidget);
  });

  testWidgets('Create sheet mint opens mint screen', (tester) async {
    _iphoneSurface(tester);
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
    await tester.tap(find.text('Mint demo NFT'));
    await tester.pumpAndSettle();

    expect(find.text('Mint demo NFT'), findsWidgets);
    expect(find.textContaining('Metadata URI'), findsOneWidget);
  });

  testWidgets('Create sheet Quick Escrow form still works', (tester) async {
    _iphoneSurface(tester);
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
    await tester.ensureVisible(find.text('Quick Escrow form'));
    await tester.tap(find.text('Quick Escrow form'));
    await tester.pumpAndSettle();

    expect(find.text('Seller address'), findsOneWidget);
    expect(find.textContaining('Amount'), findsOneWidget);
  });

  testWidgets('Create sheet blocks button opens Scratch builder', (tester) async {
    _iphoneSurface(tester);
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
    await tester.ensureVisible(find.text('Escrow sur mesure (blocks)'));
    await tester.tap(find.text('Escrow sur mesure (blocks)'));
    await tester.pumpAndSettle();

    expect(find.text('Escrow sur mesure'), findsOneWidget);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Deploy'), findsOneWidget);
  });

  testWidgets('Block builder tap-adds a multi-block stack without layout errors',
      (tester) async {
    tester.view.physicalSize = const Size(900, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(home: const EscrowBlockBuilderScreen()),
    );
    await tester.pumpAndSettle();

    Future<void> addChip(String label) async {
      final chip = find.text(label).first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      if (find.text('Save').evaluate().isNotEmpty) {
        if (find.byType(TextField).evaluate().isNotEmpty) {
          await tester.enterText(
            find.byType(TextField).first,
            label.contains('Seller')
                ? '0x1111111111111111111111111111111111111111'
                : label.contains('Lock')
                    ? '0.1'
                    : '7',
          );
        }
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
      }
    }

    await addChip('When buyer creates this deal');
    await addChip('Buyer is me');
    await addChip('Seller is …');
    await addChip('Lock … ETH');
    await addChip('Deadline in … days');

    expect(find.text('Buyer is me'), findsWidgets);
    expect(find.textContaining('Lock'), findsWidgets);

    final deploy = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Deploy'),
    );
    expect(deploy.onPressed, isNotNull);
  });
}
