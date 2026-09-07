import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/m3u_service.dart';
import '../services/stalker_service.dart';
import '../services/xtream_service.dart';
import '../theme/nova_theme.dart';
import '../widgets/nova_widgets.dart';
import '../widgets/poster_card.dart';
import 'movie_detail_screen.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

enum _Tab { live, movies, series }

/// Contenu d'un portail : TV en direct, Films, Series.
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

  _Tab _tab = _Tab.live;
  String _group = 'Tout';
  String _query = '';

  StalkerService? _stalker;
  XtreamService? _xtream;

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
          // Films et series : on tolere un echec partiel.
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

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_live.isEmpty && _movies.isEmpty && _series.isEmpty) {
          _error = 'Aucun contenu trouve sur ce portail';
        }
        // On ouvre sur l'onglet qui a du contenu.
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

  void _switchTab(_Tab t) {
    setState(() {
      _tab = t;
      _group = 'Tout';
      _query = '';
    });
  }

  List<String> get _groups {
    final set = <String>{'Tout'};
    switch (_tab) {
      case _Tab.live:
        for (final c in _live) {
          set.add(c.group);
        }
        break;
      case _Tab.movies:
        for (final m in _movies) {
          set.add(m.group);
        }
        break;
      case _Tab.series:
        for (final s in _series) {
          set.add(s.group);
        }
        break;
    }
    return set.toList();
  }

  bool _match(String name, String group) {
    final okG = _group == 'Tout' || group == _group;
    final okQ =
        _query.isEmpty || name.toLowerCase().contains(_query.toLowerCase());
    return okG && okQ;
  }

  List<Channel> get _filteredLive =>
      _live.where((c) => _match(c.name, c.group)).toList();

  List<Movie> get _filteredMovies =>
      _movies.where((m) => _match(m.name, m.group)).toList();

  List<Series> get _filteredSeries =>
      _series.where((s) => _match(s.name, s.group)).toList();

  int get _count {
    switch (_tab) {
      case _Tab.live:
        return _live.length;
      case _Tab.movies:
        return _movies.length;
      case _Tab.series:
        return _series.length;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(36, 22, 36, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GradientTitle(widget.portal.name, size: 24),
                  const SizedBox(width: 14),
                  if (!_loading)
                    Text('$_count elements',
                        style: const TextStyle(
                            color: NovaColors.textDim, fontSize: 12)),
                  const Spacer(),
                  SizedBox(
                    width: 250,
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
              const SizedBox(height: 14),

              // Onglets TV / Films / Series
              if (!_loading && _error.isEmpty) _tabBar(),

              if (_loading) Expanded(child: _loadingView()),
              if (!_loading && _error.isNotEmpty) Expanded(child: _errorView()),
              if (!_loading && _error.isEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(height: 40, child: _groupBar()),
                const SizedBox(height: 14),
                Expanded(child: _body()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBar() => Row(
        children: [
          _tabButton(_Tab.live, Icons.live_tv_rounded, 'TV en direct',
              _live.length),
          const SizedBox(width: 10),
          _tabButton(
              _Tab.movies, Icons.movie_rounded, 'Films', _movies.length),
          const SizedBox(width: 10),
          _tabButton(_Tab.series, Icons.video_library_rounded, 'Series',
              _series.length),
        ],
      );

  Widget _tabButton(_Tab t, IconData icon, String label, int n) {
    final sel = _tab == t;
    final empty = n == 0;
    return GestureDetector(
      onTap: empty ? null : () => _switchTab(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: sel ? NovaColors.brand : null,
          color: sel ? null : NovaColors.surface,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 17,
                color: empty
                    ? NovaColors.textDim.withOpacity(0.4)
                    : Colors.white),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: empty
                    ? NovaColors.textDim.withOpacity(0.4)
                    : NovaColors.text,
              ),
            ),
            if (n > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('$n',
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
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
            SizedBox(height: 6),
            Text('Chaines, films et series',
                style: TextStyle(color: NovaColors.textDim, fontSize: 11)),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 54, color: Colors.redAccent),
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

  Widget _groupBar() {
    final gs = _groups;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: gs.length,
      separatorBuilder: (_, __) => const SizedBox(width: 9),
      itemBuilder: (context, i) {
        final g = gs[i];
        final sel = g == _group;
        return GestureDetector(
          onTap: () => setState(() => _group = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: sel ? NovaColors.brand : null,
              color: sel ? null : NovaColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(g,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
        );
      },
    );
  }

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
        child: Text('Aucun resultat',
            style: TextStyle(color: NovaColors.textDim)),
      );

  Widget _liveGrid() {
    final items = _filteredLive;
    if (items.isEmpty) return _empty();
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                channel: c,
                playlist: items,
                stalker: _stalker,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Expanded(
                  child: c.logo.isEmpty
                      ? Icon(Icons.live_tv_rounded,
                          size: 40, color: NovaColors.violet.withOpacity(0.6))
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

  Widget _movieGrid() {
    final items = _filteredMovies;
    if (items.isEmpty) return _empty();
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 165,
        childAspectRatio: 0.56,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final m = items[i];
        return PosterCard(
          autofocus: i == 0,
          title: m.name,
          poster: m.poster,
          rating: m.rating,
          year: m.year,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MovieDetailScreen(movie: m, xtream: _xtream),
            ),
          ),
        );
      },
    );
  }

  Widget _seriesGrid() {
    final items = _filteredSeries;
    if (items.isEmpty) return _empty();
    final x = _xtream;
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 165,
        childAspectRatio: 0.56,
        crossAxisSpacing: 16,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final s = items[i];
        return PosterCard(
          autofocus: i == 0,
          title: s.name,
          poster: s.poster,
          rating: s.rating,
          year: s.year,
          onTap: () {
            if (x == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SeriesDetailScreen(series: s, xtream: x),
              ),
            );
          },
        );
      },
    );
  }
}
