class Patient {
  const Patient({
    required this.nom,
    required this.telephone,
    required this.dateNaissance,
    this.id = '',
    this.uuid = '',
    this.groupeSanguin = 'O+',
    this.sexe = 'Masculin',
    this.adresse = 'Lomé, Quartier Tokoin',
    this.contactUrgence = 'Paul KOFFI (+228 90 00 11 22)',
    this.allergies = const ['Pénicilline', 'Aspirine'],
    this.antecedents = const [
      'Hypertension artérielle',
      'Appendicectomie (2015)',
    ],
  });

  final String nom;
  final String telephone;
  final String dateNaissance;

  /// Identifiant lu dans la carte QR (ex: `PAT-2024-00123`).
  final String id;

  /// Identifiant UUID du dossier KondjiPro (contenu du QR patient).
  final String uuid;

  final String groupeSanguin;
  final String sexe;
  final String adresse;
  final String contactUrgence;
  final List<String> allergies;
  final List<String> antecedents;

  /// Construit un patient depuis une ligne brute de `GET /api/patients.php`.
  ///
  /// Le serveur renvoie `date_naissance` au format `YYYY-MM-DD` (ou vide) ;
  /// le modèle travaille en `dd/MM/yyyy`. Champs absents → valeurs par
  /// défaut du modèle (l'API médicale est partielle).
  factory Patient.fromApi(Map<String, dynamic> json) {
    final naissance = (json['date_naissance'] ?? '').toString();
    var dateNaissance = naissance;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(naissance);
    if (iso != null) {
      dateNaissance = '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
    }

    final sexe = (json['sexe'] ?? '').toString();
    final allergies = json['allergies'];

    return Patient(
      id: (json['id'] ?? '').toString(),
      uuid: (json['uuid'] ?? '').toString(),
      nom: (json['nom'] ?? '').toString(),
      telephone: (json['telephone'] ?? '').toString(),
      dateNaissance: dateNaissance,
      sexe: sexe == 'F' ? 'Féminin' : sexe == 'M' ? 'Masculin' : 'Masculin',
      adresse: (json['adresse'] ?? '').toString().isNotEmpty
          ? json['adresse'].toString()
          : 'Adresse non renseignée',
      groupeSanguin:
          (json['groupe_sanguin'] ?? '').toString().isNotEmpty
              ? json['groupe_sanguin'].toString()
              : '—',
      allergies: allergies is String && allergies.isNotEmpty
          ? allergies
              .split(RegExp(r'[,;]'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
          : const [],
      antecedents: const [],
    );
  }

  String get initials {
    final parts = nom.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nom.substring(0, 2).toUpperCase();
  }

  /// Normalise un code patient pour la comparaison (casse et espaces ignorés).
  static String normalizeId(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  int get age {
    try {
      final parts = dateNaissance.split('/');
      if (parts.length == 3) {
        final birthYear = int.parse(parts[2]);
        final currentYear = DateTime.now().year;
        return currentYear - birthYear;
      }
    } catch (_) {}
    return 41; // Valeur de repli
  }
}
