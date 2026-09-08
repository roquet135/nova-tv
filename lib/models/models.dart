/// Types de portail supportes par NOVA.
enum PortalType { m3u, xtream, stalker }

extension PortalTypeLabel on PortalType {
  String get label {
    switch (this) {
      case PortalType.m3u:
        return 'M3U / M3U8';
      case PortalType.xtream:
        return 'Xtream Codes';
      case PortalType.stalker:
        return 'Stalker Portal';
    }
  }

  String get hint {
    switch (this) {
      case PortalType.m3u:
        return 'Une URL de playlist se terminant souvent par .m3u ou .m3u8';
      case PortalType.xtream:
        return 'Adresse du serveur + identifiant + mot de passe';
      case PortalType.stalker:
        return 'Adresse du portail + adresse MAC (00:1A:79:...)';
    }
  }
}

/// Un abonnement configure par l'utilisateur.
class Portal {
  final String id;
  final String name;
  final PortalType type;
  final String url;
  final String username;
  final String password;
  final String macAddress;

  const Portal({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.username = '',
    this.password = '',
    this.macAddress = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.index,
        'url': url,
        'username': username,
        'password': password,
        'macAddress': macAddress,
      };

  factory Portal.fromMap(Map<dynamic, dynamic> m) => Portal(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        type: PortalType.values[(m['type'] ?? 0) as int],
        url: (m['url'] ?? '') as String,
        username: (m['username'] ?? '') as String,
        password: (m['password'] ?? '') as String,
        macAddress: (m['macAddress'] ?? '') as String,
      );
}

/// Une chaine de television en direct.
class Channel {
  final String id;
  final String name;
  final String streamUrl;
  final String logo;
  final String group;
  final String epgId;

  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logo = '',
    this.group = 'General',
    this.epgId = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'streamUrl': streamUrl,
        'logo': logo,
        'group': group,
        'epgId': epgId,
      };

  factory Channel.fromMap(Map<dynamic, dynamic> m) => Channel(
        id: (m['id'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        streamUrl: (m['streamUrl'] ?? '') as String,
        logo: (m['logo'] ?? '') as String,
        group: (m['group'] ?? 'General') as String,
        epgId: (m['epgId'] ?? '') as String,
      );
}

/// Un film (VOD) avec sa jaquette et ses informations.
class Movie {
  final String id;
  final String streamId;
  final String name;
  final String poster;
  final String group;
  final String streamUrl;
  final String rating;
  final String year;
  final String duration;

  // Charges a la demande dans la fiche detaillee
  String plot;
  String cast;
  String director;
  String genre;

  Movie({
    required this.id,
    required this.streamId,
    required this.name,
    required this.streamUrl,
    this.poster = '',
    this.group = 'Films',
    this.rating = '',
    this.year = '',
    this.duration = '',
    this.plot = '',
    this.cast = '',
    this.director = '',
    this.genre = '',
  });

  /// Convertit le film en Channel pour le lecteur.
  Channel toChannel() => Channel(
        id: id,
        name: name,
        streamUrl: streamUrl,
        logo: poster,
        group: group,
      );
}

/// Une serie, contenant des saisons et des episodes.
class Series {
  final String id;
  final String seriesId;
  final String name;
  final String poster;
  final String group;
  final String rating;
  final String year;

  String plot;
  String cast;
  String director;
  String genre;

  Series({
    required this.id,
    required this.seriesId,
    required this.name,
    this.poster = '',
    this.group = 'Series',
    this.rating = '',
    this.year = '',
    this.plot = '',
    this.cast = '',
    this.director = '',
    this.genre = '',
  });
}

/// Un episode d'une serie.
class Episode {
  final String id;
  final String name;
  final int season;
  final int episode;
  final String streamUrl;
  final String plot;
  final String image;
  final String duration;

  const Episode({
    required this.id,
    required this.name,
    required this.season,
    required this.episode,
    required this.streamUrl,
    this.plot = '',
    this.image = '',
    this.duration = '',
  });

  Channel toChannel() => Channel(
        id: id,
        name: 'S${season}E$episode - $name',
        streamUrl: streamUrl,
        logo: image,
        group: 'Series',
      );
}

/// Un film ou un episode garde sur la box pour le regarder hors-ligne.
class DownloadItem {
  final String id; // identifiant unique du telechargement
  final String contentId; // id du film ou de l'episode source
  final String type; // 'movie' ou 'episode'
  final String name;
  final String poster;
  final String group;
  final String filePath; // chemin local du fichier sur la box
  final int sizeBytes;
  final String dateIso;
  final int season;
  final int episode;

  const DownloadItem({
    required this.id,
    required this.contentId,
    required this.type,
    required this.name,
    this.poster = '',
    this.group = '',
    required this.filePath,
    this.sizeBytes = 0,
    this.dateIso = '',
    this.season = 0,
    this.episode = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'contentId': contentId,
        'type': type,
        'name': name,
        'poster': poster,
        'group': group,
        'filePath': filePath,
        'sizeBytes': sizeBytes,
        'dateIso': dateIso,
        'season': season,
        'episode': episode,
      };

  factory DownloadItem.fromMap(Map<dynamic, dynamic> m) => DownloadItem(
        id: (m['id'] ?? '') as String,
        contentId: (m['contentId'] ?? '') as String,
        type: (m['type'] ?? 'movie') as String,
        name: (m['name'] ?? '') as String,
        poster: (m['poster'] ?? '') as String,
        group: (m['group'] ?? '') as String,
        filePath: (m['filePath'] ?? '') as String,
        sizeBytes: ((m['sizeBytes'] ?? 0) as num).toInt(),
        dateIso: (m['dateIso'] ?? '') as String,
        season: ((m['season'] ?? 0) as num).toInt(),
        episode: ((m['episode'] ?? 0) as num).toInt(),
      );

  /// Convertit en Channel jouable en local par le lecteur.
  Channel toChannel() => Channel(
        id: 'dl_$id',
        name: type == 'episode'
            ? 'S${season}E$episode - $name'
            : name,
        streamUrl: filePath,
        logo: poster,
        group: 'Telechargements',
      );
}
