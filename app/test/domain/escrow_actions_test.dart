import 'package:blockchain_app/domain/models/escrow_actions.dart';
import 'package:blockchain_app/domain/models/escrow_contract.dart';
import 'package:blockchain_app/domain/models/escrow_state.dart';
import 'package:flutter_test/flutter_test.dart';

const buyer = '0x1111111111111111111111111111111111111111';
const seller = '0x2222222222222222222222222222222222222222';
const stranger = '0x3333333333333333333333333333333333333333';

EscrowContract _c(
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

void main() {
  final now = DateTime.utc(2026, 1, 15, 12);

  group('availableEscrowActions', () {
    test('Created + buyer → fund only', () {
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.created),
          walletAddress: buyer,
          nowUtc: now,
        ),
        [EscrowActionKind.fund],
      );
    });

    test('Created + seller → none', () {
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.created),
          walletAddress: seller,
          nowUtc: now,
        ),
        isEmpty,
      );
    });

    test('Funded + buyer before deadline → release only', () {
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.funded),
          walletAddress: buyer,
          nowUtc: now,
        ),
        [EscrowActionKind.release],
      );
    });

    test('Funded + buyer after deadline → release + reclaim', () {
      final past = now.subtract(const Duration(hours: 1));
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.funded, deadline: past),
          walletAddress: buyer,
          nowUtc: now,
        ),
        [
          EscrowActionKind.release,
          EscrowActionKind.refundAfterDeadline,
        ],
      );
    });

    test('Funded + seller → refundBySeller', () {
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.funded),
          walletAddress: seller,
          nowUtc: now,
        ),
        [EscrowActionKind.refundBySeller],
      );
    });

    test('Released → no money-moving actions (buyer or seller)', () {
      for (final wallet in [buyer, seller, stranger]) {
        expect(
          availableEscrowActions(
            contract: _c(EscrowState.released),
            walletAddress: wallet,
            nowUtc: now,
          ),
          isEmpty,
          reason: wallet,
        );
      }
    });

    test('Refunded → no money-moving actions', () {
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.refunded),
          walletAddress: buyer,
          nowUtc: now,
        ),
        isEmpty,
      );
    });

    test('null wallet → none', () {
      expect(
        availableEscrowActions(
          contract: _c(EscrowState.created),
          walletAddress: null,
          nowUtc: now,
        ),
        isEmpty,
      );
    });
  });

  group('expectedStateAfter', () {
    test('maps actions to terminal / next states', () {
      expect(expectedStateAfter(EscrowActionKind.fund), EscrowState.funded);
      expect(
        expectedStateAfter(EscrowActionKind.release),
        EscrowState.released,
      );
      expect(
        expectedStateAfter(EscrowActionKind.refundBySeller),
        EscrowState.refunded,
      );
      expect(
        expectedStateAfter(EscrowActionKind.refundAfterDeadline),
        EscrowState.refunded,
      );
    });
  });
}
