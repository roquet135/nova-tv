/// Detection du pays d'une chaine, d'un film ou d'une serie a partir
/// de son nom et de sa categorie.
///
/// Les portails IPTV prefixent presque toujours leurs contenus :
/// "FR| TF1", "FR - Canal+", "[FR] Netflix", "UK: BBC One"...
///
/// OPTIMISATION v7.1 : toutes les expressions regulieres sont compilees
/// UNE SEULE FOIS au demarrage. Avant, elles etaient recreees pour chacun
/// des 100 000+ contenus, ce qui figeait l'interface et faisait tuer
/// l'application par Android sur les petites box TV.
class CountryFilter {
  /// Drapeau, libelle et motifs de reconnaissance.
  static const List<Country> all = [
    Country('ALL', 'Tous les pays', '', []),
    Country('FR', 'France', '🇫🇷', [
      'fr', 'fra', 'france', 'french', 'francais', 'française'
    ]),
    Country('BE', 'Belgique', '🇧🇪', ['be', 'bel', 'belgi', 'belgique']),
    Country('CH', 'Suisse', '🇨🇭', ['ch', 'suisse', 'swiss', 'switzerland']),
    Country('CA', 'Canada', '🇨🇦', ['ca', 'can', 'canada', 'quebec', 'qc']),
    Country('UK', 'Royaume-Uni', '🇬🇧', [
      'uk', 'gb', 'eng', 'england', 'britain', 'british'
    ]),
    Country('US', 'Etats-Unis', '🇺🇸', ['us', 'usa', 'american', 'america']),
    Country('DE', 'Allemagne', '🇩🇪', ['de', 'ger', 'deu', 'german', 'deutsch']),
    Country('ES', 'Espagne', '🇪🇸', ['es', 'esp', 'spain', 'spanish', 'espana']),
    Country('IT', 'Italie', '🇮🇹', ['it', 'ita', 'italy', 'italian', 'italia']),
    Country('PT', 'Portugal', '🇵🇹', ['pt', 'por', 'portugal', 'portugues']),
    Country('NL', 'Pays-Bas', '🇳🇱', ['nl', 'ned', 'dutch', 'holland']),
    Country('MA', 'Maroc', '🇲🇦', ['ma', 'mar', 'maroc', 'morocco']),
    Country('DZ', 'Algerie', '🇩🇿', ['dz', 'alg', 'algerie', 'algeria']),
    Country('TN', 'Tunisie', '🇹🇳', ['tn', 'tun', 'tunisie', 'tunisia']),
    Country('AR', 'Arabe', '🇸🇦', [
      'ar', 'arab', 'arabic', 'arabe', 'ksa', 'osn', 'mbc', 'bein ar'
    ]),
    Country('TR', 'Turquie', '🇹🇷', ['tr', 'tur', 'turk', 'turkish']),
    Country('PL', 'Pologne', '🇵🇱', ['pl', 'pol', 'poland', 'polska']),
    Country('RO', 'Roumanie', '🇷🇴', ['ro', 'rou', 'romania', 'romana']),
    Country('RU', 'Russie', '🇷🇺', ['ru', 'rus', 'russia', 'russian']),
    Country('IN', 'Inde', '🇮🇳', ['in', 'ind', 'india', 'hindi']),
    Country('BR', 'Bresil', '🇧🇷', ['br', 'bra', 'brazil', 'brasil']),
    Country('AF', 'Afrique', '🌍', ['af', 'africa', 'afrique', 'senegal', 'ci']),
  ];

  // ---------- Regex compilees UNE SEULE FOIS (cle de la perf) ----------

  /// Motif de prefixe explicite : "FR|", "FR -", "[FR]", "FR:"
  static final RegExp _prefixRe =
      RegExp(r'^\s*[\[\(]?\s*([a-z]{2,3})\s*[\]\)]?\s*[|:\-–]');

  /// Mots entiers (longueur >= 3), par code pays.
  static final Map<String, List<RegExp>> _wordRes = {
    for (final c in all)
      if (c.code != 'ALL')
        c.code: [
          for (final p in c.patterns)
            if (p.length >= 3) RegExp('\\b${RegExp.escape(p)}\\b'),
        ],
  };

  /// Codes courts (longueur <= 2) entoures de separateurs, par code pays.
  static final Map<String, List<RegExp>> _shortRes = {
    for (final c in all)
      if (c.code != 'ALL')
        c.code: [
          for (final p in c.patterns)
            if (p.length <= 2)
              RegExp(
                  '(^|[\\s\\|\\[\\(:\\-])$p([\\s\\|\\]\\):\\-]|\$)'),
        ],
  };

  // -------------------------------------------------------------------

  /// Detecte le code pays d'un texte. Retourne '' si indetermine.
  static String detect(String name, String group) {
    final hay = '$group $name'.toLowerCase();

    // 1. Motif de prefixe explicite : "FR|", "FR -", "[FR]", "FR:"
    final m = _prefixRe.firstMatch(hay);
    if (m != null) {
      final code = m.group(1)!;
      for (final c in all) {
        if (c.code == 'ALL') continue;
        if (c.patterns.contains(code)) return c.code;
      }
    }

    // 2. Mot entier present dans le texte
    for (final c in all) {
      if (c.code == 'ALL') continue;
      final res = _wordRes[c.code]!;
      for (final re in res) {
        if (re.hasMatch(hay)) return c.code;
      }
    }

    // 3. Code court entoure de separateurs
    for (final c in all) {
      if (c.code == 'ALL') continue;
      final res = _shortRes[c.code]!;
      for (final re in res) {
        if (re.hasMatch(hay)) return c.code;
      }
    }

    return '';
  }

  static Country byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => all.first);

  /// Ne garde que les pays reellement presents dans le contenu charge,
  /// tries par nombre d'elements decroissant.
  static List<Country> presentIn(Map<String, int> counts) {
    final out = <Country>[all.first];
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sorted) {
      if (e.key.isEmpty) continue;
      final c = all.firstWhere((x) => x.code == e.key,
          orElse: () => const Country('', '', '', []));
      if (c.code.isNotEmpty) out.add(c);
    }
    return out;
  }
}

class Country {
  final String code;
  final String label;
  final String flag;
  final List<String> patterns;

  const Country(this.code, this.label, this.flag, this.patterns);
}
