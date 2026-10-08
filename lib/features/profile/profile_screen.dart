import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Profil : contact d'urgence (SOS), langue, consentement, déconnexion,
/// et — en mode démo uniquement — interrupteurs de simulation.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Contrôleur gardé dans l'état (et non créé dans la méthode) : le disposer
  // juste après showDialog planterait pendant l'animation de fermeture.
  final _contactController = TextEditingController();

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _editEmergencyContact(String? current) async {
    final controller = _contactController..text = current ?? '';
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('profile_emergency_contact')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(prefixText: '+237 '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common_cancel'))),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(context.tr('common_save'))),
        ],
      ),
    );
    if (value == null) return;
    final phone = normalizeCameroonMobile(value);
    if (!mounted) return;
    if (phone == null) {
      showInfo(context, context.tr('auth_phone_invalid'));
      return;
    }
    try {
      final session = await ref.read(authRepositoryProvider).updateEmergencyContact(phone);
      ref.read(sessionProvider.notifier).setSession(session);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _logout() async {
    await ref.read(authRepositoryProvider).logout();
    ref.read(sessionProvider.notifier).setSession(null); // → redirection /login
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    if (session == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile_title'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: Text(context.tr('profile_phone')),
            subtitle: Text('+237 ${session.phone}'),
          ),
          ListTile(
            leading: const Icon(Icons.contact_emergency_outlined),
            title: Text(context.tr('profile_emergency_contact')),
            subtitle: Text(session.emergencyContactPhone == null
                ? context.tr('profile_emergency_none')
                : '+237 ${session.emergencyContactPhone}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editEmergencyContact(session.emergencyContactPhone),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(context.tr('profile_language')),
            trailing: DropdownButton<String>(
              value: locale?.languageCode ?? 'system',
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'system', child: Text(context.tr('profile_language_system'))),
                const DropdownMenuItem(value: 'fr', child: Text('Français')),
                const DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) => ref
                  .read(localeProvider.notifier)
                  .setLocale(v == null || v == 'system' ? null : Locale(v)),
            ),
          ),
          if (session.consentAt != null)
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(context.tr('profile_consent')),
              subtitle: Text(formatDateTime(session.consentAt!)),
            ),
          const Divider(),
          if (AppConfig.useMock) const _DemoSettings(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(context.tr('profile_logout')),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

/// Interrupteurs pour tester les cas limites du CdC sans backend.
class _DemoSettings extends ConsumerStatefulWidget {
  const _DemoSettings();

  @override
  ConsumerState<_DemoSettings> createState() => _DemoSettingsState();
}

class _DemoSettingsState extends ConsumerState<_DemoSettings> {
  @override
  Widget build(BuildContext context) {
    final backend = ref.watch(mockBackendProvider);
    final sim = backend.sim;

    Widget toggle(String key, bool value, void Function(bool) apply) => SwitchListTile(
          title: Text(context.tr(key)),
          value: value,
          onChanged: (v) {
            setState(() => apply(v));
            backend.notifySimulationChanged();
          },
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(context.tr('demo_title'), style: Theme.of(context).textTheme.titleSmall),
        ),
        toggle('demo_no_driver', sim.noDriverAvailable, (v) => sim.noDriverAvailable = v),
        toggle('demo_overrun', sim.forceFareOverrun, (v) => sim.forceFareOverrun = v),
        toggle('demo_credit_eligible', sim.eligibleForEmergencyCredit, (v) => sim.eligibleForEmergencyCredit = v),
        toggle('demo_platform_suspended', sim.platformCreditSuspended, (v) => sim.platformCreditSuspended = v),
      ],
    );
  }
}
