import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/models.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';
import '../widgets/nova_widgets.dart';
import 'player_screen.dart';

/// Ecran dedié aux fichiers gardés sur la box : films et episodes.
/// Regarde hors-ligne, libere de l'espace.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadItem> _items = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _items = Storage.downloads());

  String _formatSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} Go';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} Mo';
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}h${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  void _play(DownloadItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: item.toChannel(),
          playlist: _items.where((i) => i.type == item.type).map((i) => i.toChannel()).toList(),
        ),
      ),
    ).then((_) => _refresh());
  }

  Future<void> _delete(DownloadItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        title: const Text('Supprimer ce telechargement ?'),
        content: Text(
          '"${item.name}" (${_formatSize(item.sizeBytes)}) sera efface de la box.\nCette action est definitive.',
          style: const TextStyle(color: NovaColors.textDim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Storage.removeDownload(item.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final movies = _items.where((i) => i.type == 'movie').toList();
    final eps = _items.where((i) => i.type == 'episode').toList();
    final total = Storage.downloadsTotalSize();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 26, 40, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      gradient: NovaColors.brand,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.download_done_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GradientTitle('MES TELECHARGEMENTS', size: 24),
                      Text(
                        total > 0
                            ? '${_items.length} fichier(s) - ${_formatSize(total)} occupes sur la box'
                            : 'Aucun fichier pour l instant',
                        style: const TextStyle(
                            color: NovaColors.textDim, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: _items.isEmpty
                    ? _empty()
                    : ListView(
                        children: [
                          if (movies.isNotEmpty) ...[
                            _sectionTitle(
                                'Films telecharges', Icons.movie_outlined),
                            _grid(movies),
                          ],
                          if (eps.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _sectionTitle(
                                'Episodes telecharges', Icons.tv_rounded),
                            _grid(eps),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_for_offline_rounded,
                size: 72, color: NovaColors.violet.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            const Text(
              'Aucun fichier telecharge pour l instant',
              style: TextStyle(fontSize: 18, color: NovaColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sur la fiche d un film ou d un episode,\nappuie sur l icone de telechargement pour le garder',
              textAlign: TextAlign.center,
              style: TextStyle(color: NovaColors.textDim, height: 1.4),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String text, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: NovaColors.cyan),
            const SizedBox(width: 9),
            Text(text,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _grid(List<DownloadItem> items) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          childAspectRatio: 2.6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return Stack(
            children: [
              FocusCard(
                autofocus: i == 0,
                onTap: () => _play(item),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: SizedBox(
                          width: 62,
                          height: 88,
                          child: item.poster.isEmpty
                              ? Container(
                                  color: NovaColors.surfaceHigh,
                                  child: Icon(
                                    item.type == 'episode'
                                        ? Icons.tv_rounded
                                        : Icons.movie_outlined,
                                    color: NovaColors.textDim,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: item.poster,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: NovaColors.surfaceHigh,
                                    child: const Icon(Icons.movie_outlined,
                                        color: NovaColors.textDim),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.type == 'episode'
                                  ? 'S${item.season}E${item.episode} - ${item.name}'
                                  : item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.schedule_rounded,
                                    size: 11,
                                    color: NovaColors.textDim.withValues(alpha: 0.8)),
                                const SizedBox(width: 5),
                                Text(_formatDate(item.dateIso),
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: NovaColors.textDim)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.sd_storage_rounded,
                                    size: 11,
                                    color: NovaColors.cyan.withValues(alpha: 0.8)),
                                const SizedBox(width: 5),
                                Text(_formatSize(item.sizeBytes),
                                    style: const TextStyle(
                                        fontSize: 10.5,
                                        color: NovaColors.cyan,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 7,
                right: 7,
                child: GestureDetector(
                  onTap: () => _delete(item),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        size: 14, color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          );
        },
      );
}
