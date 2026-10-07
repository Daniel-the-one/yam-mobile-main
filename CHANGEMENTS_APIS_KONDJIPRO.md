# Rapport d'implémentation — APIs KondjiPro & Yam (Collection Postman)

Ce document répertorie l'ensemble des intégrations d'APIs réalisées à partir de la collection Postman [KondjiPro API](https://raw.githubusercontent.com/Daniel-the-one/yam/master/api/postman/KondjiPro_API.postman_collection.json), ainsi que les optimisations de robustesse apportées au client HTTP de l'application mobile `yam-mobile`.

---

## 1. Endpoints Postman intégrés

### 00 — Prérequis & Diagnostics
- **`GET /up`** : Sonde de santé de l'API Laravel (`ApiClient.healthCheck()`).
- **`GET /api/v1/config`** : Récupération de la configuration runtime Pusher + TURN (`ApiClient.fetchConfig()`).
- **`GET /api/v1/debug/logs`** : Récupération des logs de débogage application (`SystemApi.debugLogs()`).

### 01 — Authentification
- **`POST /api/v1/auth/login`** : Connexion utilisateur Yam avec jeton d'authentification Bearer, identifiant d'appareil et plateforme (`ApiClient.login()`).
- **`POST /api/v1/auth/register`** : Inscription d'un nouvel utilisateur (`ApiClient.register()`).
- **`POST /api/v1/auth/logout`** : Déconnexion de l'utilisateur (`ApiClient.logout()`).
- **`POST /api/auth/login.php`** : Connexion à la session médicale PHP KondjiPro avec capture du cookie `kondjipro_session` et du jeton `csrf_token` (`KondjiproClient.login()`).

### 02 & 03 — Utilisateur, Recherche & Contacts
- **`GET /api/v1/users/me`** : Profil détaillé de l'utilisateur authentifié (`ApiClient.getMe()`).
- **`GET /api/v1/users/search?q=...`** : Recherche d'utilisateurs (`ApiClient.searchUsers()`).
- **`GET /api/v1/contacts`** : Récupération des contacts de l'utilisateur (`ApiClient.fetchContacts()`).

### 04 — Gestion des Appareils (Devices)
- **`GET /api/v1/devices`** : Liste des appareils enregistrés (`ApiClient.fetchDevices()`).
- **`POST /api/v1/devices/register`** : Enregistrement d'un nouvel appareil (`ApiClient.registerDevice()`).
- **`DELETE /api/v1/devices/{deviceId}`** : Suppression d'un appareil enregistré (`ApiClient.deleteDevice()`).

### 05 — Portefeuille (Wallet) & Paiements
- **`GET /api/demo/v1/wallet`** / **`/api/v1/wallet`** : Consultation du portefeuille (`ApiClient.getWallet()`, bascule démo/réel via `ApiConfig.moneyDemo`).
- **`POST /api/demo/v1/wallet/recharge`** / **`/api/v1/wallet/recharge`** : Recharge de portefeuille avec support de l'en-tête `Idempotency-Key` (`ApiClient.rechargeWallet()`).

---

## 2. Fichiers modifiés & créés

- **`lib/config/api_config.dart`** : Ajout centralisé de l'ensemble des constantes d'endpoints (`healthCheck`, `usersMe`, `contacts`, `devices`, `deviceRegister`, `deviceDelete`, `wallet`, `walletRecharge`).
- **`lib/services/api_client.dart`** : Implémentation des méthodes REST (`_get`, `_post`, `_delete`, `_decodeSafe`) et des nouveaux endpoints Postman.
- **`lib/services/kondjipro_client.dart`** : Maintien de la compatibilité pour les sessions PHP KondjiPro (cookies, CSRF, re-login silencieux).
- **`lib/state/app_state.dart`** : Exposition des méthodes de haut niveau pour les écrans de l'application.
- **`test/api_client_test.dart`** : Ajout de la suite de tests unitaires avec mocks HTTP pour valider chaque nouvel endpoint.

---

## 3. Améliorations de Robustesse

- **Décodage JSON sécurisé (`_decodeSafe`)** : Interception des exceptions `FormatException` lors de la réception de pages d'erreur HTML (502/503 Nginx ou Cloudflare), garantissant un message d'erreur clair et contextuel pour l'utilisateur.
- **Validation des tests unitaires** : 62 tests unitaires validés avec succès (`All tests passed!`).
