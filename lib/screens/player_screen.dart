import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/stalker_service.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';

// --- Intentions de la telecommande ---
class _ZapUpIntent extends Intent {
  const _ZapUpIntent();
}

class _ZapDownIntent extends Intent {
  const _ZapDownIntent();
}

class _VolUpIntent extends Intent {
  const _VolUpIntent();
}

class _VolDownIntent extends Intent {
  const _VolDownIntent();
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _FitIntent extends Intent {
  const _FitIntent();
}

class _AmbilightIntent extends Intent {
  const _AmbilightIntent();
}

class _PictureIntent extends Intent {
  const _PictureIntent();
}

class _BoostIntent extends Intent {
  const _BoostIntent();
}

/// Profil d'image applique par-dessus la video.
class _Picture {
  final String name;
  final double saturation;
  final double contrast;
  final double brightness;
  final double warmth;

  const _Picture(this.name, this.saturation, this.contrast, this.brightness,
      this.warmth);
}

/// Lecteur NOVA plein ecran.
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
  bool _boost = false;
  BoxFit _fit = BoxFit.contain;
  int _pictureIndex = 0;
  Timer? _hide;

  /// Profils d'image. Standard laisse le flux intact.
  static const List<_Picture> _pictures = [
    _Picture('Standard', 1.00, 1.00, 0.00, 0.00),
    _Picture('Eclatant', 1.35, 1.14, 0.02, 0.02),
    _Picture('Cinema', 1.08, 1.16, -0.03, 0.06),
    _Picture('Sport', 1.22, 1.08, 0.05, -0.03),
    _Picture('Nuit', 0.92, 0.90, -0.10, 0.05),
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.channel;
    _pictureIndex = Storage.getDouble('picture', fallback: 0).toInt();
    if (_pictureIndex >= _pictures.length) _pictureIndex = 0;
    _boost = Storage.getBool('boost');
    _ambilight = Storage.getBool('ambilight', fallback: true);
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
      if (widget.stalker != null && !url.startsWith('http')) {
        url = await widget.stalker!.resolveLink(url);
      }
      if (url.isEmpty) throw Exception('Flux indisponible');

      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Safari/537.36',
        },
      );

      await ctrl.initialize().timeout(const Duration(seconds: 45));
      await ctrl.setVolume(_effectiveVolume);
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

  /// Le mode Boost pousse le gain au-dela de 100% pour les flux trop faibles.
  double get _effectiveVolume {
    final v = _boost ? _volume * 1.6 : _volume;
    return v > 1.0 ? 1.0 : v;
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
    final nv = v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);
    setState(() => _volume = nv);
    await _controller?.setVolume(_effectiveVolume);
    _wake();
  }

  Future<void> _toggleBoost() async {
    setState(() => _boost = !_boost);
    await Storage.setBool('boost', _boost);
    await _controller?.setVolume(_effectiveVolume);
    _wake();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    _wake();
  }

  void _cycleFit() {
    const fits = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
    setState(() => _fit = fits[(fits.indexOf(_fit) + 1) % fits.length]);
    _wake();
  }

  Future<void> _cyclePicture() async {
    setState(() => _pictureIndex = (_pictureIndex + 1) % _pictures.length);
    await Storage.setDouble('picture', _pictureIndex.toDouble());
    _wake();
  }

  Future<void> _toggleAmbilight() async {
    setState(() => _ambilight = !_ambilight);
    await Storage.setBool('ambilight', _ambilight);
    _wake();
  }

  /// Matrice de couleur : saturation, contraste, luminosite, chaleur.
  ColorFilter _colorFilter() {
    final p = _pictures[_pictureIndex];
    final s = p.saturation;
    final c = p.contrast;
    final b = p.brightness * 255;
    final w = p.warmth;

    // Luminance perceptuelle
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;

    // Chaleur : renforce le rouge, attenue le bleu
    final rw = 1 + w, bw = 1 - w;

    final off = b + (1 - c) * 127.5;

    return ColorFilter.matrix(<double>[
      (sr + s) * c * rw, sg * c, sb * c, 0, off,
      sr * c, (sg + s) * c, sb * c, 0, off,
      sr * c, sg * c, (sb + s) * c * bw, 0, off,
      0, 0, 0, 1, 0,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final neutral = _pictureIndex == 0;

    Widget video = const SizedBox.shrink();
    if (ctrl != null && ctrl.value.isInitialized) {
      video = FittedBox(
        fit: _fit,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      );
      if (!neutral) {
        video = ColorFiltered(colorFilter: _colorFilter(), child: video);
      }
    }

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp): _ZapUpIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): _ZapDownIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _VolUpIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _VolDownIntent(),
        SingleActivator(LogicalKeyboardKey.select): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.space): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.mediaPlayPause): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ): _FitIntent(),
        SingleActivator(LogicalKeyboardKey.keyL): _AmbilightIntent(),
        SingleActivator(LogicalKeyboardKey.keyI): _PictureIntent(),
        SingleActivator(LogicalKeyboardKey.keyB): _BoostIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ZapUpIntent: CallbackAction<_ZapUpIntent>(onInvoke: (i) {
            _zap(-1);
            return null;
          }),
          _ZapDownIntent: CallbackAction<_ZapDownIntent>(onInvoke: (i) {
            _zap(1);
            return null;
          }),
          _VolUpIntent: CallbackAction<_VolUpIntent>(onInvoke: (i) {
            _setVolume(_volume + 0.1);
            return null;
          }),
          _VolDownIntent: CallbackAction<_VolDownIntent>(onInvoke: (i) {
            _setVolume(_volume - 0.1);
            return null;
          }),
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(onInvoke: (i) {
            _togglePlay();
            return null;
          }),
          _FitIntent: CallbackAction<_FitIntent>(onInvoke: (i) {
            _cycleFit();
            return null;
          }),
          _AmbilightIntent: CallbackAction<_AmbilightIntent>(onInvoke: (i) {
            _toggleAmbilight();
            return null;
          }),
          _PictureIntent: CallbackAction<_PictureIntent>(onInvoke: (i) {
            _cyclePicture();
            return null;
          }),
          _BoostIntent: CallbackAction<_BoostIntent>(onInvoke: (i) {
            _toggleBoost();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: _wake,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  if (_ambilight) _ambilightLayer(),
                  Center(child: video),
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
        ),
      ),
    );
  }

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
                  NovaColors.violet.withOpacity(0.32 + t * 0.12),
                  NovaColors.cyan.withOpacity(0.16),
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
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 38),
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
            padding: const EdgeInsets.fromLTRB(28, 38, 28, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 9,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _chip(Icons.tune_rounded,
                    'Image : ${_pictures[_pictureIndex].name}   (I)',
                    active: _pictureIndex != 0),
                _chip(Icons.volume_up_rounded,
                    'Volume ${(_volume * 100).round()}%'),
                _chip(Icons.graphic_eq_rounded,
                    'Boost son : ${_boost ? "on" : "off"}   (B)',
                    active: _boost),
                _chip(Icons.aspect_ratio_rounded,
                    'Format : ${_fitLabel()}   (Z)'),
                _chip(Icons.lightbulb_outline_rounded,
                    'Ambilight : ${_ambilight ? "on" : "off"}   (L)',
                    active: _ambilight),
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

  Widget _chip(IconData i, String t, {bool active = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: active ? NovaColors.brand : null,
          color: active ? null : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.transparent
                : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 14, color: active ? Colors.white : NovaColors.cyan),
            const SizedBox(width: 7),
            Text(t,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                )),
          ],
        ),
      );

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
