import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/m3u_service.dart';
import '../services/stalker_service.dart';
import '../services/xtream_service.dart';
import '../theme/nova_theme.dart';
import '../widgets/nova_widgets.dart';
import 'player_screen.dart';

/// Liste des chaines d'un portail, avec categories et recherche.
class ChannelsScreen extends StatefulWidget {
  final Portal portal;
  const ChannelsScreen({super.key, required this.portal});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  bool _loading = true;
  String _error = '';
  List<Channel> _all = [];
  String _group = 'Tout';
  String _query = '';
  StalkerService? _stalker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final p = widget.portal;
      List<Channel> list;

      switch (p.type) {
        case PortalType.m3u:
          list = await M3uService.load(p.url);
          break;
        case PortalType.xtream:
          final x = XtreamService(
            host: p.url,
            username: p.username,
            password: p.password,
          );
          await x.authenticate();
          final live = await x.liveChannels();
          final vod = await x.vodChannels();
          list = [...live, ...vod];
          break;
        case PortalType.stalker:
          final s = StalkerService(portalUrl: p.url, mac: p.macAddress);
          await s.handshake();
          list = await s.liveChannels();
          _stalker = s;
          break;
      }

      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        if (list.isEmpty) _error = 'Aucune chaine trouvee sur ce portail';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<String> get _groups {
    final set = <String>{'Tout'};
    for (final c in _all) {
      set.add(c.group);
    }
    return set.toList();
  }

  List<Channel> get _filtered {
    return _all.where((c) {
      final okGroup = _group == 'Tout' || c.group == _group;
      final okQuery = _query.isEmpty ||
          c.name.toLowerCase().contains(_query.toLowerCase());
      return okGroup && okQuery;
    }).toList();
  }

  void _open(Channel c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          channel: c,
          playlist: _filtered,
          stalker: _stalker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 24, 36, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradientTitle(widget.portal.name, size: 26),
                  const SizedBox(width: 16),
                  if (!_loading)
                    Text('${_all.length} chaines',
                        style: const TextStyle(
                            color: NovaColors.textDim, fontSize: 13)),
                  const Spacer(),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher',
                        hintStyle: const TextStyle(color: NovaColors.textDim),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        filled: true,
                        fillColor: NovaColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading) Expanded(child: _loadingView()),
              if (!_loading && _error.isNotEmpty) Expanded(child: _errorView()),
              if (!_loading && _error.isEmpty) ...[
                SizedBox(height: 44, child: _groupBar()),
                const SizedBox(height: 14),
                Expanded(child: _grid()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingView() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NovaColors.cyan),
            SizedBox(height: 18),
            Text('Connexion au portail...',
                style: TextStyle(color: NovaColors.textDim)),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: NovaColors.text)),
            const SizedBox(height: 20),
            NovaButton(
              label: 'Reessayer',
              icon: Icons.refresh_rounded,
              autofocus: true,
              onTap: _load,
            ),
          ],
        ),
      );

  Widget _groupBar() => ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final g = _groups[i];
          final sel = g == _group;
          return GestureDetector(
            onTap: () => setState(() => _group = g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? NovaColors.brand : null,
                color: sel ? null : NovaColors.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(g,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          );
        },
      );

  Widget _grid() {
    final items = _filtered;
    if (items.isEmpty) {
      return const Center(
        child: Text('Aucun resultat',
            style: TextStyle(color: NovaColors.textDim)),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 1.35,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        return FocusCard(
          autofocus: i == 0,
          onTap: () => _open(c),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: c.logo.isEmpty
                      ? Icon(Icons.live_tv_rounded,
                          size: 40,
                          color: NovaColors.violet.withValues(alpha: 0.6))
                      : CachedNetworkImage(
                          imageUrl: c.logo,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.live_tv_rounded,
                              size: 40,
                              color: NovaColors.textDim),
                          placeholder: (_, __) => const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  c.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
