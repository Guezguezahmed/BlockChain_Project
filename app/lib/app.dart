import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'data/wallet/reown_wallet_service.dart';
import 'presentation/providers/app_providers.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/theme/app_theme.dart';

/// Root widget that owns [ProviderScope] overrides.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late final AppDependencies _deps = createAppDependencies();

  @override
  void dispose() {
    _deps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: _deps.overrides,
      child: MaterialApp(
        title: 'Contract Builder',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: ReownBootstrap(reown: _deps.reown),
      ),
    );
  }
}

/// Initializes Reown under [MaterialApp] so modal overlays work.
class ReownBootstrap extends StatefulWidget {
  const ReownBootstrap({super.key, this.reown});

  final ReownWalletService? reown;

  @override
  State<ReownBootstrap> createState() => _ReownBootstrapState();
}

class _ReownBootstrapState extends State<ReownBootstrap> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final reown = widget.reown;
    if (reown == null) {
      setState(() => _ready = true);
      return;
    }
    try {
      await reown.init(context);
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _ready = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && !AppConfig.useMock) {
      return _ConfigErrorScaffold(message: _error!);
    }
    return const MainShell();
  }
}

class _ConfigErrorScaffold extends StatelessWidget {
  const _ConfigErrorScaffold({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings_suggest_outlined, size: 40),
            const SizedBox(height: 16),
            const Text(
              'Wallet / chain setup incomplete',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            const Text(
              'For Sepolia: USE_MOCK=false and '
              'WALLETCONNECT_PROJECT_ID from https://cloud.reown.com '
              '(see app/README.md). Or keep the default USE_MOCK=true.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
