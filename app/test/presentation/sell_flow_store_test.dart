import 'package:blockchain_app/presentation/providers/sell_flow_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('begin + setStepDone persists and canResume', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ctrl = container.read(sellFlowProvider.notifier);
    await ctrl.ready;
    await ctrl.begin(tokenId: BigInt.from(7), priceEth: '0.08');
    expect(container.read(sellFlowProvider).active, isTrue);
    expect(container.read(sellFlowProvider).canResume, isTrue);
    expect(container.read(sellFlowProvider).tokenId, BigInt.from(7));

    await ctrl.setStepDone(1);
    expect(container.read(sellFlowProvider).stepDone, 1);
    expect(container.read(sellFlowProvider).canResume, isTrue);

    await ctrl.setStepDone(3);
    expect(container.read(sellFlowProvider).active, isFalse);
    expect(container.read(sellFlowProvider).canResume, isFalse);
  });

  test('hydrate restores previous session from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'sell_flow_active': true,
      'sell_flow_token': '12',
      'sell_flow_price': '0.11',
      'sell_flow_step': 2,
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctrl = container.read(sellFlowProvider.notifier);
    await ctrl.ready;

    final snap = container.read(sellFlowProvider);
    expect(snap.active, isTrue);
    expect(snap.tokenId, BigInt.from(12));
    expect(snap.priceEth, '0.11');
    expect(snap.stepDone, 2);
    expect(snap.canResume, isTrue);
  });
}
