# Putaway for Prework API Flow Report

เอกสารนี้สรุป API ที่ Flutter ใช้ในหัวข้อ **Putaway for Prework** โดยเรียงตาม Flow การใช้งานจริงของแอพ และระบุ DB table/column ที่ backend เกี่ยวข้องกับ API แต่ละเส้น

อ้างอิง Flutter:

- API wrapper: `lib/services/api/putaway_api.dart`
- หน้าหลัก: `lib/screens/putaway/putaway_prework/putaway_prework_screen.dart`
- Popup receive station: `lib/screens/putaway/putaway_prework/widgets/receive/prework_receive_sheet.dart`
- Popup send station: `lib/screens/putaway/shared/widgets/station/station_sheet.dart`

อ้างอิง backend:

- Controller: `WmsApi/WmsApi/Controllers/PutawayController.cs`
- Service: `WmsApi/WmsApi/Services/Putaway/PutawayService.cs`
- DTO: `WmsApi/WmsApi/DTOs/Putaway/PutawayDtos.cs`
- Auto-cut simulation ที่ทำให้ receive station มี cut items: `WmsApi/WmsApi/Controllers/SimulationController.cs`

Base URL ถูก resolve ใน `ApiService._resolveBase()` แล้วต่อท้าย `/api`

- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- Fallback LAN: `http://192.168.1.124:5000/api`

## Station ใน Flow นี้

Receive side:

- `PW-STN-1`
- `PW-STN-3`
- `PW-STN-5`

Send side:

- `PW-STN-2`
- `PW-STN-4`
- `PW-STN-6`

## Flow ภาพรวม

1. Home กดเมนู **Putaway for Prework**
2. เข้า `PutawayPreworkScreen`
3. แอพเชื่อม SignalR hub `/hubs/putaway`
4. แอพโหลดสถานะ send station ด้วย `GET /putaway/station-status`
5. แอพโหลดสถานะ receive station ด้วย `GET /putaway/prework-station-status`
6. ฝั่ง Receive station แสดง pallet ที่กำลังมา (`IN_TRANSIT`) หรือ pallet ที่ตัดของเสร็จแล้ว (`AVAILABLE`)
7. ถ้า receive station มี pallet ที่ตัดของเสร็จแล้ว ผู้ใช้กด station เพื่อเปิด `PreworkReceiveSheet`
8. ผู้ใช้กดคืน pallet เปล่า
9. แอพเรียก `POST /putaway/prework-return-pallet`
10. ฝั่ง Send station ผู้ใช้กด station แล้วสแกน Pallet ID
11. แอพเรียก `GET /putaway/scan-pallet/{palletId}?stationId={stationId}`
12. ผู้ใช้ยืนยันส่ง pallet กลับ `ASRS`
13. แอพเรียก `POST /putaway/confirm`
14. Backend สร้าง putaway session, update pallet, ส่ง SignalR event แล้ว Flutter refresh สถานะ

## 1. โหลดสถานะ Send Station

### Flutter

- หน้าจอ: `lib/screens/putaway/putaway_prework/putaway_prework_screen.dart`
- Method ที่เรียก: `_loadStationStatus()`
- API wrapper: `ApiService.getStationStatus()`

### API

```http
GET /putaway/station-status
```

### ใช้ทำอะไรในแอพ

- เรียกตอนเข้า `PutawayPreworkScreen`
- ใช้แสดงสถานะ busy ของ send station `PW-STN-2`, `PW-STN-4`, `PW-STN-6`
- ถ้า station มี putaway session ที่ `Status == AGV_DISPATCHED` แอพถือว่า station busy และไม่เปิด popup
- เรียกซ้ำเมื่อมี SignalR event หรือหลัง confirm putaway สำเร็จ

### Response ที่ Flutter ใช้

```json
{
  "items": [
    {
      "stationId": "PW-STN-2",
      "palletId": "PLT001",
      "destination": "ASRS",
      "createdAt": "2026-06-23T09:00:00Z",
      "items": [
        {
          "partId": "PART001",
          "itemDesc": "Item description",
          "qty": 10
        }
      ]
    }
  ]
}
```

### DB ที่เกี่ยวข้อง

#### Read

`putaway.PutawaySessions`

- `Status` ใช้ filter เฉพาะ `AGV_DISPATCHED`
- `StationId` ส่งกลับให้ Flutter map กับ send station card
- `PalletId` ส่งกลับเพื่อแสดง pallet ที่ busy
- `Destination` ส่งกลับเพื่อแสดงปลายทาง
- `CreatedAt` ส่งกลับใน response

