import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';
import '../widgets/nova_widgets.dart';

/// Formulaire d'ajout d'un abonnement (M3U, Xtream ou Stalker).
///
/// v10.2 : navigation 100% MANUELLE au curseur virtuel. On ne compte plus
/// sur le systeme de focus de Flutter (imprevisible avec certaines
/// telecommandes de box TV) : un seul Focus racine capte TOUTES les
/// touches (fleches + OK), et un curseur (zone, ligne, colonne) indique
/// quel element est selectionne. La souris fonctionne toujours en plus.
class AddPortalScreen extends StatefulWidget {
  const AddPortalScreen({super.key});

  @override
  State<AddPortalScreen> createState() => _AddPortalScreenState();
}

class _AddPortalScreenState extends State<AddPortalScreen> {
  PortalType _type = PortalType.m3u;
  final _name = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _mac = TextEditingController(text: '00:1A:79:');
  String? _error;

  // Champ actif (celui dans lequel le clavier ecrit)
  int _activeField = 0;

  // Majuscules
  bool _caps = true;

  // ---------- Curseur virtuel ----------
  // Zones : 0 = onglets type | 1 = champs (gauche) | 2 = clavier (droite)
  //         3 = boutons Enregistrer / Annuler (bas)
  int _z = 2;
  int _r = 1;
  int _c = 0;

