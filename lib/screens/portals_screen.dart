import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../theme/nova_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/nova_widgets.dart';
import 'add_portal_screen.dart';
import 'channels_screen.dart';
import 'downloads_screen.dart';

/// Ecran d'accueil : liste des abonnements enregistres.
class PortalsScreen extends StatefulWidget {
  const PortalsScreen({super.key});

  @override
  State<PortalsScreen> createState() => _PortalsScreenState();
}

class _PortalsScreenState extends State<PortalsScreen> {
  List<Portal> _portals = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _portals = Storage.portals());

  void _downloads() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DownloadsScreen()),
    );
  }

  Future<void> _add() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPortalScreen()),
    );
    _refresh();
  }

  Future<void> _delete(Portal p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        title: const Text('Supprimer cet abonnement ?'),
        content: Text(
          '"${p.name}" sera retire de NOVA TV.\nCette action est definitive.',
          style: const TextStyle(color: NovaColors.textDim, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Storage.deletePortal(p.id);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 30, 48, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/logo.png', width: 52, height: 52),
                    const SizedBox(width: 16),
                    const GradientTitle('NOVA TV', size: 34),
                    const Spacer(),
                    NovaButton(
                      label: 'Mes telechargements',
                      icon: Icons.download_done_rounded,
                      onTap: _downloads,
                    ),
                    const SizedBox(width: 12),
                    NovaButton(
                      label: 'Ajouter un abonnement',
                      icon: Icons.add_rounded,
                      autofocus: _portals.isEmpty,
                      onTap: _add,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'M3U  -  Xtream Codes  -  Stalker Portal',
                  style: TextStyle(color: NovaColors.textDim, fontSize: 13),
                ),
                const SizedBox(height: 28),
                Expanded(child: _portals.isEmpty ? _empty() : _grid()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.live_tv_rounded,
                size: 72, color: NovaColors.violet.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            const Text(
              'Aucun abonnement pour le moment',
              style: TextStyle(fontSize: 18, color: NovaColors.text),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ajoute ton premier portail pour commencer',
              style: TextStyle(color: NovaColors.textDim),
            ),
          ],
        ),
      );

  Widget _grid() => GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          childAspectRatio: 2.1,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: _portals.length,
        itemBuilder: (context, i) {
          final p = _portals[i];
          return Stack(
            children: [
              FocusCard(
                autofocus: i == 0,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChannelsScreen(portal: p)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: NovaColors.brand,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(p.type),
                                size: 18, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        p.type.label,
                        style: const TextStyle(
                            color: NovaColors.textDim, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: NovaColors.textDim, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _TrashButton(onTap: () => _delete(p)),
              ),
            ],
          );
        },
      );

  IconData _iconFor(PortalType t) {
    switch (t) {
      case PortalType.m3u:
        return Icons.playlist_play_rounded;
      case PortalType.xtream:
        return Icons.dns_rounded;
      case PortalType.stalker:
        return Icons.router_rounded;
    }
  }
}

/// Poubelle FOCUSABLE : atteignable aux fleches de la telecommande
/// (bordure cyan quand elle est selectionnee, OK pour supprimer).
class _TrashButton extends StatefulWidget {
  final VoidCallback onTap;

  const _TrashButton({required this.onTap});

  @override
  State<_TrashButton> createState() => _TrashButtonState();
}

class _TrashButtonState extends State<_TrashButton> {
  bool _f = false;
  final FocusNode _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // v10.6 : viser la poubelle avec le pointeur la selectionne,
    // OK la valide ensuite (telecommandes "OK seul").
    return Focus(
      focusNode: _node,
      onFocusChange: (v) => setState(() => _f = v),
      child: MouseRegion(
        onEnter: (_) => _node.requestFocus(),
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
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _f
                    ? Colors.redAccent.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _f
                      ? NovaColors.cyan
                      : Colors.redAccent.withValues(alpha: 0.45),
                  width: _f ? 2 : 1,
                ),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 15, color: Colors.redAccent),
            ),
          ),
        ),
      ),
      ),
    );
  }
}
