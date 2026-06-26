# Picking API Flow

Flow ของ **Picking** — 2-page navigation: รายการ Order → รายละเอียด Pallets → สแกน Pick

Base URL: `ApiService._resolveBase()` + `/api`
- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- LAN fallback: `http://192.168.1.124:5000/api`

ไฟล์ API หลัก: `lib/services/api/picking_api.dart`

---

## 🗺️ Flow Map

```
HOME → กดเมนู Picking
   ↓
PickingSessionScreen (redirect — backward-compat)
   ↓ (auto)
┌────────────────────────────────────────────────────┐
│ PickingOrdersListScreen (หน้า 1)                   │
│ Sticky top: summary (Waiting / Picking / รวม)     │── GET /picking/orders-list
│ Middle:     list orders (WAITING + PICKING)        │
│ Sticky bot: Scan Pallet panel                      │── POST /picking/return-pallet
│   └─ scan → popup confirm → ASRS/ZONE_PACK         │── GET /picking/return-pallet-preview
└─────┬──────────────────────────────────────────────┘
      │ tap order PICKING
      ▼
┌────────────────────────────────────────────────────┐
│ PickingOrderDetailScreen (หน้า 2)                  │
│   pallets + parts ของ order นี้                    │── GET /picking/orders/{id}/detail
│   สแกน source pallet → assign station             │── POST /picking/assign-station
└─────┬──────────────────────────────────────────────┘
      ▼
┌────────────────────────────────────────────────────┐
│ PickItemsScreen                                    │
│   • สแกน Part + S/N → pick                         │
│   • สแกน Pallet ปลายทาง (จาก suggest)              │── GET /picking/suggest-dest-pallets
│   • ยืนยัน pick                                     │── POST /picking/confirm-pick
│   • ส่ง Pallet ไป Pack                              │── POST /picking/send-to-pack/{id}
│   • คืน Pallet (ASRS / ZONE_PACK manual chooser)    │── POST /picking/return-pallet
└────────────────────────────────────────────────────┘

Dev/Test panel (TestPickOrderScreen)
   • สร้าง test order                                │── POST /picking/create-test-order
   • Simulate robot arrival                          │── POST /picking/orders/{id}/notify-arrival
   • ดู available lines                              │── GET /picking/available-lines

Simulation (Swagger only — ไม่มี Flutter UI)
   • ส่ง empty pallet ไป Pick Zone                   │── POST /simulate/pallet/send-to-pick/{id}
```

---

## 🎯 State Model

### PickOrder Status
```
WAITING ──robot arrival (notify)──▶ PICKING ──pick ครบ──▶ COMPLETED
```

### Pallet (Picking context) — Source vs Dest

**Source pallet** (จาก ASRS — มีของให้ pick)
```
STORED@ASRS ──assign-station──▶ PICKING@STN-x
                                    │
                                    ▼ (operator scan + เคลีย หลัง pick เสร็จ)
                            AVAILABLE@ASRS (ของหมด)
                            STORED@ASRS    (ยังเหลือของ)
```

**Dest pallet** (รับของที่ pick มา)
```
AVAILABLE@PICK ──confirm-pick──▶ PACKED@PICK ──send-to-pack──▶ PACKED@ZONE_PACK
```

> **สำคัญ:** ระบบไม่ auto-ย้าย pallet หลัง pick เสร็จ — pallet ค้างที่จุด pick จริง จนกว่า operator จะสแกนเพื่อเคลีย/ส่งต่อ

### PickOrderSub Status
```
PENDING ──confirm-pick (บางส่วน)──▶ CONFIRMED ──ครบ──▶ PICKED
```

### Location strings
| Location | ความหมาย |
| --- | --- |
| `ASRS` | คลังเก็บอัตโนมัติ |
| `STN-001`, `STN-002`, ... | Pick Station |
| `PICK` | Pick Zone (จุดวาง pallet เปล่ารอรับของ pick) |
| `ZONE_PACK` | จุดรอ pack |

---

## 1. Orders List (หน้า 1)

| | |
| --- | --- |
| Endpoint | `GET /picking/orders-list` |
| Screen | `PickingOrdersListScreen._load()` |
| Wrapper | `ApiService.getPickOrdersList()` |

**Layout:** sticky summary + scrollable order cards + sticky Scan Pallet panel

**Response:**
```json
{
  "items": [
    {
      "pickOrderId": "TEST-...",
      "status": "PICKING",
      "owner": "TOYOTA",
      "customerOrderId": "CO-...",
      "partCount": 5,
      "totalRequiredQty": 12,
      "palletCount": 2,
      "createdAt": "..."
    }
  ]
}
```

---

