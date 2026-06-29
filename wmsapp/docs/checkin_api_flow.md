# Check-in API Flow

Flow ของ **Check-in** — สแกน Pack ที่ SORTED แล้ว → group เข้า Slot ตาม Owner/CustomerOrder → READY → Dispatch ขึ้นรถ

Base URL: `ApiService._resolveBase()` + `/api`
- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- LAN fallback: `http://192.168.1.124:5000/api`

ไฟล์ API หลัก: `lib/services/api/checkin_api.dart`

---

## 🗺️ Flow Map

```
HOME → กดเมนู Check-in
   ↓
┌────────────────────────────────────────────────────┐
│ CheckInScreen                                      │
│                                                    │
│ 1. สแกน Packing ID                                 │── POST /checkin/preview
│    → popup "ส่งปลายทาง / สแกนซ้ำ"                  │   (ไม่ commit)
│    ↓                                               │
│ 2. ยืนยันใน popup                                  │── POST /checkin/scan
│    → backend assign slot ตาม Owner/CustomerOrder   │
│    ↓                                               │
│ 3. ถ้า isReadyToComplete=true                       │── POST /checkin/complete
│    → auto complete slot (READY)                    │
│ 4. ไม่งั้น                                          │── POST /checkin/dispatch  (??)
│ 5. โหลด slot detail แสดง progress + cartons        │── GET /checkin/slot/{slotId}
└────────────────────────────────────────────────────┘
```

> **หมายเหตุ:** เคยมี `GET /checkin/slots` (list active slots) — ลบไปแล้วเพราะไม่มี caller

---

## 🎯 State Model

### CheckInSlot
```
OPEN ──complete (carton ครบ)──▶ READY ──dispatch──▶ SHIPPED
```

### Packing (Check-in context)
```
SORTED ──scan check-in──▶ STAGED ──slot dispatch──▶ SHIPPED
```

### CustomerOrder (auto-close เมื่อ Slot dispatch)
```
ACTIVE ──slot SHIPPED──▶ SHIPPED
```

---

## 1. Preview Check-in (no side effect)

| | |
| --- | --- |
| Endpoint | `POST /checkin/preview` |
| Screen | `CheckInScreen._scanCarton()` |
| Wrapper | `ApiService.previewCheckIn(packingId)` |

**Request:** `{ packingId }`

**Validate:**
- Pack มี
- Status = `SORTED` (ไม่ใช่ `OPEN/DONE`)

**Response:** PreviewCheckInResponse — เต็มไปด้วยข้อมูลสำหรับแสดง dialog + delivery note
```json
{
  "packingId": "PK-...",
  "owner": "NSN",
  "customerOrderId": "CO-...",
  "packStatus": "SORTED",
  "itemCount": 6,
  "orderCount": 1,
  "pickOrderIds": ["TEST-..."],
  "slotId": "SLOT-01",
  "isNewSlot": false,
  "isAlreadyCheckedIn": false,
  "dispatchDestination": "ประตู 2",
  "items": [
    { "partId": "PT-1001", "itemDesc": "...", "brand": "Nissan",
      "imageUrl": null, "qty": 6 }
  ],
  "pipelineTotal": 3, "pickDone": 3, "packDone": 3,
  "sortingDone": 2, "checkInDone": 1
}
```

---

## 2. Scan Check-in (commit)

| | |
| --- | --- |
| Endpoint | `POST /checkin/scan` |
| Screen | `CheckInScreen._confirmDestinationDialog()` |
| Wrapper | `ApiService.scanCheckIn(packingId, operatorId)` |

**Logic:**
1. Validate: pack มี, `Status=SORTED`, ยังไม่ check-in
2. หา slot ที่ open ของ CustomerOrder/Owner เดียวกัน — ถ้าไม่มีสร้างใหม่
3. Insert `CheckInEntry` (slot, packingId, operatorId, scannedAt)
4. Pack: `Status=STAGED`
5. คำนวณ progress (cartonsInSlot vs expectedCartons) → `isReadyToComplete`

**Response (minimal):**
```json
{
  "slotId": "SLOT-01",
  "isReadyToComplete": true
}
```

> response shrunk หลัง cleanup — เหลือเฉพาะ field ที่ Flutter อ่าน

---

## 3. Slot Detail

| | |
| --- | --- |
| Endpoint | `GET /checkin/slot/{slotId}` |
| Screen | `CheckInScreen._openSlot()` |
| Wrapper | `ApiService.getCheckInSlot(slotId)` |

