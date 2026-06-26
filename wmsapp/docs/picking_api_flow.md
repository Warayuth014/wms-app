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
┌─────────────────────────────────────────────────┐
│ PickingOrdersListScreen (หน้า 1)                │
│   list orders ที่ WAITING + PICKING             │── GET /picking/orders-list
│   tap order → ไปหน้า 2                          │
└──────┬──────────────────────────────────────────┘
       ▼
┌─────────────────────────────────────────────────┐
│ PickingOrderDetailScreen (หน้า 2)               │
│   pallets + parts ของ order นี้                 │── GET /picking/orders/{id}/detail
│   สแกน source pallet → assign station          │── POST /picking/assign-station
└──────┬──────────────────────────────────────────┘
       ▼
┌─────────────────────────────────────────────────┐
│ PickItemsScreen                                 │
│   • สแกน Part + S/N → pick                      │
│   • สแกน Pallet ปลายทาง                          │── GET /picking/suggest-dest-pallets
│   • ยืนยัน pick                                  │── POST /picking/confirm-pick
│   • ส่ง Pallet ไป Pack                           │── POST /picking/send-to-pack/{id}
│   • คืน Pallet (ASRS / ZONE_PACK)                │── POST /picking/return-pallet
└─────────────────────────────────────────────────┘

Dev/Test panel
   • สร้าง test order                              │── POST /picking/create-test-order
   • Simulate robot arrival                        │── POST /picking/orders/{id}/notify-arrival
   • ดู available lines                            │── GET /picking/available-lines
```

---

## 🎯 State Model

### PickOrder Status
```
WAITING ──robot arrival──▶ PICKING ──ครบ──▶ COMPLETED
```
- `WAITING` = สร้าง order แล้ว แต่ robot ยังไม่ขนของถึง
- `PICKING` = pallet ถึง station แล้ว เริ่ม pick ได้
- `COMPLETED` = pick ครบทุกชิ้น

### Pallet Status (Picking context)
```
STORED ──assign-station──▶ PICKING ──ครบ──▶ PACKED ──send-to-pack──▶ ZONE_PACK
                                              ↓ return-pallet
                                            ASRS (กลับเก็บ)
