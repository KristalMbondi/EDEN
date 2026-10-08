import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/wallet_transaction.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Recharge du wallet via Orange Money ou MTN MoMo (CdC §2.2, §4.2).
///
/// En production, le flux réel est asynchrone :
///  1. l'app demande la recharge au backend ;
///  2. le backend appelle l'API de l'opérateur (collecte) ;
///  3. le passager valide avec son code PIN sur son téléphone ;
///  4. l'opérateur notifie le backend (webhook) → ligne ajoutée au ledger ;
///  5. l'app reçoit le nouveau solde (Socket.io / rafraîchissement).
class RechargeScreen extends ConsumerStatefulWidget {
  const RechargeScreen({super.key});

  @override
  ConsumerState<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends ConsumerState<RechargeScreen> {
  MobileMoneyOperator _operator = MobileMoneyOperator.orangeMoney;
  late final TextEditingController _phone;
  final _amount = TextEditingController();
  bool _pending = false;
  String? _phoneError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _phone = TextEditingController(text: ref.read(sessionProvider)?.phone ?? '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = normalizeCameroonMobile(_phone.text);
    final amount = int.tryParse(_amount.text.trim());
    setState(() {
      _phoneError = phone == null ? context.tr('auth_phone_invalid') : null;
      _amountError = (amount == null || amount < AppConfig.minRechargeAmount)
          ? context.tr('recharge_amount_invalid', {'min': formatXaf(AppConfig.minRechargeAmount)})
          : null;
    });
    if (phone == null || amount == null || _amountError != null) return;

    setState(() => _pending = true);
    try {
      await ref.read(walletRepositoryProvider).recharge(
            operator: _operator,
            payerPhone: phone,
            amount: amount,
          );
      if (!mounted) return;
      showInfo(context, context.tr('recharge_success', {'amount': formatXaf(amount)}));
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('wallet_recharge'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<MobileMoneyOperator>(
            segments: [
              for (final op in MobileMoneyOperator.values)
                ButtonSegment(value: op, label: Text(operatorLabel(context, op))),
            ],
            selected: {_operator},
            onSelectionChanged: _pending ? null : (s) => setState(() => _operator = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phone,
            enabled: !_pending,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              prefixText: '+237 ',
              labelText: context.tr('recharge_payer_phone'),
              errorText: _phoneError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            enabled: !_pending,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.tr('recharge_amount'),
              suffixText: 'FCFA',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [1000, 2000, 5000, 10000])
                ActionChip(
                  label: Text(formatXaf(v)),
                  onPressed: _pending ? null : () => setState(() => _amount.text = '$v'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_pending) ...[
            InfoBanner(text: context.tr('recharge_pending'), icon: Icons.phone_android),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ] else
            FilledButton(onPressed: _submit, child: Text(context.tr('recharge_submit'))),
        ],
      ),
    );
  }
}
