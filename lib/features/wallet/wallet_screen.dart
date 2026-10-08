import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/wallet.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Écran wallet (CdC §4.3) : solde, statut, historique, recharge.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final txs = ref.watch(transactionsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('wallet_title'))),
      body: walletAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (wallet) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: AppColors.primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('wallet_balance'), style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text(
                      formatXaf(wallet.balance),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // CdC §2.2 : statuts visibles.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(wallet.isBlocked ? Icons.lock : Icons.check_circle, size: 18),
                  label: Text(context.tr(wallet.isBlocked ? 'wallet_status_blocked' : 'wallet_status_active')),
                ),
                Chip(
                  avatar: const Icon(Icons.health_and_safety_outlined, size: 18),
                  label: Text(creditStatusLabel(context, wallet.emergencyCreditStatus)),
                ),
              ],
            ),
            if (wallet.isBlocked && wallet.balance < 0) ...[
              const SizedBox(height: 12),
              InfoBanner(color: AppColors.sos, icon: Icons.lock_outline, text: context.tr('wallet_blocked_negative')),
            ],
            if (wallet.emergencyCreditStatus == EmergencyCreditStatus.eligible) ...[
              const SizedBox(height: 12),
              InfoBanner(text: context.tr('wallet_credit_rules')),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/wallet/recharge'),
              icon: const Icon(Icons.add),
              label: Text(context.tr('wallet_recharge')),
            ),
            const SizedBox(height: 24),
            Text(context.tr('wallet_history'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (txs.isEmpty) Text(context.tr('wallet_no_transactions')),
            for (final tx in txs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(tx.amount >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: tx.amount >= 0 ? AppColors.primary : AppColors.sos),
                title: Text(
                  tx.operator == null
                      ? transactionLabel(context, tx.type)
                      : '${transactionLabel(context, tx.type)} · ${operatorLabel(context, tx.operator!)}',
                ),
                subtitle: Text(formatDateTime(tx.createdAt)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${tx.amount >= 0 ? '+' : ''}${formatXaf(tx.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(formatXaf(tx.balanceAfter), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
