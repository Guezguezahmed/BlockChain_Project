import 'package:blockchain_app/data/repositories/mock_contract_repository.dart';
import 'package:blockchain_app/data/repositories/mock_marketplace_repository.dart';
import 'package:blockchain_app/data/wallet/mock_wallet_service.dart';
import 'package:blockchain_app/presentation/providers/app_providers.dart';
import 'package:blockchain_app/presentation/screens/escrow_block_builder_screen.dart';
import 'package:blockchain_app/presentation/screens/home_screen.dart';
import 'package:blockchain_app/presentation/screens/listing_detail_screen.dart';
import 'package:blockchain_app/presentation/screens/main_shell.dart';
import 'package:blockchain_app/presentation/theme/app_theme.dart';
import 'package:blockchain_app/presentation/widgets/create_template_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  testWidgets('Home shows Smart Deal marketplace brand and grid', (tester) async {
    _iphoneSurface(tester);
    await tester.pumpWidget(_scope(home: const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Smart Deal'), findsOneWidget);
    expect(find.text('Sell an NFT'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    expect(find.textContaining('Discover & trade'), findsOneWidget);
    // Seeded mock listing cards (titles may be below fold on small phones —
    // scroll the marketplace grid into view).
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Teal Relic'), findsWidgets);
  });

  testWidgets('Main shell shows Market / My Items / Profile and sell FAB',
      (tester) async {
    _iphoneSurface(tester);
    await tester.pumpWidget(_scope(home: const MainShell()));

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('My Items'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.byTooltip('Sell or mint'), findsOneWidget);

    await tester.tap(find.byTooltip('Sell or mint'));
    await tester.pumpAndSettle();

    expect(find.text('Sell on Smart Deal'), findsOneWidget);
    expect(find.text('Mint demo NFT'), findsOneWidget);
    expect(find.text('List NFT for ETH'), findsOneWidget);
    expect(find.text('Escrow sur mesure (blocks)'), findsOneWidget);
    expect(find.text('Quick Escrow form'), findsOneWidget);
  });

  testWidgets('Main shell shows Continue listing resume banner', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sell_flow_active': true,
      'sell_flow_token': '5',
      'sell_flow_price': '0.05',
      'sell_flow_step': 1,
    });
    _iphoneSurface(tester);
    await tester.pumpWidget(_scope(home: const MainShell()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Continue listing'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('List NFT'), findsOneWidget);
  });

  testWidgets('Listing detail buy shows ownership celebration in mock',
      (tester) async {
    _iphoneSurface(tester);
    final wallet = MockWalletService();
    final repo = MockContractRepository(txSender: wallet);
    final market = MockMarketplaceRepository(txSender: wallet);
    addTearDown(wallet.dispose);
    await wallet.connect();
    market.ensureConnectedHasSdt();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletServiceProvider.overrideWithValue(wallet),
          chainTxSenderProvider.overrideWithValue(wallet),
          contractRepositoryProvider.overrideWithValue(repo),
          marketplaceRepositoryProvider.overrideWithValue(market),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: ListingDetailScreen(listingId: BigInt.one),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ETH'), findsWidgets);
    final buy = find.textContaining('Buy for');
    expect(buy, findsOneWidget);
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(find.text('You now own this'), findsOneWidget);
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
    expect(find.textContaining('Title or metadata URI'), findsOneWidget);
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