## 2. Scan Pallet (preview + confirm popup)

ส่วน sticky bottom ของหน้า Orders List — ใช้ scan pallet เพื่อเคลียจาก station / ส่งไป pack

### 2.1 Preview (no side effect)

| | |
| --- | --- |
| Endpoint | `GET /picking/return-pallet-preview/{palletId}` |
| Screen | `PickingOrdersListScreen._sendPallet()` step 1 |
| Wrapper | `ApiService.previewReturnPallet(palletId)` |

**Response:**
```json
{
  "palletId": "PAL-001",
  "currentStatus": "PICKING",
  "currentLocation": "STN-001",
  "canReturn": true,
  "destination": "ASRS",
  "reason": "Pallet 'PAL-001' Pick เสร็จ — คืนเข้า ASRS"
}
```

**Logic:**
| Pallet.Status | + condition | → canReturn / destination |
| --- | --- | --- |
| `PICKING` | มี PickOrderSub PENDING (ยัง pick ไม่เสร็จ) | ❌ `canReturn=false`, reason `"ยัง pick ไม่เสร็จ"` |
| `PICKING` | ไม่มี PENDING (pick เสร็จแล้ว) | ✅ → `ASRS` |
| `PACKED` | — | ✅ → `ZONE_PACK` |
| `AVAILABLE` | — | ✅ → `ASRS` |

### 2.2 Confirm popup (UI)

หลัง preview ผ่าน → popup แสดงปุ่ม **เดียว** ตาม `destination`:
- `ZONE_PACK` → "ส่งไป ZONE PACK"
- `ASRS` → "ส่งกลับ ASRS"

+ ปุ่ม "ปิด"

### 2.3 Execute

| | |
| --- | --- |
| Endpoint | `POST /picking/return-pallet` |
| Body | `{ "palletId": "PAL-001", "destination": "ASRS" }` |
| Wrapper | `ApiService.returnPallet(palletId, destination?)` |

**Behavior:**
- `Status=PACKED` → แค่เปลี่ยน Location ไป destination + clear station
- `Status=PICKING/AVAILABLE` + ของหมด → `AVAILABLE` + Location=destination
- `Status=PICKING/AVAILABLE` + ยังมีของ → `STORED` + Location=destination (เคสไม่ปกติ)
- ReceiptLines: qty>0 → `PALLETIZED`, qty=0 → `PICKED`

> Backend ยัง validate ป้องกัน source pallet ที่ยัง pick ไม่เสร็จ — ถ้า frontend ข้าม preview มาเรียก execute โดยตรง ก็ยัง reject เหมือนกัน

---

## 3. Order Detail (หน้า 2)

| | |
| --- | --- |
| Endpoint | `GET /picking/orders/{pickOrderId}/detail` |
| Screen | `PickingOrderDetailScreen._load()` |
| Wrapper | `ApiService.getPickOrderDetailFull(id)` |

**Response:** PO detail + pallets + parts breakdown
- `pallets[]` — pallet ที่มีของของ order นี้ + parts ใน pallet
- `parts[]` — สรุปรวมทุก part ของ order (RequiredQty, ReservedQty, RemainingQty)

---

## 4. Notify Arrival (Robot simulator)

| | |
| --- | --- |
| Endpoint | `POST /picking/orders/{pickOrderId}/notify-arrival` |
| Screen | `TestPickOrderScreen._scheduleRobotArrival()` |
| Wrapper | `ApiService.notifyArrival(id)` |

**ทำอะไร:** จำลอง robot ขน pallet ถึง station →
- เปลี่ยน `PickOrder.Status` `WAITING` → `PICKING`
- assign pallet ไป pick station อัตโนมัติ

---

## 5. Suggest Dest Pallet

| | |
| --- | --- |
| Endpoint | `GET /picking/suggest-dest-pallets?pickOrderId={id}` |
| Screen | `PickingDestScanCard` |
| Wrapper | `ApiService.getSuggestedDestPallet(pickOrderId)` |

**Logic:**
- **Branch 1 (continued):** มี Packing OPEN สำหรับ order นี้ + Pallet.Status ≠ PACKED + Pallet.Location = `PICK` → คืน pallet เดิม (`continued=true`)
- **Branch 2 (default):** Pallet ว่างถัดไป — `Status=AVAILABLE` + `Type=null` + `Location=PICK` (top 1 by PalletId)

**Response:**
```json
{
  "items": [
    { "palletId": "PAL-014", "continued": false }
  ]
}
```

> Empty pallet ต้องอยู่ที่ `Location=PICK` ก่อนเท่านั้นถึงจะถูกแนะนำ — ใช้ simulation endpoint ส่งไป

