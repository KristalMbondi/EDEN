import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Profil : prénom, contact d'urgence (SOS), lieux favoris, langue,
/// consentement, déconnexion et — en mode démo — interrupteurs de simulation.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // Contrôleur gardé dans l'état (et non créé dans la méthode) : le disposer
  // juste après showDialog planterait pendant l'animation de fermeture.
  final _dialogController = TextEditingController();

  @override
  void dispose() {
    _dialogController.dispose();
    super.dispose();
  }

  Future<String?> _askText({required String title, String? initial, bool phone = false}) {
    _dialogController.text = initial ?? '';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: _dialogController,
          autofocus: true,
          keyboardType: phone ? TextInputType.phone : TextInputType.name,
          textCapitalization: phone ? TextCapitalization.none : TextCapitalization.words,
          decoration: InputDecoration(prefixText: phone ? '+237 ' : null),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common_cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, _dialogController.text),
            child: Text(context.tr('common_save')),
          ),
        ],
      ),
    );
  }

  Future<void> _editFirstName(String? current) async {
    final value = await _askText(title: context.tr('profile_first_name'), initial: current);
    if (value == null || !mounted) return;
    try {
      final session = await ref.read(authRepositoryProvider).updateFirstName(value);
      ref.read(sessionProvider.notifier).setSession(session);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _editEmergencyContact(String? current) async {
    final value = await _askText(
      title: context.tr('profile_emergency_contact'),
      initial: current,
      phone: true,
    );
    if (value == null || !mounted) return;
    final phone = normalizeCameroonMobile(value);
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
    final eden = context.eden;
    if (session == null) return const Scaffold(body: LoadingView());
    final name = session.firstName;

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SoftGradient(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Row(
                  children: [
                    AvatarInitial(name: name, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (name == null || name.isEmpty) ? context.tr('profile_no_name') : name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text('+237 ${session.phone}', style: TextStyle(color: eden.muted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('profile_first_name'),
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editFirstName(name),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EdenCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _Item(
                        icon: Icons.bookmark_rounded,
                        title: context.tr('profile_favorites'),
                        onTap: () => context.push('/favorites'),
                      ),
                      _Item(
                        icon: Icons.contact_emergency_rounded,
                        iconColor: AppColors.sos,
                        title: context.tr('profile_emergency_contact'),
                        subtitle: session.emergencyContactPhone == null
                            ? context.tr('profile_emergency_none')
                            : '+237 ${session.emergencyContactPhone}',
                        onTap: () => _editEmergencyContact(session.emergencyContactPhone),
                      ),
                      _Item(
                        icon: Icons.language_rounded,
                        title: context.tr('profile_language'),
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
                        _Item(
                          icon: Icons.verified_user_rounded,
                          iconColor: AppColors.accent,
                          title: context.tr('profile_consent'),
                          subtitle: formatDateTime(session.consentAt!),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (AppConfig.useMock) ...[
                  const _DemoSettings(),
                  const SizedBox(height: 16),
                ],
                EdenCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _Item(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.sos,
                    title: context.tr('profile_logout'),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBubble(icon: icon, color: iconColor, background: iconColor.withOpacity(0.12), size: 38),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
      onTap: onTap,
    );
  }
}

/// Interrupteurs pour tester les cas limites sans backend.
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
          title: Text(context.tr(key), style: const TextStyle(fontSize: 14)),
          value: value,
          activeColor: AppColors.primary,
          onChanged: (v) {
            setState(() => apply(v));
            backend.notifySimulationChanged();
          },
        );

    return EdenCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(context.tr('demo_title'), style: Theme.of(context).textTheme.titleSmall),
          ),
          toggle('demo_no_driver', sim.noDriverAvailable, (v) => sim.noDriverAvailable = v),
          toggle('demo_overrun', sim.forceFareOverrun, (v) => sim.forceFareOverrun = v),
          toggle('demo_credit_eligible', sim.eligibleForEmergencyCredit, (v) => sim.eligibleForEmergencyCredit = v),
          toggle('demo_platform_suspended', sim.platformCreditSuspended, (v) => sim.platformCreditSuspended = v),
          toggle('demo_fast_reservations', sim.fastReservations, (v) => sim.fastReservations = v),
        ],
      ),
    );
  }
}
