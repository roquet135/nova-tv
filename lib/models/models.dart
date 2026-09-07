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

/// Une chaine, un film ou un episode.
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