```

### PickOrderSub Status
```
PENDING ──confirm-pick (บางส่วน)──▶ PICKING ──ครบ──▶ PICKED
```

---

## 1. List Orders (หน้า 1)

| | |
| --- | --- |
| Endpoint | `GET /picking/orders-list` |
| Screen | `PickingOrdersListScreen._load()` |
| Wrapper | `ApiService.getPickOrdersList()` |

**Response:**
```json
{
  "items": [
    {
      "pickOrderId": "PO-20260625-001",
      "status": "PICKING",
      "owner": "TOYOTA",
      "customerOrderId": "CO-...",
      "partCount": 5,
      "totalRequiredQty": 12,
      "palletCount": 2,
      "createdAt": "2026-06-25T08:00:00"
    }
  ]
}
```

**DB:** Read `PickOrders`, `PickOrderDetails`, `PickOrderSubs`, `ReceiptLines`, `Parts`

---

## 2. Order Detail (หน้า 2)

| | |
| --- | --- |
| Endpoint | `GET /picking/orders/{pickOrderId}/detail` |
| Screen | `PickingOrderDetailScreen._load()` |
| Wrapper | `ApiService.getPickOrderDetailFull(id)` |

**Response:** PO detail + pallets + parts breakdown

```json
{
  "pickOrderId": "PO-...",
  "status": "PICKING",
  "owner": "TOYOTA",
  "createdAt": "...",
  "pallets": [
    {
      "palletId": "PAL-001",
      "palletStatus": "PICKING",
      "stationId": "PICK-1",
      "stationName": "Pick Station 1",
      "partCount": 3,
      "totalQty": 8,
      "parts": [ { "partId": "PT-1001", "allocatedQty": 3, "pickedQty": 0, "status": "PENDING" } ]
    }
  ],
  "parts": [ { "partId": "PT-1001", "requiredQty": 3, "reservedQty": 3, "remainingQty": 0, "status": "RESERVED" } ]
}
```

---

## 3. Notify Arrival (Robot simulator)

| | |
| --- | --- |
| Endpoint | `POST /picking/orders/{pickOrderId}/notify-arrival` |
| Screen | `TestPickOrderScreen` (Dev panel) |
| Wrapper | `ApiService.notifyArrival(id)` |

**ทำอะไร:** จำลอง robot ขน pallet ถึง station →
- เปลี่ยน `PickOrder.Status` จาก `WAITING` → `PICKING`
- assign pallet ไป pick station อัตโนมัติ

---

## 4. Suggest Dest Pallet

| | |
| --- | --- |
| Endpoint | `GET /picking/suggest-dest-pallets?pickOrderId={id}` |
| Screen | `PickingDestScanCard` |
| Wrapper | `ApiService.getSuggestedDestPallet(pickOrderId: ...)` |

**ทำอะไร:** แนะนำ pallet ปลายทาง
- ถ้า order มี Packing OPEN อยู่ + pallet ปลายทางยังไม่เต็ม → ส่ง pallet **เดิม** (continued=true) — "ต่อจากเดิม"
- ไม่งั้น → ส่ง pallet ว่างถัดไป (Type=NULL + AVAILABLE)

**Response:**
```json
{
  "items": [
    { "palletId": "PAL-005", "continued": true }
  ]
}
```

---

## 5. Assign Station — สแกน Source Pallet

| | |
| --- | --- |
| Endpoint | `POST /picking/assign-station` |
| Screen | `PickingOrderDetailScreen._scanPallet()` / `PickItemsScreen._scanSourcePallet()` |
| Wrapper | `ApiService.assignPickStation(palletId, pickOrderId)` |

**Request:** `{ palletId, pickOrderId? }`

**ทำอะไร:**
- ตรวจ pallet พร้อม pick (Status ∈ {AVAILABLE, STORED, PICKING})
- หา/assign pick station ว่าง
- คืน `palletItems` (สินค้าบน pallet group ตาม PartId) + `pickOrderItems` (รายการต้อง pick ของ order ทั้งหมด)

**Response:**
```json
{
  "stationId": "PICK-1",
  "stationName": "Pick Station 1",
  "palletId": "PAL-001",
  "pickOrderId": "PO-...",
  "palletItems": [
    { "partId": "PT-1001", "qtyOnPallet": 3, "qtyToPickSuggested": 3,
      "condition": "FG", "availableSerials": ["SN-..."] }
  ],
  "pickOrderItems": [
    { "partId": "PT-1001", "requiredQty": 3, "reservedQty": 3, "remainingQty": 0, "status": "RESERVED" }
  ],
  "message": "..."
}
```

**DB Write:** `Pallets.Status=PICKING`, `Pallets.Location=stationId`, `ReceiptLines.Status=PICKING`, `PickStations.CurrentPalletId`

---

## 6. Confirm Pick

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
  "destPalletId": "PAL-005",
  "items": [
    { "partId": "PT-1001", "qty": 3, "serialNumbers": ["SN-..."] }
  ],
  "operatorId": "USR-001"
}
```

**ทำอะไร:**
1. หัก qty จาก source ReceiptLine + เพิ่ม dest ReceiptLine (Status=PALLETIZED)
2. ย้าย Serial ของแต่ละชิ้นไปยัง dest pallet
3. update `PickOrderSub.PickedQty/Status`
4. ถ้า source pallet หมดทุก line → `Pallets.Status=AVAILABLE`
5. ถ้า order ครบทุกชิ้น → `PickOrder.Status=COMPLETED` + dest pallet `Status=PACKED` + `Location=ZONE_PACK` + auto return source pallets ไป ASRS
6. สร้าง `Packing` entity สำหรับ order (กล่อง pack) — link กับ dest pallet + owner

**Response:**
```json
{
  "isPickOrderComplete": true,
  "sourcePalletEmpty": true,
  "sourcePickDone": true,
  "pickOrderStatus": "COMPLETED",
  "remainingItems": [],
  "message": "..."
}
```

---

## 7. Return Pallet

| | |
| --- | --- |
| Endpoint | `POST /picking/return-pallet` |
| Screen | `PickItemsScreen._returnPallet()` / `TestPickOrderScreen` |
| Wrapper | `ApiService.returnPallet(palletId, destination)` |

**Request:** `{ palletId, destination }` — destination ∈ {"ASRS", "ZONE_PACK"}

**ทำอะไร:** ส่ง pallet กลับไปที่ destination ที่ระบุ — clear station

---

## 8. Send to Pack

| | |
| --- | --- |
| Endpoint | `POST /picking/send-to-pack/{palletId}` |
| Screen | `PickItemsScreen._sendToPack()` |
| Wrapper | `ApiService.sendToPack(palletId: ...)` |

**ทำอะไร:** ส่ง pallet ที่ `Status=PACKED` ไป `Location=ZONE_PACK`
- Validate: `Pallet.Status==PACKED`
- Update `Location=ZONE_PACK`

---

## 9. Dev/Test endpoints

