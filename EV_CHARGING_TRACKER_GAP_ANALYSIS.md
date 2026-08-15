# EV Charging Tracker & Battery Analytics: Market Competitive Review & Gap Analysis for Joule ⚡️

**Document Version:** 1.0.0  
**Target Application:** Joule (iOS, iPadOS, macOS)  
**Scope:** Competitive feature review of top EV charging, tracking, and battery health apps across the Apple App Store and Google Play Store, detailed feature gap analysis, and prioritized product recommendations.

---

## 1. Executive Summary

The Electric Vehicle (EV) companion and charging tracker software market across the Apple App Store and Google Play Store has evolved into several distinct application archetypes:
1. **Cloud Telemetry & Automated Loggers** (e.g., *Tessie*, *TRONITY*, *EEVEE Mobility*, *TezLab*) that connect to vehicle cloud APIs to automatically ingest charging sessions, trips, and degradation data.
2. **Battery Diagnostic & Health Platforms** (e.g., *Recurrent Auto*, *Car Scanner ELM OBD2*, *LeafSpy*, *EV Watchdog*) focusing on State of Health (SoH), cell degradation, and resale certificates.
3. **Smart Charging & Utility Optimization Apps** (e.g., *Optiwatt*, *ev.energy*, *Jedlix*) centered on Time-of-Use (TOU) tariff optimization, home charger scheduling, and grid incentives.
4. **General Vehicle & Fleet Management Loggers** (e.g., *Fuelio*, *Drivvo*, *Simply EV*) offering manual logging for total cost of ownership (TCO), fuel/energy logs, and service reminders.
5. **Route Planners & Public Station Aggregators** (e.g., *A Better Routeplanner (ABRP)*, *PlugShare*, *ChargePoint*).

### Joule's Current Strategic Positioning
**Joule** occupies a strong niche: a **privacy-first, zero-subscription, local-first, universal EV charging log and longitudinal battery health tracker** built natively with SwiftUI and Swift Charts. Its core strengths lie in its **chemistry-aware degradation modeling** (tailored for LFP, NMC, NCA chemistries), **rich multi-currency and regional tariff presets** (Thailand PEA/MEA, US, UK, EU), **gas vs. EV savings financial analytics**, and **built-in universal vehicle presets**.

This document outlines the market landscape, compares Joule against top competitors across 8 functional pillars, identifies key gaps, and provides an actionable roadmap for Joule's continued development.

---

## 2. Competitive Landscape: App Store & Google Play Store

### 2.1 Overview of Major Competitors

| Competitor | Primary Platform(s) | Connection Method | Pricing Model | Primary Target Audience |
| :--- | :--- | :--- | :--- | :--- |
| **Joule** | iOS, iPadOS, macOS | Manual + Smart Form Auto-Estimation (Offline-first / Firestore) | **100% Free & Open Source** | Multi-brand EV owners wanting privacy, battery health tracking, and zero subscription costs |
| **Tessie** | iOS, Android, watchOS, Web | Tesla Fleet Cloud API | ~$4.99/mo, $49.99/yr, or $199 Lifetime | Tesla owners seeking automated tracking, automation, battery health, and Apple Watch/Siri integration |
| **TRONITY** | iOS, Android, Web | Multi-OEM Cloud APIs (Tesla, BMW, Audi, VW, Kia, etc.) | ~€4.99/mo or €49.99/yr | European & global multi-OEM EV drivers wanting automated tracking and tax-compliant reimbursement |
| **EEVEE Mobility** | iOS, Android, Web | Multi-OEM Cloud APIs | Free tier / Pro €13/mo or €130/yr | Company car drivers and fleet owners tracking home vs. public charging costs for employer reimbursement |
| **Recurrent Auto** | Web Application / Cloud | Cloud Telemetry (Tesla, Ford, GM, BMW, etc.) | Free for drivers (Monetized via B2B dealerships & resale) | EV owners tracking battery health over time and generating certified battery resale reports |
| **Optiwatt** | iOS, Android, Web | Cloud Telemetry + Smart Home Chargers | Free (Monetized via utility demand response / grid programs) | US EV owners focused on automated utility rate scheduling and maximizing cost savings |
| **TezLab** | iOS, Android, watchOS | Tesla & Rivian Cloud APIs | Freemium (Pro ~$3.99–$5.99/mo) | Tech-forward Tesla & Rivian owners who enjoy social leaderboards, badges, and trip telemetry |
| **Car Scanner ELM OBD2** | iOS, Android | Hardware (OBD-II Bluetooth / Wi-Fi Adapter) | Free / Pro one-time ($5–$10) | Enthusiasts needing real-time BMS data (cell voltages, temperatures, raw CAN-bus PIDs) |
| **Drivvo / Fuelio** | iOS, Android | Manual Logging + GPS trip tracking | Freemium / ~$1–$3/mo Pro | Drivers managing all vehicle expenses (fuel/energy, maintenance, insurance, financing) in one app |
| **A Better Routeplanner (ABRP)** | iOS, Android, CarPlay, Android Auto, Web | Cloud API / OBD-II / Manual | Freemium / Premium €5/mo | Long-distance EV road-trippers planning charging stops with weather, elevation, and live SoC |

