import 'package:flutter/material.dart';

class PublicNoticeBanner extends StatelessWidget {
  const PublicNoticeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16302C),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.public, color: Color(0xFF2DD4A8), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Smart Deal on Sepolia is public and verifiable. Listings and '
                'NFTs have no admin pause — including this app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFE7F2EE),
                      height: 1.3,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
