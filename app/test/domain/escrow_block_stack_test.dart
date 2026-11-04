import 'package:blockchain_app/domain/blocks/escrow_block.dart';
import 'package:blockchain_app/domain/blocks/escrow_block_stack.dart';
import 'package:flutter_test/flutter_test.dart';

EscrowBlock _b(EscrowBlockKind kind, {String id = 'x', String seller = '', String amount = '0.1', int days = 7, DateTime? date}) {
  return EscrowBlock(
    id: id,
    kind: kind,
    sellerAddress: seller,
    amountEth: amount,
    deadlineDays: days,
    deadlineDate: date,
  );
}

void main() {
  const seller = '0x1111111111111111111111111111111111111111';
  const buyer = '0x2222222222222222222222222222222222222222';
  final now = DateTime.utc(2026, 11, 4, 12);

  group('canAccept', () {
    test('stubs never snap', () {
      final stack = EscrowBlockStack(const []);
      expect(
        stack.canAccept(EscrowBlockKind.rentalComingSoon).reason,
        BlockRejectReason.comingSoon,
      );
      expect(
        stack.canAccept(EscrowBlockKind.milestoneComingSoon).accepted,
        isFalse,
      );
    });

    test('requires hat first', () {
      final empty = EscrowBlockStack(const []);
      expect(
        empty.canAccept(EscrowBlockKind.buyerIsMe).reason,
        BlockRejectReason.needsStartFirst,
      );
      expect(
        empty.canAccept(EscrowBlockKind.whenBuyerCreates).accepted,
        isTrue,
      );
    });

    test('rejects duplicate required blocks', () {
      final stack = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerIsMe, id: '2'),
        _b(EscrowBlockKind.sellerIs, id: '3', seller: seller),
        _b(EscrowBlockKind.lockAmount, id: '4'),
        _b(EscrowBlockKind.deadlineInDays, id: '5'),
      ]);
      expect(
        stack.canAccept(EscrowBlockKind.buyerIsMe).reason,
        BlockRejectReason.duplicateBuyer,
      );
      expect(
        stack.canAccept(EscrowBlockKind.sellerIs).reason,
        BlockRejectReason.duplicateSeller,
      );
      expect(
        stack.canAccept(EscrowBlockKind.lockAmount).reason,
        BlockRejectReason.duplicateAmount,
      );
      expect(
        stack.canAccept(EscrowBlockKind.deadlineOnDate).reason,
        BlockRejectReason.duplicateDeadline,
      );
    });

    test('allows story outcomes once each', () {
      final stack = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
      ]);
      expect(
        stack.canAccept(EscrowBlockKind.buyerCanRelease).accepted,
        isTrue,
      );
      final withStory = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerCanRelease, id: '2'),
      ]);
      expect(
        withStory.canAccept(EscrowBlockKind.buyerCanRelease).reason,
        BlockRejectReason.duplicateStory,
      );
    });
  });

  group('toCreateParams mapping', () {
    test('maps seller, amount, deadline-in-days', () {
      final stack = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerIsMe, id: '2'),
        _b(EscrowBlockKind.sellerIs, id: '3', seller: seller),
        _b(EscrowBlockKind.lockAmount, id: '4', amount: '1.5'),
        _b(EscrowBlockKind.deadlineInDays, id: '5', days: 10),
        _b(EscrowBlockKind.buyerCanRelease, id: '6'),
        _b(EscrowBlockKind.sellerCanRefund, id: '7'),
      ]);

      expect(stack.isValidForDeploy(connectedBuyer: buyer, nowUtc: now), isTrue);

      final params = stack.toCreateParams(connectedBuyer: buyer, nowUtc: now);
      expect(params.seller.toLowerCase(), seller.toLowerCase());
      expect(params.amountWei, BigInt.parse('1500000000000000000'));
      expect(params.deadline, now.add(const Duration(days: 10)));
    });

    test('maps deadline-on-date', () {
      final deadline = DateTime.utc(2026, 12, 1, 23, 59);
      final stack = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerIsMe, id: '2'),
        _b(EscrowBlockKind.sellerIs, id: '3', seller: seller),
        _b(EscrowBlockKind.lockAmount, id: '4', amount: '0.25'),
        _b(EscrowBlockKind.deadlineOnDate, id: '5', date: deadline),
      ]);

      final params = stack.toCreateParams(connectedBuyer: buyer, nowUtc: now);
      expect(params.amountWei, BigInt.parse('250000000000000000'));
      expect(params.deadline, deadline);
    });

    test('rejects seller == buyer', () {
      final stack = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerIsMe, id: '2'),
        _b(EscrowBlockKind.sellerIs, id: '3', seller: buyer),
        _b(EscrowBlockKind.lockAmount, id: '4'),
        _b(EscrowBlockKind.deadlineInDays, id: '5'),
      ]);
      expect(
        stack.isValidForDeploy(connectedBuyer: buyer, nowUtc: now),
        isFalse,
      );
      expect(
        stack.fieldErrors(connectedBuyer: buyer, nowUtc: now),
        contains('Seller must differ from buyer (you)'),
      );
    });

    test('incomplete stack lists missing requirements', () {
      final stack = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerIsMe, id: '2'),
      ]);
      expect(
        stack.missingRequirements,
        containsAll(['Seller address', 'Lock amount', 'Deadline']),
      );
      expect(
        () => stack.toCreateParams(connectedBuyer: buyer, nowUtc: now),
        throwsStateError,
      );
    });

    test('story blocks do not affect params', () {
      final base = EscrowBlockStack([
        _b(EscrowBlockKind.whenBuyerCreates, id: '1'),
        _b(EscrowBlockKind.buyerIsMe, id: '2'),
        _b(EscrowBlockKind.sellerIs, id: '3', seller: seller),
        _b(EscrowBlockKind.lockAmount, id: '4', amount: '0.1'),
        _b(EscrowBlockKind.deadlineInDays, id: '5', days: 3),
      ]);
      final withStory = EscrowBlockStack([
        ...base.blocks,
        _b(EscrowBlockKind.buyerCanRelease, id: '6'),
        _b(EscrowBlockKind.sellerCanRefund, id: '7'),
        _b(EscrowBlockKind.buyerReclaimAfterDeadline, id: '8'),
      ]);

      final a = base.toCreateParams(connectedBuyer: buyer, nowUtc: now);
      final b = withStory.toCreateParams(connectedBuyer: buyer, nowUtc: now);
      expect(a.seller, b.seller);
      expect(a.amountWei, b.amountWei);
      expect(a.deadline, b.deadline);
    });
  });
}
