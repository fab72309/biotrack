# BioTrack - Priorite 1 (bloquants avant soumission)

Ce document couvre les actions a terminer avant une premiere soumission TestFlight externe / App Store.

## Identifiants (deja patches dans le projet)

Les placeholders `com.example.*` ont ete remplaces par:

- App iOS: `com.fabienlopes.biotrack`
- Widget extension: `com.fabienlopes.biotrack.widget`
- App Group: `group.com.fabienlopes.biotrack`

Si tu veux utiliser un autre namespace (ex. domaine perso / societe), change ces valeurs **avant** de creer les App IDs et profils dans Apple Developer.

## Apple Developer (manuel)

1. Créer l'App Group
- `group.com.fabienlopes.biotrack`

2. Créer / verifier les App IDs
- `com.fabienlopes.biotrack`
- `com.fabienlopes.biotrack.widget`

3. Activer les capabilities necessaires
- App principale:
  - HealthKit
  - App Groups (avec `group.com.fabienlopes.biotrack`)
- Widget extension:
  - App Groups (avec `group.com.fabienlopes.biotrack`)

4. Regenerer les profils de provisioning (si signature automatique inactive)

## Xcode (manuel)

1. Ouvrir le target app `BioTrack`
- `Signing & Capabilities`:
  - choisir la bonne Team
  - verifier `Bundle Identifier = com.fabienlopes.biotrack`
  - verifier HealthKit
  - verifier App Group

2. Ouvrir le target widget `BioTrackWidgetExtension`
- `Signing & Capabilities`:
  - verifier `Bundle Identifier = com.fabienlopes.biotrack.widget`
  - verifier App Group

3. Build sur iPhone reel (pas seulement simulateur)
- verifier HealthKit + widget + notifications

## URLs publiques (manuel, obligatoire pour App Store Connect)

Pages preparees dans `docs/`:

- `docs/privacy-policy.html`
- `docs/support.html`
- `docs/index.html`

Actions:

1. Completer les placeholders de contact dans `docs/support.html`
2. Heberger `docs/` en HTTPS (GitHub Pages / site perso / autre)
3. Verifier publiquement les URLs:
   - `https://.../privacy-policy.html`
   - `https://.../support.html`

Recommande:

- Ajouter aussi `Marketing URL` (`https://.../`)

## App Store Connect - App Privacy (manuel)

Preparer les reponses en les alignant avec le comportement reel de l'app:

- Donnees stockees localement sur l'appareil
- Pas de compte / pas de backend BioTrack (selon l'etat actuel du projet)
- Donnees Sante utilisees localement apres consentement
- Notifications locales (rappels)
- Export manuel initie par l'utilisateur
- Pas de tracking publicitaire (si aucun SDK tiers n'en fait)

Important:

- Les reponses App Privacy doivent rester coherentes avec la policy publiee et l'app (permissions, HealthKit, export).

## Export compliance (manuel)

Le projet utilise du chiffrement via `CryptoKit` (export sauvegarde chiffré).

Actions:

1. Prevoir de repondre aux questions "Encryption / Export Compliance" lors de l'upload
2. Conserver une description simple du cas d'usage:
   - chiffrement de sauvegarde locale initie par l'utilisateur
   - pas de messagerie / VPN / chiffrement custom reseau
3. Repondre avec precision dans App Store Connect (et verifier si exemption applicable)

Note:

- Ne reponds pas "au hasard". C'est un point de conformite.

## Definition of done (Priorite 1)

- IDs Apple Developer crees et capabilities actives
- Signing Xcode OK sur app + widget
- Privacy Policy URL HTTPS publique fonctionnelle
- Support URL HTTPS publique fonctionnelle
- App Privacy renseignee dans App Store Connect
- Strategie/answers export compliance prepares