`receiving.ReceiptLines`

- `PalletId` ใช้ filter receipt line บน pallet ที่อยู่ใน active putaway sessions
- `Status` ใช้ filter เฉพาะ `PALLETIZED`
- `PartId` ส่งกลับใน item
- `QtyReceived` map เป็น `qty`

`master.Parts`

- `PartId` ใช้ join กับ `receiving.ReceiptLines.PartId`
- `ItemDesc` ส่งกลับใน item

#### Write

- ไม่มี

## 2. โหลดสถานะ Receive Station

### Flutter

- หน้าจอ: `lib/screens/putaway/putaway_prework/putaway_prework_screen.dart`
- Method ที่เรียก: `_loadPreworkStationStatus()`
- API wrapper: `ApiService.getPreworkStationStatus()`

### API

```http
GET /putaway/prework-station-status
```

### ใช้ทำอะไรในแอพ

- เรียกตอนเข้า `PutawayPreworkScreen`
- ใช้แสดงสถานะ receive station `PW-STN-1`, `PW-STN-3`, `PW-STN-5`
- ถ้า `palletStatus == IN_TRANSIT` แอพแสดงว่า pallet กำลังมาถึง และกด popup ไม่ได้
- ถ้ามี `palletId` และ status ไม่ใช่ `IN_TRANSIT` แอพเปิด `PreworkReceiveSheet` ได้
- ใช้ `cutItems` แสดงรายการสินค้าที่ถูกตัดออกจาก pallet แล้ว

### Response ที่ Flutter ใช้

```json
{
  "stations": [
    {
      "stationId": "PW-STN-1",
      "palletId": "PLT001",
      "palletStatus": "AVAILABLE",
      "cutItems": [
        {
          "partId": "PART001",
          "owner": "OWNER",
          "brand": "BRAND",
          "itemDesc": "Item description",
          "imageUrl": "/uploads/part.png",
          "qty": 10,
          "lotNumber": "LOT001",
          "expiredDate": "2026-12-31",
          "condition": "PW",
          "cutAt": "2026-06-23 09:00:00"
        }
      ]
    }
  ]
}
```

### DB ที่เกี่ยวข้อง

#### Read

`unload.Pallets`

- `Location` ใช้ filter เฉพาะ `PW-STN-1`, `PW-STN-3`, `PW-STN-5`
- `Status` ใช้ filter เฉพาะ `IN_TRANSIT`, `PREWORK`, `AVAILABLE`
- `PalletId` ส่งกลับเป็น `palletId`
- `Status` ส่งกลับเป็น `palletStatus`

`putaway.PreworkCutLogs`

- `PalletId` ใช้ filter cut log ของ pallet ที่อยู่ใน receive station
- `StationId` ใช้ filter cut log ให้ตรงกับ receive station
- `CutAt` ใช้ sort ล่าสุด และใช้เลือกกลุ่ม log ล่าสุดในช่วงเวลาประมาณ 5 วินาที
- `PartId` ส่งกลับใน `cutItems`
- `Owner` ส่งกลับใน `cutItems`
- `Brand` ส่งกลับใน `cutItems`
- `ItemDesc` ส่งกลับใน `cutItems`
- `ImageUrl` ส่งกลับใน `cutItems`
- `Qty` ส่งกลับใน `cutItems`
- `LotNumber` ส่งกลับใน `cutItems`
- `ExpiredDate` ส่งกลับใน `cutItems`
- `Condition` ส่งกลับใน `cutItems`

#### Write

- ไม่มีใน API นี้

หมายเหตุ: `putaway.PreworkCutLogs` ถูกเขียนจาก flow อื่น เช่น simulation `POST /simulate/asrs/receive-pallet/{palletId}` เมื่อ pallet ไปถึง destination `PREWORK` แล้ว backend auto-cut receipt lines ออกจาก pallet

## 3. Receive Station: คืน Pallet เปล่า

### Flutter

- หน้าจอ: `lib/screens/putaway/putaway_prework/widgets/receive/prework_receive_sheet.dart`
- Method ที่เรียก: `_returnPallet()`
- API wrapper: `ApiService.preworkReturnPallet(...)`

### API

```http
POST /putaway/prework-return-pallet
```

### Request body

