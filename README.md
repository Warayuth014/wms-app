# WMS App

ระบบจัดการคลังสินค้า (Warehouse Management System) — Flutter Mobile App

## Tech Stack

| Layer | Library |
|-------|---------|
| Framework | Flutter 3 · Dart SDK ^3.9 |
| HTTP | `http` |
| Offline DB | `sqflite` + `path` |
| Network Status | `connectivity_plus` |
| Auth / Prefs | `shared_preferences` |
| Date | `intl` (locale th_TH) |
| Image | `image_picker` |
| Font | Sarabun (Regular / Medium / Bold) |
| Theme | Light + Dark mode (Material 3) |

## Features

### Flow 1 — รับสินค้าเข้า (Goods Receiving)
- สแกน PO → สแกน Part → บันทึกจำนวน → Assign Pallet
- รองรับ FG (สินค้าปกติ) / PW (ต้องติดสติ๊กเกอร์)
- รับสินค้าคืน (Return) พร้อมใส่หมายเหตุ
- ดู Pending Pallet ที่ยังไม่ถูกจัดเก็บ

### Flow 2 — Replenishment
- สแกน Pallet → Unload สินค้าจาก ASRS
- Load Basket → ย้ายสินค้าเข้าตะกร้า

### Putaway
- สแกน Station barcode → เก็บ Pallet เข้า ASRS

### Picking
- สร้าง Picking Session → หยิบสินค้าตาม Pick Order

### Supervisor
- อนุมัติ / ยกเลิกรายการ (Cancel Approval)
- อัปโหลดรูป Part

### Offline Support
- บันทึกรายการลง SQLite เมื่อไม่มีเน็ต
- Auto sync เมื่อกลับมา online
- แสดง Offline Banner + จำนวน pending

## Project Structure

```
lib/
├── main.dart
├── theme/
│   └── theme.dart              # Light / Dark theme + AppTheme helpers
├── models/
│   └── wms_models.dart         # Data models (PO, POItem, Pallet, etc.)
├── services/
│   ├── api_service.dart        # REST API client (auto-detect base URL)
│   ├── offline_service.dart    # SQLite queue + sync
│   └── connectivity_service.dart
├── widgets/
│   ├── common_widgets.dart     # Shared UI (AppBar, Buttons, Dialogs)
│   └── part_thumbnail.dart
└── screens/
    ├── home_screen.dart
    ├── login_screen.dart
    ├── flow1/                  # รับสินค้าเข้า / คืน
    ├── flow2/                  # Replenishment (Unload / Load Basket)
    ├── putaway/                # เก็บ pallet เข้า ASRS
    ├── picking/                # Picking session
    ├── supervisor/             # Cancel approval + Part image
    └── test/                   # Test screens
```

## Setup

```bash
# 1. Clone
git clone <repo-url>
cd wms-app/wmsapp

# 2. Install dependencies
flutter pub get

# 3. Config API server IP
#    แก้ _physicalIp ใน lib/services/api_service.dart
#    (emulator ใช้ 10.0.2.2 อัตโนมัติ)

# 4. Run
flutter run
```

## API Server

แอปจะ probe base URL อัตโนมัติ:
- **Android Emulator** → `10.0.2.2:5000`
- **Physical device** → `192.168.x.x:5000` (แก้ `_physicalIp` ใน `api_service.dart`)
