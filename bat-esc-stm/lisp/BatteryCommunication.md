# Battery communication

## Testing data

### Registration ID:

`712D6A50-349F-4A59-9791-8E8033B8C428`

### SerialNumbers

<table>
  <tr><th>Unit</th><th>SerialNumber</th></tr>
  <tr><td>Battery</td><td>BA8888888</td></tr>
  <tr><td>Board</td><td>BO8888888</td></tr>
  <tr><td>Jet</td><td>JE8888888</td></tr>
  <tr><td>Remote</td><td>RE8888888</td></tr>
</table>

## Endpoints

> All esp endpoints are HTTP only.

### POST: api/esp/batteryStatusUpdate

> This should only happen if the battery has a `registrationId` registered.

This happens very frequently, something like every 5 seconds while the battery is plugged in. This is because the response of this request is how the battery knows that the user has requested to start/stop charging and frequent requests is the only way we can confirm to the user that the charging actually started/stopped.
When not plugged in the frequency can be much lower, perhaps once per hour or even day. The primary purpose of this is to know the current chargelevel as well as the current location.

#### Request

```json
{
	"registrationId": <string>,
	"units": [
		{
      "serialNumber": <string>,
      "chargeLevel": <int>,
      "chargeStatus": <int>,
      "chargeMinutesRemaining": <int>,
      "chargeLimit": <int>,
      "longitude": <double>,
      "latitude": <double>
    }
	]
}
```

<table>
  <tr><th>Property</th><th>Value</th></tr>
  <tr><td>registrationId</td><td>Battery registrationId.</td></tr>
  <tr><td>units</td><td>All the units currently connected to the battery.</td></tr>
  <tr><td>serialNumber</td><td>Serial number of the unit.</td></tr>
  <tr><td>chargeLevel</td><td>Current charge level.</td></tr>
  <tr><td>chargeStatus</td><td>If it's currently disconnected (0), connected (1) or actively charging (2).</td></tr>
  <tr><td>chargeMinutesRemaining</td><td>How long until charge reaches the chargeLimit.</td></tr>
  <tr><td>chargeLimit</td><td>Maximum chargeLevel.</td></tr>
  <tr><td>longitude</td><td>Current longitude position.</td></tr>
  <tr><td>latitude</td><td>Current latitude position.</td></tr>
</table>

#### Response

```json
[
	{
    "registrationId": <string>,
    "hardwareActionId": <int>,
    "hardwareActionTypeId": <int>,
    "date": <dateString>,
    "data": <string>
  }
]
```

<table>
  <tr><th>Property</th><th>Value</th></tr>
  <tr><td>registrationId</td><td>Battery registrationId</td></tr>
  <tr><td>hardwareActionId</td><td>The unique ID of the action, use this to confirm the action in `confirmAction` request.</td></tr>
  <tr><td>hardwareActionTypeId</td><td>The type of action to take, see table below.</td></tr>
  <tr><td>date</td><td>When it's scheduled to happen. Can ignore, it's always in the past.</td></tr>
  <tr><td>data</td><td>Arbitrary data based on the type, see table below.</td></tr>
</table>

<table>
  <tr><th>hardwareActionTypeId</th><th>Description</th><th>Data</th></tr>
  <tr><td>1</td><td>Start charging</td><td>N/A</td></tr>
  <tr><td>2</td><td>Stop charging</td><td>N/A</td></tr>
  <tr><td>3</td><td>Change charge limit</td><td>ChargeLimit</td></tr>
</table>

> Number 4 will be applying firmware but we're not doing that yet.

### POST: api/esp/confirmAction

This confirms to the API that an action (from `batteryStatusUpdate`) that was requested has been processed. E.g. confirm that we started charging.

> An action will keep being returned forever in `batteryStatusUpdate` until it has been confirmed.

#### Request

```json
{
	"registrationId": <string>,
	"hardwareActionId": <int>
}
```

<table>
  <tr><th>Property</th><th>Value</th></tr>
  <tr><td>registrationId</td><td>Battery registrationId.</td></tr>
  <tr><td>hardwareActionId</td><td>Unique ID of the action to complete. From the `batteryStatusUpdate` response.</td></tr>
</table>

#### Response

`204 No Content`

## Postman endpoints to generate actions

> **The below endpoints are all HTTPS!**

### POST: api/hardware/startCharging

#### Request

```json
{ "registrationId": <string> }
```

#### Response

`204 No Content`

### POST: api/hardware/stopCharging

#### Request

```json
{ "registrationId": <string> }
```

#### Response

`204 No Content`

### POST: api/hardware/setChargeLimit

#### Request

```json
{
  "registrationId": <string>,
  "chargeLimit": <int>
}
```

#### Response

`204 No Content`