```json
{
  "palletId": "PLT001",
  "stationId": "PW-STN-1"
}
```

### ใช้ทำอะไรในแอพ

- ใช้เมื่อ receive station มี pallet ที่ตัดของเสร็จแล้ว
- ผู้ใช้กด `Return Empty Pallet`
- Backend คืน pallet ให้เป็น pallet ว่าง
- Backend ส่ง SignalR event `PalletReturned`
- Flutter เล่น animation AMR returning และ reload สถานะทั้งหมด

### เงื่อนไขสำคัญใน backend

- Pallet ต้องมีอยู่
- `unload.Pallets.Status` ต้องเป็น `AVAILABLE`
- ถ้า status ไม่ใช่ `AVAILABLE` จะ reject

### Response ที่ Flutter ใช้

Flutter ตรวจแค่ `success/error` จาก `ApiResult<Map<String, dynamic>>`

ตัวอย่าง response สำเร็จ:

```json
{
  "success": true,
  "message": "Pallet 'PLT001' returned (AVAILABLE)"
}
```

### DB ที่เกี่ยวข้อง

#### Read

`unload.Pallets`

- `PalletId` ใช้ค้น pallet
- `Status` ใช้ validate ว่าต้องเป็น `AVAILABLE`

#### Write

`unload.Pallets`

- `Type` update เป็น `null`
- `Status` update เป็น `AVAILABLE`
- `Location` update เป็น `null`
- `UpdatedAt` = current UTC time

## 4. Send Station: สแกน Pallet

### Flutter

- หน้าจอ popup: `lib/screens/putaway/shared/widgets/station/station_sheet.dart`
- เรียกจาก `PutawayPreworkScreen._openStationPopup()` เฉพาะ send station
- Method ที่เรียก: `_scanPallet()`
- API wrapper: `ApiService.scanPalletForPutaway(palletId, stationId: station.id)`

### API

```http
GET /putaway/scan-pallet/{palletId}?stationId={stationId}
```

ตัวอย่าง:

```http
GET /putaway/scan-pallet/PLT001?stationId=PW-STN-2
```

### ใช้ทำอะไรในแอพ

- ใช้กับ send station `PW-STN-2`, `PW-STN-4`, `PW-STN-6`
- ผู้ใช้สแกน pallet ที่ต้องส่งกลับ ASRS
- Flutter ตรวจเพิ่มว่า pallet type ต้องตรงกับ station config `allowedType == PW`
- เพราะ send station มี `fixedDestination == ASRS` แอพไม่ให้เลือก destination อื่น
- หลัง scan สำเร็จ แอพแสดงข้อมูล pallet/items และปุ่มส่ง pallet ไป ASRS

### เงื่อนไขสำคัญใน backend

- ถ้า `stationId` ขึ้นต้นด้วย `PW-STN` backend ถือว่าเป็น prework station
- Pallet ต้องมี `Status == PREWORK`
- ถ้า status ไม่ใช่ `PREWORK` จะ reject

### Response ที่ Flutter ใช้

```json
{
  "palletId": "PLT001",
  "type": "PW",
  "status": "PREWORK",
  "suggestedDestination": "PREWORK",
  "items": [
    {
      "partId": "PART001",
      "owner": "OWNER",
      "brand": "BRAND",
      "itemDesc": "Item description",
      "imageUrl": "/uploads/part.png",
      "lotNumber": "LOT001",
      "expiredDate": "2026-12-31",
      "qty": 10,
      "condition": "PW"
    }
  ],
  "message": "Pallet PW -> แนะนำ Prework"
}
```

Model ที่ map:

- `PutawayPalletInfo`
- `UnloadItem`

### DB ที่เกี่ยวข้อง

#### Read

`unload.Pallets`

- `PalletId` ใช้ค้น pallet
- `Status` ใช้ validate ว่าต้องเป็น `PREWORK` เมื่อ station เป็น `PW-STN-*`
- `Type` ส่งกลับ และ Flutter ใช้ตรวจว่าต้องเป็น `PW`
- `Location` อาจถูกใช้ใน validation branch อื่น แต่สำหรับ `PW-STN-*` หลัก ๆ ตรวจ `Status`

`receiving.ReceiptLines`

- `PalletId` ใช้ filter receipt line บน pallet
- `Status` ใช้ filter เฉพาะ `PALLETIZED`
- `PartId` ส่งกลับใน item
- `LotNumber` ส่งกลับใน item
- `ExpiredDate` ส่งกลับใน item
- `QtyReceived` map เป็น `qty`
- `Condition` ส่งกลับใน item

