import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../theme/app_theme.dart';

/// Explains how demo SDT works for sellers (fee + stake).
class SdtFaucetNote extends StatelessWidget {
  const SdtFaucetNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demo SDT faucet',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Fixed supply ${AppConfig.listingFeeSdtLabel} listing fee + '
              '${AppConfig.sellerStakeSdtLabel} stake per listing '
              '(${AppConfig.feeDiscountLabel} fee off if you hold ≥ '
              '${AppConfig.discountHoldSdtLabel}). '
              'All demo SDT was minted to the deployer — ask for a small '
              'transfer, or use mock mode.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppTheme.ink.withValues(alpha: 0.7),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => launchUrl(
                Uri.parse(
                  AppConfig.etherscanAddressUrl(AppConfig.sdtDeployerAddress),
                ),
              ),
              child: const Text('Deployer (SDT holder) on Etherscan'),
            ),
          ],
        ),
      ),
    );
  }
}
