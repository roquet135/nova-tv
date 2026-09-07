import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/nova_theme.dart';

/// Bandeau haut facon Netflix : grande jaquette a droite, titre, note,
/// resume et informations a gauche. Se met a jour au survol d'une carte.
class HeroBanner extends StatelessWidget {
  final String title;
  final String poster;
  final String plot;
  final String rating;
  final String year;
  final String genre;
  final String extra;
  final bool loading;

  const HeroBanner({
    super.key,
    required this.title,
    this.poster = '',
    this.plot = '',
    this.rating = '',
    this.year = '',
    this.genre = '',
    this.extra = '',
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 215,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: NovaColors.surface.withOpacity(0.5),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Voile colore
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0x140E1018), Color(0x3322D3EE)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (rating.isNotEmpty &&
                              rating != '0' &&
                              rating != 'null') ...[
                            const Icon(Icons.star_rounded,
                                size: 15, color: Color(0xFFFFC107)),
                            const SizedBox(width: 4),
                            Text(rating,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFC107))),
                            const SizedBox(width: 12),
                          ],
                          if (year.isNotEmpty) ...[
                            Text(year,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: NovaColors.textDim)),
                            const SizedBox(width: 12),
                          ],
                          if (genre.isNotEmpty)
                            Flexible(
                              child: Text(
                                genre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: NovaColors.cyan,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: loading
                            ? const Row(
                                children: [
                                  SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: NovaColors.cyan),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Chargement du resume...',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: NovaColors.textDim)),
                                ],
                              )
                            : SingleChildScrollView(
                                child: Text(
                                  plot.isEmpty
                                      ? 'Aucun resume disponible.'
                                      : plot,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.55,
                                    color: plot.isEmpty
                                        ? NovaColors.textDim
                                        : NovaColors.text,
                                  ),
                                ),
                              ),
                      ),
                      if (extra.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          extra,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: NovaColors.textDim),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),

                // Jaquette
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 124,
                    height: 183,
                    child: poster.isEmpty
                        ? Container(
                            color: NovaColors.surfaceHigh,
                            child: Icon(Icons.movie_outlined,
                                size: 34,
                                color: NovaColors.violet.withOpacity(0.5)),
                          )
                        : CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: NovaColors.surfaceHigh,
                              child: Icon(Icons.movie_outlined,
                                  size: 34,
                                  color: NovaColors.violet.withOpacity(0.5)),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
