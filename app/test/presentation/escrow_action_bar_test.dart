import 'package:blockchain_app/domain/models/escrow_contract.dart';
import 'package:blockchain_app/domain/models/escrow_state.dart';
import 'package:blockchain_app/presentation/widgets/escrow_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const buyer = '0x1111111111111111111111111111111111111111';
const seller = '0x2222222222222222222222222222222222222222';

EscrowContract _contract(
  EscrowState state, {
  DateTime? deadline,
}) {
  final now = DateTime.utc(2026, 1, 15, 12);
  return EscrowContract(
    address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    buyer: buyer,
    seller: seller,
    amountWei: BigInt.from(10).pow(17),
    deadline: deadline ?? now.add(const Duration(days: 7)),
    state: state,
    createdAt: now.subtract(const Duration(days: 1)),
  );
}

Future<void> _pumpBar(
  WidgetTester tester, {
  required EscrowContract contract,
  required String? wallet,
  bool busy = false,
  DateTime? nowUtc,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: EscrowActionBar(
          contract: contract,
          walletAddress: wallet,
          busy: busy,
          nowUtc: nowUtc ?? DateTime.utc(2026, 1, 15, 12),
          onFund: () {},
          onRelease: () {},
          onRefundBySeller: () {},
          onRefundAfterDeadline: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('buyer sees Deposit in Created', (tester) async {
    await _pumpBar(
      tester,
      contract: _contract(EscrowState.created),
      wallet: buyer,
    );
    expect(find.text('Deposit (fund)'), findsOneWidget);
    expect(find.text('Release to seller'), findsNothing);
  });

  testWidgets('buyer sees Release only when Funded before deadline',
      (tester) async {
    await _pumpBar(
      tester,
      contract: _contract(EscrowState.funded),
      wallet: buyer,
    );
    expect(find.text('Release to seller'), findsOneWidget);
    expect(find.text('Reclaim after deadline'), findsNothing);
    expect(find.text('Refund buyer'), findsNothing);
  });

  testWidgets('buyer sees Release + Reclaim when Funded past deadline',
      (tester) async {
    final now = DateTime.utc(2026, 1, 15, 12);
    await _pumpBar(
      tester,
      contract: _contract(
        EscrowState.funded,
        deadline: now.subtract(const Duration(hours: 1)),
      ),
      wallet: buyer,
      nowUtc: now,
    );
    expect(find.text('Release to seller'), findsOneWidget);
    expect(find.text('Reclaim after deadline'), findsOneWidget);
  });

  testWidgets('seller sees Refund when Funded', (tester) async {
    await _pumpBar(
      tester,
      contract: _contract(EscrowState.funded),
      wallet: seller,
    );
    expect(find.text('Refund buyer'), findsOneWidget);
    expect(find.text('Deposit (fund)'), findsNothing);
    expect(find.text('Release to seller'), findsNothing);
  });

  testWidgets('Released shows read-only final message, no buttons',
      (tester) async {
    await _pumpBar(
      tester,
      contract: _contract(EscrowState.released),
      wallet: buyer,
    );
    expect(
      find.text('No further actions — this escrow is Released (final).'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('Release to seller'), findsNothing);
  });

  testWidgets('Refunded shows read-only final message, no buttons',
      (tester) async {
    await _pumpBar(
      tester,
      contract: _contract(EscrowState.refunded),
      wallet: seller,
    );
    expect(
      find.text('No further actions — this escrow is Refunded (final).'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('busy disables Funded buyer Release', (tester) async {
    await _pumpBar(
      tester,
      contract: _contract(EscrowState.funded),
      wallet: buyer,
      busy: true,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });
}
