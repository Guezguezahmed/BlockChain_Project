import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

import '../../config/app_config.dart';
import '../../domain/wallet/wallet_session.dart';

/// Reown AppKit (WalletConnect) → MetaMask, Sepolia only.
///
/// Requires a non-empty [AppConfig.walletConnectProjectId]. Never stores keys.
class ReownWalletService implements WalletService, ChainTxSender {
  ReownWalletService();

  ReownAppKitModal? _modal;
  final _controller = StreamController<WalletSession?>.broadcast();
  WalletSession? _session;

  ReownAppKitModal? get modal => _modal;

  @override
  Stream<WalletSession?> get sessionChanges => _controller.stream;

  @override
  WalletSession? get currentSession => _session;

  @override
  bool get isConnected => currentSession != null;

  @override
  String? get fromAddress => _session?.address;

  /// Must be called once with a [BuildContext] under [MaterialApp].
  Future<void> init(BuildContext context) async {
    if (_modal != null) return;
    if (!AppConfig.hasWalletConnectProjectId) {
      throw StateError(
        'WALLETCONNECT_PROJECT_ID is empty. Create a project at '
        'https://cloud.reown.com and pass '
        '--dart-define=WALLETCONNECT_PROJECT_ID=...',
      );
    }

    // Sepolia-only (AGENTS.md): drop Solana.
    ReownAppKitModalNetworks.removeSupportedNetworks('solana');

    _modal = ReownAppKitModal(
      context: context,
      projectId: AppConfig.walletConnectProjectId,
      metadata: const PairingMetadata(
        name: 'No-Code Contract Builder',
        description: 'Decentralized escrow builder on Sepolia',
        url: 'https://github.com/Guezguezahmed/BlockChain_Project',
        icons: [
          'https://raw.githubusercontent.com/WalletConnect/walletconnect-assets/master/Icon/Gradient/Icon.png',
        ],
        redirect: Redirect(
          native: 'blockchainapp://',
          universal: 'https://reown.com/blockchainapp',
          linkMode: false,
        ),
      ),
      featuredWalletIds: {
        // MetaMask
        'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96',
      },
    );

    _modal!.onModalConnect.subscribe(_onConnect);
    _modal!.onModalUpdate.subscribe(_onUpdate);
    _modal!.onModalDisconnect.subscribe(_onDisconnect);

    await _modal!.init();

    final sepolia = ReownAppKitModalNetworks.getNetworkInfo(
      'eip155',
      '${AppConfig.sepoliaChainId}',
    );
    if (sepolia != null && _modal!.selectedChain?.chainId != sepolia.chainId) {
      try {
        await _modal!.selectChain(sepolia);
      } catch (_) {}
    }

    _syncFromModal();
  }

  void _onConnect(ModalConnect? event) => _syncFromModal();
  void _onUpdate(ModalConnect? event) => _syncFromModal();
  void _onDisconnect(ModalDisconnect? event) {
    _session = null;
    _controller.add(null);
  }

  void _syncFromModal() {
    final modal = _modal;
    if (modal == null || !modal.isConnected || modal.session == null) {
      _session = null;
      _controller.add(null);
      return;
    }
    final chainIdStr =
        modal.selectedChain?.chainId ?? modal.session!.chainId;
    final numeric = int.tryParse(chainIdStr.split(':').last) ??
        AppConfig.sepoliaChainId;
    final ns = NamespaceUtils.getNamespaceFromChain(
      chainIdStr.contains(':') ? chainIdStr : 'eip155:$chainIdStr',
    );
    final address = modal.session!.getAddress(ns);
    if (address == null) {
      _session = null;
      _controller.add(null);
      return;
    }
    _session = WalletSession(address: address, chainId: numeric);
    _controller.add(_session);
  }

  @override
  Future<void> connect() async {
    final modal = _modal;
    if (modal == null) {
      throw StateError('Reown AppKit not initialized');
    }
    await modal.openModalView();
  }

  @override
  Future<void> disconnect() async {
    await _modal?.disconnect();
    _session = null;
    _controller.add(null);
  }

  @override
  Future<void> ensureSepolia() async {
    final modal = _modal;
    if (modal == null || !modal.isConnected) return;
    final sepolia = ReownAppKitModalNetworks.getNetworkInfo(
      'eip155',
      '${AppConfig.sepoliaChainId}',
    );
    if (sepolia == null) {
      throw StateError('Sepolia network not available in AppKit');
    }
    if (modal.selectedChain?.chainId == sepolia.chainId) return;
    await modal.requestSwitchToChain(sepolia);
    _syncFromModal();
    if (_session != null && !_session!.isSepolia) {
      throw StateError(
        'Please switch MetaMask to Sepolia (chain id 11155111)',
      );
    }
  }

  @override
  Future<String> sendTransaction({
    required String to,
    required String dataHex,
    BigInt? valueWei,
  }) async {
    final modal = _modal;
    final session = _session;
    if (modal == null || session == null || modal.session == null) {
      throw StateError('Wallet not connected');
    }
    await ensureSepolia();

    final chainId =
        modal.selectedChain?.chainId ?? AppConfig.sepoliaChainIdCaip2;
    final from = EthereumAddress.fromHex(session.address);
    final raw = dataHex.startsWith('0x') ? dataHex.substring(2) : dataHex;
    final tx = Transaction(
      from: from,
      to: EthereumAddress.fromHex(to),
      data: Uint8List.fromList(hex.decode(raw.isEmpty ? '' : raw)),
      value: valueWei != null ? EtherAmount.inWei(valueWei) : null,
    );

    final result = await modal.request(
      topic: modal.session!.topic,
      chainId: chainId.contains(':') ? chainId : 'eip155:$chainId',
      request: SessionRequestParams(
        method: 'eth_sendTransaction',
        params: [tx.toJson()],
      ),
    );

    if (result is String) return result;
    return result.toString();
  }

  Future<void> dispose() async {
    _modal?.onModalConnect.unsubscribe(_onConnect);
    _modal?.onModalUpdate.unsubscribe(_onUpdate);
    _modal?.onModalDisconnect.unsubscribe(_onDisconnect);
    await _controller.close();
  }
}
