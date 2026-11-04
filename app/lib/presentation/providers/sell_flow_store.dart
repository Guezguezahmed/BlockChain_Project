import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Survives MetaMask app-switch / process kill so listing isn't "lost".
class SellFlowSnapshot {
  const SellFlowSnapshot({
    required this.active,
    this.tokenId,
    this.priceEth = '0.05',
    this.stepDone = 0,
  });

  final bool active;
  final BigInt? tokenId;
  final String priceEth;

  /// 0 none, 1 SDT approved, 2 NFT approved, 3 listed (clears active).
  final int stepDone;

  bool get canResume => active && stepDone < 3;

  SellFlowSnapshot copyWith({
    bool? active,
    BigInt? tokenId,
    String? priceEth,
    int? stepDone,
    bool clearToken = false,
  }) {
    return SellFlowSnapshot(
      active: active ?? this.active,
      tokenId: clearToken ? null : (tokenId ?? this.tokenId),
      priceEth: priceEth ?? this.priceEth,
      stepDone: stepDone ?? this.stepDone,
    );
  }
}

class SellFlowController extends StateNotifier<SellFlowSnapshot> {
  SellFlowController() : super(const SellFlowSnapshot(active: false)) {
    _ready = Completer<void>();
    // ignore: discarded_futures
    _hydrate();
  }

  static const _kActive = 'sell_flow_active';
  static const _kToken = 'sell_flow_token';
  static const _kPrice = 'sell_flow_price';
  static const _kStep = 'sell_flow_step';

  late final Completer<void> _ready;

  /// Completes after SharedPreferences hydrate (or failure).
  Future<void> get ready => _ready.future;

  Future<void> _hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final active = prefs.getBool(_kActive) ?? false;
      final tokenRaw = prefs.getString(_kToken);
      final price = prefs.getString(_kPrice) ?? '0.05';
      final step = prefs.getInt(_kStep) ?? 0;
      state = SellFlowSnapshot(
        active: active,
        tokenId: tokenRaw == null ? null : BigInt.tryParse(tokenRaw),
        priceEth: price,
        stepDone: step,
      );
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kActive, state.active);
    if (state.tokenId == null) {
      await prefs.remove(_kToken);
    } else {
      await prefs.setString(_kToken, state.tokenId.toString());
    }
    await prefs.setString(_kPrice, state.priceEth);
    await prefs.setInt(_kStep, state.stepDone);
  }

  Future<void> begin({
    BigInt? tokenId,
    String? priceEth,
    int? stepDone,
  }) async {
    await ready;
    if (!mounted) return;
    final sameToken = tokenId != null && tokenId == state.tokenId;
    state = SellFlowSnapshot(
      active: true,
      tokenId: tokenId ?? state.tokenId,
      priceEth: priceEth ?? state.priceEth,
      stepDone: stepDone ??
          (sameToken ? state.stepDone.clamp(0, 2) : 0),
    );
    await _persist();
  }

  Future<void> setToken(BigInt? tokenId) async {
    await ready;
    if (!mounted) return;
    state = state.copyWith(tokenId: tokenId, clearToken: tokenId == null);
    await _persist();
  }

  Future<void> setPrice(String priceEth) async {
    await ready;
    if (!mounted) return;
    state = state.copyWith(priceEth: priceEth);
    await _persist();
  }

  Future<void> setStepDone(int step) async {
    await ready;
    if (!mounted) return;
    state = state.copyWith(stepDone: step, active: step < 3);
    if (step >= 3) {
      await clear();
      return;
    }
    await _persist();
  }

  Future<void> clear() async {
    await ready;
    if (!mounted) return;
    state = const SellFlowSnapshot(active: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActive);
    await prefs.remove(_kToken);
    await prefs.remove(_kPrice);
    await prefs.remove(_kStep);
  }
}

final sellFlowProvider =
    StateNotifierProvider<SellFlowController, SellFlowSnapshot>((ref) {
  return SellFlowController();
});
