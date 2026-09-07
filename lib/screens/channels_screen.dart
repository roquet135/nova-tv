import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/country_filter.dart';
import '../services/m3u_service.dart';
import '../services/stalker_service.dart';
import '../services/storage.dart';
import '../services/xtream_service.dart';
import '../theme/nova_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/mini_player.dart';
import '../widgets/nova_widgets.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

enum _Tab { live, movies, series }

class ChannelsScreen extends StatefulWidget {
  final Portal portal;
  const ChannelsScreen({super.key, required this.portal});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  bool _loading = true;
  String _error = '';

  List<Channel> _live = [];
  List<Movie> _movies = [];
  List<Series> _series = [];

  // Pays detecte pour chaque element, calcule une seule fois.
  final Map<String, String> _countryOf = {};
  List<Country> _countries = [CountryFilter.all.first];

  _Tab _tab = _Tab.live;
  String _group = 'Tout';
  String _country = 'ALL';
  String _query = '';

  // Mini televiseur
  Channel? _preview;
  bool _manageMode = false;

  StalkerService? _stalker;
  XtreamService? _xtream;

  @override
  void initState() {
    super.initState();
    _country = Storage.getString('country_${widget.portal.id}',
        fallback: 'ALL');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final p = widget.portal;

      switch (p.type) {
        case PortalType.m3u:
          _live = await M3uService.load(p.url);
          break;

        case PortalType.xtream:
          final x = XtreamService(
            host: p.url,
            username: p.username,
            password: p.password,
          );
          await x.authenticate();
          _xtream = x;
          _live = await x.liveChannels();
          try {
            _movies = await x.movies();
          } catch (_) {
            _movies = [];
          }
          try {
            _series = await x.series();
          } catch (_) {
            _series = [];
          }
          break;

        case PortalType.stalker:
          final s = StalkerService(portalUrl: p.url, mac: p.macAddress);
          await s.handshake();
          _live = await s.liveChannels();
          _stalker = s;
          break;
      }

      _computeCountries();

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_live.isEmpty && _movies.isEmpty && _series.isEmpty) {
          _error = 'Aucun contenu trouve sur ce portail';
        }
        if (_live.isEmpty && _movies.isNotEmpty) _tab = _Tab.movies;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Detecte le pays de chaque element et construit la liste des pays.
  void _computeCountries() {
    final counts = <String, int>{};
    void add(String id, String name, String group) {
      final c = CountryFilter.detect(name, group);
      _countryOf[id] = c;
      if (c.isNotEmpty) counts[c] = (counts[c] ?? 0) + 1;
    }

    for (final c in _live) {
      add(c.id, c.name, c.group);
    }
    for (final m in _movies) {
      add(m.id, m.name, m.group);
    }
    for (final s in _series) {
      add(s.id, s.name, s.group);
    }
    _countries = CountryFilter.presentIn(counts);
  }

  void _switchTab(_Tab t) {
    setState(() {
      _tab = t;
      _group = 'Tout';
      _query = '';
    });
  }

  Future<void> _setCountry(String code) async {
    setState(() {
      _country = code;
      _group = 'Tout';
    });
    await Storage.setString('country_${widget.portal.id}', code);
  }

  // --- Filtrage ---

  bool _visible(String id, String name, String group) {
    if (Storage.isHidden(widget.portal.id, id)) return false;
    if (_country != 'ALL' && (_countryOf[id] ?? '') != _country) return false;
    if (_group != 'Tout' && group != _group) return false;
    if (_query.isNotEmpty &&
        !name.toLowerCase().contains(_query.toLowerCase())) {
      return false;
    }
    return true;
  }

  List<Channel> get _fLive =>
      _live.where((c) => _visible(c.id, c.name, c.group)).toList();
  List<Movie> get _fMovies =>
      _movies.where((m) => _visible(m.id, m.name, m.group)).toList();
  List<Series> get _fSeries =>
      _series.where((s) => _visible(s.id, s.name, s.group)).toList();

  List<String> get _groups {
    final set = <String>{'Tout'};
    void collect(String id, String group) {
      if (_country != 'ALL' && (_countryOf[id] ?? '') != _country) return;
      set.add(group);
    }

    switch (_tab) {
      case _Tab.live:
        for (final c in _live) {
          collect(c.id, c.group);
        }
        break;
      case _Tab.movies:
        for (final m in _movies) {
          collect(m.id, m.group);
        }
        break;
      case _Tab.series:
        for (final s in _series) {
          collect(s.id, s.group);
        }
        break;
    }
    return set.toList();
  }

