import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Client Stalker Portal (Ministra / stalker_portal).
///
/// Sequence : handshake -> jeton -> profil -> genres -> chaines -> lien reel.
class StalkerService {
  final String portalUrl;
  final String mac;
  String _token = '';

  StalkerService({required String portalUrl, required this.mac})
      : portalUrl = _clean(portalUrl);

  static String _clean(String u) {
    var v = u.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (!v.startsWith('http')) v = 'http://$v';
    // Les portails exposent /portal.php ou /stalker_portal/server/load.php
    if (v.endsWith('/c') || v.endsWith('/c/')) {
      v = v.substring(0, v.lastIndexOf('/c'));
    }
    return v;
  }

  String get _endpoint => '$portalUrl/portal.php';

  Map<String, String> _headers() {
    final encodedMac = Uri.encodeComponent(mac);
    return {
      'User-Agent':
          'Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3',
      'Referer': '$portalUrl/c/',
      'X-User-Agent': 'Model: MAG250; Link: WiFi',
      'Cookie': 'mac=$encodedMac; stb_lang=fr; timezone=Europe/Paris',
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> _call(Map<String, String> params) async {
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

  /// Ouvre la session. A appeler avant tout le reste.
  Future<void> handshake() async {
    final r = await _call({'type': 'stb', 'action': 'handshake'});
    final js = r['js'];
    if (js is Map && js['token'] != null) {
      _token = '${js['token']}';
    }
    if (_token.isEmpty) {
      throw Exception('Le portail a refuse cette adresse MAC');
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
          logo: '${e['logo'] ?? ''}',
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

  /// Transforme la commande Stalker en URL de flux reellement lisible.
  Future<String> resolveLink(String cmd) async {
    if (_token.isEmpty) await handshake();

    var clean = cmd.trim();
    // Les commandes ont souvent la forme "ffmpeg http://..." ou "auto http://..."
    final space = clean.indexOf(' ');
    if (space > 0 && !clean.startsWith('http')) {
      clean = clean.substring(space + 1).trim();
    }

    final r = await _call({
      'type': 'itv',
      'action': 'create_link',
      'cmd': clean,
      'forced_storage': 'undefined',
      'disable_ad': '0',
    });

    final js = r['js'];
    if (js is Map && js['cmd'] != null) {
      var link = '${js['cmd']}'.trim();
      final sp = link.indexOf(' ');
      if (sp > 0 && !link.startsWith('http')) {
        link = link.substring(sp + 1).trim();
      }
      if (link.isNotEmpty) return link;
    }
    if (clean.startsWith('http')) return clean;
    throw Exception('Impossible d obtenir le lien de lecture');
  }
}
