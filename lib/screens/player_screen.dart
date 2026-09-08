import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../services/epg_service.dart';
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

/// OK en mode normal : ouvre le panneau des reglages focusable.
class _OpenCtrlsIntent extends Intent {
  const _OpenCtrlsIntent();
}

/// Retour quand le panneau est ouvert : referme le panneau.
class _ExitCtrlsIntent extends Intent {
  const _ExitCtrlsIntent();
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
  final EpgService? epg;

  const PlayerScreen({
    super.key,
    required this.channel,
    required this.playlist,
    this.stalker,
    this.epg,
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
  List<EpgProgram> _programs = [];

  // Panneau de reglages pilotable a la telecommande :
  // OK l'ouvre, les fleches naviguent entre les boutons, OK valide.
  bool _ctrls = false;
  final FocusNode _firstCtrl = FocusNode(debugLabel: 'firstCtrl');

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
    _firstCtrl.dispose();
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
      _loadEpg(c);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadEpg(Channel c) async {
    setState(() => _programs = []);
    final svc = widget.epg;
    if (svc == null) return;
    final sid = c.id.startsWith('xt_live_') ? c.id.substring(8) : '';
    if (sid.isEmpty) return;
    final p = await svc.forStream(sid);
    if (!mounted || _current.id != c.id) return;
    setState(() => _programs = p);
  }

  /// Le mode Boost pousse le gain au-dela de 100% pour les flux trop faibles.
  double get _effectiveVolume {
    final v = _boost ? _volume * 1.6 : _volume;
    return v > 1.0 ? 1.0 : v;
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 6), () {
      // On ne masque pas l'interface pendant la navigation dans le panneau.
      if (mounted && !_ctrls) setState(() => _ui = false);
    });
  }

  void _wake() {
    setState(() => _ui = true);
    _scheduleHide();
  }

  // --- Panneau de reglages telecommande ---

