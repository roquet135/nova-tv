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
///
/// v10 GREFFE : parseur "tout-terrain" porte du kit aether.
/// Rien n'est normalise dans le monde Xtream : selon la version du
/// serveur, une meme API renvoie l'un ou l'autre de ces formats.
///  - enveloppe : `{"epg_listings":[...]}`, `{"js":{"data":[...]}}` ou
///    un tableau nu ;
///  - horaires : `start_timestamp` (secondes ou millisecondes) ou
///    `start` ("2026-08-19 21:00:00", heure serveur ~ UTC) ;
///  - titres : texte simple ou base64 ;
///  - noms de champs : `title`/`name`, `description`/`descr`.
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

      final root = jsonDecode(res.body);
      final listings = _listingsOf(root);
      if (listings.isEmpty) {
        _cache[streamId] = const [];
        return const [];
      }

      final out = <EpgProgram>[];
      for (final e in listings) {
        if (e is! Map) continue;
        final start =
            _instant(e, const ['start_timestamp', 'start', 'start_time']);
        if (start == null) continue;
        var end = _instant(e, const [
          'stop_timestamp',
          'end_timestamp',
          'end',
          'stop',
          'stop_time'
        ]);
        // Pas de fin fiable : on suppose 30 minutes, comme le kit.
        if (end == null || !end.isAfter(start)) {
          end = start.add(const Duration(minutes: 30));
        }

        final title = _b64('${e['title'] ?? e['name'] ?? ''}');
        if (title.isEmpty) continue;

        out.add(EpgProgram(
          title: title,
          description:
              _b64('${e['description'] ?? e['descr'] ?? ''}'),
          start: start,
          end: end,
        ));
      }
      // Une grille dont deux programmes se chevauchent rendrait
      // "en cours" ambigu : l'ordre chronologique est la garantie.
      out.sort((a, b) => a.start.compareTo(b.start));
      _cache[streamId] = out;
      return out;
    } catch (_) {
      _cache[streamId] = const [];
      return const [];
    }
  }

  /// Trouve le tableau des programmes, quelle que soit la forme
  /// de l'enveloppe renvoyee par le serveur.
  static List<dynamic> _listingsOf(dynamic root) {
    if (root is List) return root;
    if (root is! Map) return const [];
    for (final key in const ['epg_listings', 'data', 'js', 'epg']) {
      final child = root[key];
      if (child is List) return child;
      if (child is Map) {
        for (final inner in const ['data', 'epg_listings']) {
          final nested = child[inner];
          if (nested is List) return nested;
        }
      }
    }
    return const [];
  }

  /// Millisecondes depuis l'epoque, quel que soit le champ ou le format.
  static DateTime? _instant(Map e, List<String> keys) {
    for (final k in keys) {
      final raw = '${e[k] ?? ''}'.trim();
      if (raw.isEmpty) continue;

      // Horodatage numerique : secondes (parfois millisecondes sur
      // certains panels).
      final n = int.tryParse(raw);
      if (n != null) {
        if (n > 4000000000) return DateTime.fromMillisecondsSinceEpoch(n);
        if (n > 100000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }

      final d = _textDate(raw);
      if (d != null) return d;
    }
    return null;
  }

  /// Accepte "2026-08-19 21:00:00", "2026-08-19T21:00", "2026/08/19 21:00".
  /// Les panels datent en heure serveur, presque toujours UTC.
  static final RegExp _dateRe = RegExp(
      r'^(\d{4})[-/](\d{2})[-/](\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?');

  static DateTime? _textDate(String raw) {
    final m = _dateRe.firstMatch(raw);
    if (m == null) return null;
    try {
      return DateTime.utc(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6) ?? '0'),
      );
    } catch (_) {
      return null;
    }
  }

  /// Xtream encode souvent les titres en base64.
  static String _b64(String v) {
    if (v.isEmpty) return '';
    try {
      final d = base64.decode(v);
      final s = utf8.decode(d, allowMalformed: true).trim();
      // Si le decodage donne du texte lisible on le garde,
      // sinon c'etait du texte deja clair.
      final readable = s.isNotEmpty &&
          s.runes.every((r) => r >= 32 || r == 10 || r == 13);
      return readable ? s : v;
    } catch (_) {
      return v;
    }
  }
}
