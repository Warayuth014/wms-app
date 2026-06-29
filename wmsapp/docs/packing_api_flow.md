# Packing API Flow

Flow ของ **Packing** — สแกน Pallet ที่อยู่ ZONE_PACK → เลือก Pack/Order → สแกน Part + S/N → auto-finalize เมื่อครบ

Base URL: `ApiService._resolveBase()` + `/api`
- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- LAN fallback: `http://192.168.1.124:5000/api`

ไฟล์ API หลัก: `lib/services/api/packing_api.dart`

---

## 🗺️ Flow Map

```
HOME → กดเมนู Packing
   ↓
┌────────────────────────────────────────────────────┐
│ PackingScreen (state machine)                      │
│                                                    │
│ _PackState.scanPallet                              │
│   • สแกน Pallet ID                                 │── GET /packing/pallet/{id}
│   ↓                                                │
│ _PackState.packList                                │
│   • list Pack ของ pallet (ถ้ามี 1 Pack → skip)    │
│   ↓ tap pack                                       │
│   • โหลด pack detail                                │── GET /packing/pack/{id}
│   ↓                                                │
│ _PackState.orderList (ข้ามถ้ามี 1 Order)           │
│   ↓ tap order                                      │
│   • โหลด order detail                               │── GET /packing/pack/{id}/order/{poId}
│   ↓                                                │
│ _PackState.orderParts                              │
│   • สแกน Part → highlight                          │
│   • สแกน S/N → เก็บใน collectedSerials             │
│   • ครบ qty → POST /packing/scan-part              │── POST /packing/scan-part
│   • ถ้าทุก Detail DONE → backend auto-finalize     │
│     (response.packFinalized=true)                  │
│   ↓                                                │
│ _PackState.success                                 │
│   • Print tracking + ส่งต่อ                        │
└────────────────────────────────────────────────────┘
```

**Key:** ไม่มี endpoint "Confirm Pack" — backend auto-finalize ใน `scan-part` เมื่อ Detail ครบทุก Order

---

## 🎯 State Model

### Packing (entity)
```
OPEN ──ทุก PackingDetail DONE──▶ DONE
                                  └─ generate TrackingId
                                  └─ ถ้า Pallet หมด Pack → release Pallet
```

### PackingDetail (entity, ต่อ Order)
```
PENDING ──ทุก part scan ครบ──▶ DONE
```

### Pallet (Packing context)
```
PACKED@ZONE_PACK ──scan-part (auto-finalize)──▶ DONE Pack → ถ้าหมด Pack → AVAILABLE@null
```

---

## 1. Scan Pallet — ดู Pack ที่ค้างใน Pallet

| | |
| --- | --- |
| Endpoint | `GET /packing/pallet/{palletId}` |
| Screen | `PackingScreen._scanPallet()` |
| Wrapper | `ApiService.scanPalletForPacking(palletId)` |

**Response:**
```json
{
  "palletId": "PAL-014",
  "status": "PACKED",
  "location": "ZONE_PACK",
  "packs": [
    {
      "packingId": "PK-2906-001",
      "status": "OPEN",
      "createdAt": "2026-06-29T...",
      "completedAt": null,
      "orderCount": 1,
      "orderDoneCount": 0
    }
  ]
}
```

**Validate (backend):**
- Pallet ต้องมี
- ต้องมี Packing record อ้างถึง pallet นี้

---

## 2. Pack Detail — ดู Order ใน Pack

| | |
| --- | --- |
| Endpoint | `GET /packing/pack/{packingId}` |
| Screen | `PackingScreen._openPack()` |
| Wrapper | `ApiService.getPack(packingId)` |

**Response:**
```json
{
  "packingId": "PK-2906-001",
  "palletId": "PAL-014",
  "status": "OPEN",
  "createdAt": "...",
  "completedAt": null,
  "trackingId": null,
  "orders": [
    {
      "pickOrderId": "TEST-...",
      "status": "PENDING",
      "partCount": 3,
      "partDoneCount": 0
    }
  ]
}
```

> ถ้า `orders.length == 1` → Flutter ข้าม `_PackState.orderList` ไป `orderParts` ทันที

---

## 3. Order Detail — ดู Part + Serials บน Pallet

| | |
| --- | --- |
| Endpoint | `GET /packing/pack/{packingId}/order/{pickOrderId}` |
| Screen | `PackingScreen._openOrder()` |
| Wrapper | `ApiService.getPackOrder(packingId, pickOrderId)` |

