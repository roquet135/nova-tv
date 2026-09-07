import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/nova_theme.dart';

/// Jaquette de film ou de serie, format portrait 2:3 comme au cinema.
/// Grandit et s'illumine quand la telecommande arrive dessus.
class PosterCard extends StatefulWidget {
  final String title;
  final String poster;
  final String rating;
  final String year;
  final VoidCallback onTap;
  final VoidCallback? onFocus;
  final bool autofocus;

  const PosterCard({
    super.key,
    required this.title,
    required this.poster,
    required this.onTap,
    this.onFocus,
    this.rating = '',
    this.year = '',
    this.autofocus = false,
  });

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) {
        setState(() => _f = v);
        if (v) widget.onFocus?.call();
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (i) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              transform: Matrix4.diagonal3Values(
                  _f ? 1.08 : 1.0, _f ? 1.08 : 1.0, 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _f
                    ? [
                        BoxShadow(
                          color: NovaColors.violet.withOpacity(0.55),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: NovaColors.surface),
                          if (widget.poster.isNotEmpty)
                            CachedNetworkImage(
                              imageUrl: widget.poster,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _fallback(),
                              placeholder: (_, __) => Center(
                                child: Icon(Icons.movie_outlined,
                                    size: 30,
                                    color: NovaColors.textDim.withOpacity(0.4)),
                              ),
                            )
                          else
                            _fallback(),

                          // Degrade bas pour lisibilite
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.center,
                                colors: [Colors.black87, Colors.transparent],
                              ),
                            ),
                          ),

                          // Note
                          if (widget.rating.isNotEmpty &&
                              widget.rating != '0' &&
                              widget.rating != 'null')
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 12, color: Color(0xFFFFC107)),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.rating,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Bordure lumineuse au focus
                          if (_f)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: NovaColors.cyan, width: 2.5),
                              ),
                            ),

                          // Bouton lecture au focus
                          if (_f)
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  gradient: NovaColors.brand,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.play_arrow_rounded,
                                    size: 26, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: _f ? NovaColors.cyan : NovaColors.text,
                    ),
                  ),
                  if (widget.year.isNotEmpty)
                    Text(
                      widget.year,
                      style: const TextStyle(
                          fontSize: 10, color: NovaColors.textDim),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() => Container(
        color: NovaColors.surfaceHigh,
        child: Center(
          child: Icon(Icons.movie_creation_outlined,
              size: 34, color: NovaColors.violet.withOpacity(0.5)),
        ),
      );
}
