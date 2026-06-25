# Receive API Flow Report

เอกสารนี้สรุป API ที่ Flutter ใช้ในหัวข้อ **Receive** โดยเรียงตาม Flow การใช้งานจริงของแอพ

Base URL ถูก resolve ใน `ApiService._resolveBase()` แล้วต่อท้าย `/api`

- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- Fallback LAN: `http://192.168.1.124:5000/api`

ไฟล์ API หลัก: `lib/services/api/receiving_api.dart`

## Flow ภาพรวม

1. Home กดเมนู **Receive**
2. เข้า `ReceivingMenuScreen`
3. แอพดึงรายการรับแล้วค้างผูก Pallet เพื่อแสดงจำนวน badge
4. ผู้ใช้เลือกเมนู **รับเอกสาร**
5. เข้า `ScanPoScreen`
6. ผู้ใช้สแกน/กรอก PO Number
7. แอพดึงข้อมูล PO และรายการสินค้าใน PO
8. ผู้ใช้กดเริ่มรับสินค้า
9. แอพเช็คว่ามี Receiving Session ที่เปิดค้างอยู่ไหม
10. ถ้าไม่มี session ค้าง แอพเปิด Receiving Session ใหม่
11. เข้า `ScanPartScreen`
12. ผู้ใช้สแกน Part ID และ Serial Number
13. แอพ validate serial
14. ผู้ใช้บันทึกรายการรับเข้า
15. แอพสร้าง receipt line
16. ผู้ใช้สแกน Pallet ID เพื่อผูก receipt line เข้ากับ pallet
17. แอพ assign pallet
18. ถ้า backend ส่ง `autoClosed = true` กลับมา แอพแสดงว่าปิด session/จบ PO อัตโนมัติ
19. ถ้ามี line ที่ยังไม่ผูก pallet ผู้ใช้เข้าเมนู **ค้างการผูก Pallet** แล้ว assign ย้อนหลังได้

## 1. Receiving Menu: โหลดรายการค้างผูก Pallet

### Flutter

- หน้าจอ: `lib/screens/receiving/receiving_menu/receiving_menu_screen.dart`
- Method ที่เรียก: `_loadPendingCount()`
- API wrapper: `ApiService.getPendingPalletLines()`

### API

```http
GET /receiving/pending-pallet-lines
```

### ใช้ทำอะไรในแอพ

- เรียกตอนเข้า `ReceivingMenuScreen`
- ใช้นับจำนวนรายการที่รับสินค้าแล้ว แต่ยังไม่ได้ผูก Pallet
- แสดง badge ที่การ์ดเมนู **ค้างการผูก Pallet**
- เรียกซ้ำหลังกลับจากหน้า Scan PO หรือ Pending Pallet เพื่อ refresh จำนวน

### Response ที่ Flutter ใช้

```json
{
  "lines": [
    {
      "lineId": 1,
      "sessionId": 10,
      "poId": "PO001",
      "partId": "PART001",
      "owner": "OWNER",
      "brand": "BRAND",
      "itemDesc": "Item description",
      "imageUrl": "/uploads/part.png",
      "qtyReceived": 1,
      "condition": "FG",
      "lotNumber": "LOT001",
      "receivedAt": "2026-06-23T09:00:00"
    }
  ]
}
```

Model ที่ map: `PendingPalletLine`

## 2. Scan PO: ค้นหา PO

### Flutter

- หน้าจอ: `lib/screens/receiving/scan_po/scan_po_screen.dart`
- Method ที่เรียก: `_scanPO()`
- API wrapper: `ApiService.getPO(poId)`

### API

```http
GET /receiving/po/{poId}
```

ตัวอย่าง:

```http
GET /receiving/po/PO001
```

### ใช้ทำอะไรในแอพ

