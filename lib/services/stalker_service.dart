import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Client Stalker Portal (Ministra / stalker_portal).
///
/// v10 GREFFE : logique de pro porte du kit aether.
///  - MAC normalisee (tirets, minuscules, espaces)
///  - SONDAGE des chemins d'API : le portail ne repond pas toujours
///    sur /portal.php (server/load.php, stalker_portal, etc.)
///  - create_link avec les parametres d'un vrai boitier MAG
///  - commande du catalogue en repli, hors gabarits internes
///  - logos relatifs retraduits en adresses complettes
///
/// Sequence : handshake -> jeton -> profil -> genres -> chaines -> lien.
class StalkerService {
  final String portalUrl;
  final String mac;
  String _token = '';
  String _endpoint = '';

  StalkerService({required String portalUrl, required this.mac})
      : portalUrl = _clean(portalUrl);

  /// Nettoie l'adresse saisie : retire le fichier terminal
  /// (/portal.php, index.html...) et l'eventuel /c final.
  static String _clean(String u) {
    var v = u.trim().replaceAll(' ', '');
    if (!v.startsWith('http')) v = 'http://$v';
    v = v.split('?').first;
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    for (final tail in const ['index.html', 'portal.php', 'load.php']) {
      if (v.toLowerCase().endsWith(tail)) {
        v = v.substring(0, v.length - tail.length);
        while (v.endsWith('/')) {
          v = v.substring(0, v.length - 1);
        }
      }
    }
    if (v.toLowerCase().endsWith('/c')) {
      v = v.substring(0, v.length - 2);
    }
    return v;
  }

  /// Les chemins d'API reellement observes sur les portails, dans
  /// l'ordre de probabilite (portage fidele du kit aether).
  static const _classicPaths = [
    '/portal.php',
    '/server/load.php',
    '/stalker_portal/server/load.php',
  ];

  static const _extraPaths = [
    '/stalker_portal/portal.php',
    '/c/portal.php',
    '/c/server/load.php',
    '/p/portal.php',
    '/portalstb.php',
    '/magLoad.php',
    '/stalker/portal.php',
    '/ministra/portal.php',
  ];

  static const _magUa =
      'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3';