---

### 2.2 Deep-Dive Competitor Profiles

#### 1. Tessie (App Store: 4.8 ★ | Google Play: 4.7 ★)
- **Key Functionality:** Automated continuous 24/7 background logging of charging, driving, idle phantom drain, and climate usage.
- **Battery Health:** Longitudinal battery degradation curve comparing current capacity against the global Tessie fleet.
- **Cost Tracking:** Configurable rates per charging location, automated Supercharger cost synchronization, and CSV export.
- **Ecosystem:** Rich Apple Watch app, interactive iOS Home Screen & Lock Screen widgets, Siri Shortcuts, and Webhook/API access.
- **Weaknesses / Limitations:** **Exclusively locked to Tesla**; high recurring subscription fee; requires handing over Tesla credentials to third-party cloud.

#### 2. TRONITY (App Store: 4.4 ★ | Google Play: 4.2 ★)
- **Key Functionality:** Hardware-free multi-brand cloud connectivity across 20+ EV manufacturers (Tesla, Volkswagen, Audi, Porsche, BMW, Mercedes-Benz, Hyundai, Kia, Renault, Stellantis).
- **Charging & Reimbursement:** Automatic session detection, dynamic electricity pricing (day-ahead rates), and automated monthly employer reimbursement PDF reports for home charging.
- **Battery Analytics:** Community-wide battery degradation benchmarking ("virtual fleet" comparison).
- **Integrations:** Direct export to Home Assistant, A Better Routeplanner (ABRP), and Apple CarPlay.
- **Weaknesses / Limitations:** Relies on OEM API stability (frequent disconnects when OEMs alter API policies); monthly/annual subscription; requires persistent cloud account.

#### 3. EEVEE Mobility (App Store: 4.5 ★ | Google Play: 4.3 ★)
- **Key Functionality:** Automated multi-OEM charging cost tracker specifically tailored for corporate and private reimbursement.
- **Cost Management:** Categorization of home, work, and public charging with location-based automated cost attribution.
- **Reporting:** Export of employer-ready PDF and Excel expense receipts.
- **Weaknesses / Limitations:** Limited battery health analytics; steep subscription price for Pro features (€130/year); dependent on supported OEM APIs.

#### 4. Recurrent Auto (Web App / API)
- **Key Functionality:** Specializes almost exclusively in **EV Battery Health & Range Analytics**.
- **Battery Insights:** Generates a standardized "Recurrent Battery Report" (similar to a CARFAX score for EV batteries).
- **Algorithms:** Models range variation by weather/temperature, historical charging speeds (DC fast charge ratio vs. AC), and compares degradation against thousands of identical vehicle models in its dataset.
- **Weaknesses / Limitations:** No native mobile app (primarily web-based); lacks granular day-to-day session cost logging and receipts; heavily dependent on cloud telemetry connections.

