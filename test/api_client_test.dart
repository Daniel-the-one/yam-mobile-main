import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:yam_mobile/services/api_client.dart';

/// Tests du mécanisme d'offre différée côté client HTTP.
///
/// `ApiClient.fetchDeferredOffer` récupère l'offre SDP stockée par le serveur
/// (GET /call/{call_id}/offer) quand elle n'a pas été reçue en temps réel.
/// Contrat : payload `{sdp, type}` sur 200, null sur toute autre issue
/// (404/403/410/422, erreur réseau, payload illisible).
void main() {
  group('ApiClient.fetchDeferredOffer', () {
    late ApiClient client;

    ApiClient buildClient(MockClient mock) =>
        ApiClient(() => 'https://api.example.com', client: mock);

    test(
      'retourne le payload {sdp, type} quand le serveur répond 200',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.com/api/v1/call/call-1/offer?device_id=dev-bob',
          );
          return http.Response(
            jsonEncode({
              'ok': true,
              'call_id': 'call-1',
              'type': 'offer',
              'payload': {'sdp': 'v=0\r\no=alice\r\n', 'type': 'offer'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        client = buildClient(mock);

        final result = await client.fetchDeferredOffer(
          callId: 'call-1',
          deviceId: 'dev-bob',
        );

        expect(result, {'sdp': 'v=0\r\no=alice\r\n', 'type': 'offer'});
      },
    );

    test('encode call_id et device_id dans l\'URL', () async {
      final mock = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/call/call%201/offer?device_id=dev%2Bbob',
        );
        return http.Response(
          jsonEncode({
            'ok': true,
            'payload': {'sdp': 'sdp', 'type': 'offer'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      client = buildClient(mock);

      await client.fetchDeferredOffer(callId: 'call 1', deviceId: 'dev+bob');
    });

    test(
      'retourne null quand le payload est absent de la réponse 200',
      () async {
        final mock = MockClient((request) async {
          return http.Response(
            jsonEncode({'ok': true, 'call_id': 'call-1'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        client = buildClient(mock);

        final result = await client.fetchDeferredOffer(
          callId: 'call-1',
          deviceId: 'dev-bob',
        );

        expect(result, isNull);
      },
    );

    test('retourne null quand le payload n\'est pas un objet JSON', () async {
      final mock = MockClient((request) async {
        return http.Response(
          jsonEncode({'ok': true, 'payload': 'pas-un-objet'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      client = buildClient(mock);

      final result = await client.fetchDeferredOffer(
        callId: 'call-1',
        deviceId: 'dev-bob',
      );

      expect(result, isNull);
    });

    test('retourne null sur 404 (offre introuvable)', () async {
      final mock = MockClient(
        (request) async => http.Response(
          jsonEncode({'ok': false, 'error': 'offer_not_found'}),
          404,
          headers: {'content-type': 'application/json'},
        ),
      );
      client = buildClient(mock);

      expect(
        await client.fetchDeferredOffer(callId: 'call-1', deviceId: 'dev-bob'),
        isNull,
      );
    });

    test('retourne null sur 403 (device non destinataire)', () async {
      final mock = MockClient(
        (request) async => http.Response(
          jsonEncode({'ok': false, 'error': 'forbidden_device'}),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      client = buildClient(mock);

      expect(
        await client.fetchDeferredOffer(callId: 'call-1', deviceId: 'dev-eve'),
        isNull,
      );
    });

    test('retourne null sur 410 (offre expirée)', () async {
      final mock = MockClient(
        (request) async => http.Response(
          jsonEncode({'ok': false, 'error': 'offer_expired'}),
          410,
          headers: {'content-type': 'application/json'},
        ),
      );
      client = buildClient(mock);

      expect(
        await client.fetchDeferredOffer(callId: 'call-1', deviceId: 'dev-bob'),
        isNull,
      );
    });

    test('retourne null sur 422 (device_id invalide)', () async {
      final mock = MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'validation', 'errors': {}}),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );
      client = buildClient(mock);

      expect(
        await client.fetchDeferredOffer(callId: 'call-1', deviceId: ''),
        isNull,
      );
    });

    test('retourne null sur erreur réseau (exception)', () async {
      final mock = MockClient(
        (request) async => throw http.ClientException('connexion refusée'),
      );
      client = buildClient(mock);

      expect(
        await client.fetchDeferredOffer(callId: 'call-1', deviceId: 'dev-bob'),
        isNull,
      );
    });

    test('retourne null sur réponse non-JSON', () async {
      final mock = MockClient(
        (request) async => http.Response('<html>erreur</html>', 200),
      );
      client = buildClient(mock);

      expect(
        await client.fetchDeferredOffer(callId: 'call-1', deviceId: 'dev-bob'),
        isNull,
      );
    });
  });

  group('ApiClient.signal — champ call_id', () {
    test('inclut call_id dans le body quand il est fourni (offer)', () async {
      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(() => 'https://api.example.com', client: mock);

      await client.signal(
        toDeviceId: 'dev-bob',
        fromDeviceId: 'dev-alice',
        type: 'offer',
        callId: 'call-42',
        payload: {
          'sdp': {'type': 'offer', 'sdp': 'v=0\r\n'},
        },
      );

      expect(sentBody['call_id'], 'call-42');
      expect(sentBody['type'], 'offer');
      expect(sentBody['to_device_id'], 'dev-bob');
    });

    test('omet call_id dans le body quand il est null (candidate)', () async {
      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(() => 'https://api.example.com', client: mock);

      await client.signal(
        toDeviceId: 'dev-bob',
        fromDeviceId: 'dev-alice',
        type: 'candidate',
        payload: {
          'candidate': {'candidate': 'cand'},
        },
      );

      expect(sentBody.containsKey('call_id'), isFalse);
    });

    test('omet call_id quand il est une chaîne vide', () async {
      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(() => 'https://api.example.com', client: mock);

      await client.signal(
        toDeviceId: 'dev-bob',
        fromDeviceId: 'dev-alice',
        type: 'bye',
        callId: '',
        payload: {},
      );

      expect(sentBody.containsKey('call_id'), isFalse);
    });
  });

  group('ApiClient — Nouveaux endpoints Postman KondjiPro', () {
    ApiClient buildAuthClient(MockClient mock) => ApiClient(
      () => 'https://api.example.com',
      tokenProvider: () => 'test-bearer-token',
      demoTokenProvider: () => 'test-demo-token',
      client: mock,
    );

    test(
      'healthCheck retourne true sur HTTP 200 et false sur erreur',
      () async {
        var okMock = MockClient((request) async {
          expect(request.url.toString(), 'https://api.example.com/up');
          return http.Response('OK', 200);
        });
        var client = ApiClient(() => 'https://api.example.com', client: okMock);
        expect(await client.healthCheck(), isTrue);

        var errMock = MockClient((request) async {
          return http.Response('Service Unavailable', 503);
        });
        client = ApiClient(() => 'https://api.example.com', client: errMock);
        expect(await client.healthCheck(), isFalse);
      },
    );

    test(
      'getMe transmet le token Bearer et retourne les infos utilisateur',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.com/api/v1/users/me',
          );
          expect(request.headers['Authorization'], 'Bearer test-bearer-token');
          return http.Response(
            jsonEncode({
              'data': {'id': 1, 'name': 'Demo User'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = buildAuthClient(mock);
        final res = await client.getMe();
        expect(res['data']['name'], 'Demo User');
      },
    );

    test('fetchContacts retourne la liste des contacts', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/contacts',
        );
        expect(request.headers['Authorization'], 'Bearer test-bearer-token');
        return http.Response(
          jsonEncode({
            'contacts': [
              {'id': 'c1', 'name': 'Contact 1'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.fetchContacts();
      expect(res['contacts'], isList);
    });

    test('fetchDevices retourne la liste des appareils', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/devices',
        );
        expect(request.headers['Authorization'], 'Bearer test-bearer-token');
        return http.Response(
          jsonEncode({
            'devices': [
              {'device_id': 'dev-1', 'label': 'Pixel 7'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.fetchDevices();
      expect(res['devices'], isList);
    });

    test('registerDevice enregistre un nouvel appareil via POST', () async {
      late Map<String, dynamic> bodySent;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/devices/register',
        );
        expect(request.headers['Authorization'], 'Bearer test-bearer-token');
        bodySent = jsonDecode(request.body);
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.registerDevice(
        label: 'Mon Phone',
        deviceId: 'dev-123',
        platform: 'android',
      );
      expect(res['ok'], isTrue);
      expect(bodySent['label'], 'Mon Phone');
      expect(bodySent['device_id'], 'dev-123');
      expect(bodySent['platform'], 'android');
    });

    test('deleteDevice supprime un appareil via DELETE', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/devices/dev-123',
        );
        expect(request.headers['Authorization'], 'Bearer test-bearer-token');
        return http.Response(
          jsonEncode({'ok': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.deleteDevice('dev-123');
      expect(res['ok'], isTrue);
    });

    test('getWallet consulte les infos du portefeuille', () async {
      final mock = MockClient((request) async {
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.com/api/demo/v1/wallet',
        );
        // Endpoint démo → jeton de démonstration, PAS le jeton Yam réel.
        expect(request.headers['Authorization'], 'Bearer test-demo-token');
        return http.Response(
          jsonEncode({
            'demo': true,
            'wallet': {'solde': 150000},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.getWallet();
      expect(res['demo'], isTrue);
      expect(res['wallet']['solde'], 150000);
    });

    test(
      'rechargeWallet enchaîne recharge puis confirmation (notify) en démo',
      () async {
        late Map<String, dynamic> rechargeBody;
        var calls = 0;
        final mock = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer test-demo-token');
          calls++;
          if (request.url.path.endsWith('/wallet/recharge')) {
            expect(
              request.url.toString(),
              'https://api.example.com/api/demo/v1/wallet/recharge',
            );
            expect(request.headers['Idempotency-Key'], 'idem-key-123');
            rechargeBody = jsonDecode(request.body);
            return http.Response(
              jsonEncode({
                'demo': true,
                'information': {'reference': 'REF123456'},
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          // Confirmation automatique (webhook Mobile Money simulé).
          expect(
            request.url.toString(),
            'https://api.example.com/api/demo/v1/wallet/recharge/notify',
          );
          expect(request.headers.containsKey('Idempotency-Key'), isFalse);
          final notifyBody = jsonDecode(request.body);
          expect(notifyBody['transaction_id'], 'REF123456');
          expect(notifyBody['code'], 200);
          return http.Response(
            jsonEncode({'demo': true, 'status': '000', 'credit': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = buildAuthClient(mock);
        final res = await client.rechargeWallet(
          montant: 5000,
          phoneNumber: '+22890000000',
          idempotencyKey: 'idem-key-123',
        );
        expect(calls, 2, reason: 'recharge puis confirmation automatique');
        expect(res['status'], '000', reason: 'réponse de la confirmation');
        expect(res['credit'], isTrue);
        expect(rechargeBody['montant'], 5000);
        expect(rechargeBody['phone_number'], '+22890000000');
      },
    );

    test('rechargeWallet : confirmation refusée → recharge en attente, pas '
        "d'exception", () async {
      var calls = 0;
      final mock = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/wallet/recharge')) {
          return http.Response(
            jsonEncode({
              'demo': true,
              'information': {'reference': 'REF123456'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // Le webhook simulé refuse la confirmation (ex. transaction inconnue).
        return http.Response(
          jsonEncode({'error': 'transaction_not_found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.rechargeWallet(montant: 5000);
      expect(calls, 2);
      expect(
        res['information']['reference'],
        'REF123456',
        reason: 'la recharge reste en attente, l\'appel ne lève pas',
      );
    });

    test('transferWallet transmet le jeton démo et le destinataire', () async {
      late Map<String, dynamic> bodySent;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/api/demo/v1/wallet/transfert',
        );
        expect(request.headers['Authorization'], 'Bearer test-demo-token');
        bodySent = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'demo': true,
            'information': {'reference': 'TRF123'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.transferWallet(montant: 2000, recipient: '9002');
      expect(res['demo'], isTrue);
      expect(bodySent['montant'], 2000);
      expect(bodySent['recipient'], '9002');
    });

    test('withdrawWallet transmet le jeton démo et le montant', () async {
      late Map<String, dynamic> bodySent;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/api/demo/v1/wallet/withdraw',
        );
        expect(request.headers['Authorization'], 'Bearer test-demo-token');
        bodySent = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'demo': true,
            'information': {'reference': 'WDR123'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.withdrawWallet(
        montant: 1000,
        phoneNumber: '+22890000000',
      );
      expect(res['demo'], isTrue);
      expect(bodySent['montant'], 1000);
      expect(bodySent['phone_number'], '+22890000000');
    });

    test('demoLogin ouvre une session de démonstration (visiteur)', () async {
      late Map<String, dynamic> bodySent;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/api/demo/v1/auth/login',
        );
        bodySent = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'demo': true,
            'data': {
              'token': 'demo_token_abc',
              'user': {'id': 9001},
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(() => 'https://api.example.com', client: mock);
      final res = await client.demoLogin(deviceId: 'dev-1');
      expect(res['data']['token'], 'demo_token_abc');
      expect(bodySent.containsKey('phone_number'), isFalse);
      expect(bodySent['device_id'], 'dev-1');
    });

    test(
      'demoLogin avec identifiants transmet phone_number et password',
      () async {
        late Map<String, dynamic> bodySent;
        final mock = MockClient((request) async {
          bodySent = jsonDecode(request.body);
          return http.Response(
            jsonEncode({
              'demo': true,
              'data': {'token': 't'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = ApiClient(() => 'https://api.example.com', client: mock);
        await client.demoLogin(
          phoneNumber: '+22890000000',
          password: 'secret',
          deviceId: 'dev-1',
        );
        expect(bodySent['phone_number'], '+22890000000');
        expect(bodySent['password'], 'secret');
      },
    );

    test('demoRegister crée un compte de démonstration', () async {
      late Map<String, dynamic> bodySent;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/api/demo/v1/auth/register',
        );
        bodySent = jsonDecode(request.body);
        return http.Response(
          jsonEncode({
            'demo': true,
            'data': {
              'token': 'demo_token_xyz',
              'user': {'id': 9002},
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(() => 'https://api.example.com', client: mock);
      final res = await client.demoRegister(
        name: 'Daniel',
        phoneNumber: '+22890000000',
        password: 'yam-demo-2026',
        deviceId: 'dev-1',
      );
      expect(res['data']['token'], 'demo_token_xyz');
      expect(bodySent['name'], 'Daniel');
      expect(bodySent['phone_number'], '+22890000000');
      expect(bodySent['password'], 'yam-demo-2026');
    });

    test('addContact enregistre un contact via POST /contacts', () async {
      late Map<String, dynamic> bodySent;
      final mock = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/contacts',
        );
        expect(request.headers['Authorization'], 'Bearer test-bearer-token');
        bodySent = jsonDecode(request.body);
        return http.Response(
          jsonEncode({'ok': true}),
          201,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = buildAuthClient(mock);
      final res = await client.addContact(42);
      expect(res['ok'], isTrue);
      expect(bodySent['contact_user_id'], 42);
    });

    test(
      'removeContact supprime un contact via DELETE /contacts/{id}',
      () async {
        final mock = MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(
            request.url.toString(),
            'https://api.example.com/api/v1/contacts/42',
          );
          expect(request.headers['Authorization'], 'Bearer test-bearer-token');
          return http.Response(
            jsonEncode({'ok': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = buildAuthClient(mock);
        final res = await client.removeContact(42);
        expect(res['ok'], isTrue);
      },
    );
  });
}
