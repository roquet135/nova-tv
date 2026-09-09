import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/storage.dart';
import 'theme/nova_theme.dart';
import 'screens/portals_screen.dart';
import 'widgets/pointer_arrows.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Storage.init();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  KeyRadar.install();
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVA TV',
      debugShowCheckedModeBanner: false,
      theme: NovaTheme.build(),
      // Listener = traducteur de balayage ; la pastille radar est
      // dessinee PAR-DESSUS toutes les pages.
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerHover: PointerArrows.onPointer,
        onPointerMove: PointerArrows.onPointer,
        child: Stack(
          children: [
            if (child != null) child,
            const KeyRadarBanner(),
          ],
        ),
      ),
      home: const PortalsScreen(),
    );
  }
}

/// RADAR A TOUCHES : ecoute TOUTES les touches qui arrivent de
/// l'exterieur (telecommande, clavier...).
///
/// But : verifier ce que ta telecommande envoie vraiment. A chaque
/// pression, la pastille en bas affiche le nom de la touche recue.
/// Secours : si rien n'est selectionne quand une touche arrive, la
/// selection revient toute seule.
class KeyRadar {
  /// Derniere touche vue (null = aucune touche recue depuis le depart).
  static final ValueNotifier<KeyEvent?> last = ValueNotifier<KeyEvent?>(null);
  static int count = 0;
  static bool _installed = false;

  static void install() {
    if (_installed) return;
    _installed = true;
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  static bool _onKey(KeyEvent e) {
    if (e is! KeyUpEvent && e is! KeyRepeatEvent) {
      count++;
      last.value = e;
    }
    // Filet de securite : une touche arrive mais AUCUN element de
    // l'ecran n'est selectionne -> on en selectionne un automatiquement.
    if (e is KeyDownEvent && FocusManager.instance.primaryFocus == null) {
      final dir = _directionFor(e.logicalKey);
      if (dir != null) {
        FocusManager.instance.rootScope.focusInDirection(dir);
      } else {
        FocusManager.instance.rootScope.nextFocus();
      }
    }
    return false; // on laisse toujours la touche continuer son chemin
  }

  static TraversalDirection? _directionFor(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft) return TraversalDirection.left;
    if (key == LogicalKeyboardKey.arrowRight) return TraversalDirection.right;
    if (key == LogicalKeyboardKey.arrowUp) return TraversalDirection.up;
    if (key == LogicalKeyboardKey.arrowDown) return TraversalDirection.down;
    return null;
  }
}

/// La pastille du radar : apparait 3 secondes a chaque touche recue ou
/// chaque fleche simulee, en bas au centre, sans jamais gener les clics.
class KeyRadarBanner extends StatefulWidget {
  const KeyRadarBanner({super.key});

  @override
  State<KeyRadarBanner> createState() => _KeyRadarBannerState();
}

class _KeyRadarBannerState extends State<KeyRadarBanner> {
  Timer? _timer;
  bool _visible = false;
  String _text = '';

  @override
  void initState() {
    super.initState();
    KeyRadar.last.addListener(_refreshKey);
    PointerArrows.simMsg.addListener(_refreshSim);
  }

  @override
  void dispose() {
    KeyRadar.last.removeListener(_refreshKey);
    PointerArrows.simMsg.removeListener(_refreshSim);
    _timer?.cancel();
    super.dispose();
  }

  void _show(String text) {
    _text = text;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
    setState(() => _visible = true);
  }

  void _refreshKey() {
    final e = KeyRadar.last.value;
    if (e == null) return;
    final k = e.logicalKey;
    _show('TOUCHE VUE : ${k.debugName ?? k.keyLabel}   (x${KeyRadar.count})');
  }

  void _refreshSim() {
    final m = PointerArrows.simMsg.value;
    if (m != null) _show(m);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: _visible ? 1.0 : 0.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                  color: NovaColors.cyan.withValues(alpha: 0.9), width: 1.6),
            ),
            child: Text(
              _text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: NovaColors.cyan,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
