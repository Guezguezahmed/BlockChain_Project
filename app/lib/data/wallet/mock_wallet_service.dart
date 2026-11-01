import 'dart:async';

import '../../domain/wallet/wallet_session.dart';

/// Fake wallet for UI / widget tests (no keys, no network).
class MockWalletService implements WalletService, ChainTxSender {
  MockWalletService({
    this.mockAddress = '0x1111111111111111111111111111111111111111',
  });

  final String mockAddress;
  final _controller = StreamController<WalletSession?>.broadcast();
  WalletSession? _session;
  int _txCounter = 0;

  @override
  Stream<WalletSession?> get sessionChanges => _controller.stream;

  @override
  WalletSession? get currentSession => _session;

  @override
  bool get isConnected => currentSession != null;

  @override
  String? get fromAddress => _session?.address;

  @override
  Future<void> connect() async {
    _session = WalletSession(
      address: mockAddress,
      chainId: 11155111,
      isMock: true,
    );
    _controller.add(_session);
  }

  @override
  Future<void> disconnect() async {
    _session = null;
    _controller.add(null);
  }

  @override
  Future<void> ensureSepolia() async {
    if (_session == null) return;
    if (!_session!.isSepolia) {
      _session = WalletSession(
        address: _session!.address,
        chainId: 11155111,
        isMock: true,
      );
      _controller.add(_session);
    }
  }

  @override
  Future<String> sendTransaction({
    required String to,
    required String dataHex,
    BigInt? valueWei,
  }) async {
    if (_session == null) {
      throw StateError('Wallet not connected');
    }
    _txCounter++;
    return '0xmock${_txCounter.toRadixString(16).padLeft(64, '0')}';
  }

  void dispose() {
    _controller.close();
  }
}
