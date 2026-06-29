# Sorting API Flow

Flow ของ **Sorting** — 10 stations รับ Pack ที่ DONE แล้วเข้า SortingPallet ขนาดใหญ่ (แต่ละ pallet มี max capacity) → SEALED → ส่งต่อ

Base URL: `ApiService._resolveBase()` + `/api`
- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- LAN fallback: `http://192.168.1.124:5000/api`

ไฟล์ API หลัก: `lib/services/api/sorting_api.dart`

---

## 🗺️ Flow Map

```
HOME → กดเมนู Sorting
   ↓
┌────────────────────────────────────────────────────┐
│ SortingScreen (Dashboard 10 stations)              │
│   • โหลด stations + counters                       │── GET /sorting/stations
│   • Tap station → เปิด sheet                       │── GET /sorting/stations/{id}
│   • Enable/Disable station                         │── POST /sorting/stations/toggle
│   • Clear FULL pallet                              │── POST /sorting/stations/clear
└────────────────────────────────────────────────────┘

Dev/Test panel (TestSortingScreen)
   • ดู Pack DONE ที่ยังไม่ถูก sort                  │── GET /sorting/test/available-packs
   • สร้าง batch จาก pack ที่เลือก                  │── POST /sorting/test/create-batch
     → ถ้ามี station ว่าง: ASSIGNED + create pallet
     → ถ้าเต็ม: QUEUED ใน SortingBatchQueue
                ↓
                SortingFlowSimulator (hosted service)
                ตรวจ queue ทุก N วินาที — assign เมื่อมี station ว่าง
```

---

## 🎯 State Model

### SortingStation (10 stations, ID 1..10)
```
Enabled=true + CurrentPalletId=null  →  AVAILABLE
Enabled=true + CurrentPalletId=X     →  BUSY
Enabled=false                         →  DISABLED
```

### SortingPallet
```
ACTIVE ──รับ pack ครบ max──▶ FULL ──seal──▶ SEALED
```

### SortingPalletPack (queue)
```
PENDING ──simulator tick──▶ ASSIGNED (เพิ่มลง pallet)
```

### SortingBatchQueue (waiting queue สำหรับ batch)
```
WAITING ──station ว่าง──▶ ASSIGNED (simulator)
```

---

## 1. Dashboard — 10 stations

| | |
| --- | --- |
| Endpoint | `GET /sorting/stations` |
| Screen | `SortingScreen._load()` |
| Wrapper | `ApiService.getSortingDashboard()` |

**Response:**
```json
{
  "stations": [
    {
      "stationId": 1,
      "enabled": true,
      "status": "BUSY",
      "palletId": "SP-001",
      "cartonsCount": 5,
      "maxCapacity": 10,
      "isFull": false,
      "disableReason": null
    }
  ],
  "completedCount": 12,
  "queuedCount": 3
}
```

`status` calculation (backend):
- `!enabled` → `DISABLED`
- `CurrentPalletId == null` → `AVAILABLE`
- มี pallet → `BUSY`

---

## 2. Station Detail (Sheet)

| | |
| --- | --- |
| Endpoint | `GET /sorting/stations/{stationId}` |
| Screen | `SortingScreen` (tap station card → sheet) |
| Wrapper | `ApiService.getSortingStation(stationId)` |

**Response:**
```json
{
  "stationId": 1,
  "enabled": true,
  "status": "BUSY",
  "palletId": "SP-001",
  "cartonsCount": 5,
  "maxCapacity": 10,
  "isFull": false,
  "cartons": [
    {
      "packingId": "PK-2906-001",
      "owner": "NSN",
      "weightGram": 2500,
      "itemCount": 6,
      "sortedAt": "2026-06-29T...",
      "sequenceNo": 1
    }
  ],
  "pendingCount": 2
}
```

`cartons` = Packs ที่ assigned แล้ว เรียงตาม `SortedAt`
`pendingCount` = packs ใน queue ที่ยัง `PENDING` รอ simulator process

---

## 3. Toggle Station (Enable/Disable)

| | |
| --- | --- |
| Endpoint | `POST /sorting/stations/toggle` |
| Screen | `SortingScreen` (station sheet) |
| Wrapper | `ApiService.toggleSortingStation(...)` |

**Request:** `{ stationId, enable, operatorId, reason? }`

**DB Write:**
- `SortingStation.Enabled = enable`
- ถ้า disable → `DisabledBy`, `DisabledAt`, `DisableReason` set
- ถ้า enable → clear ฟิลด์ disable
- เพิ่ม `StationAuditLog` (DISABLE/ENABLE)

---

## 4. Clear FULL Station

| | |
| --- | --- |
| Endpoint | `POST /sorting/stations/clear` |
| Screen | `SortingScreen` (sheet — แสดงเมื่อ pallet FULL) |
| Wrapper | `ApiService.clearSortingStation(stationId, operatorId)` |

**Request:** `{ stationId, operatorId }`

**Logic:**
- Validate: pallet ต้อง `FULL` ก่อน clear
- Seal pallet → `Status=SEALED`, `SealedAt=now`
- Station.CurrentPalletId = null → กลับมา AVAILABLE
- เพิ่ม `StationAuditLog` (CLEAR)

