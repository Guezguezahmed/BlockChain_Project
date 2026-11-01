import 'package:blockchain_app/domain/models/escrow_contract.dart';
import 'package:blockchain_app/domain/models/escrow_state.dart';
import 'package:blockchain_app/presentation/widgets/escrow_action_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EscrowContract _contract(EscrowState state) {
  final now = DateTime.now().toUtc();
  return EscrowContract(
    address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    buyer: '0x1111111111111111111111111111111111111111',
    seller: '0x2222222222222222222222222222222222222222',
    amountWei: BigInt.from(10).pow(17),
    deadline: now.subtract(const Duration(hours: 1)),
    state: state,
    createdAt: now.subtract(const Duration(days: 1)),
  );
}

void main() {
  testWidgets('buyer sees Deposit in Created', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EscrowActionBar(
            contract: _contract(EscrowState.created),
            walletAddress: '0x1111111111111111111111111111111111111111',
            busy: false,
            onFund: () {},
            onRelease: () {},
            onRefundBySeller: () {},
            onRefundAfterDeadline: () {},
          ),
        ),
      ),
    );
    expect(find.text('Deposit (fund)'), findsOneWidget);
    expect(find.text('Release to seller'), findsNothing);
  });

  testWidgets('buyer sees Release + Reclaim when Funded past deadline',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EscrowActionBar(
            contract: _contract(EscrowState.funded),
            walletAddress: '0x1111111111111111111111111111111111111111',
            busy: false,
            onFund: () {},
            onRelease: () {},
            onRefundBySeller: () {},
            onRefundAfterDeadline: () {},
          ),
        ),
      ),
    );
    expect(find.text('Release to seller'), findsOneWidget);
    expect(find.text('Reclaim after deadline'), findsOneWidget);
  });

  testWidgets('seller sees Refund when Funded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EscrowActionBar(
            contract: _contract(EscrowState.funded),
            walletAddress: '0x2222222222222222222222222222222222222222',
            busy: false,
            onFund: () {},
            onRelease: () {},
            onRefundBySeller: () {},
            onRefundAfterDeadline: () {},
          ),
        ),
      ),
    );
    expect(find.text('Refund buyer'), findsOneWidget);
    expect(find.text('Deposit (fund)'), findsNothing);
  });
}
