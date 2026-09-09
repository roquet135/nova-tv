import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/nova_theme.dart';

/// Fond NOVA : des vagues de couleur composees de degrades radiaux.
///
/// v10.3 : FIGE volontairement. Avant, la nappe bougeait en continu et
/// forcait un redessin complet de l'ecran 60 fois par seconde : sur une
/// box TV modeste, ca donnait des saccades des qu'on defilait dans les
/// grilles. Peint UNE SEULE FOIS, zero effort ensuite.
/// (L'animation ne te manque pas ? on te la remettra en option plus tard.)
class AuroraBackground extends StatelessWidget {
  final Widget child;

  /// 0 = calme (ecrans de liste), 1 = intense (accueil)
  final double intensity;

  const AuroraBackground({
    super.key,
    required this.child,
    this.intensity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: NovaColors.bg),
          CustomPaint(
            painter: _AuroraPainter(t: 0.31, intensity: intensity),
          ),
          child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final double intensity;

  _AuroraPainter({required this.t, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final tau = math.pi * 2;

    // Trois nappes de couleur posees a des endroits choisis.
    _blob(
      canvas,
      size,
      Offset(
        w * (0.22 + 0.30 * math.sin(tau * t)),
        h * (0.18 + 0.22 * math.cos(tau * t * 0.8)),
      ),
      w * 0.75,
      NovaColors.violet,
      0.34 * intensity,
    );

    _blob(
      canvas,
      size,
      Offset(
        w * (0.80 + 0.22 * math.cos(tau * t * 0.65 + 1.2)),
        h * (0.30 + 0.28 * math.sin(tau * t * 0.9 + 0.6)),
      ),
      w * 0.68,
      NovaColors.cyan,
      0.26 * intensity,
    );

    _blob(
      canvas,
      size,
      Offset(
        w * (0.50 + 0.34 * math.sin(tau * t * 0.5 + 2.4)),
        h * (0.92 + 0.14 * math.cos(tau * t * 0.7)),
      ),
      w * 0.80,
      NovaColors.magenta,
      0.22 * intensity,
    );

    // Voile sombre en bas pour garder le texte lisible.
    final veil = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Color(0xCC05060A)],
      ).createShader(Rect.fromLTWH(0, h * 0.55, w, h * 0.45));
    canvas.drawRect(Rect.fromLTWH(0, h * 0.55, w, h * 0.45), veil);
  }

  void _blob(Canvas canvas, Size size, Offset center, double radius,
      Color color, double alpha) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.45),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.intensity != intensity;
}
