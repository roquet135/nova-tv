import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Moteur de telechargement NOVA : file d'attente d'un fichier a la fois,
/// progression detaillee, annulation propre (fichier .part supprime).
class NovaDownloader {
  http.Client? _client;
  bool _cancelled = false;

  bool get cancelled => _cancelled;

  /// Dossier prive de l'app sur la box (pas de permission necessaire).
  static Future<Directory> dir() async {
    final base = await getExternalStorageDirectory();
    final d = Directory('${base!.path}/nova_downloads');
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  /// Nom de fichier sur sur base d'un identifiant + l'extension du lien.
  static String fileName(String uniqueId, String url) {
    final cleanUrl = url.split('?').first;
    var ext = 'mp4';
    final dot = cleanUrl.lastIndexOf('.');
    if (dot >= 0 && cleanUrl.length - dot <= 5) {
      ext = cleanUrl.substring(dot + 1);
    }
    final safeId = uniqueId.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
    return '$safeId.$ext';
  }

  /// Telecharge un fichier en continu. Retourne le chemin final.
  /// Lance une Exception('Annulé') si l'utilisateur interrompt.
  Future<String> download({
    required String url,
    required String outFileName,
    void Function(int received, int total)? onProgress,
  }) async {
    final d = await dir();
    final dst = File('${d.path}/$outFileName');
    final tmp = File('${dst.path}.part');
    if (await tmp.exists()) await tmp.delete();

    _cancelled = false;
    _client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] =
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120 Safari/537.36';
      final res =
          await _client!.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode >= 400) {
        throw Exception('Serveur indisponible (code ${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      final sink = tmp.openWrite();
      var received = 0;
      await for (final chunk in res.stream) {
        if (_cancelled) throw Exception('Annulé');
        sink.add(chunk);
        received += chunk.length;
        // On notifie tous les 512 Ko pour une barre fluide
        if (received % (512 * 1024) < chunk.length || received == total) {
          onProgress?.call(received, total);
        }
      }
      await sink.flush();
      await sink.close();
      await tmp.rename(dst.path);
      onProgress?.call(received, received > 0 ? received : total);
      return dst.path;
    } on Exception {
      if (await tmp.exists()) {
        try {
          await tmp.delete();
        } catch (_) {}
      }
      rethrow;
    } finally {
      _client?.close();
      _client = null;
    }
  }

  /// Demande d'annulation (propre, reception du prochain bloc).
  void cancel() {
    _cancelled = true;
  }
}
