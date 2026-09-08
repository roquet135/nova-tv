import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Stockage 100% local : aucun compte, aucun serveur.
class Storage {
  static const _portals = 'portals';
  static const _favs = 'favorites';
  static const _prefs = 'prefs';
  static const _hidden = 'hidden';
  static const _downloads = 'downloads';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_portals);
    await Hive.openBox(_favs);
    await Hive.openBox(_prefs);
    await Hive.openBox(_hidden);
    await Hive.openBox(_downloads);
  }

  // --- Portails ---
  static List<Portal> portals() {
    final box = Hive.box(_portals);
    return box.values
        .whereType<Map>()
        .map((e) => Portal.fromMap(e))
        .toList(growable: false);
  }

  static Future<void> savePortal(Portal p) =>
      Hive.box(_portals).put(p.id, p.toMap());

  static Future<void> deletePortal(String id) async {
    await Hive.box(_portals).delete(id);
    // On nettoie aussi les chaines masquees de ce portail.
    final box = Hive.box(_hidden);
    final keys = box.keys.where((k) => '$k'.startsWith('$id::')).toList();
    await box.deleteAll(keys);
  }

  // --- Chaines masquees (liens morts) ---
  static String _hk(String portalId, String channelId) =>
      '$portalId::$channelId';

  static bool isHidden(String portalId, String channelId) =>
      Hive.box(_hidden).containsKey(_hk(portalId, channelId));

  static Future<void> hide(String portalId, String channelId) =>
      Hive.box(_hidden).put(_hk(portalId, channelId), true);

  static Future<void> unhide(String portalId, String channelId) =>
      Hive.box(_hidden).delete(_hk(portalId, channelId));

  static int hiddenCount(String portalId) => Hive.box(_hidden)
      .keys
      .where((k) => '$k'.startsWith('$portalId::'))
      .length;

  static Future<void> clearHidden(String portalId) async {
    final box = Hive.box(_hidden);
    final keys = box.keys.where((k) => '$k'.startsWith('$portalId::')).toList();
    await box.deleteAll(keys);
  }

  // --- Favoris ---
  static bool isFavorite(String channelId) =>
      Hive.box(_favs).containsKey(channelId);

  static Future<void> toggleFavorite(Channel c) async {
    final box = Hive.box(_favs);
    if (box.containsKey(c.id)) {
      await box.delete(c.id);
    } else {
      await box.put(c.id, c.toMap());
    }
  }

  static List<Channel> favorites() => Hive.box(_favs)
      .values
      .whereType<Map>()
      .map((e) => Channel.fromMap(e))
      .toList(growable: false);

  // --- Preferences ---
  static bool getBool(String key, {bool fallback = false}) =>
      Hive.box(_prefs).get(key, defaultValue: fallback) as bool;

  static Future<void> setBool(String key, bool value) =>
      Hive.box(_prefs).put(key, value);

  static String getString(String key, {String fallback = ''}) =>
      Hive.box(_prefs).get(key, defaultValue: fallback) as String;

  static Future<void> setString(String key, String value) =>
      Hive.box(_prefs).put(key, value);

  static double getDouble(String key, {double fallback = 0}) =>
      (Hive.box(_prefs).get(key, defaultValue: fallback) as num).toDouble();

  static Future<void> setDouble(String key, double value) =>
      Hive.box(_prefs).put(key, value);

  static Future<void> setLastChannel(String id) =>
      Hive.box(_prefs).put('lastChannel', id);

  static String lastChannel() =>
      Hive.box(_prefs).get('lastChannel', defaultValue: '') as String;

  // --- Telechargements (slides gardes enfili) ---
  static List<DownloadItem> downloads() {
    final box = Hive.box(_downloads);
    final list = box.values
        .whereType<Map>()
        .map((e) => DownloadItem.fromMap(e))
        .toList(growable: false);
    // Les plus recents en premier
    list.sort((a, b) => b.dateIso.compareTo(a.dateIso));
    return list;
  }

  static Future<void> saveDownload(DownloadItem d) =>
      Hive.box(_downloads).put(d.id, d.toMap());

  static Future<void> removeDownload(String id) async {
    final d = Hive.box(_downloads).get(id);
    await Hive.box(_downloads).delete(id);
    // Supprime aussi le fichier s'il existe encore (securite).
    try {
      if (d is Map) {
        final path = '${d['filePath'] ?? ''}';
        if (path.isNotEmpty) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      }
    } catch (_) {}
  }

  /// Espace total occupe par les telechargements (en octets).
  static int downloadsTotalSize() {
    var total = 0;
    for (final v in Hive.box(_downloads).values.whereType<Map>()) {
      total += ((v['sizeBytes'] ?? 0) as num).toInt();
    }
    return total;
  }

  /// Vrai si ce contenu (film ou episode) est deja sur la box.
  static bool isDownloaded(String contentId) {
    for (final v in Hive.box(_downloads).values.whereType<Map>()) {
      if ('${v['contentId']}' == contentId) return true;
    }
    return false;
  }
}