---

## 5. Test — Available Packs

| | |
| --- | --- |
| Endpoint | `GET /sorting/test/available-packs` |
| Screen | `TestSortingScreen` |
| Wrapper | `ApiService.getAvailablePacksForSorting()` |

**Response:** Pack ที่ `Status=DONE` + ยังไม่ถูก sort (`SortingPalletId == null`)

```json
{
  "items": [
    {
      "packingId": "PK-...",
      "owner": "NSN",
      "customerOrderId": "CO-...",
      "itemCount": 6,
      "orderCount": 1,
      "completedAt": "..."
    }
  ]
}
```

---

## 6. Test — Create Batch

| | |
| --- | --- |
| Endpoint | `POST /sorting/test/create-batch` |
| Screen | `TestSortingScreen` |
| Wrapper | `ApiService.createSortingBatch(operatorId, packingIds)` |

**Request:** `{ operatorId, packingIds: [...] }`

**Logic:**
- Validate: pack ทั้งหมดต้อง DONE + ยังไม่ถูก sort
- หา station ว่าง (Enabled + CurrentPalletId=null)
- ถ้าเจอ → `CreatePalletForBatchAsync` → assign pallet (SP-XX) + queue packs (`SortingPalletPack` Status=PENDING) → simulator process ทีหลัง
- ถ้าไม่เจอ → push เข้า `SortingBatchQueue` Status=WAITING → simulator process ทีหลัง

**Response:**
```json
{
  "outcome": "ASSIGNED",     // หรือ "QUEUED"
  "stationId": 1,            // null ถ้า QUEUED
  "batchSize": 5
}
```

> SignalR event `BatchQueued` เมื่อ queued — Flutter ฟัง refresh dashboard

---

## 🤖 Background — SortingFlowSimulator

[`SortingFlowSimulator`](../wms-api/WmsApi/WmsApi/Services/Sorting/SortingFlowSimulator.cs) — hosted background service

ทุก ~N วินาที:
1. หา `SortingPalletPack (Status=PENDING, ScheduledAt <= now)` → process เข้า pallet (เพิ่ม CartonsCount, set Pack.SortingPalletId, fire SignalR)
2. หา `SortingBatchQueue (Status=WAITING)` → ถ้ามี station ว่าง → assign + create pallet (`SortingService.CreatePalletForBatchAsync`)

---

## 📋 TL;DR

| # | จังหวะ | Screen | API |
| - | --- | --- | --- |
| 1 | Dashboard | `SortingScreen` | `GET /sorting/stations` |
| 2 | Station sheet | `SortingScreen` | `GET /sorting/stations/{id}` |
| 3 | Enable/Disable | `SortingScreen` (sheet) | `POST /sorting/stations/toggle` |
| 4 | Clear FULL | `SortingScreen` (sheet) | `POST /sorting/stations/clear` |
| 5 | List available packs (test) | `TestSortingScreen` | `GET /sorting/test/available-packs` |
| 6 | Create batch (test) | `TestSortingScreen` | `POST /sorting/test/create-batch` |

**Total 6 endpoints — ไม่มี dead** ทั้งหมดมี caller

---

## 🧹 Cleanup Log (2026-06-29)

| ที่เคยมี | จัดการ |
| --- | --- |
| `SortingStationView.DisabledBy` 💀 | ลบจาก DTO + service + Flutter model (UI ไม่แสดง) |
| `SortingStationView.DisabledAt` 💀 | ลบ — UI ไม่แสดง |
| `SortingStationView.StartedAt` 💀 | ลบ — UI ไม่แสดง |
| `SortingStationDetail.StartedAt` 💀 | ลบ — UI ไม่แสดง |
| `SortingStationDetail.FullAt` 💀 | ลบ — UI ไม่แสดง |
| `CreateSortingBatchResponse.PalletId` 💀 | ลบ — Flutter ไม่ display SP-XX (มี stationId พอ) |
| `CreateSortingBatchResponse.QueueId` 💀 | ลบ — Flutter ไม่ display |
| `CreateSortingBatchResponse.Message` 💀 | ลบ — Flutter สร้าง message เอง |

> DB columns ที่เกี่ยวข้อง (`SortingStation.DisabledBy/DisabledAt`, `SortingPallet.CreatedAt/SealedAt`) **คงอยู่** — backend ยังเขียน/อ่านสำหรับ audit แต่ไม่ expose ผ่าน API

---

## 🗂️ Source Files

**Flutter**
- `lib/screens/sorting/sorting_screen.dart` (dashboard + sheet)
- `lib/screens/test/test_sorting_screen.dart` (dev panel)
- `lib/models/sorting/sorting_models.dart`
- `lib/services/api/sorting_api.dart`

**Backend**
- `Controllers/SortingController.cs`
- `Services/Sorting/SortingService.cs`, `ISortingService.cs`
- `Services/Sorting/SortingFlowSimulator.cs` (background hosted service)
- `DTOs/Sorting/SortingDtos.cs`
- `Models/Sorting/StationAuditLog.cs` (audit table)