  final FocusNode _root = FocusNode(debugLabel: 'addPortalRoot');

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _mac.dispose();
    _root.dispose();
    super.dispose();
  }

  /// Champs visibles selon le type d'abonnement.
  List<int> get _visibleFields {
    switch (_type) {
      case PortalType.m3u:
        return [0, 1];
      case PortalType.xtream:
        return [0, 1, 2, 3];
      case PortalType.stalker:
        return [0, 1, 4];
    }
  }

  TextEditingController _ctrlFor(int idx) {
    switch (idx) {
      case 0:
        return _name;
      case 1:
        return _url;
      case 2:
        return _user;
      case 3:
        return _pass;
      default:
        return _mac;
    }
  }

  String _labelFor(int idx) {
    switch (idx) {
      case 0:
        return 'Nom de l abonnement';
      case 1:
        return _type == PortalType.m3u
            ? 'URL de la playlist'
            : 'Adresse du serveur';
      case 2:
        return 'Identifiant';
      case 3:
        return 'Mot de passe';
      default:
        return 'Adresse MAC';
    }
  }

  TextEditingController get _active => _ctrlFor(_activeField);

  void _typeChar(String ch) {
    final c = _active;
    final t = c.text;
    if (t.length > 300) return;
    c.text = t + ch;
    setState(() {});
  }

  void _backspace() {
    final c = _active;
    final t = c.text;
    if (t.isEmpty) return;
    c.text = t.substring(0, t.length - 1);
    setState(() {});
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Donne un nom a cet abonnement');
      return;
    }
    if (_url.text.trim().isEmpty) {
      setState(() => _error = 'L adresse est obligatoire');
      return;
    }
    if (_type == PortalType.xtream &&
        (_user.text.trim().isEmpty || _pass.text.trim().isEmpty)) {
      setState(() => _error = 'Identifiant et mot de passe requis');
      return;
    }
    if (_type == PortalType.stalker && _mac.text.trim().length < 12) {
      setState(() => _error = 'Adresse MAC invalide');
      return;
    }

    final portal = Portal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      type: _type,
      url: _url.text.trim(),
      username: _user.text.trim(),
      password: _pass.text.trim(),
      macAddress: _mac.text.trim(),
    );
    await Storage.savePortal(portal);
    if (mounted) Navigator.pop(context);
  }

  // =========================================================
  //  NAVIGATION TELECOMMANDE (curseur virtuel)
  // =========================================================

  static const List<String> _rowDigits = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '0'
  ];
  static const List<String> _row1 = [
    'a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'
  ];
  static const List<String> _row2 = [
    'q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'
  ];
  static const List<String> _row3 = [
    'w', 'x', 'c', 'v', 'b', 'n', ':', '/', '-', '.'
  ];
  // Ligne speciale : 7 touches
  static const int _specialLen = 7;

  static const List<int> _kbLen = [10, 10, 10, 10, _specialLen];

  bool _isCur(int z, [int r = 0, int c = 0]) => _z == z && _r == r && _c == c;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    // On ignore les relachements, on gere l'appui ET la repetition
    // (maintenir une fleche de telecommande fait defiler).
    if (e is KeyUpEvent) return KeyEventResult.ignored;

    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _move(-1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _move(1, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(0, -1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(0, 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      _activate();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  int _nFields() => _visibleFields.length;

  void _move(int dc, int dr) {
    setState(() {
      if (_z == 0) {
        // Onglets : gauche/droite uniquement ; bas -> clavier ligne 0
        if (dc != 0) {
          _c = (_c + dc).clamp(0, 2);
        } else if (dr > 0) {
          _z = 2;
          _r = 0;
          _c = _c.clamp(0, _kbLen[0] - 1);
        }
        return;
      }

      if (_z == 1) {
        // Champs (colonne) : haut/bas; droite -> clavier; bas (fin) -> boutons
        if (dr != 0) {
          final nr = _r + dr;
          if (nr >= _nFields()) {
            _z = 3;
            _c = 0;
          } else if (nr >= 0) {
            _r = nr;
          }
        } else if (dc > 0) {
          _z = 2;
          _r = _r.clamp(0, _kbLen.length - 1);
          _c = _c.clamp(0, _kbLen[_r] - 1);
        }
        // (gauche : deja dans la colonne la plus a gauche, on reste)
        return;
      }

      if (_z == 2) {
        // Clavier : deplacement en grille + sorties laterales
        if (dr != 0) {
          final nr = _r + dr;
          if (nr < 0) {
            _z = 0; // tout en haut -> onglets
            _c = _c.clamp(0, 2);
          } else if (nr >= _kbLen.length) {
            _z = 3; // tout en bas -> boutons
            _c = _c.clamp(0, 1);
          } else {
            _r = nr;
            _c = _c.clamp(0, _kbLen[_r] - 1);
          }
        } else if (dc != 0) {
          final nc = _c + dc;
          if (nc < 0 || nc >= _kbLen[_r]) {
            // Sortie laterale : on passe a la colonne des champs
            _z = 1;
            _r = _r.clamp(0, _nFields() - 1);
          } else {
            _c = nc;
          }
        }
        return;
      }

      if (_z == 3) {
        // Boutons : gauche/droite; haut -> clavier derniere ligne
        if (dc != 0) {
          _c = (_c + dc).clamp(0, 1);
        } else if (dr < 0) {
          _z = 2;
          _r = _kbLen.length - 1;
          _c = (_c == 0 ? 1 : 4).clamp(0, _kbLen[_kbLen.length - 1] - 1);
        }
        return;
      }
    });
  }

  void _activate() {
    switch (_z) {
      case 0:
        final t = PortalType.values[_c];
        setState(() {
          _type = t;
          _activeField = _visibleFields.first;
          _r = _r.clamp(0, _nFields() - 1);
        });
        break;
      case 1:
        setState(() => _activeField = _visibleFields[_r]);
        break;
      case 2:
        _pressKey(_r, _c);
        break;
      case 3:
        if (_c == 0) {
          _save();
        } else {
          Navigator.pop(context);
        }
        break;
    }
  }

  void _pressKey(int r, int c) {
    if (r == 0) return _typeChar(_rowDigits[c]);
    if (r == 1) return _typeChar(_caps ? _row1[c].toUpperCase() : _row1[c]);
    if (r == 2) return _typeChar(_caps ? _row2[c].toUpperCase() : _row2[c]);
    if (r == 3) return _typeChar(_caps ? _row3[c].toUpperCase() : _row3[c]);
    // Ligne speciale
    switch (c) {
      case 0:
        setState(() => _caps = !_caps);
        break;
      case 1:
        _typeChar('@');
        break;
      case 2:
        _typeChar('_');
        break;
      case 3:
        _typeChar('www.');
        break;
      case 4:
        _typeChar('.com');
        break;
      case 5:
        _typeChar(' ');
        break;
      case 6:
        _backspace();
        break;
    }
  }

  // =========================================================
  //  UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final fields = _visibleFields;

    return Scaffold(
      body: Focus(
        focusNode: _root,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GradientTitle('Nouvel abonnement', size: 24),
                const SizedBox(height: 14),

                // ----- Type d'abonnement -----
                Row(
                  children: [
                    for (var i = 0; i < PortalType.values.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _CursorPill(
                          label: PortalType.values[i].label,
                          selected: PortalType.values[i] == _type,
                          focused: _isCur(0, 0, i),
                          onTap: () => setState(() {
                            _z = 0;
                            _c = i;
                            _activate();
                          }),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _type.hint,
                  style:
                      const TextStyle(color: NovaColors.textDim, fontSize: 12),
                ),
                const SizedBox(height: 14),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----- Champs -----
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          for (var fi = 0; fi < fields.length; fi++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _FieldBox(
                                label: _labelFor(fields[fi]),
                                text: _ctrlFor(fields[fi]).text,
                                obscure: fields[fi] == 3,
                                active: _activeField == fields[fi],
                                focused: _isCur(1, fi),
                                onTap: () => setState(() {
                                  _z = 1;
                                  _r = fi;
                                  _activeField = fields[fi];
                                }),
                              ),
                            ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.redAccent)),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _CursorPill(
                                label: 'Enregistrer',
                                icon: Icons.check_rounded,
                                selected: true,
                                focused: _isCur(3, 0, 0),
                                onTap: _save,
                              ),
                              const SizedBox(width: 12),
                              _CursorPill(
                                label: 'Annuler',
                                icon: Icons.close_rounded,
                                focused: _isCur(3, 0, 1),
                                onTap: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),

                    // ----- Clavier TV -----
                    Expanded(flex: 6, child: _keyboard()),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Telecommande : fleches pour se deplacer, OK pour taper.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: NovaColors.textDim, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Clavier TV integre ----------

  Widget _keyboard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.cyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _charRow(0, _rowDigits),
          _charRow(1, _row1),
          _charRow(2, _row2),
          _charRow(3, _row3),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _KbKey(
                label: _caps ? 'MAJ' : 'maj',
                wide: true,
                accent: _caps,
                focused: _isCur(2, 4, 0),
                onTap: () {
                  setState(() {
                    _z = 2;
                    _r = 4;
                    _c = 0;
                    _caps = !_caps;
                  });
                },
              ),
              _KbKey(
                label: '@',
                focused: _isCur(2, 4, 1),
                onTap: () => _tapSpecial(1),
              ),
              _KbKey(
                label: '_',
                focused: _isCur(2, 4, 2),
                onTap: () => _tapSpecial(2),
              ),
              _KbKey(
                label: 'www.',
                wide: true,
                focused: _isCur(2, 4, 3),
                onTap: () => _tapSpecial(3),
              ),
              _KbKey(
                label: '.com',
                wide: true,
                focused: _isCur(2, 4, 4),
                onTap: () => _tapSpecial(4),
              ),
              _KbKey(
                label: 'ESPACE',
                wide: true,
                focused: _isCur(2, 4, 5),
                onTap: () => _tapSpecial(5),
              ),
              _KbKey(
                icon: Icons.backspace_outlined,
                wide: true,
                danger: true,
                focused: _isCur(2, 4, 6),
                onTap: () => _tapSpecial(6),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _tapSpecial(int c) {
    setState(() {
      _z = 2;
      _r = 4;
      _c = c;
    });
    _pressKey(4, c);
  }

  Widget _charRow(int r, List<String> keys) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (var c = 0; c < keys.length; c++)
            _KbKey(
              label: _caps && r > 0 && r < 4 ? keys[c].toUpperCase() : keys[c],
              focused: _isCur(2, r, c),
              onTap: () {
                setState(() {
                  _z = 2;
                  _r = r;
                  _c = c;
                });
                _pressKey(r, c);
              },
            ),
        ],
      ),
    );
  }
}

// =========================================================
//  WIDGETS SIMPLES (la bordure cyan = position du curseur)
// =========================================================

/// Case d'affichage d'un champ (pas de TextField = pas de clavier systeme).
class _FieldBox extends StatelessWidget {
  final String label;
  final String text;
  final bool obscure;
  final bool active;
  final bool focused;
  final VoidCallback onTap;

  const _FieldBox({
    required this.label,
    required this.text,
    required this.active,
    required this.focused,
    required this.onTap,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final shown = obscure && text.isNotEmpty ? '•' * text.length : text;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: NovaColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focused
                ? NovaColors.cyan
                : (active
                    ? NovaColors.cyan.withValues(alpha: 0.45)
                    : Colors.white12),
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: NovaColors.cyan.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: NovaColors.textDim, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              shown.isEmpty ? ' ' : shown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: shown.isEmpty ? NovaColors.textDim : NovaColors.text,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill (onglet de type ou bouton d'action).
class _CursorPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool focused;
  final VoidCallback onTap;

  const _CursorPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected ? NovaColors.brand : null,
          color: selected ? null : NovaColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: focused ? NovaColors.cyan : Colors.transparent,
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: NovaColors.cyan.withValues(alpha: 0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Touche du clavier TV.
class _KbKey extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool wide;
  final bool accent;
  final bool danger;
  final bool focused;
  final VoidCallback onTap;

  const _KbKey({
    required this.onTap,
    this.label,
    this.icon,
    this.wide = false,
    this.accent = false,
    this.danger = false,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: wide ? null : 50,
        padding: EdgeInsets.symmetric(
            horizontal: wide ? 12 : 0, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent
              ? NovaColors.violet.withValues(alpha: 0.5)
              : NovaColors.surfaceHigh,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: focused
                ? NovaColors.cyan
                : (danger
                    ? Colors.redAccent.withValues(alpha: 0.4)
                    : Colors.white10),
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: NovaColors.cyan.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: icon != null
            ? Icon(icon!,
                size: 16, color: danger ? Colors.redAccent : NovaColors.text)
            : Text(
                label ?? '',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: danger ? Colors.redAccent : NovaColors.text,
                ),
              ),
      ),
    );
  }
}
