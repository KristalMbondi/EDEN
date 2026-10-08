import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';
import 'phone_screen.dart';

/// Étape 3 : prénom FACULTATIF (décision du 08/10/2026) + consentement
/// EXPLICITE sur l'usage des données (CdC §2.2, §7).
/// Le texte définitif du consentement doit être validé juridiquement (CdC §9).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  final _firstName = TextEditingController();
  bool _accepted = false;
  bool _loading = false;

  @override
  void dispose() {
    _firstName.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .completeProfile(firstName: _firstName.text);
      ref.read(sessionProvider.notifier).setSession(session);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return Scaffold(
      body: AuthLayout(
        title: context.tr('consent_title'),
        subtitle: context.tr('consent_subtitle'),
        children: [
          TextField(
            controller: _firstName,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: context.tr('consent_first_name'),
              helperText: context.tr('consent_first_name_help'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),
          Text(context.tr('consent_intro'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          EdenCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (final item in const [
                  ('consent_item_location', Icons.location_on_outlined),
                  ('consent_item_phone', Icons.phone_locked_outlined),
                  ('consent_item_payments', Icons.receipt_long_outlined),
                  ('consent_item_retention', Icons.history_toggle_off),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        IconBubble(icon: item.$2, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text(context.tr(item.$1), style: const TextStyle(fontSize: 13.5))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoBanner(
            text: context.tr('consent_legal_pending'),
            icon: Icons.gavel_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            title: Text(context.tr('consent_checkbox'), style: TextStyle(fontSize: 14, color: eden.muted)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: (_accepted && !_loading) ? _continue : null,
            child: Text(context.tr('consent_continue')),
          ),
        ],
      ),
    );
  }
}