#### 5. Optiwatt (App Store: 4.6 ★ | Google Play: 4.4 ★)
- **Key Functionality:** Automatic smart charging schedule builder linked to over 1,000+ utility rate plans across North America.
- **Cost Analytics:** Tracks exact electricity costs based on real-time peak/off-peak rates and calculates lifetime gas savings vs. ICE vehicles.
- **Weaknesses / Limitations:** Primarily focused on North America; limited vehicle diagnostic or battery degradation tools; requires linking vehicle and utility accounts.

#### 6. Car Scanner ELM OBD2 / LeafSpy / EV Watchdog (App Store: 4.7 ★ | Google Play: 4.8 ★)
- **Key Functionality:** Connects directly to the car's OBD-II CAN-bus via a Bluetooth/Wi-Fi hardware dongle.
- **Battery Health:** Unlocks raw BMS data: individual cell voltages (e.g. min/max cell delta in mV), battery pack internal resistance, real-time coolant temperatures, and manufacturer factory State of Health (SoH) registers.
- **Weaknesses / Limitations:** High technical barrier to entry; requires physical OBD-II adapter hardware; no automated cloud logging; rudimentary UI design for long-term historical cost trends.

#### 7. Drivvo & Fuelio (App Store: 4.6 ★ | Google Play: 4.7 ★)
- **Key Functionality:** Comprehensive vehicle expense and maintenance loggers with added EV/Hybrid energy logging capabilities.
- **Features:** Total Cost of Ownership (TCO) tracking including insurance, tires, maintenance schedules, financing, registration, and tolls.
- **Weaknesses / Limitations:** Generic ICE-centric architecture retrofitted for EVs; lacks battery chemistry awareness, SoH calculations, SoC delta auto-estimation, and charging curve metrics.

---

## 3. Comprehensive Feature Comparison Matrix

The table below benchmarks **Joule** against the major market solutions across 8 key functional dimensions:

