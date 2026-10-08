import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/components.dart';
import '../../domain/models/favorite_place.dart';
import '../../domain/models/place.dart';
import '../../providers.dart';
import '../common/ui_helpers.dart';

/// Gestion des lieux favoris (décision du 08/10/2026) :
/// Maison, Bureau (uniques) et lieux libres nommés par le passager.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _set(FavoriteKind kind) async {
    String? name;
    if (kind == FavoriteKind.custom) {
      _nameController.clear();
      name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.tr('fav_custom_name')),
          content: TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: context.tr('fav_custom_hint')),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common_cancel'))),
            TextButton(
              onPressed: () => Navigator.pop(context, _nameController.text),
              child: Text(context.tr('common_next')),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty || !mounted) return;
    }
    final place = await context.push<Place>('/pick-place?mode=favorite');
    if (place == null || !mounted) return;
    try {
      await ref.read(favoritesRepositoryProvider).saveFavorite(kind: kind, place: place, customName: name);
      if (mounted) showInfo(context, context.tr('fav_saved'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(FavoritePlace f) async {
    try {
      await ref.read(favoritesRepositoryProvider).deleteFavorite(f.id);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider).valueOrNull ?? const <FavoritePlace>[];
    final eden = context.eden;
    FavoritePlace? find(FavoriteKind k) => favorites.where((f) => f.kind == k).firstOrNull;
    final customs = favorites.where((f) => f.kind == FavoriteKind.custom).toList();

    Widget fixed(FavoriteKind kind) {
      final f = find(kind);
      return _FavoriteRow(
        icon: favoriteIcon(kind),
        title: context.tr('fav_${kind.name}'),
        subtitle: f == null ? context.tr('fav_not_set') : f.place.label,
        onTap: () => _set(kind),
        onDelete: f == null ? null : () => _delete(f),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile_favorites'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          EdenCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [fixed(FavoriteKind.home), fixed(FavoriteKind.work)]),
          ),
          const SizedBox(height: 20),
          SectionTitle(context.tr('fav_others')),
          if (customs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(context.tr('fav_none'), style: TextStyle(color: eden.muted)),
            )
          else
            EdenCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final f in customs)
                    _FavoriteRow(
                      icon: favoriteIcon(f.kind),
                      title: f.customName ?? '',
                      subtitle: f.place.label,
                      onDelete: () => _delete(f),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _set(FavoriteKind.custom),
            icon: const Icon(Icons.add_rounded),
            label: Text(context.tr('fav_add')),
          ),
          const SizedBox(height: 16),
          InfoBanner(text: context.tr('fav_demo_note')),
        ],
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconBubble(icon: icon, color: AppColors.accent, background: context.eden.accentSoft, size: 40),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      trailing: onDelete == null
          ? const Icon(Icons.chevron_right_rounded)
          : IconButton(
              tooltip: context.tr('common_delete'),
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onDelete,
            ),
    );
  }
}
