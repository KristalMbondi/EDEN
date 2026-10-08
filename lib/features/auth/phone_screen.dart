import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Inscription / connexion, étape 1 : numéro de téléphone (CdC §2.2).
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizeCameroonMobile(_controller.text);
    if (phone == null) {
      setState(() => _error = context.tr('auth_phone_invalid'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).requestOtp(phone);
      if (!mounted) return;
      context.push('/otp?phone=$phone');
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
        title: context.tr('auth_welcome'),
        subtitle: context.tr('auth_title'),
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 8),
                child: Text('🇨🇲 +237', style: TextStyle(fontSize: 16, color: eden.muted)),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              labelText: context.tr('auth_phone_label'),
              hintText: '6XX XX XX XX',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(context.tr('auth_send_code')),
          ),
        ],
      ),
    );
  }
}

/// Mise en page commune des écrans d'inscription : en-tête en dégradé doux
/// avec le logo, puis contenu sur fond clair.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final eden = context.eden;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [eden.gradientStart, eden.gradientEnd],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: showBack
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: () => Navigator.of(context).maybePop(),
                          )
                        : null,
                  ),
                  Center(child: Image.asset('assets/branding/logo.png', height: 72)),
                  const SizedBox(height: 28),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: eden.muted, fontSize: 15, height: 1.4)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