| Functional Area | Feature / Capability | Joule ⚡️ | Tessie | TRONITY | EEVEE | Recurrent | Optiwatt | Car Scanner (OBD2) | Fuelio / Drivvo |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Session Ingestion** | Manual Entry with Smart Auto-Estimation ($\Delta\text{SoC}$) | ✅ **Yes** | ❌ (Manual only fallback) | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ Basic Manual |
| | Cloud Telemetry (Zero-Click Auto Ingest) | ❌ No | ✅ Tesla only | ✅ Multi-OEM | ✅ Multi-OEM | ✅ Multi-OEM | ✅ Multi-OEM | ❌ | ❌ |
| | Hardware OBD-II CAN-Bus Live Reading | ❌ No | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ Yes (Dongle) | ❌ |
| | OCR / Photo Scanning (Receipt / Meter Screen) | ❌ No | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ Receipt Attach |
| | Offline-First (No Internet required to log) | ✅ **100% Native** | ❌ Requires Cloud | ❌ Requires Cloud | ❌ Requires Cloud | ❌ Requires Cloud | ❌ Requires Cloud | ✅ Yes | ✅ Yes |
| **Battery Health Analytics** | Longitudinal State of Health (SoH) Estimation | ✅ **Yes** | ✅ Yes | ✅ Yes | ⚠️ Basic | ✅ **Advanced** | ❌ | ✅ Raw BMS | ❌ |
| | Chemistry-Aware Modeling (LFP vs. NMC vs. NCA) | ✅ **Yes (Unique)** | ⚠️ Limited | ❌ | ❌ | ⚠️ Backend only | ❌ | ❌ (Raw data) | ❌ |
| | Least-Squares Linear Regression (Rate/10k km & Year) | ✅ **Yes** | ✅ Yes | ⚠️ Basic | ❌ | ✅ Yes | ❌ | ❌ | ❌ |
| | Projected 100% Usable Range Tracking | ✅ **Yes** | ✅ Yes | ✅ Yes | ⚠️ Basic | ✅ Yes | ❌ | ⚠️ Live only | ❌ |
| | Cell-Level Diagnostics (Cell Delta mV, Temp, Resistance) | ❌ No | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ **Yes** | ❌ |
| | Resale Condition Certificate / Exportable Health Card | ⚠️ Visual Card | ⚠️ Basic | ⚠️ Diagnostics | ❌ | ✅ **Certified** | ❌ | ❌ | ❌ |
| **Cost & Tariffs** | Regional Tariff Presets (Thailand PEA/MEA, US, UK, EU) | ✅ **Yes (Built-in)**| ⚠️ Custom | ⚠️ Dynamic EU | ⚠️ Custom | ❌ | ✅ US 1000+ | ❌ | ⚠️ Custom |
| | Time-of-Use (TOU) Peak / Off-Peak Calculation | ✅ **Yes** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ | ✅ **Advanced** | ❌ | ⚠️ Basic |
| | Multi-Currency Support with Auto-Formatting (14+ Currencies)| ✅ **Yes** | ⚠️ Limited | ⚠️ EUR/USD | ⚠️ EUR/USD | ❌ | ⚠️ USD only | ❌ | ✅ Yes |
| | Employer Reimbursement / Tax PDF Report Generation | ❌ (CSV only) | ⚠️ CSV only | ✅ **PDF Report** | ✅ **PDF Report** | ❌ | ❌ | ❌ | ⚠️ Basic Report |
| **Driving & Efficiency** | Real-World Driving Efficiency (km/kWh, kWh/100km, mi/kWh) | ✅ **Yes** | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ Est. | ⚠️ Est. | ✅ Raw Live | ✅ Yes |
| | Gas vs. EV Savings Comparative Engine | ✅ **Yes (Built-in)**| ⚠️ Basic | ⚠️ Basic | ⚠️ Basic | ⚠️ Basic | ✅ Yes | ❌ | ⚠️ Fuel compare |
| | Fuel Avoided & Running Cost per Distance Unit | ✅ **Yes** | ⚠️ Basic | ❌ | ❌ | ❌ | ⚠️ Basic | ❌ | ⚠️ Basic |
| | Phantom Drain / Idle Standby Loss Tracking | ❌ No | ✅ **Yes** | ✅ Yes | ⚠️ Basic | ❌ | ❌ | ❌ | ❌ |
| | Elevation / Weather Temperature Correlation | ❌ No | ⚠️ Basic | ⚠️ Basic | ❌ | ✅ **Yes** | ❌ | ⚠️ Live sensors | ❌ |
| **Vehicle & Preset Management** | Universal EV Preset Library (BYD, Tesla, MG, Hyundai, etc.)| ✅ **Yes (Extensive)**| ❌ (Tesla only) | ⚠️ Connected only | ⚠️ Connected only | ⚠️ Connected only | ⚠️ Connected only | ⚠️ OBD PIDs | ❌ (Generic) |
| | Multi-Vehicle Garage Management (Switching Profiles) | ✅ **Yes (Full Multi-Vehicle Garage)** | ⚠️ Multi-Tesla | ✅ Multi-car | ✅ Multi-car | ✅ Multi-car | ✅ Multi-car | ✅ Profiles | ✅ **Multi-vehicle** |
| | Total Cost of Ownership (Insurance, Tires, Service, Taxes)| ❌ No | ❌ | ⚠️ Fixed costs | ❌ | ❌ | ❌ | ❌ | ✅ **Comprehensive**|
| **User Experience & Ecosystem** | Apple Platforms (iOS, iPadOS, macOS Catalyst) | ✅ **Yes** | ✅ iOS/watchOS/Web | ✅ iOS/Android/Web | ✅ iOS/Android/Web | ⚠️ Web only | ✅ iOS/Android | ✅ iOS/Android | ✅ iOS/Android |
| | Android Native Support (Google Play Store) | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes | ⚠️ Web | ✅ Yes | ✅ Yes | ✅ Yes |
| | Live Activities / Dynamic Island Charging Progress | ❌ No | ✅ Yes | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| | Apple Watch App & Home/Lock Screen Widgets | ❌ No | ✅ **Yes** | ⚠️ Widgets | ⚠️ Widgets | ❌ | ❌ | ❌ | ⚠️ Widgets |
| | Interactive Charts with Tooltips & Toggles (Swift Charts) | ✅ **Yes** | ✅ Yes | ✅ Yes | ⚠️ Basic | ✅ Yes | ⚠️ Basic | ⚠️ Live Gauges | ⚠️ Basic |
| **Privacy & Licensing** | Zero Mandatory Account / Anonymous Local Mode | ✅ **Yes** | ❌ Mandatory | ❌ Mandatory | ❌ Mandatory | ❌ Mandatory | ❌ Mandatory | ✅ Yes | ⚠️ Account optional|
| | Pricing Model | **Free / MIT** | $4.99/mo | €4.99/mo | €13/mo | Free (Data) | Free (Data) | $5–$10 one-time | $1–$3/mo |

