import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Image.asset('assets/branding/logo.png', height: 88),
            const SizedBox(height: 16),
            Text(
              context.tr('app_name'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(context.tr('auth_title'), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
              decoration: InputDecoration(
                prefixText: '+237 ',
                labelText: context.tr('auth_phone_label'),
                hintText: '6XX XX XX XX',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(context.tr('auth_send_code')),
            ),
          ],
        ),
      ),
    );
  }
}
