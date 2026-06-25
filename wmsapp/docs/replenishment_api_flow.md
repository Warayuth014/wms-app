# Replenishment API Flow

Flow ของ **Replenishment** มี 2 phase หลัก:

1. **Unload** — เอาของออกจาก Pallet ที่ ASRS ส่งมาเติม stock
2. **Load to Basket** — เอาของที่ Unload แล้วใส่ Basket ไปแจกที่ shelf

---

## 🧹 Cleanup Log (2026-06-25)

Dead code/field/param/bug ที่เคยอยู่ในเอกสารนี้ถูกลบออกแล้ว:

| ที่เคยมี | จัดการ |
| --- | --- |
| `POST /unload/confirm-labeling` 🧟 | ลบ endpoint + service + DTO + Flutter wrapper + `_showLabelingDialog` |
| `GET /basket/{basketId}` 🧟 | ลบ endpoint + service + `BasketResponse`/`BasketLineResponse` DTOs |
| `needsLabeling` ใน scan-pallet 💀 | ลบจาก DTO + Flutter model + ทุกที่ที่ใช้ |
| `operatorId` ใน `confirm-labeling` 💀 | หมดไปกับ endpoint |
| `operatorId` ใน `return-pallet-to-asis` 💀 | ลบจาก DTO + Flutter wrapper + caller |
| `Condition: "NORMAL"` hardcoded 🐛 | แก้เป็น lookup จาก `ReceiptLines` ตอน open-session resume |

> **Convention สำหรับเอกสารอื่น:** 🧟 = endpoint ตาย, 💀 = field/param ตาย, 🐛 = bug เล็ก (ไม่ตาย แต่ผิดเงียบๆ)

---

## 🗺️ Flow Map (ภาพรวมหน้า + API)

```
┌─────────────────────────────────────────────────────────────┐
│ HOME → กดเมนู "Replenishment"                                │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
            ┌──────────────────────────────┐
            │   UnloadMenuScreen           │  เลือกเมนูย่อย
            │   ├─ Unload                  │
            │   └─ Load to Basket          │
            └─────┬────────────────┬───────┘
                  │                │
        ╔═════════▼═════════╗      │
        ║  PHASE 1: UNLOAD  ║      │
        ╚═════════╤═════════╝      │
                  ▼                │
        UnloadScreen               │   เลือก/สแกน Station
        (UNL-1 / UNL-2 / UNL-3)    │
                  ▼                │
        UnloadSessionSheet (popup) │
        ┌──────────────────────┐   │
        │ 1. สแกน Pallet ID    │── │──▶ GET  /unload/scan-pallet/{id}
        │                      │   │
        │ 2. เปิด session       │── │──▶ POST /unload/open-session
        │                      │   │      → Pallet: REPLENISH→UNLOADING
        │                      │   │
        │ 3. สแกน Part + qty   │── │──▶ POST /unload/confirm-unload
        │    (ทำซ้ำจนครบ)      │   │      → UnloadLine: PENDING→CONFIRMED
        │                      │   │      → Session: STEP1→STEP2 ถ้าครบ
        │                      │   │
        │ 4. คืน Pallet         │── │──▶ POST /unload/return-pallet-to-asis
        └──────────────────────┘   │      → Pallet กลับ REPLENISH/AVAILABLE
                                   │      → AGV รับกลับ ASRS
                                   │
        ╔══════════════════════════▼══╗
        ║  PHASE 2: LOAD TO BASKET    ║
        ╚══════════════════════════╤══╝
                                   ▼
                  LoadToBasketScreen
                  ┌─────────────────────────┐
                  │ เข้าหน้า → โหลดรายการ    │── GET  /basket/unloaded-items
                  │                         │
                  │ สแกน Part → ใส่ Basket  │── POST /basket/load
                  │ → กรอกจำนวน             │       → UnloadLine: CONFIRMED→LOADED
                  │ → ทำซ้ำจนหมด            │       → สร้าง Basket ถ้ายังไม่มี
                  └─────────────────────────┘
```

---

## 🔑 Prerequisite — Pallet เข้า Replenishment ได้ยังไง?

Replenishment **ไม่ได้สร้าง pallet เอง** — pallet มาจาก `Putaway for Receive`:

