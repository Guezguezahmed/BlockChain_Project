import 'package:flutter/material.dart';

import 'create_escrow_screen.dart';

class PresetPickerScreen extends StatelessWidget {
  const PresetPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a preset')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Presets are ready-made templates. You fill a form; the factory '
            'deploys a real contract clone on Sepolia.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _PresetTile(
            title: 'Escrow',
            subtitle:
                'Buyer locks ETH, releases to seller when satisfied, or gets refunded.',
            enabled: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreateEscrowScreen(),
                ),
              );
            },
          ),
          const _PresetTile(
            title: 'Rental',
            subtitle: 'Coming in a later phase (v2).',
            enabled: false,
          ),
          const _PresetTile(
            title: 'Milestone payment',
            subtitle: 'Coming in a later phase (v3).',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? const Color(0xFF0F1C1A).withValues(alpha: 0.25)
                  : Colors.black12,
            ),
            color: enabled ? Colors.white.withValues(alpha: 0.65) : Colors.black12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: enabled ? null : Colors.black45,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: enabled ? null : Colors.black38,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
