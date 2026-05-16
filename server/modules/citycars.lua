-- City cars module (server).
--
-- Spawns a configurable amount of each car model at random parking spots
-- around the city to simulate stealable "hot cars" - normal unlocked
-- vehicles with blank plates that any player can jump in and drive off.
--
-- Behaviour:
--   * Every Config.CityCars.Rotation.Interval ms the city is rotated:
--       - cars that nobody touched are deleted
--       - cars that were sat in or driven away (>StolenDistance) are
--         released - we forget about them and leave them in the world for
--         AdvancedParking to take ownership of
--       - the full per-model maxActive set is then spawned again at fresh
--         random unused locations
--   * That means if maxActive = 1 for a model and a player steals it,
--     no new one appears until the next rotation tick - and at that tick
--     the slot is refilled at a new random spot.
--   * Released cars are NEVER deleted by us.
--
-- Server-side spawning means every player sees the same cars in the same
-- spots (requires OneSync).
--
-- Integration with kiminaze AdvancedParking:
--   AdvancedParking persists any vehicle a player has interacted with.
--   The moment a player sits in one of our cars we mark it as released and
--   never touch it again - so we will never despawn it out from under the
--   parking system.

if not Config.Modules or not Config.Modules.citycars then return end
if not Config.CityCars then
    TM.Log.warn('citycars', 'module enabled but Config.CityCars is missing')
    return
end

-- Each entry: { entity = vehHandle, loc = vec4 }
local activeVehicles = {}

-- Sets tracking what was used last rotation. The next rotation prefers
-- entries NOT in these sets, only falling back to reusing one if there
-- aren't enough fresh options available.
local lastUsedLocations = {}
local lastUsedModels    = {}

-- Released cars we're watching for abandoned-cleanup (only populated when
-- Config.CityCars.Cleanup.PersistReleased is false). Each entry:
--   { entity = vehHandle, abandonedSince = nil | timestamp(ms) }
-- abandonedSince is set the first tick we observe no player nearby and
-- cleared the moment a player gets close again.
local releasedVehicles = {}

-- How close a player has to be to a released car to keep it "alive".
-- Roughly outside normal client render range so we don't yank cars out from
-- under players who can still see them.
local ABANDONED_NEARBY_DISTANCE = 150.0

-- How often the abandoned-cleanup watchdog wakes up.
local ABANDONED_CHECK_INTERVAL_MS = 60 * 1000