---

## 4. Deep-Dive Gap Analysis: Joule vs. Market Competitors

```mermaid
quadrantChart
    title EV Tracking Solutions: Automation vs. Privacy & Battery Intelligence
    x-axis Low Privacy / Cloud-Dependent --> High Privacy / Local-First
    y-axis Basic / Cost-Only Analytics --> Advanced Battery Health & Chemistry
    quadrant-1 Specialized Local Analytics (Joule Opportunity)
    quadrant-2 Niche Diagnostic Tools (Car Scanner)
    quadrant-3 Commercial Telemetry SaaS (Tessie, Tronity, EEVEE)
    quadrant-4 Basic Expense Loggers (Drivvo, Fuelio)
    "Joule": [0.88, 0.78]
    "Tessie": [0.25, 0.82]
    "TRONITY": [0.22, 0.65]
    "EEVEE": [0.18, 0.40]
    "Recurrent": [0.30, 0.85]
    "Optiwatt": [0.20, 0.35]
    "Car Scanner OBD2": [0.85, 0.90]
    "Drivvo / Fuelio": [0.70, 0.25]
```

### 4.1 Joule's Key Differentiators & Competitive Moats

1. **True Privacy & Zero-Friction Local-First Architecture:**
   - Most competitors (Tessie, TRONITY, EEVEE, Optiwatt) mandate creating a cloud account and granting access to the vehicle's OEM API credentials. If the OEM changes its API pricing or revokes third-party access (as seen with Tesla's Fleet API pricing and various European OEM changes), these services break or pass high costs to users.
   - Joule works **100% offline out-of-the-box** with on-device persistence. Google Sign-In and Firestore backup are completely optional.

2. **Chemistry-Aware Degradation Intelligence:**
   - While competitors treat every EV battery as a generic lithium pack, Joule specifically differentiates between **LFP** (Lithium Iron Phosphate / BYD Blade / GAC Magazine), **NMC/NCM**, and **NCA** chemistries.
   - Joule adjusts degradation curves, confidence ratings based on $\Delta\text{SoC}$, expected cycle life (e.g. 3,000 cycles for LFP vs. 1,500 for NMC), and dynamically serves chemistry-specific care advisories (e.g. weekly 100% calibration for LFP to balance cell voltage vs. 80% daily ceiling for NMC).

3. **Global Multi-Region Tariff & Smart Presets:**
   - Pre-configured tariff structures for Southeast Asia (Thailand PEA/MEA TOU Peak/Off-Peak/Standard), North America, UK (Octopus Agile style overnight rates), and Europe, alongside custom user tariffs and multi-currency formatting.

4. **Gas vs. EV Comparative Financial Engine:**
   - Built-in baseline comparison supporting multiple vehicle classes (Compact, Mid-Size SUV, Full-Size SUV/Truck, Custom) with real-time fuel avoided calculations and running cost differentials ($/mi or ฿/km).