  // --- Actions ---

  /// Premier clic : apercu dans la mini TV. Deuxieme clic : plein ecran.
  void _tapChannel(Channel c, List<Channel> list) {
    if (_manageMode) {
      _confirmHide(c.id, c.name);
      return;
    }
    if (_preview?.id == c.id) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PlayerScreen(channel: c, playlist: list, stalker: _stalker),
        ),
      );
    } else {
      setState(() => _preview = c);
    }
  }

  Future<void> _confirmHide(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        title: const Text('Supprimer de la liste ?'),
        content: Text(
          '"$name" sera masque.\nTu pourras le restaurer depuis le bouton Corbeille.',
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
      await Storage.hide(widget.portal.id, id);
      if (mounted) {
        setState(() {
          if (_preview?.id == id) _preview = null;
        });
      }
    }
  }

  Future<void> _restoreAll() async {
    final n = Storage.hiddenCount(widget.portal.id);
    if (n == 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        title: const Text('Restaurer les elements masques ?'),
        content: Text('$n element(s) reviendront dans la liste.',
            style: const TextStyle(color: NovaColors.textDim, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Storage.clearHidden(widget.portal.id);
      if (mounted) setState(() {});
    }
  }

  int get _count {
    switch (_tab) {
      case _Tab.live:
        return _fLive.length;
      case _Tab.movies:
        return _fMovies.length;
      case _Tab.series:
        return _fSeries.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hidden = Storage.hiddenCount(widget.portal.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        intensity: 0.55,
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 18, 32, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(hidden),
                    const SizedBox(height: 12),
                    if (!_loading && _error.isEmpty) ...[
                      _tabBar(),
                      const SizedBox(height: 10),
                      if (_countries.length > 1)
                        SizedBox(height: 36, child: _countryBar()),
                      const SizedBox(height: 8),
                      SizedBox(height: 36, child: _groupBar()),
                      const SizedBox(height: 12),
                    ],
                    if (_loading) Expanded(child: _loadingView()),
                    if (!_loading && _error.isNotEmpty)
                      Expanded(child: _errorView()),
                    if (!_loading && _error.isEmpty)
                      Expanded(child: _body()),
                  ],
                ),
              ),

              // Mini televiseur, en bas a droite
              if (_preview != null)
                Positioned(
                  right: 24,
                  bottom: 20,
                  child: MiniPlayer(
                    channel: _preview,
                    stalker: _stalker,
                    onClose: () => setState(() => _preview = null),
                    onExpand: () {
                      final c = _preview;
                      if (c == null) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            channel: c,
                            playlist: _fLive,
                            stalker: _stalker,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(int hidden) => Row(
        children: [
          GradientTitle(widget.portal.name, size: 23),
          const SizedBox(width: 12),
          if (!_loading)
            Text('$_count',
                style: const TextStyle(
                    color: NovaColors.textDim, fontSize: 12)),
          const Spacer(),

          // Mode suppression
          _iconChip(
            icon: _manageMode
                ? Icons.check_circle_rounded
                : Icons.delete_outline_rounded,
            label: _manageMode ? 'Terminer' : 'Supprimer',
            active: _manageMode,
            onTap: () => setState(() {
              _manageMode = !_manageMode;
              if (_manageMode) _preview = null;
            }),
          ),
          const SizedBox(width: 8),
          if (hidden > 0)
            _iconChip(
              icon: Icons.restore_from_trash_rounded,
              label: '$hidden',
              onTap: _restoreAll,
            ),
          const SizedBox(width: 10),
          SizedBox(
            width: 220,
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher',
                hintStyle: const TextStyle(color: NovaColors.textDim),
                prefixIcon: const Icon(Icons.search_rounded, size: 17),
                isDense: true,
                filled: true,
                fillColor: NovaColors.surface.withOpacity(0.85),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _iconChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: active ? NovaColors.brand : null,
            color: active ? null : NovaColors.surface.withOpacity(0.85),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : Colors.redAccent.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: active ? Colors.white : Colors.redAccent),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : NovaColors.text,
                  )),
            ],
          ),
        ),
      );

  Widget _tabBar() => Row(
        children: [
          _tabButton(_Tab.live, Icons.live_tv_rounded, 'TV', _live.length),
          const SizedBox(width: 9),
          _tabButton(_Tab.movies, Icons.movie_rounded, 'Films', _movies.length),
          const SizedBox(width: 9),
          _tabButton(
              _Tab.series, Icons.video_library_rounded, 'Series', _series.length),
        ],
      );

  Widget _tabButton(_Tab t, IconData icon, String label, int n) {
    final sel = _tab == t;
    final empty = n == 0;
    return GestureDetector(
      onTap: empty ? null : () => _switchTab(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: sel ? NovaColors.brand : null,
          color: sel ? null : NovaColors.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color:
                    empty ? NovaColors.textDim.withOpacity(0.4) : Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: empty
                      ? NovaColors.textDim.withOpacity(0.4)
                      : NovaColors.text,
                )),
            if (n > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$n',
                    style: const TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _countryBar() => ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _countries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _countries[i];
          final sel = c.code == _country;
          return GestureDetector(
            onTap: () => _setCountry(c.code),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel ? NovaColors.brand : null,
                color: sel ? null : NovaColors.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : NovaColors.cyan.withOpacity(0.18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.flag.isNotEmpty) ...[
                    Text(c.flag, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ] else ...[
                    const Icon(Icons.public_rounded,
                        size: 13, color: NovaColors.cyan),
                    const SizedBox(width: 6),
                  ],
                  Text(c.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      )),
                ],
              ),
            ),
          );
        },
      );

  Widget _groupBar() {
    final gs = _groups;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: gs.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final g = gs[i];
        final sel = g == _group;
        return GestureDetector(
          onTap: () => setState(() => _group = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel
                  ? NovaColors.violet.withOpacity(0.85)
                  : NovaColors.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(g,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
        );
      },
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
                size: 52, color: Colors.redAccent),
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

  Widget _body() {
    switch (_tab) {
      case _Tab.live:
        return _liveGrid();
      case _Tab.movies:
        return _movieGrid();
      case _Tab.series:
        return _seriesGrid();
    }
  }

  Widget _empty() => const Center(
        child: Text('Aucun resultat pour ce filtre',
            style: TextStyle(color: NovaColors.textDim)),
      );

  Widget _liveGrid() {
    final items = _fLive;
    if (items.isEmpty) return _empty();
    return GridView.builder(
      padding: EdgeInsets.only(bottom: _preview != null ? 250 : 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 1.32,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        final playing = _preview?.id == c.id;
        return Stack(
          children: [
            FocusCard(
              autofocus: i == 0,
              onTap: () => _tapChannel(c, items),
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: Column(
                  children: [
                    Expanded(
                      child: c.logo.isEmpty
                          ? Icon(Icons.live_tv_rounded,
                              size: 36,
                              color: NovaColors.violet.withOpacity(0.6))
                          : CachedNetworkImage(
                              imageUrl: c.logo,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.live_tv_rounded,
                                  size: 36,
                                  color: NovaColors.textDim),
                              placeholder: (_, __) => const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      c.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: playing ? NovaColors.cyan : NovaColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (playing)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: NovaColors.brand,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text('A L ECRAN',
                      style: TextStyle(
                          fontSize: 7.5, fontWeight: FontWeight.w800)),
                ),
              ),
            if (_manageMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _movieGrid() {
    final items = _fMovies;
    if (items.isEmpty) return _empty();
    return GridView.builder(
      padding: EdgeInsets.only(bottom: _preview != null ? 250 : 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 165,
        childAspectRatio: 0.56,
        crossAxisSpacing: 15,
        mainAxisSpacing: 18,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return Stack(
          children: [
            PosterCard(
              autofocus: i == 0,
              title: m.name,
              poster: m.poster,
              rating: m.rating,
              year: m.year,
              onTap: () {
                if (_manageMode) {
                  _confirmHide(m.id, m.name);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        MovieDetailScreen(movie: m, xtream: _xtream),
                  ),
                );
              },
            ),
            if (_manageMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _seriesGrid() {
    final items = _fSeries;
    if (items.isEmpty) return _empty();
    final x = _xtream;
    return GridView.builder(
      padding: EdgeInsets.only(bottom: _preview != null ? 250 : 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 165,
        childAspectRatio: 0.56,
        crossAxisSpacing: 15,
        mainAxisSpacing: 18,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final s = items[i];
        return Stack(
          children: [
            PosterCard(
              autofocus: i == 0,
              title: s.name,
              poster: s.poster,
              rating: s.rating,
              year: s.year,
              onTap: () {
                if (_manageMode) {
                  _confirmHide(s.id, s.name);
                  return;
                }
                if (x == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesDetailScreen(series: s, xtream: x),
                  ),
                );
              },
            ),
            if (_manageMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }
}