`master.Parts`

- `PartId` ใช้ join กับ `receiving.ReceiptLines.PartId`
- `Owner` ส่งกลับใน item
- `Brand` ส่งกลับใน item
- `ItemDesc` ส่งกลับใน item
- `ImageUrl` ส่งกลับใน item

#### Write

- ไม่มี

## 5. Send Station: Confirm ส่ง Pallet ไป ASRS

### Flutter

- หน้าจอ popup: `lib/screens/putaway/shared/widgets/station/station_sheet.dart`
- Method ที่เรียก: `_confirmPutaway()`
- API wrapper: `ApiService.confirmPutaway(...)`

### API

```http
POST /putaway/confirm
```

### Request body

```json
{
  "stationId": "PW-STN-2",
  "palletId": "PLT001",
  "destination": "ASRS",
  "operatorId": "USR-001",
  "wrappingRequired": false
}
```

หมายเหตุ:

- `destination` ถูก fix เป็น `ASRS` จาก station config
- เพราะ `stationId` เป็น `PW-STN-*` และ `pallet.Type == "PW"` backend จะแปลง pallet/line จาก `PW` เป็น `FG` อัตโนมัติ (prework เสร็จแล้ว)

### ใช้ทำอะไรในแอพ

- ใช้ส่ง pallet จาก send station กลับเข้า ASRS
- หลังสำเร็จ Flutter ปิด popup และ reload สถานะ
- Backend broadcast SignalR event `StationDispatched`

### เงื่อนไขสำคัญใน backend

- Pallet ต้องมีอยู่
- Pallet status ต้องเป็น `FG`, `PW`, `PREWORK`, หรือ `AVAILABLE`
- ถ้า pallet `Status == AVAILABLE` และ `Location == ASRS` จะ reject
- Operator ต้องมีอยู่ใน `master.Users`
- Destination ต้องเป็น `ASRS`, `PREWORK`, หรือ `REPLENISH`
- `wrappingRequired == true` ใช้ได้กับ `ASRS` เท่านั้น
- ถ้า station มี session `AGV_DISPATCHED` อยู่แล้ว จะ reject ว่า station ไม่ว่าง

### Response ที่ Flutter ใช้

```json
{
  "success": true,
  "palletId": "PLT001",
  "stationId": "PW-STN-2",
  "destination": "ASRS",
  "message": "Pallet 'PLT001' -> ASRS (PW->FG converted)"
}
```

Model ที่ map: `PutawayResult`

### DB ที่เกี่ยวข้อง

#### Read

`unload.Pallets`

- `PalletId` ใช้ค้น pallet
- `Status` ใช้ validate
- `Location` ใช้ validate ว่าอยู่ ASRS แล้วหรือยัง
- `Type` ใช้ตรวจว่าเป็น `PW` เพื่อ convert เป็น `FG`

`master.Users`

- `UserId` ใช้ validate `operatorId`

`putaway.PutawaySessions`

- `StationId` ใช้เช็ค station busy
- `Status` ใช้ filter `AGV_DISPATCHED`
- `PalletId` ใช้สร้าง error message ถ้า station ไม่ว่าง

`receiving.ReceiptLines`

- `PalletId` ใช้ filter line บน pallet ตอน convert
- `Condition` ใช้ filter `PW` แล้ว update เป็น `FG`

#### Write

`putaway.PutawaySessions`

- Insert row ใหม่
- `PalletId` = request `palletId`
- `StationId` = request `stationId` แบบ uppercase
- `Destination` = `ASRS`
- `Status` = `AGV_DISPATCHED`
- `WrappingRequired` = request `wrappingRequired`
- `OperatorId` = request `operatorId`
- `CreatedAt` = current UTC time
- `CompletedAt` ยังเป็น `null` ตอนสร้าง session

`unload.Pallets`

- `Type` update จาก `PW` เป็น `FG` เมื่อ station เป็น `PW-STN-*` และ pallet เดิม `Type=PW`
- `Status` update เป็น `IN_TRANSIT`
- `Location` update เป็น `ASRS`
- `UpdatedAt` = current UTC time

`receiving.ReceiptLines`

- `Condition` update จาก `PW` เป็น `FG` สำหรับ line ที่อยู่บน pallet และ condition เป็น `PW`