5. **No Subscriptions / 100% Open Source:**
   - Provides premium-grade analytics without charging $50–$150/year.

---

### 4.2 High-Impact Functional Gaps in Joule

#### 1. Ingestion Automation & Zero-Click Experience
- **Competitor Benchmark:** Tessie, TRONITY, and EEVEE automatically log charging sessions the moment the car is plugged in. Users do not need to open the app.
- **Joule's Current State:** Manual form entry, aided by the Smart $\Delta\text{SoC}$ calculation.
- **Impact:** Manual data entry friction remains the primary reason users abandon manual tracking apps.

#### 2. Receipt, Meter & Dashboard Screen OCR Scanning
- **Competitor Benchmark:** Apps like Fuelio, Drivvo, and various expense trackers allow users to snap a photo of the receipt or charging dispenser screen to parse kWh, cost, and duration automatically via on-device Vision/OCR.
- **Joule's Current State:** All numbers must be entered by hand.
- **Impact:** A camera-based receipt/screen scanner would reduce input time by 80% without sacrificing privacy.

#### 3. Live Activities, Dynamic Island & Apple Watch Integration
- **Competitor Benchmark:** Tessie and native OEM apps provide a Live Activity on iOS Lock Screen and Dynamic Island displaying real-time charging status, current kW speed, time remaining to target SoC, and battery percentage.
- **Joule's Current State:** No WidgetKit extensions, Live Activities, or watchOS target.
- **Impact:** High user delight feature for iOS users who want a quick glance while charging at public stations or home.

#### 4. Employer Reimbursement & Tax-Compliant PDF Reports
- **Competitor Benchmark:** TRONITY and EEVEE Mobility dominate the European corporate car market because they generate official, branded PDF expense reports for home charging reimbursement.
- **Joule's Current State:** Exports raw CSV data only.
- **Impact:** Users who need to submit home electricity bills to employers for charging reimbursement must manually format spreadsheets.

#### 5. Multi-Vehicle Garage Support [IMPLEMENTED ✅]
- **Competitor Benchmark:** Drivvo, Fuelio, TRONITY, and Tessie allow managing multiple vehicles under a single account/app instance (e.g. Family EV 1 + Family EV 2).
- **Joule's Implementation:** Fully implemented via `Vehicle` model and multi-vehicle collection in `SessionStore`. Features top-bar `GarageSwitcherMenu` ("All Vehicles" + per-car switching), `GarageManagementView` with CRUD operations and default profile selection, `VehicleEditorView` with preset catalog picker, per-vehicle battery health diagnostics, custom home tariffs, gas baseline comparisons, local JSON caching, and live Cloud Firestore synchronization.
- **Status:** **Completed & Verified** (Full unit test coverage in `GarageTests.swift`).

#### 6. Total Cost of Ownership (TCO) & Maintenance Tracking
- **Competitor Benchmark:** Drivvo and Fuelio track maintenance (tire rotations, brake fluid, cabin air filter, 12V auxiliary battery replacement), insurance, registration fees, and tolls to calculate the full TCO.
- **Joule's Current State:** Focused exclusively on charging energy and charging costs.
- **Impact:** Misses the broader fleet/ownership expense tracking picture.

#### 7. Ambient Weather & Temperature Normalization
- **Competitor Benchmark:** Recurrent Auto and ABRP adjust degradation and range estimations based on ambient temperature (cold weather lithium sluggishness vs. hot weather degradation).
- **Joule's Current State:** SOH calculations assume nominal operating temperature without ambient weather adjustments.
- **Impact:** Capacity estimations during extreme cold or heat can show temporary variance.

---

### 4.3 Platform & Technical Gaps

1. **Android Native Version:**
   - Over 60% of global EV drivers outside North America (particularly in Asia and Europe) use Android devices. Joule is currently an Apple-exclusive SwiftUI application (iOS, iPadOS, macOS Catalyst).
2. **Hardware OBD-II BLE Dongle Support:**
   - Dedicated EV diagnostic apps (Car Scanner ELM OBD2, LeafSpy) read BMS registers directly via Bluetooth Low Energy (BLE). Joule has no BLE peripheral communication layer.
