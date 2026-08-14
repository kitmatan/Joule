# Joule ⚡️

A modern EV charging log and longitudinal battery health tracker for iOS, iPadOS, and macOS (Mac Catalyst), built with SwiftUI, Swift Charts, Google Sign-In, and Cloud Firestore.

Tuned with out-of-the-box specifications for the **AION V 602 Luxury** (Magazine Battery 2.0 LFP) with customizable vehicle and tariff profiles.

---

## ✨ Features

- 📊 **Comprehensive Dashboard**:
  - Monthly stats (Cost, Energy, Average monthly costs).
  - Driving efficiency calculations (km/kWh, ฿/km, average charging speed).
  - Interactive Swift Charts (Monthly Cost breakdown, Stacked AC/DC energy, Charging speed trends).
  - Top charging locations with per-unit price analysis.
  
- 🔋 **Battery Health & Longitudinal Analytics**:
  - State of Health (SoH) and usable capacity (kWh) estimation per session with confidence weighting.
  - Least-squares linear regression modeling for degradation rates per 10,000 km and per year.
  - 4 interactive charts: SoH over Time, SoH vs. Mileage, Projected 100% Range, and Cycle Wear vs. LFP Benchmark.
  - Chemistry-specific battery care advisories.

- 📜 **Session History & Management**:
  - Grouped chronologically by month with monthly totals.
  - Multi-criteria filters: AC, DC, Home, Public, and Deferred Payments.
  - Full-text search by location, vendor, and notes.
  - Deletion safety with confirmation dialogs.

- ⚡️ **Smart Charging Form**:
  - Auto-estimates home AC charging based on SoC delta ($\Delta\text{SoC}$) and residential tariffs.
  - Support for Thailand PEA/MEA tariffs (Standard Non-TOU, TOU Peak, TOU Off-Peak, Custom).
  - Smart speed handling and inline validation.

- 📁 **CSV Import & Export**:
  - Export entire charging history to standard CSV for backup or external analysis.
  - Resilient importer with header mapping and sanitized number parsing.

- ☁️ **Cloud Sync & Privacy**:
  - Authenticates with Google Sign-In.
  - Scoped per-user Firestore database rules (`/users/{uid}/sessions`).

---

## 🛠️ Requirements & Setup

- **Xcode 15+** (iOS 17.0+ / macOS 14.0+ deployment target)
- **XcodeGen**: `brew install xcodegen`

### Generating the Project
Generate the `.xcodeproj` from `project.yml`:
```bash
xcodegen generate
```

### Firebase Setup
Follow the steps in [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to:
1. Configure Google Sign-In and download `GoogleService-Info.plist`.
2. Deploy Firestore security rules (`firestore.rules`).

---

## 📄 License
MIT License
