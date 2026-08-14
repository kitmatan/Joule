# Joule ⚡️

A modern EV charging log and longitudinal battery health tracker for iOS, iPadOS, and macOS (Mac Catalyst), built with SwiftUI, Swift Charts, Google Sign-In, and Cloud Firestore.

Supports **any electric vehicle (EV)** out of the box with an extensive built-in library of popular vehicle presets (BYD, Tesla, MG, Hyundai, Kia, Volvo, Deepal, ORA, BMW, GAC AION, etc.) and complete custom vehicle configuration.

---

## 📱 App Screenshots

<div align="center">

| **Dashboard Analytics** | **Battery Health Tracker** | **Session History** |
| :---: | :---: | :---: |
| <img src="screenshots/01_dashboard.png" width="280" alt="Dashboard" /> | <img src="screenshots/02_battery_health.png" width="280" alt="Battery Health" /> | <img src="screenshots/03_session_history.png" width="280" alt="Session History" /> |

| **Session Details** | **Smart Charging Form** | **Vehicle Presets & Settings** |
| :---: | :---: | :---: |
| <img src="screenshots/04_session_detail.png" width="280" alt="Session Detail" /> | <img src="screenshots/05_add_session.png" width="280" alt="Add Session" /> | <img src="screenshots/07_ev_presets.png" width="280" alt="EV Presets" /> |

</div>

---

## ✨ Features

- 🚗 **Universal EV & Battery Chemistry Support**:
  - **EV Preset Library**: One-tap configuration for popular EVs across global brands (BYD Atto 3 / Dolphin / Seal, Tesla Model 3 / Y, MG4 / ZS EV, Hyundai Ioniq 5 / 6, Kia EV5 / EV6, Volvo EX30 / EX40, Deepal S07, ORA Good Cat, GAC AION V / Y, BMW i4 / iX3, etc.).
  - **Chemistry-Aware Analytics**: Tailored algorithms for **LFP** (Blade / Magazine / Lithium Iron Phosphate), **NMC/NCM** (Nickel Manganese Cobalt), **NCA**, and Custom chemistries.
  - **Custom EV Profile**: Freely customize nominal pack capacity, rated range, range testing cycles (WLTP, NEDC, CLTC, EPA), chemistry, expected cycle life to 80% SoH, and AC onboard charger limits.

- 📊 **Comprehensive Dashboard**:
  - Monthly stats (Cost, Energy, Average monthly costs).
  - Driving efficiency calculations (km/kWh, ฿/km, average charging speed).
  - Interactive Swift Charts (Monthly Cost breakdown, Stacked AC/DC energy, Charging speed trends).
  - Top charging locations with per-unit price analysis.
  
- 🔋 **Battery Health & Longitudinal Analytics**:
  - State of Health (SoH) and usable capacity (kWh) estimation per session with confidence weighting.
  - Least-squares linear regression modeling for degradation rates per 10,000 km and per year.
  - 4 interactive charts: SoH over Time, SoH vs. Mileage, Projected 100% Range (dynamic scaling), and Cycle Wear vs. Chemistry Benchmark.
  - Chemistry-specific battery care advisories (e.g., LFP periodic 100% cell balancing vs. NMC 80% daily charge limits).

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

- 📱 **Offline-First & Cloud Sync**:
  - **Zero-Friction Launch**: Start logging charges immediately in Local Mode without creating an account or logging in.
  - **Local Persistence**: All data is saved instantly to on-device storage, functioning seamlessly in offline environments (e.g. underground parking garages).
  - **Seamless Cloud Sync**: Sign in with Google anytime from Settings to back up and sync across iPhone, iPad, and Mac. Existing local sessions automatically merge into your cloud account.

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
