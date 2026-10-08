import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../core/utils/formatters.dart';
import '../../domain/models/wallet.dart';
import '../../domain/models/wallet_transaction.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Écran wallet (CdC §4.3) : solde, statut, historique, recharge.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final txs = ref.watch(transactionsProvider).valueOrNull ?? const <WalletTransaction>[];
    final eden = context.eden;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('wallet_title'))),
      body: walletAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (wallet) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Carte de solde aux couleurs du logo.
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -10,
                    top: -10,
                    child: Icon(Icons.eco_rounded, size: 90, color: AppColors.accent.withOpacity(0.35)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('wallet_balance'), style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 6),
                      Text(
                        formatXaf(wallet.balance),
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () => context.push('/wallet/recharge'),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.tr('wallet_recharge')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // CdC §2.2 : statuts visibles.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  icon: wallet.isBlocked ? Icons.lock_rounded : Icons.check_circle_rounded,
                  color: wallet.isBlocked ? AppColors.sos : AppColors.accent,
                  text: context.tr(wallet.isBlocked ? 'wallet_status_blocked' : 'wallet_status_active'),
                ),
                StatusPill(
                  icon: Icons.health_and_safety_rounded,
                  color: wallet.emergencyCreditStatus == EmergencyCreditStatus.eligible
                      ? AppColors.accent
                      : eden.muted,
                  text: creditStatusLabel(context, wallet.emergencyCreditStatus),
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
            const SizedBox(height: 24),
            SectionTitle(context.tr('wallet_history')),
            if (txs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(context.tr('wallet_no_transactions'),
                    textAlign: TextAlign.center, style: TextStyle(color: eden.muted)),
              ),
            for (final tx in txs) ...[
              EdenCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    IconBubble(
                      icon: tx.amount >= 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                      color: tx.amount >= 0 ? AppColors.accent : AppColors.primary,
                      background: tx.amount >= 0 ? eden.accentSoft : eden.primarySoft,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.operator == null
                                ? transactionLabel(context, tx.type)
                                : '${transactionLabel(context, tx.type)} · ${operatorLabel(context, tx.operator!)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          Text(formatDateTime(tx.createdAt), style: TextStyle(color: eden.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${tx.amount >= 0 ? '+' : ''}${formatXaf(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: tx.amount >= 0 ? AppColors.accent : null,
                          ),
                        ),
                        Text(formatXaf(tx.balanceAfter), style: TextStyle(color: eden.muted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
