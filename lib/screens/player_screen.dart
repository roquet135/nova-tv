import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/stalker_service.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';

/// Lecteur NOVA.
///
/// Innovations image et son :
///  - AMBILIGHT : halo colore anime derriere l ecran, qui respire.
///  - EGALISEUR VISUEL : barres animees, signature NOVA.
///  - RATIO ADAPTATIF : Original / Plein ecran / Etire (TV 21:9).
///  - VOLUME et zapping a la telecommande.
class PlayerScreen extends StatefulWidget {
  final Channel channel;
  final List<Channel> playlist;
  final StalkerService? stalker;

  const PlayerScreen({
    super.key,
    required this.channel,
    required this.playlist,
    this.stalker,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  late final AnimationController _pulse;

  late Channel _current;
  bool _loading = true;
  String _error = '';
  bool _ui = true;
  bool _ambilight = true;
  double _volume = 1.0;
  BoxFit _fit = BoxFit.contain;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _current = widget.channel;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _play(_current);
    _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _pulse.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _play(Channel c) async {
    setState(() {
      _loading = true;
      _error = '';
      _current = c;
    });

    final old = _controller;
    _controller = null;
    await old?.dispose();

    try {
      var url = c.streamUrl;
      // Stalker : la commande doit etre convertie en vraie URL.
      if (widget.stalker != null && !url.startsWith('http')) {
        url = await widget.stalker!.resolveLink(url);
      }
      if (url.isEmpty) throw Exception('Flux indisponible');

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Safari/537.36',
        },
      );

      await ctrl.initialize().timeout(const Duration(seconds: 45));
      await ctrl.setVolume(_volume);
      await ctrl.play();
      await Storage.setLastChannel(c.id);

      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _ui = false);
    });
  }

  void _wake() {
    setState(() => _ui = true);
    _scheduleHide();
  }

  void _zap(int delta) {
    final list = widget.playlist;
    if (list.isEmpty) return;
    final i = list.indexWhere((e) => e.id == _current.id);
    var next = (i < 0 ? 0 : i) + delta;
    if (next < 0) next = list.length - 1;
    if (next >= list.length) next = 0;
    _play(list[next]);
    _wake();
  }

  Future<void> _setVolume(double v) async {
    final nv = v.clamp(0.0, 1.0);
    setState(() => _volume = nv);
    await _controller?.setVolume(nv);
    _wake();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    c.value.isPlaying ? c.pause() : c.play();
    _wake();
  }

  void _cycleFit() {
    const fits = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
    setState(() => _fit = fits[(fits.indexOf(_fit) + 1) % fits.length]);
    _wake();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;

    if (k == LogicalKeyboardKey.arrowUp) {
      _zap(-1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowDown) {
      _zap(1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      _setVolume(_volume + 0.1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      _setVolume(_volume - 0.1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyZ) {
      _cycleFit();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyL) {
      setState(() => _ambilight = !_ambilight);
      _wake();
      return KeyEventResult.handled;
    }
    _wake();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        onTap: _wake,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (_ambilight) _ambilightLayer(),
              if (ctrl != null && ctrl.value.isInitialized)
                Center(
                  child: FittedBox(
                    fit: _fit,
                    child: SizedBox(
                      width: ctrl.value.size.width,
                      height: ctrl.value.size.height,
                      child: VideoPlayer(ctrl),
                    ),
                  ),
                ),
              if (_loading) _loadingLayer(),
              if (_error.isNotEmpty) _errorLayer(),
              AnimatedOpacity(
                opacity: _ui ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(ignoring: !_ui, child: _overlay()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Halo colore anime derriere la video : effet ambilight.
  Widget _ambilightLayer() => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final t = _pulse.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6 + t * 1.2, -0.6 + t * 0.8),
                radius: 1.1 + t * 0.35,
                colors: [
                  NovaColors.violet.withValues(alpha: 0.32 + t * 0.12),
                  NovaColors.cyan.withValues(alpha: 0.16),
                  Colors.black,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          );
        },
      );

  Widget _loadingLayer() => Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: NovaColors.cyan),
              SizedBox(height: 16),
              Text('Ouverture du flux...',
                  style: TextStyle(color: NovaColors.textDim)),
            ],
          ),
        ),
      );

  Widget _errorLayer() => Container(
        color: Colors.black87,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.signal_wifi_bad_rounded,
                    size: 54, color: Colors.redAccent),
                const SizedBox(height: 14),
                Text(_error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      autofocus: true,
                      onPressed: () => _play(_current),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reessayer'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _zap(1),
                      icon: const Icon(Icons.skip_next_rounded),
                      label: const Text('Chaine suivante'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _overlay() => Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: NovaColors.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _current.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700),
                      ),
                      Text(_current.group,
                          style: const TextStyle(
                              color: NovaColors.textDim, fontSize: 12)),
                    ],
                  ),
                ),
                _eq(),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _chip(Icons.volume_up_rounded,
                    'Volume ${(_volume * 100).round()}%   (gauche / droite)'),
                _chip(Icons.aspect_ratio_rounded,
                    'Image : ${_fitLabel()}   (Z)'),
                _chip(Icons.lightbulb_outline_rounded,
                    'Ambilight : ${_ambilight ? "on" : "off"}   (L)'),
                _chip(Icons.swap_vert_rounded, 'Zapper : haut / bas'),
              ],
            ),
          ),
        ],
      );

  String _fitLabel() {
    switch (_fit) {
      case BoxFit.cover:
        return 'Plein ecran';
      case BoxFit.fill:
        return 'Etire';
      default:
        return 'Original';
    }
  }

  Widget _chip(IconData i, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 15, color: NovaColors.cyan),
            const SizedBox(width: 8),
            Text(t, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  /// Egaliseur decoratif anime, signature visuelle de NOVA.
  Widget _eq() => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final phase = (_pulse.value + i * 0.18) % 1.0;
              final h = 8 + (phase < 0.5 ? phase : 1 - phase) * 34;
              return Container(
                width: 4,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: NovaColors.brand,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      );
}
