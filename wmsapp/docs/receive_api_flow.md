# Receive API Flow

Flow ของ **Receive** — เปิด PO → สแกน Part/Serial → ผูก Pallet — โดยไม่มี session แล้ว

Base URL: `ApiService._resolveBase()` + `/api`
- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- LAN fallback: `http://192.168.1.124:5000/api`

ไฟล์ API หลัก: `lib/services/api/receiving_api.dart`

---

## 🗺️ Flow Map

```
HOME → กดเมนู Receive
   ↓
┌─────────────────────────────────────────────┐
│ ReceivingMenuScreen                         │
│   ├─ "รับเอกสาร"                            │── badge ───▶ GET /receiving/pending-pallet-lines
│   └─ "ค้างการผูก Pallet"                    │
└─────┬───────────────────────────┬───────────┘
      ▼                           ▼
┌──────────────────┐    ┌────────────────────────────────────┐
│ ScanPoScreen     │    │ PendingPalletScreen                │
│ สแกน PO          │    │ ดู line ค้าง + ผูก pallet ย้อนหลัง │
└─────┬────────────┘    │                                    │
      ▼                 │  GET /receiving/pending-pallet-lines
GET /receiving/po/{id}  │  POST /receiving/assign-pallet     │
      ↓                 └────────────────────────────────────┘
  เห็น PO + pendingLines (line ค้างผูก)
      ↓ กด "เริ่มรับสินค้า"
      ▼
┌─────────────────────────────────────────────┐
│ ScanPartScreen                              │
│   • Resume: แสดง pendingLines (ถ้ามี)       │
│   • Scan Part + S/N → POST /receiving/scan-part
│   • Scan Pallet     → POST /receiving/assign-pallet
│   • PO ครบ → backend set PO.Status=RECEIVED + autoClosed=true
└─────────────────────────────────────────────┘
```

**Key change:** ไม่มี **Session** เปิด/ปิด — สแกนได้เลย ใครก็ทำต่อได้

---

## 🎯 State Model

### PO Status
```
OPEN ──scan-part ครั้งแรก──▶ RECEIVING ──ครบ──▶ RECEIVED
                                            └──▶ PARTIAL (ปิด PO แต่ยังไม่ครบ — กรณี OVER/short)
```

### ReceiptLine Status
```
PENDING ──assign-pallet──▶ PALLETIZED ──(downstream: Putaway/Pick)──▶ UNLOADED / PICKING / etc.
```

### POItem Status
```
PENDING ──scan-part บางส่วน──▶ PARTIAL ──ครบ──▶ RECEIVED
                                          └──▶ OVER (รับเกิน)
```

---

## 1. Receiving Menu — โหลด pending pallet badge

| | |
| --- | --- |
| Screen | `ReceivingMenuScreen` |
| Method | `_loadPendingCount()` |
| API | `GET /receiving/pending-pallet-lines` |
| Wrapper | `ApiService.getPendingPalletLines()` |

**ทำอะไร:** นับจำนวน line ที่ Status=PENDING → แสดง badge

**Response:**
```json
{
  "count": 3,
  "lines": [
    {
      "lineId": 99, "poId": "PO001",
      "partId": "PART001", "qtyReceived": 1,
      "condition": "FG", "lotNumber": "LOT001",
      "receivedAt": "2026-06-25T10:00:00"
    }
  ]
}
```

**DB:** Read `ReceiptLines (Status=PENDING)`, `Parts`

---

## 2. Scan PO — ค้นหา PO + pendingLines

| | |
| --- | --- |
| Endpoint | `GET /receiving/po/{poId}` |
| Screen | `ScanPoScreen._scanPO()` |
| Wrapper | `ApiService.getPO(poId)` |

**ทำอะไร:**
- คืน PO + items + supplier
- **+ pendingLines** ของ PO นี้ (สำหรับ resume) — line ที่รับแล้วแต่ยังไม่ผูก pallet

**Response:**
```json
{
  "poId": "PO001",
  "supplierId": "SUP001",
  "supplierName": "Supplier",
  "status": "RECEIVING",
  "items": [ { "partId": "PART001", "qtyOrdered": 10, "qtyReceived": 2, ... } ],
  "pendingLines": [
    { "lineId": 99, "partId": "PART001", "qtyReceived": 1,
      "condition": "FG", "poItemStatus": "PARTIAL", "message": "Resumed" }
  ]
}
```