**Response:**
```json
{
  "packingId": "PK-...",
  "pickOrderId": "TEST-...",
  "status": "PENDING",
  "parts": [
    {
      "partId": "PT-1001",
      "owner": "NSN",
      "brand": "Nissan",
      "itemDesc": "Spark Plug NGK Iridium",
      "imageUrl": null,
      "requiredQty": 6,
      "scannedQty": 0,
      "availableSerials": ["SN-...0014", "SN-...0015", ...]
    }
  ],
  "packFinalized": false,
  "trackingId": null,
  "palletReleased": false
}
```

---

## 4. Scan Part (with auto-finalize) ⭐

| | |
| --- | --- |
| Endpoint | `POST /packing/scan-part` |
| Screen | `PackingScreen._confirmScannedPart()` |
| Wrapper | `ApiService.scanPackPart(...)` |

**Request:**
```json
{
  "packingId": "PK-2906-001",
  "pickOrderId": "TEST-...",
  "partId": "PT-1001",
  "qty": 6,
  "operatorId": "USR-001",
  "serialNumbers": ["SN-...0014", "SN-...0015", "...", "...", "...", "..."]
}
```

**Logic:**
1. หา `PackingDetail (PackingId, PickOrderId)` — เพิ่ม `ScannedQty`
2. update `ScanLog` entries (per serial scanned)
3. ถ้า `packComplete` (ทุก Part ใน Detail นี้ scan ครบ) → `Detail.Status = DONE`
4. **ถ้าทุก Detail ใน Pack เป็น DONE** → `FinalizePackInternalAsync(pack)`:
   - `Pack.Status = DONE`
   - Generate `TrackingId` (`TRK-YYYYMMDDHHMMSS-NNNN`)
   - ถ้าหมด OPEN Pack ทั้งบน pallet → release pallet (`Status=AVAILABLE, Location=null`)
5. Re-fetch Order response + ถ้า finalize → enrich ด้วย `packFinalized=true`, `trackingId`, `palletReleased`

**Response:** `PackingOrderResponse` (เพิ่ม `packFinalized`/`trackingId`/`palletReleased` ถ้า finalize)

> เมื่อ Flutter เห็น `packFinalized=true` → สร้าง `ConfirmPackResponse` ใน memory แล้วไปหน้า success — **ไม่ต้องเรียก endpoint อื่น**

---

## 📋 TL;DR

| # | จังหวะ | Screen state | API |
| - | --- | --- | --- |
| 1 | สแกน Pallet | `scanPallet` | `GET /packing/pallet/{id}` |
| 2 | เลือก Pack (ถ้า > 1) | `packList` | `GET /packing/pack/{id}` |
| 3 | เลือก Order (ถ้า > 1) | `orderList` | `GET /packing/pack/{id}/order/{poId}` |
| 4 | สแกน Part + S/N + ยืนยัน | `orderParts` | `POST /packing/scan-part` |
| 5 | Auto-finalize (เมื่อ Pack ครบ) | `success` | — (จาก response ของ scan-part) |

**Total 4 endpoints — ไม่มี dead** ทั้งหมดมี caller

---

## 🧹 Cleanup Log (2026-06-29)

| ที่เคยมี | จัดการ |
| --- | --- |
| `POST /packing/confirm-pack` 🧟 | ลบ endpoint + service + interface — `scan-part` มี auto-finalize ทำให้ endpoint นี้ไม่มี caller ใน Flutter |
| `ConfirmPackRequest` DTO 💀 | ลบ — ใช้กับ endpoint ที่ลบไปแล้ว |
| `ConfirmPackResponse` DTO (backend) 💀 | ลบ — Flutter `ConfirmPackResponse` ยังอยู่ (ใช้ local synthesis จาก scan-part response) |
| `ConfirmPackRequest.OperatorId` 💀 | moot ตาม DTO ที่ลบ (weak validate, ไม่ write/lookup) |
| `PackingPalletResponse.Message` 💀 | ลบจาก DTO + backend service + Flutter model (backend ส่ง `"พบ N Pack"` แต่ Flutter ไม่อ่าน) |
| Flutter `confirmPack()` wrapper 💀 | ลบ — ไม่มี caller |

**Behavior หลัง cleanup:** flow เหมือนเดิมเป๊ะ — auto-finalize ผ่าน scan-part ทำงาน → Flutter สร้าง `ConfirmPackResponse` locally → ไปหน้า success

---

## 🗂️ Source Files

**Flutter**
- `lib/screens/packing/packing_screen.dart` (state machine)
- `lib/models/packing/packing_models.dart`
- `lib/services/api/packing_api.dart`

**Backend**
- `Controllers/PackingController.cs`
- `Services/Packing/PackingService.cs`, `IPackingService.cs`
- `DTOs/Packing/PackingDtos.cs`
