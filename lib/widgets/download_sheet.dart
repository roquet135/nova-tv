import 'dart:io';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/downloader.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';
import '../screens/downloads_screen.dart';
import 'nova_widgets.dart';

/// Fenêtre de progression d'un téléchargement, pilotable télécommande.
/// Retourne `true` si le fichier a ete telecharge avec succes.
Future<bool?> showDownloadSheet(
  BuildContext context, {
  required String contentId,
  required String type, // 'movie' ou 'episode'
  required String name,
  String poster = '',
  String group = '',
  required String streamUrl,
  int season = 0,
  int episode = 0,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _DownloadSheet(
      contentId: contentId,
      type: type,
      name: name,
      poster: poster,
      group: group,
      streamUrl: streamUrl,
      season: season,
      episode: episode,
    ),
  );
}

class _DownloadSheet extends StatefulWidget {
  final String contentId;
  final String type;
  final String name;
  final String poster;
  final String group;
  final String streamUrl;
  final int season;
  final int episode;

  const _DownloadSheet({
    required this.contentId,
    required this.type,
    required this.name,
    required this.streamUrl,
    this.poster = '',
    this.group = '',
    this.season = 0,
    this.episode = 0,
  });

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  final _client = NovaDownloader();
  bool _running = true;
  bool _done = false;
  String _error = '';
  int _received = 0;
  int _total = 0;
  String _filePath = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _client.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    // Deja present ? On le signale plutot que de retelecharger.
    if (Storage.isDownloaded(widget.contentId)) {
      if (mounted) {
        setState(() {
          _done = true;
          _running = false;
        });
      }
      return;
    }

    try {
      // on invite l'utilisateur a confirmer l'occupation d'espace
      final name = NovaDownloader.fileName(widget.contentId, widget.streamUrl);
      final itemId = '${widget.type}_${widget.contentId}';

      onProgress(int r, int t) {
        if (mounted) {
          setState(() {
            _received = r;
            _total = t;
          });
        }
      }

      final path = await _client.download(
        url: widget.streamUrl,
        outFileName: name,
        onProgress: onProgress,
      );
      if (!mounted) return;
      // Enregistre les metadonnees dans le rangement NOVA
      final size =
          await File(path).length().catchError((_) => widget.poster.isEmpty ? 0 : 0);
      await Storage.saveDownload(DownloadItem(
        id: itemId,
        contentId: widget.contentId,
        type: widget.type,
        name: widget.name,
        poster: widget.poster,
        group: widget.group,
        filePath: path,
        sizeBytes: size,
        dateIso: DateTime.now().toIso8601String(),
        season: widget.season,
        episode: widget.episode,
      ));
      if (mounted) {
        setState(() {
          _done = true;
          _running = false;
          _filePath = path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      if ('$e'.contains('Annulé')) {
        _close();
        return;
      }
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _running = false;
      });
    }
  }

  void _close() {
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context, _done);
    }
  }

  String _mb(int b) => (b / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final pct = (_total > 0 && _received <= _total)
        ? (_received / _total)
        : (_received > 0 ? -1.0 : 0.0);

    return Dialog(
      backgroundColor: NovaColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 140, vertical: 60),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: NovaColors.brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _done ? Icons.download_done_rounded : Icons.download_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _done
                            ? 'Telechargement termine !'
                            : (_error.isNotEmpty
                                ? 'Telechargement impossible'
                                : 'Telechargement en cours...'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.type == 'episode'
                            ? 'S${widget.season}E${widget.episode}  -  ${widget.name}'
                            : widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: NovaColors.textDim),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_running) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct >= 0 ? pct : null,
                  minHeight: 10,
                  backgroundColor: NovaColors.surfaceHigh,
                  valueColor:
                      const AlwaysStoppedAnimation(NovaColors.cyan),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _total > 0
                    ? '${_mb(_received)} Mo / ${_mb(_total)} Mo   (${(_received / _total * 100).toStringAsFixed(0)}%)'
                    : '${_mb(_received)} Mo telecharges...',
                style: const TextStyle(
                    fontSize: 13, color: NovaColors.textDim),
              ),
              const SizedBox(height: 18),
              NovaButton(
                autofocus: true,
                label: 'Annuler',
                icon: Icons.close_rounded,
                onTap: () {
                  _client.cancel();
                },
              ),
            ] else if (_done) ...[
              const Text(
                'Le fichier est maintenant dans "Mes telechargements".\nTu peux le regarder meme sans internet !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NovaButton(
                    autofocus: true,
                    label: 'Ouvrir Mes telechargements',
                    icon: Icons.folder_open_rounded,
                    onTap: () {
                      Navigator.pop(context, true);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DownloadsScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  NovaButton(
                    label: 'Fermer',
                    icon: Icons.check_rounded,
                    onTap: _close,
                  ),
                ],
              ),
            ] else ...[
              Text(
                _error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: Colors.redAccent, height: 1.4),
              ),
              const SizedBox(height: 18),
              NovaButton(
                autofocus: true,
                label: 'Reessayer',
                icon: Icons.refresh_rounded,
                onTap: () {
                  setState(() {
                    _error = '';
                    _wasNull();
                    _running = true;
                    _received = 0;
                    _total = 0;
                  });
                  _start();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _wasNull() {}
}
