import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../services/country_filter.dart';
import '../services/epg_service.dart';
import '../services/m3u_service.dart';
import '../services/stalker_service.dart';
import '../services/storage.dart';
import '../services/xtream_service.dart';
import '../theme/nova_theme.dart';
import '../widgets/aurora_background.dart';
import '../widgets/category_sidebar.dart';
import '../widgets/epg_panel.dart';
import '../widgets/hero_banner.dart';
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

  final Map<String, String> _countryOf = {};
  List<Country> _countries = [CountryFilter.all.first];

  _Tab _tab = _Tab.live;
  String _group = 'Tout';
  String _country = 'ALL';
  String _query = '';

  // Menu deroulant des pays (replie par defaut)
  bool _countryOpen = false;

  // Mini TV + EPG
  Channel? _preview;
  List<EpgProgram> _epg = [];
  bool _epgLoading = false;

  // Bandeau haut pour films et series
  Movie? _heroMovie;
  Series? _heroSeries;
  bool _heroLoading = false;

  bool _manageMode = false;

  StalkerService? _stalker;
  XtreamService? _xtream;
  EpgService? _epgService;

  @override
  void initState() {
    super.initState();
    _country =
        Storage.getString('country_${widget.portal.id}', fallback: 'ALL');
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
          _epgService = EpgService(
            host: x.host,
            username: p.username,
            password: p.password,
          );
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
          // v10.1 : films et series aussi, meme sur un portail Stalker.
          try {
            _movies = await s.fetchVod();
          } catch (_) {
            _movies = [];
          }
          try {
            _series = await s.fetchSeries();
          } catch (_) {
            _series = [];
          }
          break;
      }

      // Calcul des pays, protege : meme si ca echoue, les chaines
      // s'affichent quand meme (ou si le calcul est long, l'ecran
      // reste fluide et Android ne tue pas l'application).
      try {
        await _computeCountries();
      } catch (_) {}

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

  /// Calcul des pays PAR PETITS PAQUETS : on rend la main au systeme
  /// toutes les 1500 entrees pour que l'interface reste vivante.
  /// C'est ce qui empeche Android de fermer l'app ("ne repond pas")
  /// sur les gros catalogues (100 000+ contenus).
  Future<void> _computeCountries() async {
    final counts = <String, int>{};
    var since = 0;

    Future<void> breathe() async {
      since++;
      if (since >= 1500) {
        since = 0;
        await Future<void>.delayed(Duration.zero);
      }
    }

    for (final c in _live) {
      final co = CountryFilter.detect(c.name, c.group);
      _countryOf[c.id] = co;
      if (co.isNotEmpty) counts[co] = (counts[co] ?? 0) + 1;
      await breathe();
    }
    for (final m in _movies) {
      final co = CountryFilter.detect(m.name, m.group);
      _countryOf[m.id] = co;
      if (co.isNotEmpty) counts[co] = (counts[co] ?? 0) + 1;
      await breathe();
    }
    for (final s in _series) {
      final co = CountryFilter.detect(s.name, s.group);
      _countryOf[s.id] = co;
      if (co.isNotEmpty) counts[co] = (counts[co] ?? 0) + 1;
      await breathe();
    }
    _countries = CountryFilter.presentIn(counts);
  }

  void _switchTab(_Tab t) {
    setState(() {
      _tab = t;
      _group = 'Tout';
      _query = '';
      _countryOpen = false;
      _heroMovie = null;
      _heroSeries = null;
    });
  }

  Future<void> _setCountry(String code) async {
    // Le menu se replie tout seul apres le choix.
    setState(() {
      _country = code;
      _group = 'Tout';
      _countryOpen = false;
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

  /// Categories de la barre laterale, avec compteurs.
  List<SideItem> get _sideItems {
    final counts = <String, int>{};
    int total = 0;

    void collect(String id, String group) {
      if (Storage.isHidden(widget.portal.id, id)) return;
      if (_country != 'ALL' && (_countryOf[id] ?? '') != _country) return;
      counts[group] = (counts[group] ?? 0) + 1;
      total++;
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

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      SideItem('Tout', 'Toutes', total),
      ...entries.map((e) => SideItem(e.key, e.key, e.value)),
    ];
  }

  // --- Actions ---

  Future<void> _tapChannel(Channel c, List<Channel> list) async {
    if (_manageMode) {
      _confirmHide(c.id, c.name);
      return;
    }
    if (_preview?.id == c.id) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PlayerScreen(channel: c, playlist: list, stalker: _stalker, epg: _epgService),
        ),
      );
      return;
    }

    setState(() {
      _preview = c;
      _epg = [];
      _epgLoading = false;
    });
    _loadEpg(c);
  }

  Future<void> _loadEpg(Channel c) async {
    final svc = _epgService;
    if (svc == null) return;
    // L'identifiant Xtream est du type xt_live_1234
    final sid = c.id.startsWith('xt_live_') ? c.id.substring(8) : '';
    if (sid.isEmpty) return;

    setState(() => _epgLoading = true);
    final progs = await svc.forStream(sid);
    if (!mounted || _preview?.id != c.id) return;
    setState(() {
      _epg = progs;
      _epgLoading = false;
    });
  }

  Future<void> _hoverMovie(Movie m) async {
    if (_heroMovie?.id == m.id) return;
    setState(() {
      _heroMovie = m;
      _heroSeries = null;
      _heroLoading = m.plot.isEmpty;
    });
    if (m.plot.isEmpty && _xtream != null) {
      await _xtream!.fillMovieInfo(m);
      if (mounted && _heroMovie?.id == m.id) {
        setState(() => _heroLoading = false);
      }
    }
  }

  void _hoverSeries(Series s) {
    if (_heroSeries?.id == s.id) return;
    setState(() {
      _heroSeries = s;
      _heroMovie = null;
      _heroLoading = false;
    });
  }

  Future<void> _confirmHide(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surface,
        title: const Text('Supprimer de la liste ?'),
        content: Text(
          '"$name" sera masque.\nRestaurable via le bouton corbeille.',
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

  @override
  Widget build(BuildContext context) {
    final hidden = Storage.hiddenCount(widget.portal.id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        intensity: 0.5,
        child: SafeArea(
          // Marge anti-overscan : beaucoup de TV rognent les bords de
          // l'image. On eloigne tout le contenu des extremites.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // ---------- BARRE LATERALE ----------
                if (!_loading && _error.isEmpty)
                  CategorySidebar(
                    title: _tab == _Tab.live
                        ? 'Chaines'
                        : (_tab == _Tab.movies ? 'Films' : 'Series'),
                    items: _sideItems,
                    selected: _group,
                    onSelect: (id) => setState(() => _group = id),
                    query: _query,
                    onQuery: (v) => setState(() => _query = v),
                    width: 196,
                  ),

                // ---------- CONTENU ----------
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _header(hidden),
                        const SizedBox(height: 8),

                        if (!_loading && _error.isEmpty) ...[
                          // 1) MINI TV : centree en haut de l'ecran
                          if (_tab == _Tab.live && _preview != null) ...[
                            SizedBox(height: 178, child: _topPreview()),
                            const SizedBox(height: 10),
                          ],

                          // 2) ONGLETS TV / FILMS / SERIES + PAYS sur la meme ligne, centres
                          Center(child: _tabBar()),

                          // 3) LISTE DES PAYS : n'apparait que quand le menu est ouvert
                          if (_countryOpen && _countries.length > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: SizedBox(
                                  height: 34, child: _countryOptions()),
                            ),
                          const SizedBox(height: 8),

                          // Bandeau jaquette + resume (films/series)
                          if (_tab != _Tab.live && _hero != null) ...[
                            _hero!,
                            const SizedBox(height: 10),
                          ],
                        ],

                        if (_loading) Expanded(child: _loadingView()),
                        if (!_loading && _error.isNotEmpty)
                          Expanded(child: _errorView()),
                        if (!_loading && _error.isEmpty)
                          Expanded(child: _body()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? get _hero {
    final m = _heroMovie;
    if (m != null) {
      return HeroBanner(
        title: m.name,
        poster: m.poster,
        plot: m.plot,
        rating: m.rating,
        year: m.year,
        genre: m.genre.isNotEmpty ? m.genre : m.group,
        extra: m.cast.isNotEmpty ? 'Avec ${m.cast}' : '',
        loading: _heroLoading,
      );
    }
    final s = _heroSeries;
    if (s != null) {
      return HeroBanner(
        title: s.name,
        poster: s.poster,
        plot: s.plot,
        rating: s.rating,
        year: s.year,
        genre: s.genre.isNotEmpty ? s.genre : s.group,
        extra: s.cast.isNotEmpty ? 'Avec ${s.cast}' : '',
      );
    }
    return null;
  }

  /// Mini televiseur + guide TV, centres horizontalement en haut de l'ecran.
  Widget _topPreview() {
    final c = _preview!;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MiniPlayer(
            channel: c,
            stalker: _stalker,
            onClose: () => setState(() {
              _preview = null;
              _epg = [];
            }),
            onExpand: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  channel: c,
                  playlist: _fLive,
                  stalker: _stalker,
                  epg: _epgService,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 272,
            child: EpgPanel(
              programs: _epg,
              loading: _epgLoading,
              channelName: c.name,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(int hidden) => Row(
        children: [
          GradientTitle(widget.portal.name, size: 19),
          const Spacer(),
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
          if (hidden > 0) ...[
            const SizedBox(width: 8),
            _iconChip(
              icon: Icons.restore_from_trash_rounded,
              label: '$hidden',
              onTap: _restoreAll,
            ),
          ],
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            gradient: active ? NovaColors.brand : null,
            color: active ? null : NovaColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? Colors.transparent
                  : Colors.redAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: active ? Colors.white : Colors.redAccent),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : NovaColors.text,
                  )),
            ],
          ),
        ),
      );

  Widget _tabBar() => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabButton(_Tab.live, Icons.live_tv_rounded, 'TV', _live.length),
          const SizedBox(width: 9),
          _tabButton(_Tab.movies, Icons.movie_rounded, 'Films', _movies.length),
          const SizedBox(width: 9),
          _tabButton(_Tab.series, Icons.video_library_rounded, 'Series',
              _series.length),
          // Pays : meme pilule, meme ligne que les onglets
          if (_countries.length > 1) ...[
            const SizedBox(width: 9),
            _countryPill(),
          ],
        ],
      );

  Widget _tabButton(_Tab t, IconData icon, String label, int n) {
    final sel = _tab == t;
    final empty = n == 0;
    return GestureDetector(
      onTap: empty ? null : () => _switchTab(t),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          gradient: sel ? NovaColors.brand : null,
          color: sel ? null : NovaColors.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color:
                    empty ? NovaColors.textDim.withValues(alpha: 0.4) : Colors.white),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: empty
                      ? NovaColors.textDim.withValues(alpha: 0.4)
                      : NovaColors.text,
                )),
            if (n > 0) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
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

  /// Pilule du pays courant, a meme hauteur que les onglets TV/Films/Series.
  /// Un tap ouvre (ou replie) la liste des pays affichee juste en dessous.
  Widget _countryPill() {
    final current = _countries.firstWhere(
      (c) => c.code == _country,
      orElse: () => _countries.first,
    );

    return _TvChip(
      selected: true,
      onTap: () => setState(() => _countryOpen = !_countryOpen),
      leading: current.flag.isNotEmpty
          ? Text(current.flag, style: const TextStyle(fontSize: 12))
          : const Icon(Icons.public_rounded,
              size: 12, color: NovaColors.cyan),
      label: current.label,
      trailing: Icon(
        _countryOpen
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Widget _countryOptions() => ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _countries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = _countries[i];
          return _TvChip(
            selected: c.code == _country,
            onTap: () => _setCountry(c.code),
            leading: c.flag.isNotEmpty
                ? Text(c.flag, style: const TextStyle(fontSize: 13))
                : const Icon(Icons.public_rounded,
                    size: 12, color: NovaColors.cyan),
            label: c.label,
          );
        },
      );

  Widget _loadingView() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: NovaColors.cyan),
            SizedBox(height: 18),
            Text('Connexion au portail...',
                style: TextStyle(color: NovaColors.textDim)),
            SizedBox(height: 8),
            Text('Gros catalogue = premier chargement un peu long.\nNe touche a rien, ca arrive :)',
                textAlign: TextAlign.center,
                style: TextStyle(color: NovaColors.textDim, fontSize: 11)),
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

  Widget _deleteBadge() => Positioned(
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
      );

  Widget _liveGrid() {
    final items = _fLive;
    if (items.isEmpty) return _empty();
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 1.42,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
                        padding: const EdgeInsets.all(8),
                        child: Column(
                  children: [
                    Expanded(
                      child: c.logo.isEmpty
                          ? Icon(Icons.live_tv_rounded,
                              size: 28,
                              color: NovaColors.violet.withValues(alpha: 0.6))
                          : CachedNetworkImage(
                              imageUrl: c.logo,
                              fit: BoxFit.contain,
                              memCacheWidth: 240,
                              errorWidget: (_, __, ___) => const Icon(
                                  Icons.live_tv_rounded,
                                  size: 28,
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
                        fontSize: 10.5,
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
            if (_manageMode) _deleteBadge(),
          ],
        );
      },
    );
  }

  Widget _movieGrid() {
    final items = _fMovies;
    if (items.isEmpty) return _empty();
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 126,
        childAspectRatio: 0.56,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
              onFocus: () => _hoverMovie(m),
              onTap: () {
                if (_manageMode) {
                  _confirmHide(m.id, m.name);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(
                      movie: m,
                      xtream: _xtream,
                      stalker: _stalker,
                    ),
                  ),
                );
              },
            ),
            if (_manageMode) _deleteBadge(),
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
      padding: const EdgeInsets.only(bottom: 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 126,
        childAspectRatio: 0.56,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
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
              onFocus: () => _hoverSeries(s),
              onTap: () {
                if (_manageMode) {
                  _confirmHide(s.id, s.name);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SeriesDetailScreen(
                      series: s,
                      xtream: x,
                      stalker: _stalker,
                    ),
                  ),
                );
              },
            ),
            if (_manageMode) _deleteBadge(),
          ],
        );
      },
    );
  }
}

/// Petit pill-bouton compatible telecommande (fleches + OK) ET souris.
/// Un liseret cyan apparait quand le focus est dessus.
class _TvChip extends StatefulWidget {
  final Widget? leading;
  final String label;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  const _TvChip({
    required this.label,
    required this.onTap,
    this.leading,
    this.trailing,
    this.selected = false,
  });

  @override
  State<_TvChip> createState() => _TvChipState();
}

class _TvChipState extends State<_TvChip> {
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
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                gradient: sel ? NovaColors.brand : null,
                color: sel ? null : NovaColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: _f
                      ? NovaColors.cyan
                      : (sel
                          ? Colors.transparent
                          : NovaColors.cyan.withValues(alpha: 0.18)),
                  width: _f ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 6),
                  ],
                  Text(widget.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      )),
                  if (widget.trailing != null) ...[
                    const SizedBox(width: 6),
                    widget.trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
