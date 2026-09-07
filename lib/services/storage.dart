import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Stockage 100% local : aucun compte, aucun serveur.
class Storage {
  static const _portals = 'portals';
  static const _favs = 'favorites';
  static const _prefs = 'prefs';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_portals);
    await Hive.openBox(_favs);
    await Hive.openBox(_prefs);
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

  static Future<void> deletePortal(String id) => Hive.box(_portals).delete(id);

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

  static Future<void> setLastChannel(String id) =>
      Hive.box(_prefs).put('lastChannel', id);

  static String lastChannel() =>
      Hive.box(_prefs).get('lastChannel', defaultValue: '') as String;
}