3. **Location-Based Geofencing / CoreLocation:**
   - Competitors automatically detect when the user is at "Home", "Work", or a known DC Fast Charger based on GPS geofencing. In Joule, location name and location type are selected manually.

---

## 5. Strategic Roadmap & Prioritized Recommendations

To bridge the gap between Joule and market leaders while maintaining Joule's core values (**Privacy, Chemistry Awareness, Clean Native UI, Zero Subscriptions**), the following prioritized roadmap is proposed:

```mermaid
gantt
    title Joule Feature Roadmap & Gap Closure
    dateFormat  YYYY-Q#
    axisFormat  %Y Q%q

    section Phase 1: High-Impact Quick Wins
    Multi-Vehicle Garage Support            :done, p1_1, 2026-Q1, 45d
    Vision OCR for Receipts & Meter Screens :p1_2, after p1_1, 40d
    PDF Reimbursement Report Generator      :p1_3, after p1_1, 30d
    Location Geofencing (CoreLocation)      :p1_4, after p1_2, 30d

    section Phase 2: iOS Ecosystem Polish
    Live Activities & Dynamic Island Timer  :p2_1, 2026-Q2, 45d
    Home & Lock Screen WidgetKit Extensions :p2_2, after p2_1, 30d
    TCO & Maintenance / Service Reminders   :p2_3, after p2_1, 40d

    section Phase 3: Hardware & Cross-Platform
    Bluetooth Low Energy (BLE) OBD-II Sync  :p3_1, 2026-Q3, 60d
    Ambient Weather / Temp Normalization    :p3_2, after p3_1, 30d
    Kotlin Multiplatform / Android Port     :p3_3, 2026-Q4, 90d
```

### 5.1 Tier 1: High-Impact, High-Leverage Features (Immediate Value)

#### 1. Multi-Vehicle Garage Management 🚗🚗 [COMPLETED & VERIFIED ✅]
- **Feature:** Refactor `VehicleProfile` into a first-class `Vehicle` entity and manage a full garage collection in `SessionStore`.
- **Delivered Implementation:**
  - **Garage Switcher UI:** `GarageSwitcherMenu` in navigation bar and toolbars across Dashboard, History, Battery Health, and macOS split view.
  - **Session Association:** Associated `ChargingSession.vehicleId` with automatic legacy profile migration and reassignment protection on vehicle deletion.
  - **Independent Analytics:** Vehicle-scoped battery health State of Health (SoH) regression, dynamic chemistry care advice, home charging duration/cost estimators, and gas savings comparisons.
  - **Full Management:** `GarageManagementView` and `VehicleEditorView` with preset catalog integration, local JSON caching, and Cloud Firestore sync.

#### 2. On-Device Vision OCR Scanner for Station Screens & Receipts 📸
- **Feature:** Use Apple's native `VisionKit` / `VNRecognizeTextRequest` to scan DC charger summary screens, home meter LCDs, or receipt printouts.
- **Implementation:**
  - One-tap "Scan Charger Screen" button in `AddSessionView`.
  - Automatically parse: Energy (kWh), Total Cost, Duration (min), Speed (kW), and Unit Price.
  - 100% on-device processing preserves total user privacy.

#### 3. Official PDF Expense & Reimbursement Report Generator 📄
- **Feature:** Generate clean, professional PDF reports formatted for employer reimbursement, accounting, or tax deductions using `PDFKit`.
- **Implementation:**
  - Date range filtering (e.g. "July 2026", "Q2 2026").
  - Breakdown of Home vs. Work vs. Public charging, total kWh, and total monetary claim.
  - Includes vehicle VIN / License Plate metadata and signature block.

#### 4. CoreLocation Geofencing for Automatic Location Detection 📍
- **Feature:** Use iOS `CoreLocation` to store coordinates for "Home", "Work", and favorite public chargers.
- **Implementation:**
  - When opening `AddSessionView`, if within 150 meters of saved Home coordinates, automatically default Location Type to `.home`, select the Home Tariff preset, and fill location name.