`putaway.WrappingSessions`

- Insert เฉพาะเมื่อ `wrappingRequired == true`
- `PutawayId` = putaway session ที่เพิ่งสร้าง
- `PalletId` = request `palletId`
- `Status` = `COMPLETED`
- `CreatedAt` = current UTC time
- `CompletedAt` = current UTC time

## SignalR ที่เกี่ยวข้องกับ Flow

### Flutter

- Service: `lib/services/signalr_service.dart`
- Hub URL: `/hubs/putaway`
- ใช้ใน `PutawayPreworkScreen`

### Events ที่ Flutter ฟัง

- `StationDispatched`
- `PalletArrived`
- `PalletReturned`
- `LabelingCompleted`

### ใช้ในหน้าจออย่างไร

- `StationDispatched`: ถ้าเป็น send station จะ update station card และ reload status; ถ้า destination เป็น `PREWORK` จะ reload receive station status
- `PalletArrived`: reload ทั้ง send/receive status
- `PalletReturned`: ถ้าเป็น receive station จะเล่น return animation แล้ว reload status
- `LabelingCompleted`: reload status ทั้งหมด

## 🧹 Cleanup Log (2026-06-25)

Dead code/field/param ที่เคยอยู่ในเอกสารนี้ถูกลบออกแล้ว:

| ที่เคยมี | จัดการ |
| --- | --- |
| `GET /putaway/prework-pallets` 🧟 | ลบ endpoint + service + Flutter wrapper `getPreworkPallets()` (backend ถูก comment ไว้นานแล้ว + ไม่มีหน้าจอเรียก) |
| `POST /putaway/prework-receive` 🧟 | ลบ endpoint + service + DTO + Flutter wrapper `preworkReceive()` + model `PreworkReceiveResult` |
| `RecallToPreworkRequest` DTO 💀 | ลบ — orphan zero reference |
| `AsisDispatchRequest` DTO 💀 | ลบ — orphan zero reference |
| `PreworkReceiveRequest` / `PreworkReceiveItemResponse` / `PreworkReceiveResponse` DTOs 💀 | ลบ — เคยใช้กับ commented endpoint เท่านั้น |
| `operatorId` ใน `POST /putaway/prework-return-pallet` 💀 | ลบจาก DTO + Flutter wrapper + caller |
| `ConvertToFG` ใน `ConfirmPutawayRequest` 🟡 | ลบ field, hardcode logic ใน service: `PW-Station + Type=PW → auto convert` |

## สรุปลำดับ API ตาม Flow หลัก

| ลำดับ | จังหวะในแอพ | Flutter screen | API | DB หลัก |
| --- | --- | --- | --- | --- |
| 1 | เข้า Putaway for Prework | `PutawayPreworkScreen` | `GET /putaway/station-status` | `putaway.PutawaySessions`, `receiving.ReceiptLines`, `master.Parts` |
| 2 | เข้า Putaway for Prework | `PutawayPreworkScreen` | `GET /putaway/prework-station-status` | `unload.Pallets`, `putaway.PreworkCutLogs` |
| 3 | Receive station คืน pallet เปล่า | `PreworkReceiveSheet` | `POST /putaway/prework-return-pallet` | `unload.Pallets` |
| 4 | Send station สแกน pallet | `StationSheet` | `GET /putaway/scan-pallet/{palletId}?stationId={stationId}` | `unload.Pallets`, `receiving.ReceiptLines`, `master.Parts` |
| 5 | Send station confirm ไป ASRS | `StationSheet` | `POST /putaway/confirm` | `unload.Pallets`, `master.Users`, `putaway.PutawaySessions`, `receiving.ReceiptLines`, `putaway.WrappingSessions` |

## สรุป Field สำคัญที่ Flutter ใช้

### Prework receive station status

- `stationId`
- `palletId`
- `palletStatus`
- `cutItems`
  - `partId`
  - `owner`
  - `brand`
  - `itemDesc`
  - `imageUrl`
  - `qty`
  - `lotNumber`
  - `expiredDate`
  - `condition`
  - `cutAt`

### Send station status

- `stationId`
- `palletId`
- `destination`
- `createdAt`
- `items`

### Putaway pallet info

- `palletId`
- `type`
- `status`
- `suggestedDestination`
- `items`
- `message`

### Putaway result

- `success`
- `palletId`
- `stationId`
- `destination`
- `message`