| ขั้น | สิ่งที่เกิดขึ้น |
| --- | --- |
| 1 | Putaway flow: user เลือก destination = `REPLENISH` |
| 2 | `POST /putaway/confirm` สร้าง PutawaySession |
| 3 | ASRS/simulation พา pallet ไปถึง station |
| 4 | Backend set `Pallets.Status = REPLENISH`, `Location = REPLENISH` |
| 5 | Pallet โผล่ใน Unload flow ได้ |

> Pallet ต้อง `Status ∈ {REPLENISH, UNLOADING}` เท่านั้นจึงสแกนใน Unload ได้

---

## 🎯 State Machine

### Pallet (`unload.Pallets.Status`)

```
REPLENISH ──open-session──▶ UNLOADING ──return-pallet──┬──▶ REPLENISH  (ยังมีของเหลือ)
                                                       └──▶ AVAILABLE  (ของหมดแล้ว)
```

ตัวพิเศษ: ถ้า `Type=PW` → ต้อง `confirm-labeling` ก่อน (จะเปลี่ยน Type/Status เป็น `FG`)

### UnloadSession (`unload.UnloadSessions.Status`)

```
STEP1 (กำลังหยิบ) ──ทุก line CONFIRMED──▶ STEP2 (พร้อม load)
STEP1/STEP2 ──return-pallet──▶ COMPLETED
```

### UnloadLine (`unload.UnloadLines.Status`)

```
PENDING ──confirm-unload──▶ CONFIRMED ──load to basket (ครบ)──▶ LOADED
PENDING ──return-pallet──▶ CANCELLED   (ยกเลิกเพราะคืน pallet ก่อนเสร็จ)
```

---

# PHASE 1 — UNLOAD

## API 1.1 — สแกน Pallet

| field | value |
| --- | --- |
| **Endpoint** | `GET /unload/scan-pallet/{palletId}` |
| **Screen** | `UnloadSessionSheet._scanPallet()` |
| **API wrapper** | `ApiService.scanPalletForUnload()` |

**ทำอะไร:** ตรวจว่า pallet พร้อม unload ไหม + คืน item ที่อยู่บน pallet

**Validate:**
- Pallet ต้องมีอยู่
- `Status ∈ {REPLENISH, UNLOADING}`

