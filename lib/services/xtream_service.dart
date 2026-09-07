import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Client Xtream Codes (player_api.php).
class XtreamService {
  final String host;
  final String username;
  final String password;

  XtreamService({
    required String host,
    required this.username,
    required this.password,
  }) : host = _clean(host);

  static String _clean(String h) {
    var v = h.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.startsWith('http')) v = 'http://$v';
    return v;
  }

  Uri _api(Map<String, String> extra) =>
      Uri.parse('$host/player_api.php').replace(queryParameters: {
        'username': username,
        'password': password,
        ...extra,
      });

  /// Verifie les identifiants. Retourne le statut du compte.
  Future<String> authenticate() async {
    final res = await http.get(_api({})).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('Serveur injoignable (code ${res.statusCode})');
    }
    final body = jsonDecode(res.body);
    if (body is! Map || body['user_info'] == null) {
      throw Exception('Identifiants refuses par le serveur');
    }
    final info = body['user_info'] as Map<dynamic, dynamic>;
    if ('${info['auth']}' != '1') {
      throw Exception('Authentification echouee');
    }
    return '${info['status'] ?? 'Actif'}';
  }

  // ---------------------------------------------------------------
  //  TELEVISION EN DIRECT
  // ---------------------------------------------------------------

  Future<List<Channel>> liveChannels() async {
    final names = await _categoryNames('get_live_categories', 'General');
    final items = await _get('get_live_streams');
    final out = <Channel>[];
    for (final s in items) {
      if (s is! Map) continue;
      final sid = '${s['stream_id']}';
      out.add(Channel(
        id: 'xt_live_$sid',
        name: '${s['name'] ?? 'Sans titre'}',
        streamUrl: '$host/live/$username/$password/$sid.m3u8',
        logo: '${s['stream_icon'] ?? ''}',
        group: names['${s['category_id']}'] ?? 'General',
        epgId: '${s['epg_channel_id'] ?? ''}',
      ));
    }
    return out;
  }

  // ---------------------------------------------------------------
  //  FILMS
  // ---------------------------------------------------------------

  Future<List<Movie>> movies() async {
    final names = await _categoryNames('get_vod_categories', 'Films');
    final items = await _get('get_vod_streams');
    final out = <Movie>[];
    for (final s in items) {
      if (s is! Map) continue;
      final sid = '${s['stream_id']}';
      final ext = '${s['container_extension'] ?? 'mp4'}';
      out.add(Movie(
        id: 'xt_vod_$sid',
        streamId: sid,
        name: '${s['name'] ?? 'Sans titre'}',
        poster: '${s['stream_icon'] ?? ''}',
        group: names['${s['category_id']}'] ?? 'Films',
        streamUrl: '$host/movie/$username/$password/$sid.$ext',
        rating: '${s['rating'] ?? ''}',
        year: _year('${s['added'] ?? ''}', '${s['releaseDate'] ?? ''}'),
      ));
    }
    return out;
  }

  /// Charge le resume, le casting et le realisateur d'un film.
  Future<void> fillMovieInfo(Movie m) async {
    try {
      final r = await _getMap('get_vod_info', {'vod_id': m.streamId});
      final info = r['info'];
      if (info is Map) {
        m.plot = '${info['plot'] ?? info['description'] ?? ''}'.trim();
        m.cast = '${info['cast'] ?? info['actors'] ?? ''}'.trim();
        m.director = '${info['director'] ?? ''}'.trim();
        m.genre = '${info['genre'] ?? ''}'.trim();
      }
    } catch (_) {
      // Fiche indisponible : on garde ce qu'on a deja.
    }
  }

  // ---------------------------------------------------------------
  //  SERIES
  // ---------------------------------------------------------------

  Future<List<Series>> series() async {
    final names = await _categoryNames('get_series_categories', 'Series');
    final items = await _get('get_series');
    final out = <Series>[];
    for (final s in items) {
      if (s is! Map) continue;
      final sid = '${s['series_id']}';
      out.add(Series(
        id: 'xt_ser_$sid',
        seriesId: sid,
        name: '${s['name'] ?? 'Sans titre'}',
        poster: '${s['cover'] ?? ''}',
        group: names['${s['category_id']}'] ?? 'Series',
        rating: '${s['rating'] ?? ''}',
        year: _year('${s['last_modified'] ?? ''}', '${s['releaseDate'] ?? ''}'),
        plot: '${s['plot'] ?? ''}'.trim(),
        cast: '${s['cast'] ?? ''}'.trim(),
        director: '${s['director'] ?? ''}'.trim(),
        genre: '${s['genre'] ?? ''}'.trim(),
      ));
    }
    return out;
  }

  /// Recupere les episodes d'une serie, ranges par saison.
  Future<Map<int, List<Episode>>> episodes(Series s) async {
    final out = <int, List<Episode>>{};
    try {
      final r = await _getMap('get_series_info', {'series_id': s.seriesId});

      final info = r['info'];
      if (info is Map && s.plot.isEmpty) {
        s.plot = '${info['plot'] ?? ''}'.trim();
        s.cast = '${info['cast'] ?? ''}'.trim();
        s.director = '${info['director'] ?? ''}'.trim();
        s.genre = '${info['genre'] ?? ''}'.trim();
      }

      final eps = r['episodes'];
      if (eps is Map) {
        eps.forEach((season, list) {
          if (list is! List) return;
          final sn = int.tryParse('$season') ?? 1;
          final bucket = <Episode>[];
          for (final e in list) {
            if (e is! Map) continue;
            final eid = '${e['id']}';
            final ext = '${e['container_extension'] ?? 'mp4'}';
            final ei = e['info'];
            bucket.add(Episode(
              id: 'xt_ep_$eid',
              name: '${e['title'] ?? 'Episode'}',
              season: sn,
              episode: int.tryParse('${e['episode_num'] ?? 0}') ?? 0,
              streamUrl: '$host/series/$username/$password/$eid.$ext',
              plot: ei is Map ? '${ei['plot'] ?? ''}'.trim() : '',
              image: ei is Map ? '${ei['movie_image'] ?? ''}' : '',
              duration: ei is Map ? '${ei['duration'] ?? ''}' : '',
            ));
          }
          bucket.sort((a, b) => a.episode.compareTo(b.episode));
          if (bucket.isNotEmpty) out[sn] = bucket;
        });
      }
    } catch (_) {
      // Serie sans details exploitables.
    }
    return out;
  }

  // ---------------------------------------------------------------
  //  Utilitaires
  // ---------------------------------------------------------------

  Future<Map<String, String>> _categoryNames(
      String action, String fallback) async {
    final names = <String, String>{};
    final cats = await _get(action);
    for (final c in cats) {
      if (c is Map) {
        names['${c['category_id']}'] = '${c['category_name'] ?? fallback}';
      }
    }
    return names;
  }

  String _year(String added, String release) {
    if (release.length >= 4) {
      final y = release.substring(0, 4);
      if (int.tryParse(y) != null) return y;
    }
    final ts = int.tryParse(added);
    if (ts != null && ts > 0) {
      return '${DateTime.fromMillisecondsSinceEpoch(ts * 1000).year}';
    }
    return '';
  }

  Future<List<dynamic>> _get(String action) async {
    final res = await http
        .get(_api({'action': action}))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) return <dynamic>[];
    try {
      final d = jsonDecode(res.body);
      return d is List ? d : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  Future<Map<String, dynamic>> _getMap(
      String action, Map<String, String> extra) async {
    final res = await http
        .get(_api({'action': action, ...extra}))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) return <String, dynamic>{};
    try {
      final d = jsonDecode(res.body);
      return d is Map<String, dynamic> ? d : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
