# tm-streetside

Modular FiveM resource for parked cars - both the legit kind and the kind people steal.

- **Display vehicles** - locked, frozen showroom cars that spawn when a player gets close.
- **City cars** - ambient stealable cars rotated around random parking spots across the map.

> Made by **themannster**

## Requirements

- **OneSync** (or OneSync Infinity) - city cars are spawned server-side.
- **ox_lib**, **ox_inventory**, **qbx_core**, **mk_vehiclekeys**

## Install

1. Drop `tm-streetside` into your `resources/` folder.
2. Add `ensure tm-streetside` to your `server.cfg`.
3. Edit `config.lua` and restart.
4. Wire the lockpick items to the police gate (see below).

## Config

Everything is in [`config.lua`](./config.lua) - toggle modules, set vehicle lists, rotation timing, parking spots, and the police gate. The `CityCars` block is grouped into `Rotation`, `Vehicle`, `Cleanup`, `Police`, plus the `Vehicles` and `Locations` pools.

## Stealing

City cars spawn locked. Lockpick attempts are gated by the police count - if there aren't enough cops online the lockpick item is cancelled and the player gets a notification. Once stolen, the car is released and left alone.

If you run a persistence resource like **kiminaze AdvancedParking**, set `Config.CityCars.Cleanup.PersistReleased = true` and it'll take ownership of released cars. Otherwise leave it `false` and the script will clean up abandoned cars itself after `Cleanup.AbandonedMinutes`.

## Lockpick wiring (ox_inventory)

Point your lockpick items at our export in `ox_inventory/data/items.lua`:

```lua
['lockpick'] = {
    label = 'Lockpick', weight = 5, stack = false, close = true,
    server = { export = 'tm-streetside.uselockpick' },
},

['advancedlockpick'] = {
    label = 'Advanced Lockpick', weight = 160, stack = false, close = true,
    server = { export = 'tm-streetside.uselockpick' },
},
```

If you have any `CreateUseableItem('lockpick', ...)` block elsewhere that fires `MK_VehicleKeys:Client:UseLockpick`, **delete it** - our export is the single entry point now and forwards to mk_vehiclekeys when the gate passes.

## Exports

| Export | Side | Returns | Notes |
|---|---|---|---|
| `tm-streetside.uselockpick` | server | - | ox_inventory item handler. Wire to lockpick / advancedlockpick. |
| `tm-streetside.useaccesstool` | server | - | Wraps `r14-evidence.accesstool` - blocks it on city cars when no cops are on, otherwise forwards normally. |
| `tm-streetside.CanSteal` | server | `boolean` | True if enough cops are online to allow theft. |
| `tm-streetside.GetOnlineCops` | server | `number` | Count of police that satisfy `Police.Jobs` + `Police.RequireOnDuty`. |

## License

Proprietary (FiveM). Copyright © 2026 TheMannster. All rights reserved.

See [`LICENSE`](./LICENSE) for the full terms: you may run and adapt this resource on your own server; redistribution, substitute forks or mirrors, and commercial use unless the copyright holder has **explicitly agreed in writing** are not allowed. Other resources or packages must not ship copies of these source files—direct end users to **your** official download or channel instead.