-- How often the break-in watchdog polls active cars for occupants. Kept as a
-- fallback when `baseevents` is not running (instant enter events won't fire).
local BREAKIN_CHECK_INTERVAL_MS = 1000

local function locationKey(loc)
    return ('%.2f|%.2f|%.2f'):format(loc.x, loc.y, loc.z)
end

local function shuffled(src)
    local pool = {}
    for i = 1, #src do
        pool[i] = src[i]
    end
    -- Fisher-Yates shuffle
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    return pool
end

-- Returns true if any seat is occupied or the car has moved past
-- StolenDistance from its spawn point.
local function isTouched(entry)
    if not DoesEntityExist(entry.entity) then return true end

    for seat = -1, 4 do
        local ped = GetPedInVehicleSeat(entry.entity, seat)
        if ped and ped ~= 0 then return true end
    end

    local pos    = GetEntityCoords(entry.entity)
    local origin = vector3(entry.loc.x, entry.loc.y, entry.loc.z)
    local maxDist = Config.CityCars.Vehicle.StolenDistance or 10.0
    if #(pos - origin) > maxDist then return true end

    return false
end

-- Walks every player ped looking for one currently sitting in `veh`. Returns
-- (playerSrcId, playerName) on a hit, nil otherwise.
local function findOccupant(veh)
    for _, playerId in ipairs(GetPlayers()) do
        local pid = tonumber(playerId)
        if pid then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 and GetVehiclePedIsIn(ped, false) == veh then
                return pid, GetPlayerName(pid) or 'unknown'
            end
        end
    end
    return nil
end

local function logBreakIn(entry, srcId, name)
    local pos = GetEntityCoords(entry.entity)
    TM.Log.info('citycars',
        ('^1break-in^7 - ^3%s^7 (id ^2%d^7) entered ^2%s^7 at ^2%.1f, %.1f, %.1f^7'):format(
            name, srcId, entry.model or 'unknown', pos.x, pos.y, pos.z))
end

-- When a city car is stolen we log, optionally track it for abandoned cleanup,
-- and remove it from activeVehicles (rotation must not delete it).
local function releaseStolenCityCar(entry, srcId, name)
    logBreakIn(entry, srcId, name)
    if not Config.CityCars.Cleanup.PersistReleased then
        releasedVehicles[#releasedVehicles + 1] = {
            entity = entry.entity,
            abandonedSince = nil,
        }
    end
    local survivors = {}
    for _, e in ipairs(activeVehicles) do
        if e.entity ~= entry.entity then
            survivors[#survivors + 1] = e
        end
    end
    activeVehicles = survivors
end

-- Performance mods + tint are applied on clients (see client/modules/citycars.lua)
-- — those natives are not available on the server.

local function spawnCar(model, loc)
    local hash = (type(model) == 'string') and joaat(model) or model
    local veh = CreateVehicle(hash, loc.x, loc.y, loc.z, loc.w or 0.0, true, false)
    if not veh or veh == 0 then
        -- OneSync commonly cannot create vehicles with nobody connected; avoid noisy WARN spam.
        if #GetPlayers() > 0 then
            TM.Log.warn('citycars', ('failed to spawn %s at %s'):format(tostring(model), locationKey(loc)))
        end
        return nil
    end

    if Config.CityCars.Vehicle.BlankPlates then
        SetVehicleNumberPlateText(veh, '        ')
    end
    SetVehicleDoorsLocked(veh, 2)

    Wait(0)
    for _ = 1, 50 do
        if DoesEntityExist(veh) then
            if Config.CityCars.Vehicle.VariedColours ~= false then
                Entity(veh).state:set('tm_streetside_paint',
                    tostring(math.random(0, 159)), true)
            end
            Entity(veh).state:set('tm_streetside', true, true)
            return veh
        end
        Wait(20)
    end

    return veh
end

local function despawnUntouched()
    local despawned, released, gone = 0, 0, 0
    local watchReleased = not Config.CityCars.Cleanup.PersistReleased

    for _, entry in ipairs(activeVehicles) do
        if not DoesEntityExist(entry.entity) then
            gone = gone + 1
        elseif isTouched(entry) then
            released = released + 1
            -- Rotation used to "release" occupied cars with no log if the
            -- break-in poll hadn't run yet — same message as live detection.
            local srcId, name = findOccupant(entry.entity)
            if srcId then
                logBreakIn(entry, srcId, name)
            end
            if watchReleased then
                releasedVehicles[#releasedVehicles + 1] = {
                    entity = entry.entity,
                    abandonedSince = nil,
                }
            end
        else
            DeleteEntity(entry.entity)
            despawned = despawned + 1
        end
    end
    activeVehicles = {}
    return despawned, released, gone
end

-- Wipe everything we still own (resource stop). Released cars are no longer
-- in activeVehicles so they're never touched here.
local function forceDelete(entity)
    if DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function despawnAll()
    local count = 0
    for _, entry in ipairs(activeVehicles) do
        forceDelete(entry.entity)
        count = count + 1
    end
    activeVehicles = {}
    TM.Log.info('citycars', ('shutdown: deleted ^2%d^7'):format(count))
end

-- Generic "shuffled fresh first, then shuffled reused" pick order. Used for
-- both locations and models so that back-to-back repeats only happen when
-- the pool isn't big enough to avoid them.
local function freshFirstOrder(items, lastUsedSet, keyFn)
    local fresh, reused = {}, {}
    for _, item in ipairs(items) do
        if lastUsedSet[keyFn(item)] then
            reused[#reused + 1] = item
        else
            fresh[#fresh + 1] = item
        end
    end

    fresh  = shuffled(fresh)
    reused = shuffled(reused)

    local order = {}
    for _, item in ipairs(fresh)  do order[#order + 1] = item end
    for _, item in ipairs(reused) do order[#order + 1] = item end
    return order
end

-- Minimum clearance (meters) required at a spawn point. If any existing
-- vehicle is closer than this we skip the spot and try the next one.
local SPAWN_CLEARANCE = 2.5

local function locationOccupied(loc)
    local pool = GetAllVehicles()
    if not pool then return false end
    local origin = vector3(loc.x, loc.y, loc.z)
    for _, veh in ipairs(pool) do
        if DoesEntityExist(veh) then
            if #(GetEntityCoords(veh) - origin) < SPAWN_CLEARANCE then
                return true
            end
        end
    end
    return false
end

-- Full city respawn at fresh random spots. Picks a random subset of models
-- (up to ModelsPerRotation) and spawns a random 1..maxActive count of each.
-- Skips any location that already has a vehicle within SPAWN_CLEARANCE.
local function spawnRound()
    local despawned, released, gone = despawnUntouched()

    local locations = freshFirstOrder(Config.CityCars.Locations, lastUsedLocations, locationKey)
    local models    = freshFirstOrder(Config.CityCars.Vehicles, lastUsedModels, function(v) return v.model end)
    local nextLoc   = 1
    local usedLocsThisRound   = {}
    local usedModelsThisRound = {}

    local pickCount = Config.CityCars.Rotation.ModelsPerRound or #models
    if pickCount > #models then pickCount = #models end

    local function nextFreeLocation()
        while true do
            local loc = locations[nextLoc]
            if not loc then return nil end
            nextLoc = nextLoc + 1
            if locationOccupied(loc) then
                if Config.CityCars.Rotation.LogSkippedSpots then
                    TM.Log.info('citycars',
                        ('skipping ^3%s^7 - vehicle already there'):format(locationKey(loc)))
                end
            else
                return loc
            end
        end
    end

    for i = 1, pickCount do
        local vehCfg = models[i]
        local maxA   = vehCfg.maxActive or 0
        if maxA > 0 then
            usedModelsThisRound[vehCfg.model] = true
            local count = math.random(1, maxA)
            for _ = 1, count do
                local loc = nextFreeLocation()
                if not loc then
                    TM.Log.warn('citycars',
                        'ran out of free locations - add more entries to Config.CityCars.Locations')
                    lastUsedLocations = usedLocsThisRound
                    lastUsedModels    = usedModelsThisRound
                    return despawned, released, gone
                end
                usedLocsThisRound[locationKey(loc)] = true

                local veh = spawnCar(vehCfg.model, loc)
                if veh then
                    activeVehicles[#activeVehicles + 1] = {
                        entity = veh,
                        loc    = loc,
                        model  = vehCfg.model,
                    }
                end
            end
        end
    end

    lastUsedLocations = usedLocsThisRound
    lastUsedModels    = usedModelsThisRound
    return despawned, released, gone
end

-- Boot-time orphan sweep. If a previous instance failed to clean up its
-- cars on shutdown they're still in the world tagged with the
-- `tm_streetside` state bag - delete them before our first rotation runs.
local function sweepOrphans()
    local pool = GetAllVehicles()
    if not pool then return 0 end
    local removed = 0
    for _, veh in ipairs(pool) do
        if Entity(veh).state.tm_streetside then
            forceDelete(veh)
            removed = removed + 1
        end
    end
    if removed > 0 then
        TM.Log.info('citycars', ('boot sweep: removed ^2%d^7 orphan(s) from previous run'):format(removed))
    end
    return removed
end

CreateThread(function()
    Wait(2000)
    sweepOrphans()
    while true do
        local despawned, released, gone = spawnRound()
        TM.Log.info('citycars',
            ('rotated - ^2%d^7 active, ^2%d^7 cleaned, ^3%d^7 released, ^9%d^7 already gone, next in ^2%dm^7'):format(
                #activeVehicles,
                despawned or 0,
                released or 0,
                gone or 0,
                math.floor(Config.CityCars.Rotation.Interval / 60000)))
        Wait(Config.CityCars.Rotation.Interval)
    end
end)

-- Break-in watchdog. Polls the active set as a fallback (see
-- baseevents:enteredVehicle below).
CreateThread(function()
    Wait(4000)
    while true do
        Wait(BREAKIN_CHECK_INTERVAL_MS)

        local survivors = {}

        for _, entry in ipairs(activeVehicles) do
            if not DoesEntityExist(entry.entity) then
                -- already gone, drop it
            else
                local srcId, name = findOccupant(entry.entity)
                if srcId then
                    releaseStolenCityCar(entry, srcId, name)
                else
                    survivors[#survivors + 1] = entry
                end
            end
        end

        activeVehicles = survivors
    end
end)

-- Instant enter detection when the `baseevents` resource is running (default on
-- most Cfx server templates). Client sends netId; resolves to server entity.
-- RegisterNetEvent marks this as an allowed client→server event so the runtime
-- does not log "was not safe for net" when we handle it here.
RegisterNetEvent('baseevents:enteredVehicle')
AddEventHandler('baseevents:enteredVehicle', function(vehicle, _seat, _displayName, netId)
    local src = source
    local veh = 0
    if netId and netId ~= 0 then
        veh = NetworkGetEntityFromNetworkId(netId)
    end
    if veh == 0 or not DoesEntityExist(veh) then
        veh = vehicle
    end
    if veh == 0 or not DoesEntityExist(veh) then return end
    if Entity(veh).state.tm_streetside ~= true then return end

    for _, entry in ipairs(activeVehicles) do
        if entry.entity == veh then
            releaseStolenCityCar(entry, src, GetPlayerName(src) or 'unknown')
            return
        end
    end
end)

-- Returns true if any connected player is within ABANDONED_NEARBY_DISTANCE
-- of the given coords. Used by the watchdog below to decide whether a
-- released car still has someone around it.
local function anyPlayerNear(coords)
    for _, playerId in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(playerId)
        if ped and ped ~= 0 then
            local pPos = GetEntityCoords(ped)
            if #(pPos - coords) <= ABANDONED_NEARBY_DISTANCE then
                return true
            end
        end
    end
    return false
end

-- Abandoned-cleanup watchdog.
-- Only runs when the server has no external persistence resource
-- (Cleanup.PersistReleased = false). Periodically walks every released car:
--   * if the entity is gone, drop it
--   * if a player is nearby, mark it as "not abandoned"
--   * otherwise, start (or continue) an abandoned timer; once it crosses
--     Cleanup.AbandonedMinutes we delete the car so it doesn't stick around
--     forever.
CreateThread(function()
    Wait(5000)
    while true do
        Wait(ABANDONED_CHECK_INTERVAL_MS)

        if Config.CityCars.Cleanup.PersistReleased then
            -- Persistence resource owns these now - drop our list and stop.
            releasedVehicles = {}
            goto continue
        end

        local now = GetGameTimer()
        local maxAbandonedMs = (Config.CityCars.Cleanup.AbandonedMinutes or 30) * 60 * 1000
        local survivors, deleted = {}, 0

        for _, entry in ipairs(releasedVehicles) do
            if not DoesEntityExist(entry.entity) then
                -- car already gone (cleanup, manual delete, etc) - drop it
            else
                local pos = GetEntityCoords(entry.entity)
                if anyPlayerNear(pos) then
                    entry.abandonedSince = nil
                    survivors[#survivors + 1] = entry
                else
                    entry.abandonedSince = entry.abandonedSince or now
                    if (now - entry.abandonedSince) >= maxAbandonedMs then
                        DeleteEntity(entry.entity)
                        deleted = deleted + 1
                    else
                        survivors[#survivors + 1] = entry
                    end
                end
            end
        end

        releasedVehicles = survivors

        if deleted > 0 then
            TM.Log.info('citycars',
                ('cleaned up ^2%d^7 abandoned released car(s) (^2%d^7 still being watched)'):format(
                    deleted, #releasedVehicles))
        end

        ::continue::
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    despawnAll()
end)
