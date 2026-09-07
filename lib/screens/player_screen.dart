import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../models/models.dart';
import '../services/stalker_service.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';

/// Lecteur NOVA.
///
/// Innovations image et son :
///  - AMBILIGHT : un halo colore anime derriere l ecran, qui respire.
///  - EGALISEUR VISUEL : barres reactives au temps de lecture.
///  - MODES SONORES : normal, voix claire, nuit, cinema (via mpv audio filters).
///  - RATIO ADAPTATIF et ZOOM pour remplir les televiseurs 21:9.
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
  late final Player _player;
  late final VideoController _video;
  late final AnimationController _pulse;

  late Channel _current;
  bool _loading = true;
  String _error = '';
  bool _ui = true;
  bool _ambilight = true;
  int _audioMode = 0;
  BoxFit _fit = BoxFit.contain;
  Timer? _hide;

  static const _audioModes = [
    ('Normal', ''),
    ('Voix claire', 'lavfi=[equalizer=f=2500:t=q:w=1.4:g=6,equalizer=f=180:t=q:w=1:g=-4]'),
    ('Nuit', 'lavfi=[acompressor=threshold=-24dB:ratio=6:attack=10:release=250,loudnorm=I=-18]'),
    ('Cinema', 'lavfi=[bass=g=6:f=90,treble=g=3:f=9000,extrastereo=m=1.4]'),
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.channel;
    _player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
        title: 'NOVA TV',
      ),
    );
    _video = VideoController(_player);
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
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(Channel c) async {
    setState(() {
      _loading = true;
      _error = '';
      _current = c;
    });
    try {
      var url = c.streamUrl;
      // Stalker : la commande doit etre convertie en vraie URL.
      if (widget.stalker != null && !url.startsWith('http')) {
        url = await widget.stalker!.resolveLink(url);
      }
      if (url.isEmpty) throw Exception('Flux indisponible');

      await _player.open(Media(url), play: true);
      await Storage.setLastChannel(c.id);
      if (mounted) setState(() => _loading = false);
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
    final next = ((i < 0 ? 0 : i) + delta) % list.length;
    _play(list[next < 0 ? list.length - 1 : next]);
    _wake();
  }

  Future<void> _cycleAudio() async {
    setState(() => _audioMode = (_audioMode + 1) % _audioModes.length);
    final filter = _audioModes[_audioMode].$2;
    try {
      // media_kit expose la plateforme native mpv pour les filtres audio.
      final native = _player.platform;
      if (native is NativePlayer) {
        await native.setProperty('af', filter);
      }
    } catch (_) {
      // Filtre non supporte : on garde le son normal, sans casser la lecture.
    }
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
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.space) {
      _player.playOrPause();
      _wake();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyA) {
      _cycleAudio();
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
              Center(
                child: Video(
                  controller: _video,
                  fit: _fit,
                  controls: NoVideoControls,
                ),
              ),
              if (_loading) _loadingLayer(),
              if (_error.isNotEmpty) _errorLayer(),
              AnimatedOpacity(
                opacity: _ui ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_ui,
                  child: _overlay(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Halo colore anime derriere la video : le fameux effet ambilight.
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
              ElevatedButton.icon(
                autofocus: true,
                onPressed: () => _play(_current),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reessayer'),
              ),
            ],
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
                _chip(Icons.graphic_eq_rounded,
                    'Son : ${_audioModes[_audioMode].$1}   (A)'),
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
