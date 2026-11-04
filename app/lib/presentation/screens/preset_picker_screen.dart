import 'package:flutter/material.dart';

import '../widgets/create_template_sheet.dart';

/// Full-screen entry that opens the shared create-template sheet.
/// Prefer the shell FAB; this remains for any deep links / older routes.
class PresetPickerScreen extends StatefulWidget {
  const PresetPickerScreen({super.key});

  @override
  State<PresetPickerScreen> createState() => _PresetPickerScreenState();
}

class _PresetPickerScreenState extends State<PresetPickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showCreateTemplateSheet(context);
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
