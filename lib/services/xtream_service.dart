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

  Uri _api(Map<String, String> extra) => Uri.parse('$host/player_api.php')
      .replace(queryParameters: {
    'username': username,
    'password': password,
    ...extra,
  });

  /// Verifie les identifiants. Retourne le statut du compte.
  Future<String> authenticate() async {
    final res =
        await http.get(_api({})).timeout(const Duration(seconds: 30));
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

  /// Recupere les chaines de television en direct.
  Future<List<Channel>> liveChannels() async {
    final cats = await _get('get_live_categories');
    final names = <String, String>{};
    for (final c in cats) {
      if (c is Map) {
        names['${c['category_id']}'] = '${c['category_name'] ?? 'General'}';
      }
    }

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

  /// Recupere les films a la demande.
  Future<List<Channel>> vodChannels() async {
    final cats = await _get('get_vod_categories');
    final names = <String, String>{};
    for (final c in cats) {
      if (c is Map) {
        names['${c['category_id']}'] = '${c['category_name'] ?? 'Films'}';
      }
    }

    final items = await _get('get_vod_streams');
    final out = <Channel>[];
    for (final s in items) {
      if (s is! Map) continue;
      final sid = '${s['stream_id']}';
      final ext = '${s['container_extension'] ?? 'mp4'}';
      out.add(Channel(
        id: 'xt_vod_$sid',
        name: '${s['name'] ?? 'Sans titre'}',
        streamUrl: '$host/movie/$username/$password/$sid.$ext',
        logo: '${s['stream_icon'] ?? ''}',
        group: names['${s['category_id']}'] ?? 'Films',
      ));
    }
    return out;
  }

  Future<List<dynamic>> _get(String action) async {
    final res = await http
        .get(_api({'action': action}))
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) return <dynamic>[];
    try {
      final decoded = jsonDecode(res.body);
      return decoded is List ? decoded : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }
}
