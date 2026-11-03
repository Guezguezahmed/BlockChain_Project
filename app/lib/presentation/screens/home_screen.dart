import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/public_notice_banner.dart';
import 'my_contracts_screen.dart';
import 'preset_picker_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(walletSessionProvider).asData?.value;

    return Scaffold(
      body: Column(
        children: [
          const PublicNoticeBanner(),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(gradient: AppTheme.heroGradient),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Contract Builder',
                            style: TextStyle(
                              color: Color(0xFFE7F2EE),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE7F2EE),
                            ),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const WalletScreen(),
                              ),
                            ),
                            child: Text(
                              session == null
                                  ? 'Connect wallet'
                                  : session.shortAddress,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(flex: 2),
                      const Text(
                        'No-code\nsmart contracts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          height: 1.05,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Pick a preset, fill a form, deploy on ${AppConfig.networkName}. '
                        'You sign; the chain enforces the rules.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: AppTheme.ink,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PresetPickerScreen(),
                            ),
                          );
                        },
                        child: const Text('Create a contract'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyContractsScreen(),
                            ),
                          );
                        },
                        child: Text(
                          session == null
                              ? 'My contracts'
                              : 'My contracts (${session.shortAddress})',
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppConfig.useMock
                            ? 'Mode: Mock repository (UI without chain)'
                            : AppConfig.hasFactoryAddress
                                ? 'Mode: Sepolia · factory ${AppConfig.factoryAddress.substring(0, 10)}…'
                                : 'Mode: Sepolia · FACTORY_ADDRESS missing',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
