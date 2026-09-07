import 'dart:convert';
import 'package:http/http.dart' as http;

/// Un programme du guide TV.
class EpgProgram {
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;

  const EpgProgram({
    required this.title,
    required this.start,
    required this.end,
    this.description = '',
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  /// Avancement du programme, de 0 a 1.
  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    final done = DateTime.now().difference(start).inSeconds;
    final r = done / total;
    return r < 0 ? 0 : (r > 1 ? 1 : r);
  }

  String get startLabel => _hm(start);
  String get endLabel => _hm(end);
  String get range => '${_hm(start)} - ${_hm(end)}';

  static String _hm(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:'
        '${l.minute.toString().padLeft(2, '0')}';
  }
}

/// Guide des programmes via l'API Xtream (get_short_epg).
class EpgService {
  final String host;
  final String username;
  final String password;

  /// Cache memoire : on n'interroge le serveur qu'une fois par chaine.
  final Map<String, List<EpgProgram>> _cache = {};

  EpgService({
    required this.host,
    required this.username,
    required this.password,
  });

  bool has(String streamId) => _cache.containsKey(streamId);

  List<EpgProgram> cached(String streamId) => _cache[streamId] ?? const [];

  /// Recupere les prochains programmes d'une chaine.
  /// Retourne une liste vide si le portail ne fournit pas d'EPG.
  Future<List<EpgProgram>> forStream(String streamId, {int limit = 8}) async {
    if (_cache.containsKey(streamId)) return _cache[streamId]!;

    try {
      final uri = Uri.parse('$host/player_api.php').replace(queryParameters: {
        'username': username,
        'password': password,
        'action': 'get_short_epg',
        'stream_id': streamId,
        'limit': '$limit',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 18));
      if (res.statusCode != 200) {
        _cache[streamId] = const [];
        return const [];
      }

      final body = jsonDecode(res.body);
      final listings = body is Map ? body['epg_listings'] : null;
      if (listings is! List) {
        _cache[streamId] = const [];
        return const [];
      }

      final out = <EpgProgram>[];
      for (final e in listings) {
        if (e is! Map) continue;
        final start = _parse('${e['start'] ?? ''}');
        final end = _parse('${e['end'] ?? e['stop'] ?? ''}');
        if (start == null || end == null) continue;

        out.add(EpgProgram(
          title: _b64('${e['title'] ?? ''}'),
          description: _b64('${e['description'] ?? ''}'),
          start: start,
          end: end,
        ));
      }
      out.sort((a, b) => a.start.compareTo(b.start));
      _cache[streamId] = out;
      return out;
    } catch (_) {
      _cache[streamId] = const [];
      return const [];
    }
  }

  /// Xtream encode les titres en base64.
  static String _b64(String v) {
    if (v.isEmpty) return '';
    try {
      final d = base64.decode(v);
      final s = utf8.decode(d, allowMalformed: true);
      // Si le decodage donne des caracteres illisibles, on garde l'original.
      if (s.trim().isEmpty) return v;
      return s.trim();
    } catch (_) {
      return v;
    }
  }

  /// Formats rencontres : "2026-09-07 21:30:00" ou timestamp unix.
  static DateTime? _parse(String v) {
    if (v.isEmpty) return null;
    final ts = int.tryParse(v);
    if (ts != null && ts > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
    try {
      return DateTime.parse(v.replaceFirst(' ', 'T'));
    } catch (_) {
      return null;
    }
  }
}