**Response:**
```json
{
  "status": "OPEN",
  "cartons": [
    { "packingId": "PK-...", "trackingId": "TRK-...",
      "status": "STAGED", "scannedAt": "...",
      "itemCount": 6, "orderCount": 1 }
  ],
  "customerOrderId": "CO-...",
  "pipelineTotal": 3, "pickDone": 3, "packDone": 3,
  "sortingDone": 3, "checkInDone": 2
}
```

ใช้แสดง:
- Slot status banner
- Cartons list (packingId + tracking + item/order counts + scannedAt + status)
- 4-column pipeline progress bar

---

## 4. Complete Slot → READY

| | |
| --- | --- |
| Endpoint | `POST /checkin/complete` |
| Screen | `CheckInScreen._autoCompleteSlot()` (เรียก auto เมื่อ `isReadyToComplete=true`) |
| Wrapper | `ApiService.completeCheckIn(slotId, operatorId)` returns `void` |

**Logic:**
- Validate: slot OPEN + carton ครบ
- Slot: `Status=READY`, `CompletedAt=now`

**Response:** Success/error only (no body fields read by Flutter)

---

## 5. Dispatch Slot → SHIPPED

| | |
| --- | --- |
| Endpoint | `POST /checkin/dispatch` |
| Screen | `CheckInScreen._autoDispatchSlot()` |
| Wrapper | `ApiService.dispatchCheckIn(slotId, operatorId)` returns `void` |

**Logic:**
- Validate: slot READY
- Slot: `Status=SHIPPED`, `ShippedAt=now`
- CheckInEntries: `Status=SHIPPED`, `ShippedAt=now`
- Packings: `Status=SHIPPED`
- CustomerOrder ถูก close (`Status=SHIPPED`) ถ้า slot มี CustomerOrderId

**Response:** Success/error only

---

## 📋 TL;DR

| # | จังหวะ | Screen | API |
| - | --- | --- | --- |
| 1 | สแกน Pack (preview) | `CheckInScreen` | `POST /checkin/preview` |
| 2 | ยืนยันใน popup (commit) | `CheckInScreen` | `POST /checkin/scan` |
| 3 | Slot detail | `CheckInScreen` | `GET /checkin/slot/{id}` |
| 4 | Auto-complete (carton ครบ) | `CheckInScreen` | `POST /checkin/complete` |
| 5 | Auto-dispatch (slot ready) | `CheckInScreen` | `POST /checkin/dispatch` |

**Total 5 endpoints — ไม่มี dead** ทั้งหมดมี caller

---

## 🧹 Cleanup Log (2026-06-29)

| ที่เคยมี | จัดการ |
| --- | --- |
| `GET /checkin/slots` 🧟 | ลบ endpoint + service + wrapper + `CheckInSlotSummary` DTO/model (no Flutter caller) |
| `CompleteCheckInResponse` model 💀 | ลบ — Flutter ใช้แค่ success check, ไม่อ่าน field |
| `DispatchCheckInResponse` model 💀 | ลบ — เหมือนกัน |
| `PackTrackingItem` 💀 | ลบ — orphan หลัง CompleteCheckInResponse หายไป |
| `PreviewCheckInResponse.Message` 💀 | ลบ — Flutter ไม่อ่าน |
| `ScanCheckInResponse.Owner/PackingId/CartonsInSlot/ExpectedCartons/Message` 💀 | ลบ 5 fields — Flutter ใช้แค่ `slotId` + `isReadyToComplete` |
| `CheckInSlotDetail.SlotId/Owner/CreatedAt/CompletedAt/CartonsInSlot/ExpectedCartons/IsReadyToComplete` 💀 | ลบ 7 fields — Flutter อ่าน status, cartons, customerOrderId, pipeline counters |
| Flutter `completeCheckIn` / `dispatchCheckIn` return type | เปลี่ยน `ApiResult<Response>` → `ApiResult<void>` |

**Backend service:**
- Complete/Dispatch service methods → return `ApiSuccess(success, message)` แทน object responses
- Service หยุด query `trackings` ใน CompleteSlotAsync (เพราะ DTO ไม่มีแล้ว)

> `CheckInCartonItem.Status` — **คงไว้** (พบว่าใช้จริงตอน build delivery note card — เลือกสถานะ STAGED/SHIPPED จาก slot.cartons list)

---

## 🗂️ Source Files

**Flutter**
- `lib/screens/checkin/checkin_screen.dart`
- `lib/models/checkin/checkin_models.dart`
- `lib/services/api/checkin_api.dart`

**Backend**
- `Controllers/CheckInController.cs`
- `Services/CheckIn/CheckInService.cs`, `ICheckInService.cs`
- `DTOs/CheckIn/CheckInDtos.cs`
- `Models/Checkin/CheckInSlot.cs`, `CheckInEntry.cs`
