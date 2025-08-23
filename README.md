# BioTrack (MVP) — iOS SwiftUI Skeleton

Skeleton iOS app for **BioTrack**, a biohacking tracker focused on checklists, metrics, stats, protocols and supplements.  
This repo is designed to be minimal, privacy-first (local storage), and **XcodeGen**-driven for easy project generation.

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

## What’s inside

- SwiftUI Tabs: **Checklist**, **Track**, **Stats**, **Protocols**, **Supplements**
- Local JSON storage (Documents directory) via `LocalStore`
- Notifications stub via `NotificationService`
- HealthKit stub (sleep/steps read; mindfulness/nutrition write) via `HealthKitService`
- CSV export via `ExportService`
- FR/EN localization via `Localizable.strings`
- App privacy-first: no accounts, no servers

> Note: This is a **skeleton**—safe stubs & minimal logic are included to compile and demonstrate architecture. You can iterate quickly from here.

## Targets

- iOS 15+ (SwiftUI)
- HealthKit is optional; enable capability in Signing & Capabilities if you need actual reads/writes.

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

## CI (optional)

A lightweight GitHub Actions workflow (`ios-ci.yml`) builds the app on macOS with XcodeGen.

## Privacy

All data remain **on device**. Health data access (if enabled) requires explicit user permission. See `PrivacyPolicy.md` (simplified) and Info.plist usage descriptions.

## License

MIT