---

## 6. Assign Station — สแกน Source Pallet

| | |
| --- | --- |
| Endpoint | `POST /picking/assign-station` |
| Screen | `PickingOrderDetailScreen._scanPallet()` / `PickItemsScreen._scanSourcePallet()` |
| Wrapper | `ApiService.assignPickStation(palletId, pickOrderId)` |

**Request:** `{ palletId, pickOrderId? }`

**Validate:**
- Pallet พร้อม pick (`Status ∈ {AVAILABLE, STORED, PICKING}`)
- ไม่ใช่ pallet PACKED แล้ว
- หา/assign pick station ว่าง

**Returns:**
- `palletItems` — สินค้าบน pallet (group ตาม PartId; **ลบ SessionId ออกแล้ว**)
- `pickOrderItems` — รายการต้อง pick ของ order ทั้งหมด

**DB Write:** `Pallets.Status=PICKING`, `Pallets.Location=stationId`, `ReceiptLines.Status=PICKING`, `PickStations.CurrentPalletId`

---

## 7. Confirm Pick

| | |
| --- | --- |
| Endpoint | `POST /picking/confirm-pick` |
| Screen | `PickItemsScreen._confirmPick()` |
| Wrapper | `ApiService.confirmPickV2(...)` |

**Request:**
```json
{
  "pickOrderId": "PO-...",
  "sourcePalletId": "PAL-001",
  "destPalletId": "PAL-014",
  "items": [
    { "partId": "PT-1001", "qty": 3, "serialNumbers": ["SN-..."] }
  ],
  "operatorId": "USR-001"
}
```

**Logic:**
1. หัก qty จาก source ReceiptLine + เพิ่ม dest ReceiptLine (`Status=PALLETIZED`)
2. ย้าย Serial ไป dest pallet
3. update `PickOrderSub.PickedQty/Status`
4. ถ้า source pallet หมดของ → `Pallets.Status=AVAILABLE` ใน confirm นี้
5. ตั้ง `destPallet.Status = "PACKED"` ทุกรอบ confirm
6. ถ้า order ครบ → `PickOrder.Status=COMPLETED`
   - ⚠️ **ไม่ auto-ย้าย pallet** — source ค้าง STN, dest ค้าง PICK ต้อง operator สแกนเอง
7. สร้าง `Packing` entity สำหรับ order

---

## 8. Send to Pack

| | |
| --- | --- |
| Endpoint | `POST /picking/send-to-pack/{palletId}` |
| Screen | `PickItemsScreen._sendToPack()` |
| Wrapper | `ApiService.sendToPack(palletId)` |

**ทำอะไร:** ส่ง pallet ที่ `Status=PACKED` ไป `Location=ZONE_PACK`

> ใช้ในหน้า pick. ถ้า scan ที่ Orders List → preview จะคืน `destination=ZONE_PACK` แล้วเรียก `return-pallet` แทน — ผลลัพธ์เหมือนกัน

---

## 9. Dev/Test endpoints

### 9.1 Available Lines
| | |
| --- | --- |
| Endpoint | `GET /picking/available-lines` |
| Screen | `TestPickOrderScreen._loadAvailableLines()` |

### 9.2 Create Test Order
| | |
| --- | --- |
| Endpoint | `POST /picking/create-test-order` |
| Screen | `TestPickOrderScreen._createOrder()` / `_quickCreate()` |

**Request:** `{ operatorId, items: [{ lineId, partId, qty }] }`

**ทำอะไร:** สร้าง PickOrder + PickOrderDetail + PickOrderSubs โดยระบุ ReceiptLine ตรงๆ
- เริ่ม `Status=WAITING` — รอ robot arrival

---

## 10. Simulation (Swagger only)

### 10.1 ส่ง Pallet เปล่าไป Pick Zone

| | |
| --- | --- |
| Endpoint | `POST /simulate/pallet/send-to-pick/{palletId}` |
| Caller | **(ไม่มี Flutter UI — เรียกผ่าน Swagger)** |

**Validate:**
- Pallet มี
- ไม่มี ReceiptLines `PALLETIZED|PICKING` ค้าง (ต้องเปล่าจริง)
- Status ไม่เป็น PICKING

**Set:** `Status=AVAILABLE`, `Location=PICK`, `Type=null`

---

## 📋 TL;DR