- ผู้ใช้กรอกหรือสแกน PO Number แล้วกดค้นหา
- แอพแสดงข้อมูล PO, supplier, status และรายการสินค้า
- ถ้า `status == RECEIVED` แอพไม่แสดงปุ่มเริ่มรับสินค้า
- หลังกลับจาก `ScanPartScreen` แอพเรียก API นี้ซ้ำผ่าน `_reloadPO()` เพื่อ refresh ยอดรับล่าสุด
- ใน `ScanPartScreen` เรียกซ้ำผ่าน `_reloadPo()` หลัง assign pallet สำเร็จและยังไม่ auto close

### Response ที่ Flutter ใช้

```json
{
  "poId": "PO001",
  "supplierId": "SUP001",
  "supplierName": "Supplier name",
  "status": "OPEN",
  "createdAt": "2026-06-23T09:00:00",
  "items": [
    {
      "id": 1,
      "partId": "PART001",
      "owner": "OWNER",
      "brand": "BRAND",
      "itemDesc": "Item description",
      "imageUrl": "/uploads/part.png",
      "qtyOrdered": 10,
      "qtyReceived": 2,
      "qtyRemaining": 8,
      "status": "PARTIAL",
      "condition": "FG",
      "lotNumber": "LOT001",
      "expiredDate": "2026-12-31"
    }
  ]
}
```

Model ที่ map:

- `POResponse`
- `POItem`

## 3. Start Receiving: เปิด/Resume Receiving Session

### Flutter

- หน้าจอ: `lib/screens/receiving/scan_po/scan_po_screen.dart`
- Method ที่เรียก: `_startReceiving()`
- API wrapper: `ApiService.openReceivingSession(...)`

### API

```http
POST /receiving/open-session
```

### Request body

```json
{
  "poId": "PO001",
  "operatorId": "USR-001"
}
```

### ใช้ทำอะไรในแอพ

- เรียกเมื่อผู้ใช้กด **เริ่มรับสินค้า**
- Backend ตัดสินใจ resume/create:
  - ถ้ามี OPEN session ของ PO นี้ → คืน session เดิม พร้อม `pendingLines` (รายการที่รับแล้วแต่ยังไม่ผูก Pallet)
  - ถ้าไม่มี → สร้าง session ใหม่, set PO.Status=`RECEIVING`, validate operator
- เมื่อสำเร็จ แอพส่ง `ReceivingSession` และ `POResponse` ไปยัง `ScanPartScreen`

### Response ที่ Flutter ใช้

```json
{
  "sessionId": 10,
  "poId": "PO001",
  "supplierName": "Supplier name",
  "status": "OPEN",
  "pendingLines": [
    {
      "lineId": 99,
      "partId": "PART001",
      "owner": "OWNER",
      "brand": "BRAND",
      "itemDesc": "Item description",
      "imageUrl": "/uploads/part.png",
      "qtyOrdered": 10,
      "qtyReceived": 1,
      "condition": "FG",
      "lotNumber": "LOT001",
      "poItemStatus": "PARTIAL",
      "message": "Resumed"
    }
  ]
}
```

Model ที่ map: `ReceivingSession`

> `pendingLines` ว่างถ้าเป็น session ที่เพิ่งสร้าง / มีรายการถ้า resume

## 4. Scan Part: validate Serial Number

### Flutter

- หน้าจอ: `lib/screens/receiving/scan_part/scan_part_screen.dart`
- Method ที่เรียก: `_scanPart()`
- API wrapper: `ApiService.validateReceivingSerial(...)`

### API

```http
GET /receiving/validate-serial?partId={partId}&serialNo={serialNo}     
```

ตัวอย่าง:

```http
GET /receiving/validate-serial?partId=PART001&serialNo=SN001
```

### ใช้ทำอะไรในแอพ