**DB:** Read `PurchaseOrders`, `POItems`, `Parts`, `ReceiptLines (Status=PENDING, POId=X)`

---

## 3. Start Receiving — เปิด ScanPartScreen ทันที (ไม่มี API call)

| | |
| --- | --- |
| Screen | `ScanPoScreen._startReceiving()` |
| Method | navigate ไป `ScanPartScreen` พร้อม `POResponse` |

**ทำอะไร:**
- ไม่ยิง API — `POResponse` มี `pendingLines` มาแล้วจากขั้น 2
- ScanPartScreen ใช้ `po.pendingLines` แสดง resume list

> ก่อนหน้านี้เคยมี `POST /receiving/open-session` — ลบไปแล้ว เพราะ "เริ่มรับ" ไม่ต้อง commit state ใดๆ

---

## 4. Validate Serial

| | |
| --- | --- |
| Endpoint | `GET /receiving/validate-serial?partId=X&serialNo=Y` |
| Screen | `ScanPartScreen._scanPart()` |
| Wrapper | `ApiService.validateReceivingSerial(...)` |

**ทำอะไร:** ตรวจ S/N มีอยู่ + ยังไม่ถูกใช้

**Response:** `{ valid: true }` (success) / 400 error (มี/ไม่มี/ถูกใช้)

**DB:** Read `PartSerials`

---

## 5. Scan Part — บันทึก line

| | |
| --- | --- |
| Endpoint | `POST /receiving/scan-part` |
| Screen | `ScanPartScreen._confirmPart(...)` |
| Wrapper | `ApiService.scanReceiptPart(...)` |

**Request:**
```json
{
  "poId": "PO001",
  "partId": "PART001",
  "qtyReceived": 2,
  "operatorId": "USR-001",
  "serialNumbers": ["SN-PART001-000001", "SN-PART001-000002"]
}
```

> ไม่มี `sessionId` แล้ว

**Validate:**
- PO ต้องมี + Status ไม่เป็น RECEIVED
- Operator valid + active
- Part อยู่ใน PO
- Serial ครบ + ไม่ซ้ำ + ไม่ถูกใช้
- ไม่มี PENDING line ของ Part นี้ค้างอยู่ (กัน duplicate)

**ทำอะไร:**
1. สร้าง `ReceiptLine (Status=PENDING)` — ผูกกับ Part Serial
2. Update `POItem.QtyReceived/QtyRemaining/Status`
3. ถ้า `PO.Status==OPEN` → เปลี่ยนเป็น `RECEIVING`

**DB Write:** `ReceiptLines`, `POItems`, `PurchaseOrders`, `PartSerials`

---

## 6. Assign Pallet — ผูก line เข้า Pallet

| | |
| --- | --- |
| Endpoint | `POST /receiving/assign-pallet` |
| Screen | `ScanPartScreen._assignToPallet(...)` / `PendingPalletScreen._doAssign(...)` |
| Wrapper | `ApiService.assignPallet(...)` |

**Request:**
```json
{
  "palletId": "PLT001",
  "palletType": "FG",
  "operatorId": "USR-001",
  "lineIds": [99]
}
```

> ไม่มี `sessionId` แล้ว

**Validate:**
- Pallet มี + Status ∈ {AVAILABLE, FG, PW}
- PalletType ตรงกับ Condition ของ lines
- ถ้า Pallet มีของอยู่แล้ว: Condition / Owner / Lot ต้องตรงกัน

**Auto-close:** ถ้า assign แล้วทำให้ PO นี้ครบ (ทุก POItem ∈ {RECEIVED, OVER} + ไม่มี PENDING line เหลือ) → backend set `PO.Status=RECEIVED` + ส่ง `autoClosed=true`

**Response:**
```json
{
  "success": true,
  "palletId": "PLT001", "palletType": "FG",
  "linesAssigned": 1,
  "partsAssigned": ["PART001"],
  "autoClosed": true,
  "poStatus": "RECEIVED",
  "closeMessage": "PO 'PO001' รับสินค้าครบแล้ว"
}
```

**DB Write:** `ReceiptLines`, `Pallets`, `PartSerials`, `PurchaseOrders` (auto-close), `POItems`

---

## 📋 TL;DR