  Map<String, String> _headers() {
    final encodedMac = Uri.encodeComponent(mac);
    return {
      'User-Agent': _magUa,
      'Referer': '$portalUrl/c/',
      'X-User-Agent': 'Model: MAG250; Link: WiFi',
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Cookie': 'mac=$encodedMac; stb_lang=fr; timezone=Europe%2FParis',
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> _call(Map<String, String> params) async {
    if (_endpoint.isEmpty) throw Exception('Portail non initialise');
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'JsHttpRequest': '1-xml',
      ...params,
    });
    final res = await http
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('Portail injoignable (code ${res.statusCode})');
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      throw Exception('Reponse du portail illisible');
    }
  }

  /// Sonde un chemin d'API. Retourne le jeton ou null.
  Future<String?> _probeToken(String base, int timeoutSeconds) async {
    try {
      final uri = Uri.parse(base).replace(queryParameters: {
        'type': 'stb',
        'action': 'handshake',
        'token': '',
        'JsHttpRequest': '1-xml',
      });
      final res = await http
          .get(uri, headers: _headers())
          .timeout(Duration(seconds: timeoutSeconds));
      if (res.statusCode != 200) return null;
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        final js = decoded['js'];
        if (js is Map && js['token'] != null && '${js['token']}'.isNotEmpty) {
          return '${js['token']}';
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Ouvre la session en sondant tous les emplacements d'API connus.
  /// A appeler avant tout le reste.
  Future<void> handshake() async {
    // Configuration classique d'abord : c'est celle qui fonctionne
    // dans 90% des cas (comme dans le kit).
    for (final path in _classicPaths) {
      final base = '$portalUrl$path';
      final token = await _probeToken(base, 15);
      if (token != null) {
        _endpoint = base;
        _token = token;
        break;
      }
    }

    // Chemins moins courants, essais rapides.
    if (_token.isEmpty) {
      for (final path in _extraPaths) {
        final base = '$portalUrl$path';
        final token = await _probeToken(base, 8);
        if (token != null) {
          _endpoint = base;
          _token = token;
          break;
        }
      }
    }

    if (_token.isEmpty) {
      throw Exception('Le portail a refuse cette adresse MAC '
          '(ou l URL du portail est inexacte)');
    }

    // Certains portails exigent get_profile juste apres le handshake.
    try {
      await _call({'type': 'stb', 'action': 'get_profile'});
    } catch (_) {
      // Non bloquant : beaucoup de portails s'en passent.
    }
  }

  /// Liste les chaines de tous les genres.
  Future<List<Channel>> liveChannels() async {
    if (_token.isEmpty) await handshake();

    final genres = <String, String>{};
    try {
      final g = await _call({'type': 'itv', 'action': 'get_genres'});
      final js = g['js'];
      if (js is List) {
        for (final e in js) {
          if (e is Map) genres['${e['id']}'] = '${e['title'] ?? 'General'}';
        }
      }
    } catch (_) {
      // Sans genres on regroupe tout sous General.
    }

    final out = <Channel>[];
    var page = 1;
    while (page <= 40) {
      final r = await _call({
        'type': 'itv',
        'action': 'get_ordered_list',
        'genre': '*',
        'force_ch_link_check': '',
        'fav': '0',
        'sortby': 'number',
        'hd': '0',
        'p': '$page',
      });

      final js = r['js'];
      if (js is! Map) break;
      final data = js['data'];
      if (data is! List || data.isEmpty) break;

      for (final e in data) {
        if (e is! Map) continue;
        out.add(Channel(
          id: 'stk_${e['id']}',
          name: '${e['name'] ?? 'Sans titre'}',
          streamUrl: '${e['cmd'] ?? ''}', // resolu plus tard par resolveLink
          logo: _logo('${e['logo'] ?? ''}'),
          group: genres['${e['tv_genre_id']}'] ?? 'General',
          epgId: '${e['xmltv_id'] ?? ''}',
        ));
      }

      final total = int.tryParse('${js['total_items'] ?? 0}') ?? 0;
      if (out.length >= total || data.length < 10) break;
      page++;
    }
    return out;
  }

  /// Logo relatif -> adresse complete (portage du resolveLogo du kit).
  String _logo(String raw) {
    final v = raw.trim();
    if (v.isEmpty || v == 'null') return '';
    if (v.startsWith('http')) return v;
    return '$portalUrl/stalker_portal/misc/logos/320/$v';
  }

  /// Extrait l'URL exploitable d'une commande Stalker
  /// ("ffmpeg http://..." ou "auto http://...").
  /// Portage du cleanCmd du kit : on coupe a partir du premier "http"
  /// et au premier espace, en rejetant les gabarits internes.
  static String? _cleanCmd(String value) {
    final idx = value.indexOf('http');
    if (idx < 0) return null;
    var out = value.substring(idx).trim();
    final sp = out.indexOf(' ');
    if (sp > 0) out = out.substring(0, sp).trim();
    if (out.contains('localhost') || out.contains('127.0.0.1')) {
      return null; // gabarit interne du portail, refus immediate garanti
    }
    return out;
  }

  /// Transforme la commande Stalker en URL de flux reellement lisible.
  /// Parametres d'un vrai boitier MAG : certains portails refusent
  /// la demande quand ils manquent.
  Future<String> resolveLink(String cmd) async {
    if (_token.isEmpty) await handshake();

    final clean = _cleanCmd(cmd.trim()) ?? cmd.trim();

    final r = await _call({
      'type': 'itv',
      'action': 'create_link',
      'cmd': clean,
      'series': '',
      'forced_storage': 'undefined',
      'disable_ad': '0',
      'download': '0',
      'force_ch_link_check': '0',
    });

    final js = r['js'];
    if (js is Map && js['cmd'] != null) {
      final link = _cleanCmd('${js['cmd']}');
      if (link != null && link.isNotEmpty) return link;
    }

    // Repli : certains portails livrent deja une adresse exploitable
    // dans la commande du catalogue.
    final direct = _cleanCmd(cmd.trim());
    if (direct != null && direct.isNotEmpty) return direct;
    throw Exception('Impossible d obtenir le lien de lecture');
  }
}