- เรียกหลังผู้ใช้กรอก/สแกน Part ID และ S/N
- ก่อนเรียก API แอพเช็คฝั่ง Flutter ก่อนว่า:
  - Part ID ต้องไม่ว่าง
  - S/N ต้องไม่ว่าง
  - Part ต้องอยู่ใน PO ปัจจุบัน
  - ถ้ากำลังสแกน serial ของ part หนึ่งอยู่ ต้องไม่สลับไป part อื่นก่อนบันทึกหรือล้างรายการ
  - S/N ต้องไม่ซ้ำกับรายการที่สแกนค้างในหน้าจอ
  - จำนวน serial ที่สแกนต้องไม่เกิน `qtyRemaining` หรือ `qtyOrdered`
- ถ้า validate สำเร็จ แอพเพิ่ม S/N เข้า list และ set qty รับจริงตามจำนวน serial ที่สแกน

### Response ที่ Flutter ใช้

Flutter ตรวจแค่ `success/error` จาก `ApiResult<Map<String, dynamic>>`

ตัวอย่าง response สำเร็จ:

```json
{
  "valid": true
}
```

หมายเหตุ: โครง response ภายในไม่ได้ถูก map เป็น model เฉพาะใน Flutter

## 5. Scan Part: บันทึกรายการรับสินค้า

### Flutter

- หน้าจอ: `lib/screens/receiving/scan_part/scan_part_screen.dart`
- Method ที่เรียก: `_confirmPart(poItem)` หรือ `_saveScannedSerials()`
- API wrapper: `ApiService.scanReceiptPart(...)`

### API

```http
POST /receiving/scan-part
```

### Request body

```json
{
  "sessionId": 10,
  "poId": "PO001",
  "partId": "PART001",
  "qtyReceived": 2,
  "operatorId": "USR-001",
  "serialNumbers": ["SN001", "SN002"]
}
```

### ใช้ทำอะไรในแอพ

- เรียกเมื่อผู้ใช้กดบันทึกหลังสแกน serial ครบตามจำนวนที่ต้องการรับ
- Flutter ส่ง `serialNumbers` เฉพาะเมื่อมีรายการ serial และจำนวน serial ตรงกับ `qtyReceived`
- ถ้า response มี `poItemStatus == OVER` แอพแสดง warning over receiving
- ถ้าสำเร็จ แอพเก็บ receipt line ไว้เป็น `_pendingLine` เพื่อให้ผู้ใช้สแกน Pallet ต่อ
- ถ้า pallet ล่าสุดยังใช้ได้กับ condition เดียวกัน แอพเติม Pallet ID เดิมให้เพื่อยิง assign ต่อได้เร็ว

### Response ที่ Flutter ใช้

```json
{
  "lineId": 99,
  "partId": "PART001",
  "owner": "OWNER",
  "brand": "BRAND",
  "itemDesc": "Item description",
  "imageUrl": "/uploads/part.png",
  "qtyOrdered": 10,
  "qtyReceived": 2,
  "condition": "FG",
  "lotNumber": "LOT001",
  "poItemStatus": "PARTIAL",
  "message": "Received successfully"
}
```

Model ที่ map: `ReceiptLineResponse`

## 6. Scan Pallet: ผูก receipt line เข้ากับ Pallet

### Flutter

- หน้าจอ: `lib/screens/receiving/scan_part/scan_part_screen.dart`
- Method ที่เรียก: `_scanPallet()` แล้วต่อไป `_assignToPallet(...)`
- API wrapper: `ApiService.assignPallet(...)`

### API

```http
POST /receiving/assign-pallet
```

### Request body

```json
{
  "sessionId": 10,
  "palletId": "PLT001",
  "palletType": "FG",
  "operatorId": "USR-001",
  "lineIds": [99]
}
```

### ใช้ทำอะไรในแอพ

