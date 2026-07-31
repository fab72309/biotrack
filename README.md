# BioTrack — suivi personnel privé sur iOS

[![iOS CI](https://github.com/fab72309/biotrack/actions/workflows/ios-ci.yml/badge.svg)](https://github.com/fab72309/biotrack/actions/workflows/ios-ci.yml)

BioTrack est une application SwiftUI de suivi personnel centrée sur les routines, métriques, check-ins, protocoles et suppléments. Les données restent sur l’appareil, sans compte ni backend BioTrack.

La version 1.1.0 renforce la fiabilité des associations temporelles, améliore les comparaisons entre unités différentes et rend les graphiques, légendes et périodes sans mesure plus explicites. BioTrack comprend aussi des expériences N-of-1, HealthKit en lecture, des widgets, les Live Activities et des sauvegardes chiffrées.

## Quickstart

1. Install Xcode 15+ (iOS target 15.0+).
2. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen):  
   ```bash
   brew install xcodegen
   ```
3. Generate the Xcode project:
   ```bash
   xcodegen generate
   open BioTrack.xcodeproj
   ```
4. Build & run the **BioTrack** scheme on an iPhone Simulator.

## Fonctionnalités

- checklist quotidienne, rappels locaux et profils de routine ;
- métriques personnalisées et check-ins matin/soir ;
- lecture HealthKit facultative : sommeil, pas, poids, fréquence cardiaque au repos et HRV ;
- graphiques multi-séries accessibles et filtres par période ;
- associations Pearson/Spearman contrôlées pour la tendance et l’autocorrélation, avec intervalle de confiance et correction des comparaisons multiples ;
- protocoles, suppléments et expériences N-of-1 ;
- widget, Live Activity, export CSV/JSON et sauvegarde chiffrée.

## Targets

- iOS 15+ pour l’app principale ;
- iOS 17+ pour le widget et la Live Activity ;
- HealthKit est facultatif et utilisé en lecture uniquement.

## Project structure

```
BioTrack-MVP/
├─ BioTrack/
│  ├─ Models/
│  ├─ Services/
│  ├─ ViewModels/
│  ├─ Views/
│  │  └─ Components/
│  └─ Resources/
│     ├─ en.lproj/
│     └─ fr.lproj/
├─ .github/workflows/ios-ci.yml
├─ project.yml
└─ README.md
```

## Validation

Le schéma `BioTrack` contient les tests unitaires du moteur statistique. La CI GitHub reconstruit l’app sur simulateur.

```bash
xcodebuild \
  -project BioTrack.xcodeproj \
  -scheme BioTrack \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test
```

Le test de fumée statistique peut aussi s’exécuter sans simulateur en compilant [Scripts/CorrelationSmoke.swift](Scripts/CorrelationSmoke.swift) avec les modèles et services associés.

## Landing page (marketing)

This repo also includes a standalone landing + waitlist server in `landing/`.

```bash
cd landing
npm run dev
```

The landing includes SEO/AEO metadata, legal pages, waitlist form (`POST /api/leads`), double opt-in confirmation, and analytics events (`POST /api/events`).

## Confidentialité et sécurité

Les données restent **sur l’appareil**. Le fichier local utilise la protection des fichiers iOS et est exclu des sauvegardes iCloud. HealthKit nécessite un consentement explicite et n’est jamais utilisé pour la publicité. Les résultats statistiques sont exploratoires et ne constituent ni un diagnostic ni un conseil médical.

Les pages publiques destinées aux stores se trouvent dans `docs/` et sont publiées par GitHub Pages.

## License

MIT
