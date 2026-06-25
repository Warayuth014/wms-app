# Putaway for Receive API Flow Report

เอกสารนี้สรุป API ที่ Flutter ใช้ในหัวข้อ **Putaway for Receive** โดยเรียงตาม Flow การใช้งานจริงของแอพ และระบุ DB table/column ที่ backend เกี่ยวข้องกับ API แต่ละเส้น

อ้างอิง Flutter:

- API wrapper: `lib/services/api/putaway_api.dart`
- หน้าหลัก: `lib/screens/putaway/putaway_main/putaway_screen.dart`
- Popup station: `lib/screens/putaway/shared/widgets/station/station_sheet.dart`

อ้างอิง backend:

- Controller: `WmsApi/WmsApi/Controllers/PutawayController.cs`
- Service: `WmsApi/WmsApi/Services/Putaway/PutawayService.cs`
- DTO: `WmsApi/WmsApi/DTOs/Putaway/PutawayDtos.cs`

Base URL ถูก resolve ใน `ApiService._resolveBase()` แล้วต่อท้าย `/api`

- Android emulator: `http://10.0.2.2:5000/api`
- Desktop/non-Android: `http://localhost:5000/api`
- Fallback LAN: `http://192.168.1.124:5000/api`

## Flow ภาพรวม

1. Home กดเมนู **Putaway for Receive**
2. เข้า `PutawayScreen`
3. แอพเชื่อม SignalR hub `/hubs/putaway`
4. แอพโหลดสถานะ station ที่กำลัง dispatch อยู่
5. ผู้ใช้สแกน Station ID หรือกด station card
6. ถ้า station ไม่ busy แอพเปิด `StationSheet`
7. ผู้ใช้สแกน Pallet ID
8. แอพตรวจ pallet และดึง item บน pallet
9. แอพแนะนำ destination จาก type/status ของ pallet
10. ผู้ใช้เลือก destination เช่น `ASRS`, `PREWORK`, `REPLENISH`
11. ถ้า destination เป็น `ASRS` ผู้ใช้เลือกได้ว่าจะผ่าน wrapping หรือไม่
12. ผู้ใช้กดยืนยัน Putaway
13. Backend สร้าง putaway session, update pallet, และส่ง SignalR event
14. แอพปิด popup และ refresh station status

Station ที่ใช้ในเมนูนี้:

- `STN-1`
- `STN-2`
- `STN-3`

## 1. โหลดสถานะ Station

### Flutter

- หน้าจอ: `lib/screens/putaway/putaway_main/putaway_screen.dart`
- Method ที่เรียก: `_loadStationStatus()`
- API wrapper: `ApiService.getStationStatus()`

### API

```http
GET /putaway/station-status
```

### ใช้ทำอะไรในแอพ

- เรียกตอนเข้า `PutawayScreen`
- ใช้ตรวจว่า `STN-1`, `STN-2`, `STN-3` มี Pallet กำลัง dispatch อยู่ไหม
- ถ้า station มี session ค้าง status `AGV_DISPATCHED` แอพถือว่า busy และไม่เปิด popup station
- เรียกซ้ำเมื่อได้รับ SignalR event เช่น `StationDispatched`, `PalletArrived`, `PalletReturned`, `LabelingCompleted`
- เรียกซ้ำหลัง confirm putaway สำเร็จ

### Response ที่ Flutter ใช้