| # | จังหวะ | Screen | API | Method |
| - | --- | --- | --- | --- |
| 1 | List orders | `PickingOrdersListScreen` | `/picking/orders-list` | GET |
| 2a | Preview scan pallet | `PickingOrdersListScreen` | `/picking/return-pallet-preview/{id}` | GET |
| 2b | Execute scan pallet | `PickingOrdersListScreen` | `/picking/return-pallet` | POST |
| 3 | Order detail | `PickingOrderDetailScreen` | `/picking/orders/{id}/detail` | GET |
| 4 | Robot arrival (test) | `TestPickOrderScreen` | `/picking/orders/{id}/notify-arrival` | POST |
| 5 | Suggest dest pallet | `PickingDestScanCard` | `/picking/suggest-dest-pallets` | GET |
| 6 | Assign source pallet | `OrderDetail`/`PickItems` | `/picking/assign-station` | POST |
| 7 | Confirm pick | `PickItemsScreen` | `/picking/confirm-pick` | POST |
| 8 | Send to pack | `PickItemsScreen` | `/picking/send-to-pack/{id}` | POST |
| 9 | Return (manual chooser) | `PickItemsScreen` | `/picking/return-pallet` | POST |
| 10 | Available lines (test) | `TestPickOrderScreen` | `/picking/available-lines` | GET |
| 11 | Create test order | `TestPickOrderScreen` | `/picking/create-test-order` | POST |
| 12 | Send pallet to PICK (Swagger) | — | `/simulate/pallet/send-to-pick/{id}` | POST |

**Total 12 endpoints — ไม่มี dead** ทั้งหมดมี caller (UI หรือ Swagger)

---

## 🧹 Cleanup History

### Round 1 (2026-06-26): Remove pre-2-page legacy
| ที่เคยมี | จัดการ |
| --- | --- |
| `GET /picking/orders` 🧟 | ลบ |
| `GET /picking/order/{id}` 🧟 | ลบ |
| `POST /picking/create-order` 🧟 | ลบ |
| `RequestFromAsrsRequest`, `PickOrderResponse`, `PickOrderSubResponse`, `CreatePickOrderRequest/Response`, `CreatePickOrderItem`, `PickOrderDetailAllocation` DTOs 💀 | ลบ |
| `Subs` field ใน `PickOrderDetailResponse` 💀 | ลบ (Flutter ไม่อ่าน) |
| `OperatorId` ใน `AssignPickStationRequest` 💀 | ลบ (validate-only ไม่เขียน DB) |
| Flutter `PickOrder` + `PickOrderSub` models 💀 | ลบ |
| `PickOrderDetail.subs` field | ลบ |
| `PickingSessionScreen` body 150 บรรทัด | refactor เป็น clean redirect |
| `picking_scan_card.dart` widget | ลบ |

### Round 2 (2026-06-26): Pick Zone + Suggest + Return UX

| การเปลี่ยนแปลง | รายละเอียด |
| --- | --- |
| Suggest Branch 1 | เพิ่ม filter `Status != PACKED && Location == "PICK"` (กัน suggest pallet ที่ pack แล้ว) |
| Suggest Branch 2 | เพิ่ม filter `Location == "PICK"` |
| `POST /simulate/pallet/send-to-pick/{id}` | สร้างใหม่ — ส่ง pallet เปล่าไป Location=PICK (validate pallet empty + not PICKING) |
| `ReturnPalletRequest.Destination` | ทำเป็น nullable → backend auto-decide ถ้า null |
| `ReturnPalletAsync` validate | block ถ้า PICKING + มี PickOrderSub PENDING |
| `ReturnPalletAsync` line update | qty=0 → PICKED, qty>0 → PALLETIZED |
| `ConfirmPickAsync` order complete | ลบ auto-set dest Location=ZONE_PACK + ลบ auto-return source ASRS |
| `ReturnSourcePalletsToAsrsAsync` helper | ลบ (ไม่มี caller) |
| `GET /picking/return-pallet-preview/{id}` | สร้างใหม่ — preview destination + canReturn ก่อน execute |
| Scan Pallet panel ใน orders-list | scan → preview → popup confirm (ปุ่มเดียวตาม dest + ปิด) → execute |

---

## 🗂️ Source Files

**Flutter**
- `lib/screens/picking/picking_session/picking_session_screen.dart` (redirect)
- `lib/screens/picking/orders_list/picking_orders_list_screen.dart` (หน้า 1 + Scan Pallet panel)
- `lib/screens/picking/order_detail/picking_order_detail_screen.dart` (หน้า 2)
- `lib/screens/picking/pick_items/pick_items_screen.dart` (pick UI)
- `lib/models/picking/picking_models.dart`
- `lib/services/api/picking_api.dart`

**Backend**
- `Controllers/PickingController.cs`
- `Controllers/SimulationController.cs` (send-to-pick endpoint)
- `Services/Picking/PickingService.cs`, `IPickingService.cs`
- `DTOs/Picking/PickingDtos.cs`
