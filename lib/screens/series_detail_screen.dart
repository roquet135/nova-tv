import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/stalker_service.dart';
import '../services/storage.dart';
import '../services/xtream_service.dart';
import '../theme/nova_theme.dart';
import '../widgets/download_sheet.dart';
import '../widgets/nova_widgets.dart';
import 'player_screen.dart';

/// Fiche d'une serie : jaquette, resume, saisons et episodes.
/// Marche avec un portail Xtream OU un portail Stalker (v10.1).
class SeriesDetailScreen extends StatefulWidget {
  final Series series;
  final XtreamService? xtream;
  final StalkerService? stalker;

  const SeriesDetailScreen({
    super.key,
    required this.series,
    this.xtream,
    this.stalker,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  bool _loading = true;
  Map<int, List<Episode>> _seasons = {};
  int _season = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<int, List<Episode>> eps;
    final x = widget.xtream;
    if (x != null) {
      eps = await x.episodes(widget.series);
    } else if (widget.stalker != null) {
      eps = await widget.stalker!.fetchEpisodes(widget.series);
    } else {
      eps = {};
    }
    if (!mounted) return;
    final keys = eps.keys.toList()..sort();
    setState(() {
      _seasons = eps;
      _season = keys.isEmpty ? 0 : keys.first;
      _loading = false;
    });
  }

  void _playEpisode(Episode e) {
    final list = _seasons[_season] ?? const <Episode>[];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: e.toChannel(),
          playlist: list.map((x) => x.toChannel()).toList(),
          stalker: widget.stalker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.series;
    final keys = _seasons.keys.toList()..sort();
    final eps = _seasons[_season] ?? const <Episode>[];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 26, 40, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Colonne gauche : jaquette et infos
              SizedBox(
                width: 300,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 190,
                          height: 285,
                          child: s.poster.isEmpty
                              ? Container(
                                  color: NovaColors.surfaceHigh,
                                  child: const Icon(Icons.tv_rounded,
                                      size: 50, color: NovaColors.textDim),
                                )
                              : CachedNetworkImage(
                                  imageUrl: s.poster,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: NovaColors.surfaceHigh,
                                    child: const Icon(Icons.tv_rounded,
                                        size: 50, color: NovaColors.textDim),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.name,
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.2),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (s.rating.isNotEmpty &&
                              s.rating != '0' &&
                              s.rating != 'null')
                            _badge(Icons.star_rounded, s.rating,
                                const Color(0xFFFFC107)),
                          if (s.year.isNotEmpty)
                            _badge(Icons.calendar_today_rounded, s.year,
                                NovaColors.cyan),
                          if (keys.isNotEmpty)
                            _badge(Icons.layers_rounded,
                                '${keys.length} saison(s)', NovaColors.violet),
                        ],
                      ),
                      if (s.plot.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          s.plot,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.55,
                            color: NovaColors.textDim,
                          ),
                        ),
                      ],
                      if (s.cast.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Avec : ${s.cast}',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: NovaColors.textDim,
                                height: 1.4)),
                      ],
                      const SizedBox(height: 18),
                      NovaButton(
                        label: 'Retour',
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),

              // Colonne droite : saisons et episodes
              Expanded(
                child: _loading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: NovaColors.cyan),
                            SizedBox(height: 14),
                            Text('Chargement des episodes...',
                                style: TextStyle(color: NovaColors.textDim)),
                          ],
                        ),
                      )
                    : keys.isEmpty
                        ? const Center(
                            child: Text('Aucun episode disponible',
                                style: TextStyle(color: NovaColors.textDim)),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: keys.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 9),
                                  itemBuilder: (context, i) {
                                    final k = keys[i];
                                    final sel = k == _season;
                                    return GestureDetector(
                                      onTap: () => setState(() => _season = k),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          gradient:
                                              sel ? NovaColors.brand : null,
                                          color:
                                              sel ? null : NovaColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(21),
                                        ),
                                        child: Text('Saison $k',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: sel
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            )),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: eps.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, i) {
                                    final e = eps[i];
                                    return FocusCard(
                                      autofocus: i == 0,
                                      radius: 12,
                                      onTap: () => _playEpisode(e),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: SizedBox(
                                                width: 116,
                                                height: 66,
                                                child: e.image.isEmpty
                                                    ? Container(
                                                        color: NovaColors
                                                            .surfaceHigh,
                                                        child: const Icon(
                                                            Icons
                                                                .play_circle_outline_rounded,
                                                            color: NovaColors
                                                                .textDim),
                                                      )
                                                    : CachedNetworkImage(
                                                        imageUrl: e.image,
                                                        fit: BoxFit.cover,
                                                        errorWidget: (_, __,
                                                                ___) =>
                                                            Container(
                                                          color: NovaColors
                                                              .surfaceHigh,
                                                          child: const Icon(
                                                              Icons
                                                                  .play_circle_outline_rounded,
                                                              color: NovaColors
                                                                  .textDim),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'E${e.episode}  ${e.name}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  if (e.plot.isNotEmpty) ...[
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      e.plot,
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color:
                                                            NovaColors.textDim,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            _EpisodeDownloadButton(
                                              episode: e,
                                              seriesName: s.name,
                                              stalker: widget.stalker,
                                            ),
                                            const SizedBox(width: 8),
                                            const Icon(
                                                Icons.play_arrow_rounded,
                                                color: NovaColors.cyan),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData i, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 12, color: c),
            const SizedBox(width: 5),
            Text(t,
                style: TextStyle(
                    fontSize: 10.5, color: c, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Petit icone de telechargement par episode : focusable aux fleches,
/// devient un crochet vert quand l episode est deja garde sur la box.
class _EpisodeDownloadButton extends StatefulWidget {
  final Episode episode;
  final String seriesName;
  final StalkerService? stalker;

  const _EpisodeDownloadButton({
    required this.episode,
    required this.seriesName,
    this.stalker,
  });

  @override
  State<_EpisodeDownloadButton> createState() => _EpisodeDownloadButtonState();
}

class _EpisodeDownloadButtonState extends State<_EpisodeDownloadButton> {
  bool _f = false;

  Future<void> _download() async {
    if (Storage.isDownloaded(widget.episode.id)) return;
    // Sur un portail Stalker, la commande n'est pas telechargeable telle
    // quelle : on la traduit d'abord en vraie URL.
    var url = widget.episode.streamUrl;
    final st = widget.stalker;
    if (st != null && !url.startsWith('http')) {
      try {
        url = await st.resolveSmart(widget.episode.id, url);
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    showDownloadSheet(
      context,
      contentId: widget.episode.id,
      type: 'episode',
      name: '${widget.seriesName} - ${widget.episode.name}',
      poster: widget.episode.image,
      group: 'Series',
      streamUrl: url,
      season: widget.episode.season,
      episode: widget.episode.episode,
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final got = Storage.isDownloaded(widget.episode.id);
    return Focus(
      onFocusChange: (v) => setState(() => _f = v),
      child: Builder(
        builder: (context) {
          return Shortcuts(
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            child: Actions(
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (intent) {
                    _download();
                    return null;
                  },
                ),
              },
              child: GestureDetector(
                onTap: _download,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: got
                        ? const Color(0xFF14351F)
                        : (_f ? NovaColors.cyan.withValues(alpha: 0.18) : Colors.transparent),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: _f
                          ? NovaColors.cyan
                          : (got
                              ? const Color(0xFF22C55E)
                              : Colors.white.withValues(alpha: 0.2)),
                      width: _f ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    got ? Icons.check_circle_rounded : Icons.download_rounded,
                    size: 17,
                    color: got
                        ? const Color(0xFF22C55E)
                        : (_f ? NovaColors.cyan : NovaColors.textDim),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