```json
{
  "items": [
    {
      "stationId": "STN-1",
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
- `StationId` ส่งกลับให้ Flutter map กับ station card
- `PalletId` ส่งกลับเพื่อแสดง pallet ที่ busy
- `Destination` ส่งกลับเพื่อแสดงปลายทาง
- `CreatedAt` ส่งกลับเพื่อบอกเวลาที่เริ่ม dispatch

`receiving.ReceiptLines`

- `PalletId` ใช้ filter เฉพาะ pallet ที่อยู่ใน active putaway sessions
- `Status` ใช้ filter เฉพาะ `PALLETIZED`
- `PartId` ส่งกลับในรายการ item
- `QtyReceived` map เป็น `qty`

`master.Parts`

- `PartId` ใช้ join กับ `receiving.ReceiptLines.PartId`
- `ItemDesc` ส่งกลับในรายการ item

#### Write

- ไม่มี

## 2. สแกน Pallet ที่ Station

### Flutter

- หน้าจอ: `lib/screens/putaway/shared/widgets/station/station_sheet.dart`
- Method ที่เรียก: `_scanPallet()`
- API wrapper: `ApiService.scanPalletForPutaway(palletId, stationId: station.id)`

### API

```http
GET /putaway/scan-pallet/{palletId}?stationId={stationId}
```

ตัวอย่าง:

```http
GET /putaway/scan-pallet/PLT001?stationId=STN-1
```

### ใช้ทำอะไรในแอพ

- ผู้ใช้สแกน Pallet ID ใน station popup
- Backend ตรวจว่า pallet พร้อมสำหรับ Putaway หรือไม่
- Backend ดึงสินค้าใน pallet กลับมาให้ Flutter แสดงรายละเอียด
- Flutter set destination เริ่มต้นจาก `suggestedDestination`

### เงื่อนไขสำคัญใน backend

- ถ้า station เป็นกลุ่ม `PW-STN-*` จะต้องรับ pallet ที่ `Status == PREWORK`
- สำหรับ `STN-1/2/3`:
  - ถ้า `Status == AVAILABLE` และ `Location == ASRS` จะ reject เพราะอยู่ใน ASRS แล้ว
  - ต้องมี `Status` เป็น `FG`, `PW`, หรือ `AVAILABLE`
- Backend แนะนำ destination:
  - `Status == AVAILABLE` -> `ASRS`
  - `Type == FG` -> `ASRS`
  - อื่น ๆ เช่น `PW` -> `PREWORK`

### Response ที่ Flutter ใช้

```json
{
  "palletId": "PLT001",
  "type": "FG",
  "status": "FG",
  "suggestedDestination": "ASRS",
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
      "condition": "FG"
    }
  ],
  "message": "Pallet FG -> เก็บเข้า ASRS"
}
```

Model ที่ map:

- `PutawayPalletInfo`
- `UnloadItem`

### DB ที่เกี่ยวข้อง

#### Read

`unload.Pallets`

- `PalletId` ใช้ค้น pallet จาก path param
- `Status` ใช้ validate และส่งกลับ
- `Location` ใช้ validate ว่า pallet อยู่ ASRS แล้วหรือยัง
- `Type` ใช้ validate/แนะนำ destination และส่งกลับ

`receiving.ReceiptLines`

- `PalletId` ใช้ filter line บน pallet
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

## 3. Confirm Putaway

### Flutter

- หน้าจอ: `lib/screens/putaway/shared/widgets/station/station_sheet.dart`
- Method ที่เรียก: `_confirmPutaway()`
- API wrapper: `ApiService.confirmPutaway(...)`

### API

```http
POST /putaway/confirm
```

### Request body

```json
{
  "stationId": "STN-1",
  "palletId": "PLT001",
  "destination": "ASRS",
  "operatorId": "USR-001",
  "wrappingRequired": false
}
```

### ใช้ทำอะไรในแอพ

- เรียกหลังผู้ใช้เลือก destination และกดยืนยัน
- Destination ที่ Flutter ส่งได้ใน flow นี้:
  - `ASRS`
  - `PREWORK`
  - `REPLENISH`
- `wrappingRequired` ใช้ได้เมื่อ destination เป็น `ASRS`
- เมื่อสำเร็จ Flutter ปิด popup และเรียก refresh station status
- Backend ส่ง SignalR event `StationDispatched` ให้ client ทั้งหมด refresh สถานะ

### เงื่อนไขสำคัญใน backend

- Pallet ต้องมีอยู่
- Pallet status ต้องเป็น `FG`, `PW`, `PREWORK`, หรือ `AVAILABLE`
- ถ้า pallet `Status == AVAILABLE` และ `Location == ASRS` จะ reject
- Operator ต้องมีอยู่ใน `master.Users`
- Destination ต้องเป็น `ASRS`, `PREWORK`, หรือ `REPLENISH`
- `FG` ส่งไป `PREWORK` ไม่ได้
- `PW` ส่งไป `REPLENISH` ไม่ได้
- `wrappingRequired == true` ใช้ได้กับ `ASRS` เท่านั้น
- ถ้า station มี `putaway.PutawaySessions.Status == AGV_DISPATCHED` อยู่แล้ว จะ reject ว่า station ไม่ว่าง
- ถ้า destination เป็น `PREWORK` backend จะหา receive station ว่างจาก `PW-STN-1`, `PW-STN-3`, `PW-STN-5`

### Response ที่ Flutter ใช้

```json
{
  "success": true,
  "palletId": "PLT001",
  "stationId": "STN-1",
  "destination": "ASRS",
  "message": "Pallet 'PLT001' -> ASRS"
}
```

Model ที่ map: `PutawayResult`

### DB ที่เกี่ยวข้อง

#### Read

`unload.Pallets`

- `PalletId` ใช้ค้น pallet
- `Status` ใช้ validate
- `Location` ใช้ validate และใช้เช็ค receive station ว่างตอน destination เป็น `PREWORK`
- `Type` ใช้ validate destination และใช้แปลง `PW -> FG` ในบางกรณี

`master.Users`

- `UserId` ใช้ validate `operatorId`

`putaway.PutawaySessions`

- `StationId` ใช้เช็คว่า station เดียวกันมี session busy หรือไม่
- `Status` ใช้ filter `AGV_DISPATCHED`
- `PalletId` ใช้สร้าง error message ถ้า station ไม่ว่าง
- `CreatedAt` ใช้ query session ล่าสุดใน flow อื่น แต่ใน confirm หลักใช้สำหรับข้อมูล session ที่สร้างใหม่

`receiving.ReceiptLines`

- กรณี station เป็น `PW-STN-*` และ pallet เดิม `Type=PW`:
  - `PalletId` ใช้ filter line บน pallet
  - `Condition` ใช้ filter `PW` และ update เป็น `FG`
- กรณี destination เป็น `PREWORK`:
  - `PalletId` ใช้ filter line บน pallet
  - `Status` ใช้ filter `PALLETIZED`
  - `PartId`, `LotNumber`, `ExpiredDate`, `QtyReceived`, `Condition` ใช้สร้าง payload ให้ `ShipXQueue`

`master.Parts`

- กรณี destination เป็น `PREWORK` มีการ include `Part` ตอน query receipt lines
- ใน payload ปัจจุบันไม่ได้ใช้ field จาก `Parts` โดยตรง นอกจาก join/navigation

#### Write

`putaway.PutawaySessions`

- Insert row ใหม่
- `PalletId` = request `palletId`
- `StationId` = request `stationId` แบบ uppercase
- `Destination` = request `destination` แบบ uppercase
- `Status` = `AGV_DISPATCHED`
- `WrappingRequired` = request `wrappingRequired`
- `OperatorId` = request `operatorId`
- `CreatedAt` = current UTC time
- `CompletedAt` ยังเป็น `null` ตอนสร้าง session

`unload.Pallets`

- `Type`
  - ถ้า station เป็น `PW-STN-*` และ pallet type เป็น `PW` จะ update เป็น `FG` อัตโนมัติ
  - สำหรับ `STN-1/2/3` ปกติไม่มีการ convert จาก Flutter flow นี้
- `Status` update เป็น `IN_TRANSIT`
- `Location`
  - ถ้า destination เป็น `PREWORK` จะ update เป็น receive station ที่ backend map ให้ เช่น `PW-STN-1`
  - ถ้า destination เป็น `ASRS` หรือ `REPLENISH` จะ update เป็น destination นั้น
- `UpdatedAt` = current UTC time

`receiving.ReceiptLines`

- เฉพาะกรณี station เป็น `PW-STN-*` และ pallet เดิม `Type=PW`
- `Condition` update จาก `PW` เป็น `FG`

`putaway.WrappingSessions`

- Insert เมื่อ `wrappingRequired == true`
- `PutawayId` = putaway session ที่เพิ่งสร้าง
- `PalletId` = request `palletId`
- `Status` = `COMPLETED`
- `CreatedAt` = current UTC time
- `CompletedAt` = current UTC time

`putaway.ShipXQueue`

- Insert เมื่อ destination เป็น `PREWORK`
- `PutawayId` = putaway session ที่เพิ่งสร้าง
- `PalletId` = request `palletId`
- `Payload` = JSON สำหรับส่ง pallet/items ไป prework station
- `Status` = `QUEUED`
- `CreatedAt` = current UTC time
- `SentAt` ยังเป็น `null`

### Payload ใน `putaway.ShipXQueue.Payload`

เมื่อ destination เป็น `PREWORK` backend สร้าง JSON ประมาณนี้:

```json
{
  "putawayId": 1,
  "palletId": "PLT001",
  "stationId": "PW-STN-1",
  "operatorId": "USR-001",
  "items": [
    {
      "partId": "PART001",
      "lotNumber": "LOT001",
      "expiredDate": "2026-12-31",
      "qty": 10,
      "condition": "PW"
    }
  ]
}
```

## SignalR ที่เกี่ยวข้องกับ Flow

### Flutter

- Service: `lib/services/signalr_service.dart`
- Hub URL: `/hubs/putaway`
- ใช้ใน `PutawayScreen`

### Events ที่ `PutawayScreen` ฟัง

- `StationDispatched`
- `PalletArrived`
- `PalletReturned`
- `LabelingCompleted`

### Event ที่ confirm putaway ส่งจาก backend

หลัง `POST /putaway/confirm` สำเร็จ backend broadcast:

```json
{
  "stationId": "STN-1",
  "palletId": "PLT001",
  "destination": "ASRS"
}
```

Flutter ใช้ event นี้เพื่อ update station card แบบเร็ว แล้วเรียก `GET /putaway/station-status` ซ้ำเพื่อ sync ข้อมูลจริงจาก DB

## สรุปลำดับ API ตาม Flow หลัก

| ลำดับ | จังหวะในแอพ | Flutter screen | API | DB หลัก |
| --- | --- | --- | --- | --- |
| 1 | เข้า Putaway for Receive | `PutawayScreen` | `GET /putaway/station-status` | `putaway.PutawaySessions`, `receiving.ReceiptLines`, `master.Parts` |
| 2 | สแกน/ค้น Pallet | `StationSheet` | `GET /putaway/scan-pallet/{palletId}?stationId={stationId}` | `unload.Pallets`, `receiving.ReceiptLines`, `master.Parts` |
| 3 | ยืนยัน Putaway | `StationSheet` | `POST /putaway/confirm` | `unload.Pallets`, `master.Users`, `putaway.PutawaySessions`, `receiving.ReceiptLines`, `putaway.WrappingSessions`, `putaway.ShipXQueue` |
| 4 | หลัง confirm หรือ SignalR | `PutawayScreen` | `GET /putaway/station-status` | `putaway.PutawaySessions`, `receiving.ReceiptLines`, `master.Parts` |

## สรุป Field สำคัญที่ Flutter ใช้

### Station status

- `stationId`
- `palletId`
- `destination`
- `createdAt`
- `items`
  - `partId`
  - `itemDesc`
  - `qty`

### Putaway pallet info

- `palletId`
- `type`
- `status`
- `suggestedDestination`
- `items`
- `message`

### Pallet item

- `partId`
- `owner`
- `brand`
- `itemDesc`
- `imageUrl`
- `lotNumber`
- `expiredDate`
- `qty`
- `condition`

### Putaway result

- `success`
- `palletId`
- `stationId`
- `destination`
- `message`

## API ใน `putaway_api.dart` ที่ไม่อยู่ในเมนู Putaway for Receive หลัก

ไฟล์ `lib/services/api/putaway_api.dart` ยังมี API ของ **Putaway for Prework** ด้วย แต่ไม่ได้อยู่ในเมนู `Putaway for Receive` จากหน้า Home card นี้:

- `GET /putaway/prework-station-status`
- `POST /putaway/prework-return-pallet`

ดูรายละเอียดที่ [`putaway_prework_api_flow.md`](putaway_prework_api_flow.md)

## 🧹 Cleanup Log (2026-06-25)

| ที่เคยมี | จัดการ |
| --- | --- |
| `ConvertToFG` ใน `ConfirmPutawayRequest` 🟡 | ลบ field, hardcode logic ใน service: `PW-Station + Type=PW → auto convert` |
