import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/stalker_service.dart';
import '../theme/nova_theme.dart';

/// Mini televiseur en incrustation.
///
/// Premier clic sur une chaine : elle demarre ici, en petit, sans quitter
/// la liste. Deuxieme clic sur la meme chaine : plein ecran.
class MiniPlayer extends StatefulWidget {
  final Channel? channel;
  final StalkerService? stalker;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  const MiniPlayer({
    super.key,
    required this.channel,
    required this.onExpand,
    required this.onClose,
    this.stalker,
  });

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _ctrl;
  late final AnimationController _pulse;
  bool _loading = false;
  String _error = '';
  String _loadedId = '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    if (widget.channel != null) _open(widget.channel!);
  }

  @override
  void didUpdateWidget(MiniPlayer old) {
    super.didUpdateWidget(old);
    final c = widget.channel;
    if (c == null) {
      _dispose();
    } else if (c.id != _loadedId) {
      _open(c);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ctrl?.dispose();
    super.dispose();
  }

  void _dispose() {
    final old = _ctrl;
    _ctrl = null;
    _loadedId = '';
    old?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _open(Channel c) async {
    _loadedId = c.id;
    setState(() {
      _loading = true;
      _error = '';
    });

    final old = _ctrl;
    _ctrl = null;
    await old?.dispose();

    try {
      var url = c.streamUrl;
      if (widget.stalker != null && !url.startsWith('http')) {
        url = await widget.stalker!.resolveLink(url);
      }
      if (url.isEmpty) throw Exception('Flux vide');

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Safari/537.36',
        },
      );
      await ctrl.initialize().timeout(const Duration(seconds: 25));
      await ctrl.setVolume(0.6);
      await ctrl.play();

      if (!mounted || _loadedId != c.id) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || _loadedId != c.id) return;
      setState(() {
        _loading = false;
        _error = 'Lien mort';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    if (c == null) return const SizedBox.shrink();
    final ctrl = _ctrl;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: NovaColors.cyan
                    .withOpacity(0.25 + _pulse.value * 0.25),
                blurRadius: 26 + _pulse.value * 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 320,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NovaColors.cyan.withOpacity(0.55)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ecran
              GestureDetector(
                onTap: widget.onExpand,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      if (ctrl != null && ctrl.value.isInitialized)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: ctrl.value.size.width,
                            height: ctrl.value.size.height,
                            child: VideoPlayer(ctrl),
                          ),
                        ),
                      if (_loading)
                        const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: NovaColors.cyan),
                          ),
                        ),
                      if (_error.isNotEmpty)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link_off_rounded,
                                  color: Colors.redAccent, size: 26),
                              const SizedBox(height: 6),
                              Text(_error,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.redAccent)),
                            ],
                          ),
                        ),

                      // Pastille EN DIRECT
                      Positioned(
                        top: 7,
                        left: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _error.isEmpty
                                      ? const Color(0xFF22C55E)
                                      : Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text('APERCU',
                                  style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6)),
                            ],
                          ),
                        ),
                      ),

                      // Fermer
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: widget.onClose,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ),

                      // Invite plein ecran
                      Positioned(
                        bottom: 6,
                        right: 7,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: NovaColors.brand,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_rounded,
                                  size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Text('Plein ecran',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bandeau titre
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                color: NovaColors.surface,
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 22,
                      decoration: BoxDecoration(
                        gradient: NovaColors.brand,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            c.group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 9.5, color: NovaColors.textDim),
                          ),
                        ],
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
}
