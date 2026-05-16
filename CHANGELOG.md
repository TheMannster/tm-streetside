# Changelog

## [1.3.8]
- City cars: no `failed to spawn` console warnings when the server has no players connected (OneSync cannot create vehicles; rotation summary still logs as before)

## [1.3.7]
- Varied city car paint: one random palette colour with secondary matched to primary; pearlescent and wheel colour no longer overridden (fixes harsh random combos)

## [1.3.6]
- Register `baseevents:enteredVehicle` as a net event in this resource so FiveM does not warn "was not safe for net" when handling break-ins

## [1.3.5]
- City cars get random primary, secondary, pearlescent, and wheel colours each spawn (`Config.CityCars.Vehicle.VariedColours`, default `true`)

## [1.3.4]
- Version check: when your resource version is newer than GitHub, the console now reports a pre-release build instead of implying you are merely “up to date”

## [1.3.3]
- Fixed startup error: `GetNumVehicleMods` / `SetVehicleMod` / `SetVehicleWindowTint` are client-only — city car performance + tint now apply on clients via `tm_streetside` state bag

## [1.3.2]
- Break-in console log is reliable: listens for `baseevents:enteredVehicle` when that resource runs, logs occupied cars during rotation (previously silent if the poll had not run yet), and polls every 1s as a fallback

## [1.3.1]
- City cars spawn with max engine, brakes, transmission, and suspension (per model) and pure black window tint

## [1.3.0]
- Added `Config.CityCars.Rotation.LogSkippedSpots` toggle (default `false`) to silence the per-spot `skipping ... vehicle already there` log on each rotation
- **Breaking:** reorganised `Config.CityCars` into logical sub-tables. Renames:
  - `RotationInterval` -> `Rotation.Interval`
  - `ModelsPerRotation` -> `Rotation.ModelsPerRound`
  - `BlankPlates` -> `Vehicle.BlankPlates`
  - `StolenDistance` -> `Vehicle.StolenDistance`
  - `PersistReleasedCars` -> `Cleanup.PersistReleased`
  - `AbandonedCleanupMinutes` -> `Cleanup.AbandonedMinutes`
  - `PoliceJobs` -> `Police.Jobs`
  - `MinPoliceOnline` -> `Police.MinOnline`
  - `RequireOnDuty` -> `Police.RequireOnDuty`
  - `NotEnoughCopsText` -> `Police.NotEnoughCopsText`

## [1.2.1]
- Removed misleading `failed to delete` / `was deleted by something between spawn and state-tag` warnings - they were false positives from `DoesEntityExist` not stabilising in the same tick as `CreateVehicle` / `DeleteEntity`. Spawn and cleanup were already working correctly
- Shutdown log simplified to a single `deleted N` line

## [1.2.0]
- City cars now spawn locked and tagged with a `tm_streetside` state bag
- Added police gate: lockpicking a city car requires `MinPoliceOnline` cops with one of `PoliceJobs` (on-duty when `RequireOnDuty`)
- New ox_inventory exports `tm-streetside.uselockpick` and `tm-streetside.useaccesstool` (the latter wraps `r14-evidence.accesstool`)
- New helper exports `tm-streetside.CanSteal` and `tm-streetside.GetOnlineCops`
- Boot-time orphan sweep: leftover city cars from a crashed / failed shutdown are cleaned up on next start
- Spawn-clearance check: spots with a vehicle within 2.5m are skipped and logged
- More diagnostic rotation log: now reports despawned, released, and already-gone counts
- Added `ox_lib`, `ox_inventory`, `qbx_core` dependencies

## [1.1.0]
- Added `ModelsPerRotation` - random subset of models picked each rotation
- Added fresh-first picker for both models and locations (avoids back-to-back repeats)
- Added break-in detection - logs to console when a player enters a city car
- Added GitHub-based version check on boot
- Cleaned up config and README

## [1.0.0]
- Initial release
- Display module (showroom cars)
- CityCars module (rotating ambient stealable cars)
