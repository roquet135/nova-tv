import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _focused = v),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final k = event.logicalKey.keyLabel;
          if (k == 'Select' || k == 'Enter' || k == ' ') {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scale(_focused ? 1.06 : 1.0),
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

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (v) => setState(() => _f = v),
      onKeyEvent: (n, e) {
        if (e is KeyDownEvent) {
          final k = e.logicalKey.keyLabel;
          if (k == 'Select' || k == 'Enter' || k == ' ') {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
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
    );
  }
}
