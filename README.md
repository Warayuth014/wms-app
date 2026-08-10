# WMS App

Flutter app for warehouse floor operators — a PDA-style client for the
[wms-api](https://github.com/Warayuth014/wms-api) backend, built for
barcode-scanning your way through receiving, unload, putaway, picking,
packing, sorting, and dispatch.

## Stack

- **Flutter** (Dart SDK `^3.9.2`)
- `http` for REST calls to the backend
- `signalr_netcore` for real-time putaway/sorting station updates
- `shared_preferences` for local session + server config
- `material_design_icons_flutter` for the icon set
- `image_picker`, `intl`

## Features

Each screen maps to a warehouse floor workflow, mirroring the backend's
modules:

- **Receiving** — scan Part ID, resolve condition/lot (popup if more than
  one), scan serials or enter qty, assign to pallet in one step
- **Unload** — pull replenishment pallets back onto the floor, per-lot
  cards with inline S/N scanning where required
- **Basket** — load unloaded stock into baskets, S/N-gated when the part
  requires it
- **Putaway** — route pallets to ASRS or a prework station
- **Picking / Packing** — station-based pick-and-pack flow
- **Sorting / Check-In** — sort into outbound batches, stage and dispatch
- **Settings** — point the app at any backend without touching code: set
  IP/port/protocol, validated inline, with a live connected/disconnected
  health check

## Getting started

**Prerequisites:** Flutter SDK matching `^3.9.2`, a running instance of
[wms-api](https://github.com/Warayuth014/wms-api).

```bash
flutter pub get
flutter run
```

On first launch the app auto-detects a local backend (Android emulator host
or localhost). To point it at a different machine, open **Settings** (gear
icon on the home screen) and set the server's IP, port, and protocol — no
rebuild required.

## Project layout

```text
lib/
├── screens/     → one folder per module (receiving, unload, picking, ...)
├── models/      → response/request models, mirrored per module
├── services/
│   └── api/     → one file per backend controller, all behind ApiService
├── widgets/     → shared UI components
└── theme/       → app-wide styling
```