---

### 5.2 Tier 2: Ecosystem & User Experience Polish (Medium Term)

#### 1. Live Activities & Dynamic Island Charging Tracker ⏱️
- **Feature:** Start a live charging timer from `AddSessionView` or via an interactive button.
- **Implementation:**
  - Use `ActivityKit` to display an ongoing charging session on the Dynamic Island and Lock Screen.
  - Shows elapsed time, estimated current SoC based on charger kW speed, and alert notification when target SoC (e.g. 80% or 100%) is reached.

#### 2. WidgetKit Home & Lock Screen Widgets 📊
- **Feature:** Quick-glance iOS widgets for:
  - Current Month Charging Spend & Total kWh.
  - Latest Battery Health SoH (%) and degradation trend.
  - Quick-log shortcut button opening directly to `AddSessionView`.

#### 3. Total Cost of Ownership (TCO) & Maintenance Reminders 🛠️
- **Feature:** Optional tab or section to log non-charging expenses:
  - Routine maintenance (Cabin filter, brake fluid test, tire rotations).
  - Fixed recurring expenses (Insurance, road tax, financing).
  - Mileage-based maintenance alerts (e.g., "Rotate tires in 1,200 km").

---

### 5.3 Tier 3: Advanced Hardware & Diagnostic Horizons (Long Term)

#### 1. Optional Bluetooth Low Energy (BLE) OBD-II BMS Live Reader 🔌
- **Feature:** Connect to standard ELM327 / vLinker BLE OBD-II dongles to read real-time BMS registers without internet.
- **Implementation:**
  - Query PID registers for true hardware SoC, Battery SOH (%), Min/Max Cell Voltage Delta ($mV$), and Pack Temperature ($^\circ\text{C}$).
  - Automatically log odometer mileage and SoC at plug-in and unplug events.

#### 2. Ambient Weather & Temperature Normalization Engine 🌤️
- **Feature:** Integrate on-device `WeatherKit` to record ambient temperature at session timestamp.
- **Implementation:**
  - Normalize capacity calculations against battery operating temperature curves to eliminate false seasonal degradation dips during cold winters.

#### 3. Android Version (Kotlin Multiplatform / Jetpack Compose) 🤖
- **Feature:** Expand Joule's reach to Google Play Store using shared Kotlin Multiplatform (KMP) business logic and Jetpack Compose UI, preserving the offline-first Firestore architecture.

---

## 6. Summary Conclusion

| App Category | Primary Competitors | Joule's Current Position | Action Plan to Win |
| :--- | :--- | :--- | :--- |
| **Telemetry SaaS** | Tessie, TRONITY, EEVEE | **Superior on Privacy & Pricing; Lacks Cloud Ingestion** | Add **Vision OCR**, **Geofencing**, and **Live Activities** to deliver 90% of the convenience without privacy trade-offs. |
| **Battery Health** | Recurrent, Car Scanner | **Industry-leading Chemistry Awareness; Lacks Hardware OBD** | Retain proprietary chemistry regression; add **PDF Health Certificates** and optional **BLE OBD-II reader**. |
| **Utility Optimization** | Optiwatt, ev.energy | **Global Tariff Coverage; Lacks Automated Smart Grid dispatch** | Expand built-in regional TOU tariffs and dynamic solar charging tracking. |
| **Expense & TCO** | Fuelio, Drivvo | **Superior EV Analytics & Multi-Vehicle Garage; Lacks Non-charging maintenance** | Multi-Vehicle Garage **Completed**; add **TCO Maintenance Log** next. |

By executing on the high-leverage additions (Multi-Vehicle Garage, On-Device Vision OCR, PDF Reimbursement Reports, and WidgetKit/Live Activities), **Joule** will solidify its position as the premier, privacy-respecting, all-in-one EV charging and battery health intelligence platform on the Apple ecosystem.