  void _enterCtrls() {
    setState(() => _ctrls = true);
    _wake();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstCtrl.requestFocus();
    });
  }

  void _exitCtrls() {
    setState(() => _ctrls = false);
    _wake();
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

    // En mode "panneau", les fleches servent a naviguer entre les boutons :
    // on desactive donc les raccourcis fleches (zap/volume).
    final Map<ShortcutActivator, Intent> shortcuts = _ctrls
        ? const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.goBack): _ExitCtrlsIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _ExitCtrlsIntent(),
          }
        : const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.arrowUp): _ZapUpIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): _ZapDownIntent(),
            SingleActivator(LogicalKeyboardKey.arrowRight): _VolUpIntent(),
            SingleActivator(LogicalKeyboardKey.arrowLeft): _VolDownIntent(),
            SingleActivator(LogicalKeyboardKey.select): _OpenCtrlsIntent(),
            SingleActivator(LogicalKeyboardKey.enter): _OpenCtrlsIntent(),
            SingleActivator(LogicalKeyboardKey.space): _PlayPauseIntent(),
            SingleActivator(LogicalKeyboardKey.mediaPlayPause):
                _PlayPauseIntent(),
            SingleActivator(LogicalKeyboardKey.keyZ): _FitIntent(),
            SingleActivator(LogicalKeyboardKey.keyL): _AmbilightIntent(),
            SingleActivator(LogicalKeyboardKey.keyI): _PictureIntent(),
            SingleActivator(LogicalKeyboardKey.keyB): _BoostIntent(),
          };

    return Shortcuts(
      shortcuts: shortcuts,
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
          _OpenCtrlsIntent: CallbackAction<_OpenCtrlsIntent>(onInvoke: (i) {
            _enterCtrls();
            return null;
          }),
          _ExitCtrlsIntent: CallbackAction<_ExitCtrlsIntent>(onInvoke: (i) {
            _exitCtrls();
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
                      if (_nowNext != null) ...[
                        const SizedBox(height: 7),
                        _nowNext!,
                      ],
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
            // Panneau de boutons focusables, ou simples infos + invite OK.
            child: _ctrls ? _controlsBar() : _infoChips(),
          ),
        ],
      );

  /// Affichage normal : infos non selectionnables + invite a appuyer sur OK.
  Widget _infoChips() => Wrap(
        spacing: 10,
        runSpacing: 9,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chip(Icons.smart_button_rounded, 'OK : reglages', active: true),
          _chip(Icons.tune_rounded, 'Image : ${_pictures[_pictureIndex].name}',
              active: _pictureIndex != 0),
          _chip(Icons.volume_up_rounded, 'Volume ${(_volume * 100).round()}%'),
          _chip(Icons.graphic_eq_rounded,
              'Boost son : ${_boost ? "on" : "off"}',
              active: _boost),
          _chip(Icons.aspect_ratio_rounded, 'Format : ${_fitLabel()}'),
          _chip(Icons.lightbulb_outline_rounded,
              'Ambilight : ${_ambilight ? "on" : "off"}',
              active: _ambilight),
          _chip(Icons.swap_vert_rounded, 'Zapper : haut / bas'),
        ],
      );

  /// Panneau de reglages : chaque bouton est atteignable avec les fleches
  /// de la telecommande, et se valide avec OK.
  Widget _controlsBar() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _PlayerBtn(
              focusNode: _firstCtrl,
              icon: Icons.tune_rounded,
              label: 'Image : ${_pictures[_pictureIndex].name}',
              active: _pictureIndex != 0,
              onTap: () {
                _cyclePicture();
              },
            ),
            _PlayerBtn(
              icon: Icons.aspect_ratio_rounded,
              label: 'Format : ${_fitLabel()}',
              onTap: () {
                _cycleFit();
              },
            ),
            _PlayerBtn(
              icon: Icons.graphic_eq_rounded,
              label: 'Boost : ${_boost ? "on" : "off"}',
              active: _boost,
              onTap: () {
                _toggleBoost();
              },
            ),
            _PlayerBtn(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Ambilight : ${_ambilight ? "on" : "off"}',
              active: _ambilight,
              onTap: () {
                _toggleAmbilight();
              },
            ),
            _PlayerBtn(
              icon: Icons.remove_rounded,
              label: 'Vol -',
              onTap: () {
                _setVolume(_volume - 0.1);
              },
            ),
            _PlayerBtn(
              icon: Icons.add_rounded,
              label: 'Vol + ${(_volume * 100).round()}%',
              onTap: () {
                _setVolume(_volume + 0.1);
              },
            ),
            _PlayerBtn(
              icon: Icons.skip_previous_rounded,
              label: 'Chaine -',
              onTap: () {
                _zap(-1);
              },
            ),
            _PlayerBtn(
              icon: Icons.skip_next_rounded,
              label: 'Chaine +',
              onTap: () {
                _zap(1);
              },
            ),
            _PlayerBtn(
              icon: Icons.close_rounded,
              label: 'Retour',
              danger: true,
              onTap: _exitCtrls,
            ),
          ],
        ),
      );

  /// Programme en cours et suivant, facon guide TV.
  Widget? get _nowNext {
    if (_programs.isEmpty) return null;
    EpgProgram? now;
    EpgProgram? next;
    for (final p in _programs) {
      if (p.isNow) {
        now = p;
      } else if (now != null && next == null && p.start.isAfter(now.start)) {
        next = p;
      }
    }
    now ??= _programs.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: NovaColors.brand,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('MAINTENANT',
                  style:
                      TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Text(now.range,
                style: const TextStyle(
                    fontSize: 11,
                    color: NovaColors.cyan,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                now.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 340,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: now.progress,
              minHeight: 3,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(NovaColors.cyan),
            ),
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 5),
          Text(
            'Ensuite ${next.startLabel}  -  ${next.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10.5, color: NovaColors.textDim),
          ),
        ],
      ],
    );
  }

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

/// Bouton du panneau plein ecran : focusable aux fleches de la
/// telecommande, validable avec OK, cliquable a la souris.
/// Un cadre cyan marque le bouton selectionne.
class _PlayerBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;
  final FocusNode? focusNode;

  const _PlayerBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.danger = false,
    this.focusNode,
  });

  @override
  State<_PlayerBtn> createState() => _PlayerBtnState();
}

class _PlayerBtnState extends State<_PlayerBtn> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (v) => setState(() => _f = v),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                widget.onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: widget.active && !_f ? NovaColors.brand : null,
                color: widget.active && !_f
                    ? null
                    : Colors.white.withOpacity(_f ? 0.20 : 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _f
                      ? NovaColors.cyan
                      : (widget.danger
                          ? Colors.redAccent.withOpacity(0.5)
                          : Colors.white.withOpacity(0.12)),
                  width: _f ? 2.2 : 1,
                ),
                boxShadow: _f
                    ? [
                        BoxShadow(
                          color: NovaColors.cyan.withOpacity(0.35),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 14,
                    color: widget.danger
                        ? Colors.redAccent
                        : (widget.active && !_f
                            ? Colors.white
                            : NovaColors.cyan),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: (widget.active || _f)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: widget.danger ? Colors.redAccent : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
