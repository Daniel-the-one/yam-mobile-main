import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yam_mobile/services/kondjipro_client.dart';
import 'package:yam_mobile/services/storage_service.dart';

/// Construit un client branché sur un MockClient.
///
/// [handler] reçoit la requête et doit renvoyer la réponse attendue.
KondjiproClient _clientWith(
  Future<http.Response> Function(http.Request request) handler, {
  StorageService? storage,
}) {
  return KondjiproClient(
    baseUrlProvider: () => 'http://kpro.test',
    storage: storage ?? StorageService(),
    httpClient: MockClient(handler),
  );
}

/// Réponse de login type : cookie de session + csrf_token.
http.Response _loginOk({String cookie = 'abc123session'}) {
  return http.Response(
    jsonEncode({
      'ok': true,
      'user': {'id': 4},
      'csrf_token': 'csrf-token-abc',
    }),
    200,
    headers: {'set-cookie': 'kondjipro_session=$cookie; path=/; HttpOnly'},
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KondjiproClient — session (cookie + CSRF)', () {
    test('login capture le cookie Set-Cookie et persiste cookie + csrf',
        () async {
      final storage = StorageService();
      final client = _clientWith((_) async => _loginOk(), storage: storage);

      expect(client.hasSession, isFalse);
      await client.login(identifier: '+228900000002', password: 'x');

      expect(client.hasSession, isTrue);
      expect(await storage.loadKproSession(), 'abc123session');
      expect(await storage.loadKproCsrf(), 'csrf-token-abc');
    });

    test('login sans cookie dans la réponse → exception', () async {
      final client = _clientWith(
        (_) async => http.Response(jsonEncode({'ok': true}), 200),
      );
      expect(
        () => client.login(identifier: 'a', password: 'b'),
        throwsA(isA<Exception>()),
      );
    });

    test('restore() réutilise une session persistée', () async {
      final storage = StorageService();
      await storage.saveKproSession('persisted-cookie');
      await storage.saveKproCsrf('persisted-csrf');

      final client = _clientWith(
        (_) async => http.Response('{}', 200),
        storage: storage,
      );
      await client.restore();
      expect(client.hasSession, isTrue);
    });

    test('GET envoyé avec header Cookie ; POST avec X-CSRF-Token', () async {
      final captured = <http.Request>[];
      late KondjiproClient client;

      client = _clientWith((req) async {
        captured.add(req);
        if (req.url.path.contains('login')) return _loginOk();
        if (req.method == 'POST') {
          // Réponse ok:true minimale pour la validation interne.
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response(jsonEncode({'results': []}), 200);
      });

      await client.login(identifier: 'id', password: 'pwd');
      await client.get('/api/patients.php');
      await client.postForm('/api/facture_save.php', {'patient': '1'});

      final get = captured.firstWhere((r) => r.method == 'GET');
      expect(get.headers['Cookie'], contains('kondjipro_session=abc123session'));

      final post = captured.firstWhere(
        (r) => r.method == 'POST' && !r.url.path.contains('login'),
      );
      expect(post.headers['X-CSRF-Token'], 'csrf-token-abc');
      expect(post.headers['Cookie'], contains('kondjipro_session='));
    });

    test('requête sans session → KondjiproAuthException', () async {
      final client = _clientWith(
        (_) async => http.Response('{}', 200),
      );
      expect(
        () => client.get('/api/patients.php'),
        throwsA(isA<KondjiproAuthException>()),
      );
    });
  });

  group('KondjiproClient — re-login silencieux sur 401', () {
    test('session expirée → re-login puis rejoue la requête', () async {
      var calls = 0;
      var loginCount = 0;
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) {
          loginCount++;
          return _loginOk(cookie: 'fresh-$loginCount');
        }
        calls++;
        if (calls == 1) {
          return http.Response(jsonEncode({'error': 'unauthenticated'}), 401);
        }
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 1, 'nom': 'Patient Test'}
            ],
          }),
          200,
        );
      });

      await client.login(identifier: 'id', password: 'pwd');
      final res = await client.get('/api/patients.php');

      expect(loginCount, 2, reason: 'un re-login silencieux');
      expect((res['results'] as List).length, 1);
    });

    test('401 sans identifiants en mémoire → KondjiproAuthException',
        () async {
      final storage = StorageService();
      // Session restaurée (cookie présent) mais jamais loguée dans ce cycle :
      // aucun identifiant en mémoire → pas de re-login possible.
      await storage.saveKproSession('stale-cookie');
      final client = _clientWith(
        (_) async => http.Response(jsonEncode({'error': 'unauthenticated'}), 401),
        storage: storage,
      );
      await client.restore();

      expect(
        () => client.get('/api/patients.php'),
        throwsA(isA<KondjiproAuthException>()),
      );
    });
  });

  group('KondjiproClient — validation métier des réponses', () {
    test('HTTP 200 avec ok:false → exception portant le message serveur',
        () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        return http.Response(
          jsonEncode({'ok': false, 'message': 'Patient ou actes manquants.'}),
          200,
        );
      });
      await client.login(identifier: 'i', password: 'p');

      expect(
        () => client.saveFacture(patientId: 1, codes: ['C001']),
        throwsA(predicate((e) => '$e'.contains('Patient ou actes manquants'))),
      );
    });

    test('HTTP 403 CSRF → exception avec message serveur', () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        return http.Response(
          jsonEncode({'error': 'csrf_invalid', 'message': 'Token CSRF invalide ou manquant.'}),
          403,
        );
      });
      await client.login(identifier: 'i', password: 'p');

      expect(
        () => client.postForm('/api/consultation_save.php', {'patient': '1'}),
        throwsA(predicate((e) => '$e'.contains('Token CSRF invalide'))),
      );
    });
  });

  group('KondjiproClient — corps des requêtes métier', () {
    test('saveFacture encode actes[] répétés (corps urlencodé)', () async {
      http.Request? captured;
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        captured = req;
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      await client.login(identifier: 'i', password: 'p');
      await client.saveFacture(patientId: 42, codes: ['C001', 'C003']);

      expect(captured, isNotNull);
      final body = captured!.body;
      expect(body, contains('patient=42'));
      expect(
        body,
        anyOf(contains('actes%5B%5D=C001'), contains('actes[]=C001')),
      );
      expect(body, contains('C003'));
    });

    test('saveOrdonnance envoie med[i][…]', () async {
      http.Request? captured;
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        captured = req;
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      await client.login(identifier: 'i', password: 'p');
      await client.saveOrdonnance(
        patientId: 7,
        notes: 'suivi',
        meds: [
          {'nom': 'Paracétamol', 'quantite': '10', 'unite': 'Comprimés', 'frequence': '2 fois/jour'},
        ],
      );

      final body = captured!.body;
      expect(body, contains('patient=7'));
      expect(body, contains('med'));
      expect(
        body,
        anyOf(contains('Parac%C3%A9tamol'), contains('Paracétamol')),
      );
    });
  });

  group('resolvePatientId', () {
    test('knownId fourni → conversion directe sans appel réseau', () async {
      final client = _clientWith(
        (_) async => fail('aucun appel réseau attendu'),
      );
      final id = await client.resolvePatientId(knownId: '42');
      expect(id, 42);
    });

    test('recherche par téléphone → appariement des 8 derniers chiffres',
        () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 9, 'telephone': '+22890112233'},
              {'id': 12, 'telephone': '+22890000044'},
            ],
          }),
          200,
        );
      });
      await client.login(identifier: 'i', password: 'p');

      final id = await client.resolvePatientId(phone: '+228 90 00 00 44');
      expect(id, 12);
    });

    test('aucun résultat → null', () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        return http.Response(jsonEncode({'results': []}), 200);
      });
      await client.login(identifier: 'i', password: 'p');

      final id = await client.resolvePatientId(phone: '+22890999999');
      expect(id, isNull);
    });

    test('correspondance non exacte → null (jamais de mauvais patient)',
        () async {
      // Le serveur renvoie des patients dont le téléphone contient les
      // chiffres recherchés SANS les terminer exactement : on refuse.
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        return http.Response(
          jsonEncode({
            'results': [
              {'id': 9, 'telephone': '+22890112233'}, // contient 0112233…
            ],
          }),
          200,
        );
      });
      await client.login(identifier: 'i', password: 'p');

      final id = await client.resolvePatientId(phone: '+22890999999');
      expect(id, isNull);
    });
  });

  group('KondjiproClient — erreurs réseau', () {
    test('exception réseau → message orienté action (pas de jargon)',
        () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        throw http.ClientException('Connection refused');
      });
      await client.login(identifier: 'i', password: 'p');

      expect(
        () => client.get('/api/patients.php'),
        throwsA(predicate(
          (e) => '$e'.contains('vérifiez votre connexion'),
        )),
      );
    });
  });

  group('KondjiproClient — famille argent en mode démo', () {
    test('solde() utilise le jeton Bearer démo, pas le cookie PHP', () async {
      final client = KondjiproClient(
        baseUrlProvider: () => 'http://kpro.test',
        storage: StorageService(),
        demoTokenProvider: () => 'demo-token-123',
        httpClient: MockClient((req) async {
          expect(req.url.toString(), 'http://kpro.test/api/demo/v1/kondjipro/solde');
          expect(req.headers['Authorization'], 'Bearer demo-token-123');
          expect(req.headers.containsKey('Cookie'), isFalse);
          return http.Response(
            jsonEncode({'demo': true, 'ok': true, 'solde': 150000}),
            200,
          );
        }),
      );

      final solde = await client.solde();
      expect(solde, 150000);
    });

    test('encaisser() transmet patient_id et montant en démo', () async {
      late Map<String, dynamic> bodySent;
      final client = KondjiproClient(
        baseUrlProvider: () => 'http://kpro.test',
        storage: StorageService(),
        demoTokenProvider: () => 'demo-token-123',
        httpClient: MockClient((req) async {
          expect(req.url.toString(),
              'http://kpro.test/api/demo/v1/kondjipro/encaissement');
          expect(req.headers['Authorization'], 'Bearer demo-token-123');
          bodySent = Uri.splitQueryString(req.body);
          return http.Response(
            jsonEncode({
              'demo': true,
              'ok': true,
              'transaction': {'reference': 'ENC123'},
              'qr_data': 'yam://qr/ENC123',
            }),
            201,
          );
        }),
      );

      final res = await client.encaisser(patientId: 7, montant: 2500);
      expect(res['transaction']['reference'], 'ENC123');
      expect(bodySent['patient_id'], '7');
      expect(bodySent['montant'], '2500');
    });

    test('endpoint démo sans jeton → KondjiproAuthException', () async {
      final client = KondjiproClient(
        baseUrlProvider: () => 'http://kpro.test',
        storage: StorageService(),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );

      expect(
        () => client.solde(),
        throwsA(isA<KondjiproAuthException>()),
      );
    });
  });

  group('KondjiproClient — listes factures / ordonnances', () {
    test('factures() retourne la liste parsée', () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        expect(req.url.toString(), 'http://kpro.test/api/factures.php');
        return http.Response(
          jsonEncode({
            'ok': true,
            'factures': [
              {'id': 1, 'numero': 'FAC-2026-001', 'patient': 'Jean KOFFI', 'montant': 5000, 'date': '16/09/2026', 'statut': 'payee'},
            ],
          }),
          200,
        );
      });
      await client.login(identifier: 'i', password: 'p');

      final rows = await client.factures();
      expect(rows, hasLength(1));
      expect(rows.first['numero'], 'FAC-2026-001');
      expect(rows.first['statut'], 'payee');
    });

    test('ordonnances() retourne la liste parsée', () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        expect(req.url.toString(), 'http://kpro.test/api/ordonnances.php');
        return http.Response(
          jsonEncode({
            'ok': true,
            'ordonnances': [
              {'id': 1, 'numero': 'ORD-2026-001', 'patient': 'Jean KOFFI', 'date': '16/09/2026', 'notes': '', 'medicaments': [{'nom': 'Paracétamol 500mg', 'quantite': 21}]},
            ],
          }),
          200,
        );
      });
      await client.login(identifier: 'i', password: 'p');

      final rows = await client.ordonnances();
      expect(rows, hasLength(1));
      expect(rows.first['numero'], 'ORD-2026-001');
      expect((rows.first['medicaments'] as List).first['nom'], 'Paracétamol 500mg');
    });

    test('factures() renvoie une liste vide si la clé est absente', () async {
      final client = _clientWith((req) async {
        if (req.url.path.contains('login')) return _loginOk();
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      await client.login(identifier: 'i', password: 'p');

      expect(await client.factures(), isEmpty);
    });
  });
}
