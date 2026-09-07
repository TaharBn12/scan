# 🛒 Mobile POS & Billing App 

A feature-rich, high-performance offline-first billing and Point of Sale (POS) application built with Flutter. Designed for seamless retail checkout operations featuring barcode scanning, thermal Bluetooth printing, and robust local data persistence.

## Screenshot


https://github.com/user-attachments/assets/f2d16454-5408-43b3-b207-cd843bbc2c9e



## ✨ What's new in 2.0

- **Arabic / French / English UI** with full RTL layout (language switch in Settings, follows the phone by default, Arabic fallback). Currency symbol, decimals and symbol position are configurable (default `DA`).
- **Share invoices as PDF** (WhatsApp, e‑mail…) with Arabic-capable fonts, in addition to Bluetooth thermal printing. Thermal receipts stay Latin-only because of printer font limits.
- **Backup to a file** (JSON) with share sheet, restore from file / pasted text, automatic daily local backups (last 7 kept).
- **Low-stock screen** with per-product threshold and a badge on the menu.
- **Purchases / stock-in** entries with supplier, cost update and a full stock movement log per product.
- **Partial debt payments** – credit sales keep a payment history, customers have credit limits and statements.
- **Reports** with period filter (day / week / month / custom range), daily & monthly bar charts, payment & cashier breakdown, top products, inventory value, Z-report printing and CSV / PDF export.
- **Units** (piece, kg, g, L, mL, m, box, pack) with decimal quantities for weighed goods.
- **Two-way website sync** – outbox of changed products / sales / customers / expenses / purchases pushed to your site, product changes pulled back (contract below).
- **App lock with PIN** (auto-lock after 2 min in background) and **multi-user mode** (admin / cashier, each with their own PIN; cashier name stored on every sale).
- **Daily expenses** with categories → real net profit in reports.
- **Barcode labels** – A4 PDF sticker sheets or thermal label printing for products without a barcode (auto-generated internal codes).

### Website sync contract

All requests carry `Authorization: Bearer <token>` (token shown in Settings → Website Sync).

```
POST <base>/api/sync/push
  { "token": "...", "changes": [ { "entity": "product|sale|customer|expense|purchase|stock_movement",
                                   "op": "upsert|delete", "id": "...", "data": { ... } } ] }
  -> 200 { "ok": true }

GET <base>/api/sync/products?since=<ISO-8601>
  -> 200 { "products": [ { ...product map... } ], "deleted": [ "id", ... ] }
```

## 🎯 Project Scope

This application serves as a complete offline POS system for small to medium-sized retail shops. It streamlines the checkout process, catalog management, and receipt generation securely entirely on-device.

### Core Features:
- **Product Management System**: Complete CRUD operations for inventory items with barcode/QR code support.
- **Smart Checkout System**: Rapid cart building via camera-based barcode scanning or manual entry, and robust order calculation functionality.
- **Bluetooth Thermal Printing**: Direct integration with thermal printers (`print_bluetooth_thermal`) to instantly output physical receipts.
- **Shop Settings & Customization**: Centrally managed shop details printed dynamically on receipts.
- **Offline-First Architecture**: Powered by `Hive` for lightning-fast localized NoSQL data storage. No active internet connectivity required.

## 🛠 Tech Stack & Architecture

Built leveraging industry-standard architectural principles (Clean Architecture & Feature-Driven Design) ensuring scalability, separation of concerns, and robust testability. 

- **Framework**: [Flutter](https://flutter.dev/) (SDK >=3.1.0)
- **State Management**: `flutter_bloc`
- **Dependency Injection**: `get_it`
- **Routing**: `go_router`
- **Local Database**: `hive` & `hive_flutter`
- **Data Modeling**: `json_serializable`, `equatable`
- **Functional Programming**: `fpdart`
- **Hardware Integrations**: `mobile_scanner` (barcodes), `print_bluetooth_thermal`

## 📁 File Structure

The codebase is organized using a **Feature-First Clean Architecture** utilizing domain-driven concepts.

```text
lib/
├── core/                       # Core application utilities and shared components
│   ├── data/                   # Global data sources (e.g., Hive initialization)
│   ├── error/                  # Standardized Failure/Exception models (fpdart compatible)
│   ├── theme/                  # UI aesthetics, typography, styling
│   ├── usecase/                # Base UseCase contracts
│   ├── utils/                  # Helpers (e.g., PrinterHelper, formatters)
│   ├── widgets/                # Reusable global UI widgets (AppBars, generic buttons)
│   └── service_locator.dart    # get_it dependency injection setup
│
└── features/                   # Independent feature modules
    ├── billing/                # Core POS operations: Cart, Checkout, Invoice Generation
    ├── product/                # Inventory management: Adding, Listing, Scanning products
    ├── settings/               # App configuration: Printer connections, App settings
    └── shop/                   # Shop details configuration
```

*Note: Each feature is further subdivided internally into Clean Architecture layers: `data`, `domain`, and `presentation`.*

## 💡 Use Cases

- **Rapid Billing Entry**: A cashier launches the app, navigates to the checkout page, and uses the device camera to instantly scan product barcodes. The products are added to the cart, the total is calculated including taxes, and a receipt is finalized.
- **Physical Receipt Generation**: After checkout confirmation, the app triggers a connected external Bluetooth thermal POS printer to instantly print an itemized paper receipt with the shop’s header.
- **Inventory Sideloading**: A manager opens the Product feature to add new stock to the local database, taking a picture of the barcode to bind the SKU for future lightning-fast checkouts.
- **No-Connection Operation**: The business operates a stall at an exhibition with poor networking. The app functions entirely via its embedded Hive local database and Bluetooth, completely undisturbed by network drops.

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.1.0` or higher
- Android Studio / Xcode for emulators and building.
- *Optional*: A physical Android/iOS device and a Bluetooth Thermal Printer for testing hardware integrations natively.

### Installation

1. Clone the repository and navigate to the project directory:
   ```bash
   git clone <repository_url>
   cd billing_app
   ```

2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

3. Run code generation (required for Hive adapters and JSON serialization):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. Run the project:
   ```bash
   flutter run
   ```

## 🤝 Contributing Guidelines
As a senior-focused project, please adhere to:
1. **Clean Architecture Rules**: Maintain strict boundaries between `domain`, `data`, and `presentation` layers.
2. **Immutable States**: Emit only immutable states from BLoCs utilizing `equatable`.
3. **No Direct Exceptions in Domain**: Utilize `fpdart`'s `Either<Failure, Type>` pattern to handle control flow for exceptions.