| # | จังหวะ | Screen | API |
| - | --- | --- | --- |
| 1 | เข้าเมนู Receive | `ReceivingMenuScreen` | `GET /receiving/pending-pallet-lines` |
| 2 | สแกน PO | `ScanPoScreen` | `GET /receiving/po/{poId}` |
| 3 | กดเริ่มรับสินค้า | `ScanPoScreen` | — (no API) |
| 4 | สแกน S/N | `ScanPartScreen` | `GET /receiving/validate-serial` |
| 5 | บันทึก line | `ScanPartScreen` | `POST /receiving/scan-part` |
| 6 | ผูก Pallet | `ScanPartScreen` | `POST /receiving/assign-pallet` |
| 7 | refresh ยอด PO | `ScanPartScreen` | `GET /receiving/po/{poId}` |
| 8 | ดู line ค้าง | `PendingPalletScreen` | `GET /receiving/pending-pallet-lines` |
| 9 | ผูก pallet ย้อนหลัง | `PendingPalletScreen` | `POST /receiving/assign-pallet` |

---

## 🧹 Cleanup Log (2026-06-25)

**Refactor ใหญ่: ลบ session model ทั้งหมด**

| ที่เคยมี | จัดการ |
| --- | --- |
| `ReceivingSession` table + model + EF config | 🪓 **ลบทั้งหมด** + migration `RemoveReceivingSession` (drop column + table) |
| `GET /receiving/active-session/{poId}` | 🪓 ลบ (รวมกับ open-session ก่อนหน้าแล้ว ตอนนี้ลบทั้งคู่) |
| `POST /receiving/open-session` | 🪓 ลบ — "เริ่มรับ" navigate ตรงไป ScanPart ไม่ต้อง commit |
| `POST /receiving/close-session/{sessionId}` | 🪓 ลบ — auto-close ผ่าน assign-pallet ทำหน้าที่แทน |
| `ReceiptLine.SessionId` FK + column | 🪓 ลบ (migration drop column + FK) |
| `OpenReceivingRequest/Response`, `CloseReceivingResponse`, `PartialItemSummary` DTOs | 🪓 ลบ |
| `sessionId` ใน `ScanReceiptPartRequest`, `AssignPalletRequest`, `PendingPalletLineResponse` | 🪓 ลบ — ไม่ต้องส่ง |
| Flutter `ReceivingSession` model + `openReceivingSession`/`closeReceivingSession` wrappers | 🪓 ลบ |
| Flutter `PendingPalletLine.sessionId` | 🪓 ลบ |
| `POResponse` | ➕ เพิ่ม `pendingLines` field (รวม resume info) |

**เหตุผล:**
- PO ทำหน้าที่ parent entity อยู่แล้ว (Status: OPEN/RECEIVING/RECEIVED)
- Session ซ้อนซ้อนกับ PO + ขัดกับ pattern handoff/collaborative ของคลังจริง
- Audit ระดับ line (`ReceiptLine.OperatorId`) แม่นยำกว่า session-level audit
- ไม่มี zombie session ค้างอีก

**Behavior หลัง refactor:**
- ไม่มี ceremony เปิด/ปิด — สแกนเมื่อมีของ
- User คนไหนก็สแกน PO เดียวกันต่อได้ (ระดับ line track ใครทำ)
- Auto-close ทำงานเหมือนเดิม (ผ่าน assign-pallet)
- Resume ผ่าน `pendingLines` ใน POResponse แทน session.pendingLines

---

## 🗂️ Source Files

**Flutter**
- `lib/screens/receiving/receiving_menu/receiving_menu_screen.dart`
- `lib/screens/receiving/scan_po/scan_po_screen.dart`
- `lib/screens/receiving/scan_part/scan_part_screen.dart`
- `lib/screens/receiving/pending_pallet/pending_pallet_screen.dart`
- `lib/models/receiving/receiving_models.dart`
- `lib/services/api/receiving_api.dart`

**Backend**
- `Controllers/ReceivingController.cs`
- `Services/Receiving/ReceivingService.cs`, `IReceivingService.cs`
- `Models/Receiving/ReceiptLine.cs`, `PurchaseOrder.cs`, `POItem.cs`
- `DTOs/Receiving/ReceivingDtos.cs`
- `Data/Configurations/Receiving/ReceiptLineConfiguration.cs`
- `Migrations/20260625*_RemoveReceivingSession.cs`