> Pallet ที่ไปถึง REPLENISH มี `Type=FG` เสมอ — Putaway block `Type=PW` ห้ามไป REPLENISH ([PutawayService.cs:124](../../wms-api/WmsApi/WmsApi/Services/Putaway/PutawayService.cs#L124)) และ PW→FG เกิดที่ PW-Station ใน Putaway flow

**Response:**
```json
{
  "palletId": "PLT001",
  "type": "FG",
  "status": "REPLENISH",
  "items": [
    { "partId": "PART001", "lotNumber": "LOT001",
      "qty": 10, "condition": "FG", ... }
  ],
  "message": "..."
}
```

**DB:** อ่านเท่านั้น — `Pallets`, `ReceiptLines (Status=PALLETIZED)`, `Parts`

---

## API 1.2 — เปิด Unload Session

| field | value |
| --- | --- |
| **Endpoint** | `POST /unload/open-session` |
| **Screen** | `UnloadSessionSheet._openSession()` |

**Request:** `{ palletId, operatorId }`

**ทำอะไร (2 สาขา):**

| ถ้า Pallet.Status | Backend ทำ |
| --- | --- |
| `UNLOADING` | **Resume** — หา active session (`Status ∈ {STEP1, STEP2}`) คืนกลับพร้อม `confirmedPartIds` |
| `REPLENISH` | **เปิดใหม่** — สร้าง Session + UnloadLines + เปลี่ยน Pallet เป็น `UNLOADING` |

**Logic เปิดใหม่:**
1. Validate operator มีใน `Users`
2. ดึง `ReceiptLines` ของ pallet → group by PartId
3. ต่อ Part: คำนวณ `remaining = totalOnPallet − alreadyUnloaded` (รอบเดียวกัน วัดจาก `ReceivedAt`)
4. สร้าง `UnloadLine` 1 row ต่อ Part ที่ยังเหลือ (Status=PENDING, qty=remaining)
5. `Pallets.Status = UNLOADING`, `Location = UNLOAD`

**Response:**
```json
{
  "sessionId": 42,
  "palletId": "PLT001",
  "status": "STEP1",
  "items": [ { "partId": "PART001", "qty": 10, ... } ],
  "confirmedPartIds": []
}
```

---

## API 1.3 — Confirm Unload Part (ทำซ้ำต่อ Part)

| field | value |
| --- | --- |
| **Endpoint** | `POST /unload/confirm-unload` |
| **Screen** | `UnloadSessionSheet._confirmScannedPart()` |

**Request:** `{ sessionId, palletId, partId, operatorId, qtyUnloaded }`

**ทำอะไร:** confirm 1 line + จัดการ remainder ถ้าหยิบไม่ครบ + อัปเดต ReceiptLine ถ้าหยิบครบ

**Logic:**
1. หา line `(Status=PENDING)` ตรง sessionId+partId
2. ถ้า `qtyUnloaded` น้อยกว่า qty บน line → split:
   - line เดิม → `Status=CONFIRMED`, `QtyUnloaded=qtyUnloaded`
   - insert line ใหม่ → `Status=PENDING`, `QtyUnloaded=remainder`
3. รวม `previouslyUnloaded + line.QtyUnloaded` — ถ้า ≥ totalOnPallet → `ReceiptLines.Status = UNLOADED` ทุก row ของ Part นั้น
4. ถ้าทุก line ใน session เป็น CONFIRMED → `Session.Status = STEP2`

**Response:**
```json
{ "success": true, "confirmedCount": 2, "totalCount": 3, "allConfirmed": false }
```

> ถ้า `allConfirmed=true` → Flutter เด้งถาม "คืน Pallet?" อัตโนมัติ

---

## API 1.4 — คืน Pallet กลับ ASRS

| field | value |
| --- | --- |
| **Endpoint** | `POST /unload/return-pallet-to-asis` |
| **Screen** | `UnloadSessionSheet._returnPallet()` |

**Request:** `{ palletId, sessionId? }`

**ทำอะไร:** ปิด session + คืน pallet (จะหยิบหมดหรือยังเหลือก็คืนได้)

**Logic:**
1. ถ้ามี `sessionId` → cancel pending lines + ปิด session (`Status=COMPLETED`)
2. ดู `ReceiptLines (Status=PALLETIZED)` ที่เหลือบน pallet:

| มีของเหลือ? | Pallet.Type | Pallet.Status | Pallet.Location |
| --- | --- | --- | --- |
| ✅ ยังเหลือ | จาก ReceiptLine แรก | `REPLENISH` | `REPLENISH` |
| ❌ ของหมด | `null` | `AVAILABLE` | `null` |

**Frontend UX:** เล่น animation 5 วินาทีระหว่างรอ → reset popup ให้สแกน pallet ตัวต่อไป

---

# PHASE 2 — LOAD TO BASKET

## API 2.1 — ดูรายการที่ Unload แล้ว

| field | value |
| --- | --- |
| **Endpoint** | `GET /basket/unloaded-items` |
| **Screen** | `LoadToBasketScreen._loadItems()` |

**ทำอะไร:** list ของที่ Unload แล้ว (CONFIRMED/LOADED) group ตาม **(Owner, PartId, LotNumber)**

**Logic:**
1. ดึง `UnloadLines (Status ∈ {CONFIRMED, LOADED})`
2. รวมยอด `qtyLoaded` จาก `BasketLines (Status=LOADED)` ต่อ line
3. หา `basketId` ของ basket ล่าสุดต่อ unload line
4. Group + sort: เหลือก่อน (`qtyRemaining > 0`) ตามด้วย PartId

**Response (per item):**
```json
{
  "partId": "PART001", "lotNumber": "LOT001",
  "qtyUnloaded": 10, "qtyLoaded": 4, "qtyRemaining": 6,
  "basketId": "BASKET001",
  "unloadLineIds": [12, 13]
}
```

> `unloadLineIds` ใช้ track เพราะ 1 (Part, Lot) อาจกระจายในหลาย UnloadLine

---

## API 2.2 — Load เข้า Basket

| field | value |
| --- | --- |
| **Endpoint** | `POST /basket/load` |
| **Screen** | `LoadToBasketScreen._doLoad()` |

**Request:** `{ partId, lotNumber, basketId, qty, operatorId }`

**ทำอะไร:** กระจาย qty เข้า UnloadLines ของ (Part, Lot) นั้นตามลำดับ `LineId`

**Logic:**
1. ตรวจ `req.Qty ≤ totalRemaining`
2. หา/สร้าง `Basket` (Status=OPEN) ถ้ายังไม่มี
3. Loop UnloadLines ของ (Part, Lot):
   - คำนวณ `lineRemaining = QtyUnloaded − loaded`
   - `take = min(qtyLeft, lineRemaining)`
   - Insert `BasketLine (Status=LOADED, QtyLoaded=take)`
   - ถ้า line เต็มแล้ว → `UnloadLine.Status = LOADED`
   - `qtyLeft -= take`
4. update `Basket.UpdatedAt`

**Response:**
```json
{
  "basketId": "BASKET001", "partId": "PART001",
  "qtyLoaded": 5, "basketLabel": "BASKET001",
  "message": "..."
}
```

---

---

## 📋 TL;DR — ลำดับ API ตาม Flow

| # | จังหวะ | Screen | API | DB หลัก |
| - | --- | --- | --- | --- |
| 1 | สแกน pallet | `UnloadSessionSheet` | `GET /unload/scan-pallet/{id}` | Read: `Pallets`, `ReceiptLines`, `Parts` |
| 2 | เปิด session | `UnloadSessionSheet` | `POST /unload/open-session` | Write: `UnloadSessions`, `UnloadLines`, `Pallets` |
| 3 | confirm part+qty | `UnloadSessionSheet` | `POST /unload/confirm-unload` | Write: `UnloadLines`, `ReceiptLines`, `UnloadSessions` |
| 4 | คืน pallet | `UnloadSessionSheet` | `POST /unload/return-pallet-to-asis` | Write: `UnloadLines`, `UnloadSessions`, `Pallets` |
| 5 | โหลดรายการที่ unload | `LoadToBasketScreen` | `GET /basket/unloaded-items` | Read only |
| 6 | load เข้า basket | `LoadToBasketScreen` | `POST /basket/load` | Write: `Baskets`, `BasketLines`, `UnloadLines` |

---

## 🗂️ ตาราง DB ที่เกี่ยวข้องทั้งหมด

| Schema.Table | บทบาท |
| --- | --- |
| `unload.Pallets` | ทะเบียน pallet + state machine (`REPLENISH`/`UNLOADING`/`AVAILABLE`/`PW`/`FG`) |
| `unload.UnloadSessions` | งาน unload 1 ครั้งต่อ pallet (`STEP1`→`STEP2`→`COMPLETED`) |
| `unload.UnloadLines` | line item ของแต่ละ Part ใน session (`PENDING`→`CONFIRMED`→`LOADED`) |
| `unload.Baskets` | ทะเบียน basket ปลายทาง |
| `unload.BasketLines` | line item ใน basket (link กลับไป UnloadLine) |
| `receiving.ReceiptLines` | ของบน pallet จริง (`PALLETIZED`→`UNLOADED`) |
| `master.Parts` | ข้อมูล part (Owner, Brand, ItemDesc, ImageUrl) |
| `master.Users` | validate operatorId ตอนเปิด session |

---

## 📁 Source Files

**Flutter**
- `lib/screens/unload/unload_menu/unload_menu_screen.dart` — menu
- `lib/screens/unload/unload_screen.dart` — station picker
- `lib/screens/unload/unload_session/unload_session_sheet.dart` — Phase 1 popup
- `lib/screens/unload/load_to_basket/load_to_basket_screen.dart` — Phase 2
- `lib/services/api/unload_api.dart`, `lib/services/api/basket_api.dart`

**Backend**
- `Controllers/UnloadController.cs`, `Controllers/BasketController.cs`
- `Services/Unload/UnloadService.cs`, `Services/Basket/BasketService.cs`
- `DTOs/Unload/UnloadDtos.cs`, `DTOs/Basket/BasketDtos.cs`

**Base URL** — resolve ใน `ApiService._resolveBase()` + ต่อ `/api`
- Android emulator: `http://10.0.2.2:5000/api`
- Desktop: `http://localhost:5000/api`
- LAN fallback: `http://192.168.1.124:5000/api`
