import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Étape 3 : consentement EXPLICITE sur l'usage des données (CdC §2.2, §7).
/// Le texte définitif doit être validé juridiquement (CdC §9).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _accepted = false;
  bool _loading = false;

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final session = await ref.read(authRepositoryProvider).giveConsent();
      ref.read(sessionProvider.notifier).setSession(session);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('consent_title'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.tr('consent_intro')),
          const SizedBox(height: 16),
          for (final key in ['consent_item_location', 'consent_item_phone', 'consent_item_payments', 'consent_item_retention'])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(context.tr(key)),
            ),
          const SizedBox(height: 8),
          InfoBanner(text: context.tr('consent_legal_pending'), icon: Icons.gavel_outlined),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            title: Text(context.tr('consent_checkbox')),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_accepted && !_loading) ? _continue : null,
            child: Text(context.tr('consent_continue')),
          ),
        ],
      ),
    );
  }
}