### Available Lines (สำหรับ test panel สร้าง order)

| | |
| --- | --- |
| Endpoint | `GET /picking/available-lines` |
| Screen | `TestPickOrderScreen._loadAvailableLines()` |

### Create Test Order

| | |
| --- | --- |
| Endpoint | `POST /picking/create-test-order` |
| Screen | `TestPickOrderScreen._createOrder()` |

**Request:** `{ operatorId, items: [{ lineId, partId, qty }] }`

**ทำอะไร:** สร้าง PickOrder + PickOrderDetail + PickOrderSubs (assign ReceiptLine ตาม lineId)
- เริ่ม `Status=WAITING` — รอ robot
- ใช้สำหรับ Dev/Test ที่ระบุ ReceiptLine ตรงๆ

---

## 📋 TL;DR

| # | จังหวะ | Screen | API |
| - | --- | --- | --- |
| 1 | List orders | `PickingOrdersListScreen` | `GET /picking/orders-list` |
| 2 | Order detail (page 2) | `PickingOrderDetailScreen` | `GET /picking/orders/{id}/detail` |
| 3 | Robot arrival (test) | `TestPickOrderScreen` | `POST /picking/orders/{id}/notify-arrival` |
| 4 | Suggest dest pallet | `PickingDestScanCard` | `GET /picking/suggest-dest-pallets` |
| 5 | Assign source pallet | `PickingOrderDetailScreen`/`PickItemsScreen` | `POST /picking/assign-station` |
| 6 | Confirm pick | `PickItemsScreen` | `POST /picking/confirm-pick` |
| 7 | Return pallet | `PickItemsScreen`/Test | `POST /picking/return-pallet` |
| 8 | Send to pack | `PickItemsScreen` | `POST /picking/send-to-pack/{id}` |
| 9 | Available lines (test) | `TestPickOrderScreen` | `GET /picking/available-lines` |
| 10 | Create test order | `TestPickOrderScreen` | `POST /picking/create-test-order` |

---

## 🧹 Cleanup Log (2026-06-26)

| ที่เคยมี | จัดการ |
| --- | --- |
| `GET /picking/orders` 🧟 | ลบ endpoint + service + interface (pre-2-page legacy) |
| `GET /picking/order/{pickOrderId}` 🧟 | ลบ endpoint + service + interface |
| `POST /picking/create-order` 🧟 | ลบ endpoint + service + interface (Flutter ใช้ create-test-order แทน) |
| `RequestFromAsrsRequest` DTO 💀 | ลบ — orphan zero reference |
| `PickOrderResponse` DTO 💀 | ลบ — ใช้กับ dead endpoints เท่านั้น |
| `PickOrderSubResponse` DTO 💀 | ลบ + เอา `Subs` field ออกจาก `PickOrderDetailResponse` (Flutter ไม่เคยอ่าน) |
| `CreatePickOrderRequest/Response`, `CreatePickOrderItem`, `PickOrderDetailAllocation` DTOs 💀 | ลบ — ผูกกับ dead endpoint |
| `OperatorId` ใน `AssignPickStationRequest` 💀 | ลบ — validate empty เฉยๆ ไม่ได้ lookup/write DB |
| `BuildPickOrderResponse` helper | ลบ — ใช้กับ methods ที่ตาย |
| Flutter `PickOrder` + `PickOrderSub` models 💀 | ลบ — ใช้กับ endpoint ที่ตายเท่านั้น |
| `PickOrderDetail.subs` field | ลบ — ไม่เคยอ่าน |
| `operatorId` param ใน `assignPickStation` wrapper + 3 callers | ลบ |
| `PickingSessionScreen` body 150 บรรทัด | refactor เป็น clean redirect — เหลือ initState + minimal Scaffold |
| `picking_scan_card.dart` widget file | ลบ — ใช้แค่ใน PickingSessionScreen body ที่ตาย |

---

## 🗂️ Source Files

**Flutter**
- `lib/screens/picking/picking_session/picking_session_screen.dart` (redirect)
- `lib/screens/picking/orders_list/picking_orders_list_screen.dart` (หน้า 1)
- `lib/screens/picking/order_detail/picking_order_detail_screen.dart` (หน้า 2)
- `lib/screens/picking/pick_items/pick_items_screen.dart` (pick UI)
- `lib/models/picking/picking_models.dart`
- `lib/services/api/picking_api.dart`

**Backend**
- `Controllers/PickingController.cs`
- `Services/Picking/PickingService.cs`, `IPickingService.cs`
- `DTOs/Picking/PickingDtos.cs`
