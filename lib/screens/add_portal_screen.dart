import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';
import '../widgets/nova_widgets.dart';

/// Formulaire d'ajout d'un abonnement (M3U, Xtream ou Stalker).
///
/// v8 : plus besoin du clavier Android (souvent recalcitrant avec les
/// telecommandes). Un CLAVIER TV INTEGRE, pilotable aux fleches + OK,
/// permet de taper dans les champs. La souris fonctionne aussi.
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
  final List<FocusNode> _fieldNodes = List.generate(5, (_) => FocusNode());

  // Majuscules
  bool _caps = true;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _fieldNodes.length; i++) {
      final idx = i;
      // addListener : compatible toutes versions de Flutter.
      _fieldNodes[i].addListener(() {
        if (_fieldNodes[idx].hasFocus && mounted) {
          setState(() => _activeField = idx);
        }
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    _mac.dispose();
    for (final n in _fieldNodes) {
      n.dispose();
    }
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

  @override
  Widget build(BuildContext context) {
    final fields = _visibleFields;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GradientTitle('Nouvel abonnement', size: 26),
              const SizedBox(height: 18),

              // ----- Type d'abonnement -----
              Row(
                children: PortalType.values.map((t) {
                  final sel = t == _type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _FocusPill(
                      label: t.label,
                      selected: sel,
                      onTap: () => setState(() {
                        _type = t;
                        _activeField = _visibleFields.first;
                      }),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 6),
              Text(
                _type.hint,
                style:
                    const TextStyle(color: NovaColors.textDim, fontSize: 12),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----- Champs -----
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        for (final idx in fields)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _FieldBox(
                              focusNode: _fieldNodes[idx],
                              label: _labelFor(idx),
                              text: _ctrlFor(idx).text,
                              obscure: idx == 3,
                              active: _activeField == idx,
                              onTap: () => setState(() {
                                _activeField = idx;
                                _fieldNodes[idx].requestFocus();
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
                        Row(
                          children: [
                            _FocusPill(
                              label: 'Enregistrer',
                              icon: Icons.check_rounded,
                              selected: true,
                              onTap: _save,
                            ),
                            const SizedBox(width: 14),
                            _FocusPill(
                              label: 'Annuler',
                              icon: Icons.close_rounded,
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
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Clavier TV integre ----------

  Widget _keyboard() {
    const digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];
    const row1 = ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'];
    const row2 = ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'];
    const row3 = ['w', 'x', 'c', 'v', 'b', 'n', ':', '/', '-', '.'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: NovaColors.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NovaColors.cyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _keyRow(digits),
          _keyRow(row1, letters: true),
          _keyRow(row2, letters: true),
          _keyRow(row3, letters: true),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _TvKey(
                label: _caps ? 'MAJ' : 'maj',
                wide: true,
                accent: _caps,
                onTap: () => setState(() => _caps = !_caps),
              ),
              _TvKey(label: '@', onTap: () => _typeChar('@')),
              _TvKey(label: '_', onTap: () => _typeChar('_')),
              _TvKey(label: 'www.', wide: true, onTap: () => _typeChar('www.')),
              _TvKey(label: '.com', wide: true, onTap: () => _typeChar('.com')),
              _TvKey(
                label: 'ESPACE',
                wide: true,
                onTap: () => _typeChar(' '),
              ),
              _TvKey(
                icon: Icons.backspace_outlined,
                wide: true,
                danger: true,
                onTap: _backspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyRow(List<String> keys, {bool letters = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final k in keys)
            _TvKey(
              label: letters && _caps ? k.toUpperCase() : k,
              onTap: () => _typeChar(letters && _caps ? k.toUpperCase() : k),
            ),
        ],
      ),
    );
  }
}

/// Case d'affichage d'un champ (pas de TextField = pas de clavier systeme).
class _FieldBox extends StatelessWidget {
  final FocusNode focusNode;
  final String label;
  final String text;
  final bool obscure;
  final bool active;
  final VoidCallback onTap;

  const _FieldBox({
    required this.focusNode,
    required this.label,
    required this.text,
    required this.active,
    required this.onTap,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    final shown = obscure && text.isNotEmpty ? '•' * text.length : text;
    return Focus(
      focusNode: focusNode,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                onTap();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: NovaColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? NovaColors.cyan : Colors.white12,
                  width: active ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        color: NovaColors.textDim, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shown.isEmpty ? ' ' : shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: shown.isEmpty
                          ? NovaColors.textDim
                          : NovaColors.text,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
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

/// Pill focusable telecommande + souris.
class _FocusPill extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _FocusPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.selected = false,
  });

  @override
  State<_FocusPill> createState() => _FocusPillState();
}

class _FocusPillState extends State<_FocusPill> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Focus(
      onFocusChange: (v) => setState(() => _f = v),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                gradient: sel ? NovaColors.brand : null,
                color: sel ? null : NovaColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _f ? NovaColors.cyan : Colors.transparent,
                  width: _f ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 16, color: Colors.white),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
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

/// Touche du clavier TV : focusable aux fleches, validee avec OK.
class _TvKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final bool wide;
  final bool accent;
  final bool danger;
  final VoidCallback onTap;

  const _TvKey({
    required this.onTap,
    this.label,
    this.icon,
    this.wide = false,
    this.accent = false,
    this.danger = false,
  });

  @override
  State<_TvKey> createState() => _TvKeyState();
}

class _TvKeyState extends State<_TvKey> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (v) => setState(() => _f = v),
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
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
              duration: const Duration(milliseconds: 120),
              width: widget.wide ? null : 52,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.wide ? 12 : 0, vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.accent
                    ? NovaColors.violet.withValues(alpha: 0.5)
                    : NovaColors.surfaceHigh,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _f
                      ? NovaColors.cyan
                      : (widget.danger
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : Colors.white10),
                  width: _f ? 2 : 1,
                ),
                boxShadow: _f
                    ? [
                        BoxShadow(
                          color: NovaColors.cyan.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: widget.icon != null
                  ? Icon(widget.icon,
                      size: 16,
                      color: widget.danger
                          ? Colors.redAccent
                          : NovaColors.text)
                  : Text(
                      widget.label ?? '',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.danger
                            ? Colors.redAccent
                            : NovaColors.text,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
