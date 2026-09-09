import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// TRADUCTEUR DE BALAYAGE -> FLECHES.
///
/// Certaines box n'envoient PAS les touches fleches : elles deplacent
/// un pointeur (c'est ce curseur blanc qui apparait dans tes photos).
/// Le radar a touches l'a prouve : presque rien n'arrive, sauf OK.
///
/// Ce module capte les DEPLACEMENTS BRUTS du pointeur provoques par la
/// telecommande et les traduit en un "appui de fleche" quand on balaye
/// franchement dans une direction :
///   balayage vers la droite = fleche DROITE, etc.
///
/// L'ecran d'ajout d'abonnement enregistre son propre recepteur (son
/// curseur virtuel). Partout ailleurs, on fait circuler la selection.
class PointerArrows {
  /// Recepteur specialise de l'ecran actif (ajout abonnement, etc.).
  static ValueSetter<TraversalDirection>? handler;

  /// Message affiche par la pastille radar pour chaque fleche simulee.
  static final ValueNotifier<String?> simMsg = ValueNotifier<String?>(null);

  static Offset? _anchor;
  static DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  /// Distance minimale de balayage pour deduire une fleche (px logiques).
  static const double _threshold = 120;

  /// Anti-rebond : pas plus d'une fleche simulee toutes les 160 ms.
  static const int _debounceMs = 160;

  static void onPointer(PointerEvent e) {
    final now = DateTime.now();
    final p = e.localPosition;
    final anchor = _anchor;
    if (anchor == null) {
      _anchor = p;
      return;
    }
    final dx = p.dx - anchor.dx;
    final dy = p.dy - anchor.dy;

    TraversalDirection? dir;
    if (dx.abs() > _threshold && dx.abs() >= dy.abs()) {
      dir = dx > 0 ? TraversalDirection.right : TraversalDirection.left;
    } else if (dy.abs() > _threshold) {
      dir = dy > 0 ? TraversalDirection.down : TraversalDirection.up;
    }
    if (dir == null) return;

    // Nouvel ancrage : ce morceau de mouvement a ete consomme.
    _anchor = p;
    if (now.difference(_lastEmit).inMilliseconds < _debounceMs) return;
    _lastEmit = now;

    final label = dir == TraversalDirection.up
        ? 'HAUT'
        : dir == TraversalDirection.down
            ? 'BAS'
            : dir == TraversalDirection.left
                ? 'GAUCHE'
                : 'DROITE';
    simMsg.value = 'FLECHE SIMULEE : $label';

    final h = handler;
    if (h != null) {
      h(dir);
    } else if (FocusManager.instance.primaryFocus == null) {
      FocusManager.instance.rootScope.nextFocus();
    } else {
      FocusManager.instance.primaryFocus!.focusInDirection(dir);
    }
  }

  /// Diagnostic : chaque appui du pointeur est affiche par la pastille.
  /// Si ta touche OK centre fait "clic a l'endroit pointe", on le verra.
  static void onPointerDown(PointerDownEvent e) {
    simMsg.value =
        'CLIC VU A (${e.localPosition.dx.round()}, ${e.localPosition.dy.round()})';
  }
}