- เรียกหลังบันทึกรับสินค้าแล้วมี `_pendingLine`
- `palletType` ใช้ค่าจาก `ReceiptLineResponse.condition`
- `lineIds` เป็นรายการ receipt line ที่ต้องการผูก pallet ปัจจุบัน
- ถ้าสำเร็จ แอพจำ Pallet ID ล่าสุดและ condition ล่าสุดไว้ เพื่อช่วย assign รายการถัดไปที่เป็น type เดียวกัน
- ถ้าสำเร็จและยังไม่ปิด PO/session แอพเรียก `GET /receiving/po/{poId}` เพื่อ refresh ยอดรับ
- ถ้า response ส่ง `autoClosed = true` แอพแสดง dialog จบงานและกลับออกจาก flow

### Response ที่ Flutter ใช้

```json
{
  "autoClosed": true,
  "poStatus": "RECEIVED",
  "closeMessage": "PO received completely"
}
```

หมายเหตุ: Flutter ใช้ field สำคัญคือ:

- `autoClosed`
- `poStatus`
- `closeMessage`

ถ้าไม่มี `autoClosed` หรือเป็น `false` แอพจะอยู่ในหน้า Scan Part ต่อ

## 7. Resume Pending Lines ใน ScanPartScreen

### Flutter

- หน้าจอ: `lib/screens/receiving/scan_part/scan_part_screen.dart`
- Method ที่เกี่ยวข้อง: `_assignResumedLine(line)`
- ข้อมูลตั้งต้นมาจาก `ReceivingSession.pendingLines`

### API ที่เกี่ยวข้อง

ข้อมูล pending line มาจาก response ของ `POST /receiving/open-session` (resume path)

เมื่อผู้ใช้เลือกผูก Pallet จะใช้:

```http
POST /receiving/assign-pallet
```

### ใช้ทำอะไรในแอพ

- ถ้าเปิด session เดิมที่มี line รับแล้วแต่ยังไม่ผูก pallet แอพแสดงรายการใน `ResumedPendingList`
- ถ้า pallet ล่าสุด type ตรงกับ line นั้น แอพ assign ให้เลย
- ถ้าไม่ตรง แอพย้าย line มาเป็น `_pendingLine` แล้วให้ผู้ใช้สแกน Pallet ใหม่

## 8. Pending Pallet Menu: ดูและผูก Pallet ย้อนหลัง

### Flutter

- หน้าจอ: `lib/screens/receiving/pending_pallet/pending_pallet_screen.dart`
- Method ที่เรียกโหลดรายการ: `_load()`
- Method ที่เรียกผูก pallet: `_doAssign(...)`
- API wrapper:
  - `ApiService.getPendingPalletLines()`
  - `ApiService.assignPallet(...)`

### API โหลดรายการ

```http
GET /receiving/pending-pallet-lines
```

### API ผูก Pallet

```http
POST /receiving/assign-pallet
```

### Request body

```json
{
  "sessionId": 10,
  "palletId": "PLT001",
  "palletType": "FG",
  "operatorId": "USR-001",
  "lineIds": [99]
}
```

### ใช้ทำอะไรในแอพ

- ใช้กับเมนู **ค้างการผูก Pallet**
- แอพ group รายการตาม `poId`
- ผู้ใช้เลือก line แล้วกรอก/สแกน Pallet ID
- หลัง assign สำเร็จ แอพ reload pending list ใหม่

## 🧹 Cleanup Log (2026-06-25)

| ที่เคยมี | จัดการ |
| --- | --- |
| `GET /receiving/active-session/{poId}` ♻️ | ยุบรวมกับ `POST /receiving/open-session` — backend ตัดสินใจ resume/create ใน endpoint เดียว (ประหยัด 1 round-trip) |
| `ActiveReceivingSessionResponse` DTO ♻️ | ลบ — รวม shape กับ `OpenReceivingResponse` (เพิ่ม `PendingLines`) |
| `pendingItems` field ใน session response 💀 | ลบ — Flutter ไม่เคยอ่าน (ใช้ `_currentPo.items` จาก PO response แทน) |

