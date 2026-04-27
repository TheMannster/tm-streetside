-- City car visuals: colours, max perf mods + tint. Runs on each client when the
-- networked vehicle streams in (server sets state; appearance natives are client-only).

if not Config.Modules or not Config.Modules.citycars then return end

local PERFORMANCE_MOD_TYPES = { 11, 12, 13, 15 }

local function clampPalette(n)
    n = tonumber(n) or 0
    if n < 0 then n = 0 end
    if n > 159 then n = 159 end
    return n
end

local function applyVariedColours(veh)
    if Config.CityCars.Vehicle.VariedColours == false then return end

    local spec = Entity(veh).state.tm_streetside_paint
    local p

    if type(spec) == 'string' then
        p = tonumber(spec:match('^(%d+)'))
    end

    if not p then
        p = math.random(0, 159)
    end

    p = clampPalette(p)

    if ClearVehicleCustomPrimaryColour then ClearVehicleCustomPrimaryColour(veh) end
    if ClearVehicleCustomSecondaryColour then ClearVehicleCustomSecondaryColour(veh) end
    -- Secondary matches primary (solid body colour). Pearlescent + wheel stay
    -- at the model default — we do not call SetVehicleExtraColours.
    SetVehicleColours(veh, p, p)
end

local function applyStreetBuild(veh)
    if not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return end

    SetVehicleModKit(veh, 0)
    for _, modType in ipairs(PERFORMANCE_MOD_TYPES) do
        local count = GetNumVehicleMods(veh, modType)
        if count > 0 then
            SetVehicleMod(veh, modType, count - 1, false)
        end
    end

    applyVariedColours(veh)
    SetVehicleWindowTint(veh, 1)
end

local function runWhenVehicleReady(bagName)
    CreateThread(function()
        local deadline = GetGameTimer() + 10000
        local entity = 0

        while entity == 0 or not DoesEntityExist(entity) do
            if GetGameTimer() > deadline then return end
            entity = GetEntityFromStateBagName(bagName)
            Wait(100)
        end

        applyStreetBuild(entity)
    end)
end

AddStateBagChangeHandler('tm_streetside', nil, function(bagName, key, value)
    if value ~= true then return end
    runWhenVehicleReady(bagName)
end)
