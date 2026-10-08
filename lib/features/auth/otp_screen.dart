import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';
import 'phone_screen.dart';

/// Étape 2 : code OTP reçu par SMS (CdC §2.2).
/// Après validation, le routeur redirige automatiquement vers l'écran
/// « Bienvenue » (prénom + consentement) puis l'accueil.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      final session = await ref.read(authRepositoryProvider).verifyOtp(widget.phone, _controller.text);
      // Le changement de session déclenche la redirection du routeur.
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
      body: AuthLayout(
        showBack: true,
        title: context.tr('otp_title'),
        subtitle: context.tr('otp_sent_to', {'phone': '+237 ${widget.phone}'}),
        children: [
          if (AppConfig.useMock) ...[
            InfoBanner(text: context.tr('otp_demo_hint', {'code': AppConfig.demoOtpCode})),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, letterSpacing: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _verify,
            child: Text(context.tr('otp_verify')),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loading
                ? null
                : () async {
                    await ref.read(authRepositoryProvider).requestOtp(widget.phone);
                    if (context.mounted) showInfo(context, context.tr('otp_resent'));
                  },
            child: Text(context.tr('otp_resend')),
          ),
        ],
      ),
    );
  }
}