## API Wrapper ที่มีแต่ยังไม่ถูกใช้ใน Flow ปัจจุบัน

### Flutter

- ไฟล์: `lib/services/api/receiving_api.dart`
- Method: `ApiService.closeReceivingSession(sessionId)`

### API

```http
POST /receiving/close-session/{sessionId}
```

### สถานะการใช้งานใน Flutter

- ตอนนี้ยังไม่พบจุดเรียกใช้ในหน้าจอ Receive
- Flow ปัจจุบันพึ่งการปิด session จาก backend ผ่าน response ของ `POST /receiving/assign-pallet` โดยดูจาก `autoClosed`

## สรุปลำดับ API ตาม Flow หลัก

| ลำดับ | จังหวะในแอพ | Flutter screen | API |
| --- | --- | --- | --- |
| 1 | เข้าเมนู Receive | `ReceivingMenuScreen` | `GET /receiving/pending-pallet-lines` |
| 2 | สแกน/ค้น PO | `ScanPoScreen` | `GET /receiving/po/{poId}` |
| 3 | กดเริ่มรับสินค้า (เปิด/resume session) | `ScanPoScreen` | `POST /receiving/open-session` |
| 4 | สแกน Part + S/N | `ScanPartScreen` | `GET /receiving/validate-serial?partId={partId}&serialNo={serialNo}` |
| 5 | บันทึกรับสินค้า | `ScanPartScreen` | `POST /receiving/scan-part` |
| 6 | สแกน Pallet เพื่อผูก line | `ScanPartScreen` | `POST /receiving/assign-pallet` |
| 7 | refresh ยอด PO หลัง assign | `ScanPartScreen` | `GET /receiving/po/{poId}` |
| 8 | ดูรายการค้างผูก pallet | `PendingPalletScreen` | `GET /receiving/pending-pallet-lines` |
| 9 | ผูก pallet ย้อนหลัง | `PendingPalletScreen` | `POST /receiving/assign-pallet` |

## สรุป Field สำคัญที่ Flutter ต้องใช้

### PO

- `poId`
- `supplierId`
- `supplierName`
- `status`
- `items`

### PO item

- `id`
- `partId`
- `owner`
- `brand`
- `itemDesc`
- `imageUrl`
- `qtyOrdered`
- `qtyReceived`
- `qtyRemaining`
- `status`
- `condition`
- `lotNumber`
- `expiredDate`

### Receiving session

- `sessionId`
- `poId`
- `supplierName`
- `status`
- `pendingLines`

### Receipt line

- `lineId`
- `partId`
- `owner`
- `brand`
- `itemDesc`
- `imageUrl`
- `qtyOrdered`
- `qtyReceived`
- `condition`
- `lotNumber`
- `poItemStatus`
- `message`

### Pending pallet line

- `lineId`
- `sessionId`
- `poId`
- `partId`
- `owner`
- `brand`
- `itemDesc`
- `imageUrl`
- `qtyReceived`
- `condition`
- `lotNumber`
- `receivedAt`

## หมายเหตุสำหรับคนทำ API

- Flutter คาดว่า response error จะมี `error` หรือ `detail` เพราะ `ApiService._handle()` ใช้สอง field นี้ทำข้อความ error
- ทุก request ใช้ header `Content-Type: application/json`
- `validate-serial` ใช้ query string ไม่ใช่ JSON body
- `assign-pallet` ควรรองรับ `lineIds` เป็น array แม้ตอนนี้ Flutter ส่งทีละ line
- ถ้า backend ต้องการให้แอพจบ session อัตโนมัติหลัง assign pallet ให้ส่ง `autoClosed: true` พร้อม `poStatus` และ `closeMessage`
- ถ้าต้องการให้ผู้ใช้เห็น line ที่รับแล้วแต่ยังไม่ผูก pallet ตอนกลับเข้า session เดิม ให้ส่งรายการนั้นใน `ReceivingSession.pendingLines`
