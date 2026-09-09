import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/nova_theme.dart';

/// Carte focalisable pensee pour la telecommande : elle grandit et
/// s'entoure d'un halo degrade quand le focus arrive dessus.
class FocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool autofocus;
  final double radius;

  const FocusCard({
    super.key,
    required this.child,
    required this.onTap,
    this.autofocus = false,
    this.radius = 16,
  });

  @override
  State<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends State<FocusCard> {
  bool _focused = false;
  final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // InkWell gere nativement la touche OK de la telecommande
    // et le clic, sans dependre d'une API clavier instable.
    //
    // v10.6 : MouseRegion -> viser avec le pointeur selectionne
    // l'element. Sur les telecommandes "toutes OK seulement", c'est
    // ce qui permet enfin d'appuyer OK dessus sans fleches.
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      child: MouseRegion(
        onEnter: (_) => _node.requestFocus(),
        child: Builder(
        builder: (context) {
          return Shortcuts(
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
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  transform: Matrix4.diagonal3Values(
                    _focused ? 1.06 : 1.0,
                    _focused ? 1.06 : 1.0,
                    1.0,
                  ),
                  transformAlignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius),
                    gradient: _focused ? NovaColors.focusGlow : null,
                    color: _focused ? null : NovaColors.surface,
                    boxShadow: _focused
                        ? [
                            BoxShadow(
                              color: NovaColors.cyan.withValues(alpha: 0.35),
                              blurRadius: 28,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  padding: EdgeInsets.all(_focused ? 2 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: NovaColors.surface,
                      borderRadius: BorderRadius.circular(widget.radius - 2),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      ),
    );
  }
}

/// Titre avec degrade de marque.
class GradientTitle extends StatelessWidget {
  final String text;
  final double size;
  const GradientTitle(this.text, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) => NovaColors.brand.createShader(r),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

/// Bouton principal focalisable.
class NovaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool autofocus;

  const NovaButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  State<NovaButton> createState() => _NovaButtonState();
}

class _NovaButtonState extends State<NovaButton> {
  bool _f = false;
  final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _f = v),
      child: MouseRegion(
        onEnter: (_) => _node.requestFocus(),
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
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                gradient: _f ? NovaColors.brand : null,
                color: _f ? null : NovaColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                boxShadow: _f
                    ? [
                        BoxShadow(
                          color: NovaColors.violet.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
