import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/xtream_service.dart';
import '../theme/nova_theme.dart';
import '../widgets/download_sheet.dart';
import '../widgets/nova_widgets.dart';
import 'player_screen.dart';

/// Fiche detaillee d'un film : grande jaquette, resume, casting.
class MovieDetailScreen extends StatefulWidget {
  final Movie movie;
  final XtreamService? xtream;

  const MovieDetailScreen({super.key, required this.movie, this.xtream});

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    if (widget.xtream != null && widget.movie.plot.isEmpty) {
      await widget.xtream!.fillMovieInfo(widget.movie);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _play() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: widget.movie.toChannel(),
          playlist: const [],
        ),
      ),
    );
  }

  /// Garder le film sur la box pour le regarder hors-ligne.
  void _download() {
    showDownloadSheet(
      context,
      contentId: widget.movie.id,
      type: 'movie',
      name: widget.movie.name,
      poster: widget.movie.poster,
      group: widget.movie.group,
      streamUrl: widget.movie.streamUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.movie;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fond flou tire de la jaquette
          if (m.poster.isNotEmpty)
            CachedNetworkImage(
              imageUrl: m.poster,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  NovaColors.bg,
                  NovaColors.bg.withValues(alpha: 0.97),
                  NovaColors.bg.withValues(alpha: 0.82),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 32, 48, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Jaquette
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 230,
                      height: 345,
                      child: m.poster.isEmpty
                          ? Container(
                              color: NovaColors.surfaceHigh,
                              child: const Icon(Icons.movie_outlined,
                                  size: 60, color: NovaColors.textDim),
                            )
                          : CachedNetworkImage(
                              imageUrl: m.poster,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: NovaColors.surfaceHigh,
                                child: const Icon(Icons.movie_outlined,
                                    size: 60, color: NovaColors.textDim),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 36),

                  // Informations
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              if (m.rating.isNotEmpty &&
                                  m.rating != '0' &&
                                  m.rating != 'null')
                                _badge(Icons.star_rounded, m.rating,
                                    const Color(0xFFFFC107)),
                              if (m.year.isNotEmpty)
                                _badge(Icons.calendar_today_rounded, m.year,
                                    NovaColors.cyan),
                              if (m.genre.isNotEmpty)
                                _badge(Icons.local_offer_rounded, m.genre,
                                    NovaColors.violet),
                              _badge(Icons.folder_rounded, m.group,
                                  NovaColors.textDim),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (_loading)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NovaColors.cyan),
                                ),
                                SizedBox(width: 12),
                                Text('Chargement du resume...',
                                    style:
                                        TextStyle(color: NovaColors.textDim)),
                              ],
                            )
                          else ...[
                            if (m.plot.isNotEmpty) ...[
                              const Text('Resume',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: NovaColors.cyan)),
                              const SizedBox(height: 8),
                              Text(
                                m.plot,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: NovaColors.text,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ] else
                              const Text(
                                'Aucun resume disponible pour ce film.',
                                style: TextStyle(color: NovaColors.textDim),
                              ),
                            if (m.director.isNotEmpty)
                              _line('Realisateur', m.director),
                            if (m.cast.isNotEmpty) _line('Avec', m.cast),
                          ],

                          const SizedBox(height: 30),
                          Row(
                            children: [
                              NovaButton(
                                label: 'Regarder',
                                icon: Icons.play_arrow_rounded,
                                autofocus: true,
                                onTap: _play,
                              ),
                              const SizedBox(width: 14),
                              NovaButton(
                                label: 'Telecharger',
                                icon: Icons.download_rounded,
                                onTap: _download,
                              ),
                              const SizedBox(width: 14),
                              NovaButton(
                                label: 'Retour',
                                icon: Icons.arrow_back_rounded,
                                onTap: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData i, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 13, color: c),
            const SizedBox(width: 6),
            Text(t,
                style: TextStyle(
                    fontSize: 11, color: c, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$label : ',
                style: const TextStyle(
                  color: NovaColors.cyan,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(
                    color: NovaColors.text, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
}
