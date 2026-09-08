# 🛒 Mobile POS & Billing App

[![Flutter CI](https://github.com/TaharBn12/scan/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/TaharBn12/scan/actions/workflows/flutter_ci.yml)
[![Download APK](https://img.shields.io/badge/download-latest%20APK-brightgreen)](https://github.com/TaharBn12/scan/releases/download/latest/billing_app-latest.apk)

A feature-rich, high-performance **100% offline** billing and Point of Sale (POS) application built with Flutter. Designed for fast retail checkout: barcode scanning, thermal Bluetooth printing, stock, customers, credit, expenses and reports — all stored on the phone.

> **No internet, no account, no website.** The release build does not even request the `INTERNET` permission: every byte of data lives in the shop's phone (Hive), and backups are plain files you own.

## Screenshot

https://github.com/user-attachments/assets/f2d16454-5408-43b3-b207-cd843bbc2c9e

## ✨ What's new in 3.0

### Redesign
- **New design system** (`lib/core/theme/app_theme.dart`): Material 3 built on one accent colour, neutral slate surfaces, hairline borders, soft elevation, 12/16/20/28 radii and a full set of component themes (cards, inputs, chips, dialogs, sheets, snackbars, segmented buttons, switches…).
- **6 accent palettes** (Indigo, Emerald, Ocean, Sunset, Rose, Graphite) + light / dark / auto + a **compact layout** switch — all in *Settings → Appearance*, applied instantly across every screen.
- **Shared UI kit** (`lib/core/widgets/ui_kit.dart`): `AppCard`, `SectionHeader`, `StatTile`, `AppBadge`, `EmptyState`, `GradientHeader`, `GlassIconButton`, `MiniBarChart` — so every screen speaks the same visual language.
- **Rebuilt till screen**: cleaner scanner overlay with an animated reticle, floating shortcuts, restyled cart rows with a pill stepper, and a pinned checkout bar showing the live total.

### New features
- **Live dashboard** (the old menu): today's revenue, invoice count and average ticket in the header; KPI tiles for net profit, outstanding credit, today's expenses and low stock; a **7-day revenue bar chart**; then the action grids (cashiers only see the selling section).
- **Global search** (`/search`): one box that searches products (name / barcode / category), customers (name / phone) and invoices (number / customer / item) instantly and offline — tap a product to add it straight to the cart.
- **Held (parked) invoices**: park the current cart under a name, serve another customer, then resume it later. Parked carts are persisted, so an app restart never loses the queue.

### Still there from 2.0
- **Arabic / French / English UI** with full RTL layout, configurable currency symbol, position and decimals (default `DA`).
- **Share invoices as PDF** (WhatsApp, e-mail…) with Arabic-capable fonts, plus Bluetooth thermal printing (thermal receipts stay Latin-only because of printer font limits).
- **Backups**: export/import JSON files, share sheet, restore from file or pasted text, automatic daily local backups (last 7 kept).
- **Low-stock screen** with per-product thresholds and a badge on the dashboard.
- **Purchases / stock-in** with supplier, cost update and a full stock-movement log per product.
- **Partial debt payments** — credit sales keep a payment history, customers have credit limits and statements.
- **Reports** with period filter (day / week / month / custom), daily & monthly charts, payment and cashier breakdowns, top products, inventory value, Z-report printing and CSV / PDF export.
- **Units** (piece, kg, g, L, mL, m, box, pack) with decimal quantities for weighed goods.
- **App lock with PIN** (auto-lock after 2 min in background) and **multi-user mode** (admin / cashier, each with their own PIN; cashier name stored on every sale).
- **Daily expenses** with categories → real net profit in reports.
- **Barcode labels** — A4 PDF sticker sheets or thermal label printing for products without a barcode.

## 🔒 Privacy & offline guarantees

| | |
|---|---|
| Data storage | Hive boxes on the device only |
| Network calls | none (no HTTP client, no Firebase, no analytics) |
| Android permissions | camera + Bluetooth (+ location, required by Android for BT scanning). **No `INTERNET` in release builds** |
| Moving to a new phone | Settings → Data → export the backup file and import it on the new device |

## 🎯 Project scope

A complete offline POS for small and medium retail shops: catalogue, checkout, receipts, customers and credit, purchases, expenses and reporting — all on-device.

## 🛠 Tech stack & architecture

Clean Architecture + feature-driven folders for scalability, separation of concerns and testability.

- **Framework**: [Flutter](https://flutter.dev/) (SDK >= 3.5)
- **State management**: `flutter_bloc`
- **Dependency injection**: `get_it`
- **Routing**: `go_router`
- **Local database**: `hive` & `hive_flutter`
- **Data modelling**: `equatable`, hand-written Hive adapters
- **Functional programming**: `fpdart`
- **Documents**: `pdf`, `share_plus`, `file_picker`, `path_provider`
- **Hardware**: `mobile_scanner` (barcodes), `print_bluetooth_thermal` (receipts)

## 📁 File structure

```text
lib/
├── core/
│   ├── data/          # Hive initialisation and boxes
│   ├── error/         # Failure models (fpdart friendly)
│   ├── l10n/          # ar / fr / en string tables + delegate
│   ├── pdf/ csv/      # Document and export helpers
│   ├── security/      # PIN hashing, session/lock controller
│   ├── settings/      # Language, currency, PIN preferences
│   ├── theme/         # Design tokens, Material 3 themes, accent controller
│   ├── utils/         # Money, printer, backup helpers
│   ├── widgets/       # Shared UI kit (AppCard, StatTile, EmptyState…)
│   └── service_locator.dart
│
└── features/
    ├── billing/       # Till, cart, held carts, checkout
    ├── customers/     # CRM, credit limits, statements
    ├── expenses/      # Daily expenses by category
    ├── inventory/     # Purchases, stock movements
    ├── labels/        # Barcode label sheets
    ├── menu/          # Dashboard
    ├── product/       # Catalogue, low stock, units
    ├── sales/         # Invoices, reports
    ├── search/        # Global search
    ├── settings/      # Appearance, printer, backups, security
    ├── shop/          # Shop identity used on receipts
    └── users/         # Multi-user, PIN lock
```

*Each feature is subdivided into `data`, `domain` and `presentation` layers.*

## 💡 Use cases

- **Rapid billing**: the cashier scans barcodes with the camera, the cart builds itself, the total updates live, and the receipt prints over Bluetooth.
- **Busy counter**: a customer forgets their wallet — park the invoice, serve the next person, resume it in one tap.
- **Weighed goods**: kg/L products prompt for a decimal quantity and an optional negotiated price.
- **End of day**: the dashboard shows revenue, net profit and expenses; the reports screen prints a Z-report or exports CSV/PDF.
- **Zero connectivity**: a market stall with no network runs the whole day unaffected.

## 🚀 Getting started

### Prerequisites
- Flutter SDK 3.5 or newer
- Android Studio / Xcode for emulators and builds
- *Optional*: a physical device + Bluetooth thermal printer to test hardware

### Installation

```bash
git clone <repository_url>
cd scan
flutter pub get
flutter run
```

Release APK:

```bash
flutter build apk --release
```

### Automatic builds

Every push runs `flutter analyze` + tests and, when they pass, builds a
release APK and republishes it under the rolling `latest` release — so this
link always serves the newest build:

**<https://github.com/TaharBn12/scan/releases/download/latest/billing_app-latest.apk>**

Add `[release]` to a commit message to also archive a permanent, versioned
release (`billing_app-vX.Y.Z-buildN.apk`).

## 🤝 Contributing guidelines

1. **Clean Architecture rules**: keep strict boundaries between `domain`, `data` and `presentation`.
2. **Immutable states**: BLoCs emit immutable states using `equatable`.
3. **No exceptions in the domain**: use `fpdart`'s `Either<Failure, T>` for control flow.
4. **Localise everything**: add new keys to `strings_en.dart`, `strings_ar.dart` and `strings_fr.dart` (a test enforces parity).
5. **Stay offline**: no dependency that phones home, and no new network permission.
