import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Lecture d'une playlist M3U / M3U8.
class M3uService {
  /// Telecharge puis analyse la playlist. Leve une Exception en cas d'echec.
  static Future<List<Channel>> load(String url) async {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('Playlist inaccessible (code ${res.statusCode})');
    }
    return parse(res.body);
  }

  /// Analyse le texte d'une playlist M3U.
  static List<Channel> parse(String content) {
    final channels = <Channel>[];
    final lines = content.split(RegExp(r'\r?\n'));

    String name = '';
    String logo = '';
    String group = 'General';
    String epgId = '';
    var index = 0;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        logo = _attr(line, 'tvg-logo');
        group = _attr(line, 'group-title');
        if (group.isEmpty) group = 'General';
        epgId = _attr(line, 'tvg-id');

        final comma = line.lastIndexOf(',');
        name = comma >= 0 && comma < line.length - 1
            ? line.substring(comma + 1).trim()
            : 'Sans titre';
      } else if (!line.startsWith('#')) {
        if (name.isEmpty) name = 'Chaine ${index + 1}';
        channels.add(Channel(
          id: 'm3u_$index',
          name: name,
          streamUrl: line,
          logo: logo,
          group: group,
          epgId: epgId,
        ));
        index++;
        name = '';
        logo = '';
        group = 'General';
        epgId = '';
      }
    }
    return channels;
  }

  static String _attr(String line, String key) {
    final m = RegExp('$key="([^"]*)"').firstMatch(line);
    return m?.group(1) ?? '';
  }
}
