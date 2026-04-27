Config = {}

-------------------------------------------------------------------------------
-- Global
-------------------------------------------------------------------------------

-- Toggle feature modules. Disabled modules don't load at all.
Config.Modules = {
    display  = true,
    citycars = true,
}

-- Checks GitHub for a newer release on boot and prints the changelog if one
-- exists.
Config.VersionCheck = {
    Enabled = true,
}

-------------------------------------------------------------------------------
-- Display module - static showroom cars
-------------------------------------------------------------------------------
-- Color IDs: https://wiki.rage.mp/index.php?title=Vehicle_Colors
Config.Display = {
    -- Cars only spawn once a player gets within this many meters.
    SpawnDistance = 80.0,

    Vehicles = {
        {
            model  = 'm2',
            coords = vec4(-302.83, -1371.72, 31.44, 82.74),
        },
        {
            model  = 'tempesta',
            coords = vec4(-302.66, -1347.25, 32.6, 87.69),
            color  = {27, 27},
        },
    },
}

-------------------------------------------------------------------------------
-- CityCars module - rotating ambient stealable cars
-------------------------------------------------------------------------------
-- Requires OneSync (cars are spawned server-side).
Config.CityCars = {

    ---------------------------------------------------------------------------
    -- Rotation
    ---------------------------------------------------------------------------
    Rotation = {
        -- How often the city is wiped + respawned at fresh random spots (ms).
        Interval = 10 * 60 * 1000,

        -- How many DIFFERENT models are picked from the Vehicles list each
        -- rotation. Lets you have a big variety pool but only a subset out at
        -- any one time. Capped at #Vehicles and the number of free locations.
        ModelsPerRound = 5,

        -- Log every parking spot that's skipped because a vehicle is already
        -- parked there. Useful for debugging spawn coverage but spammy on
        -- busy servers - leave off unless you need it.
        LogSkippedSpots = false,
    },

    ---------------------------------------------------------------------------
    -- Per-vehicle behaviour
    ---------------------------------------------------------------------------
    Vehicle = {
        -- Overwrite the plate with blank spaces so cars look unregistered.
        BlankPlates = true,

        -- Random GTA palette index (0–159) for body colour; secondary matches
        -- primary. Pearlescent and wheel colour are left at the model default.
        -- Set false to keep each model's default paint.
        VariedColours = true,

        -- A car is "released" (we stop tracking it) once a player sits in it
        -- OR it moves this many meters from its spawn point. Released cars
        -- are left in the world - the freed slot is refilled on the NEXT
        -- rotation.
        StolenDistance = 10.0,
    },

    ---------------------------------------------------------------------------
    -- Released car cleanup
    ---------------------------------------------------------------------------
    Cleanup = {
        -- true  : you have a persistence resource (e.g. kiminaze
        --         AdvancedParking) that will manage released cars - we never
        --         touch them again.
        -- false : we watch released cars ourselves and delete them after
        --         AbandonedMinutes with no player nearby.
        PersistReleased = true,

        -- Only used when PersistReleased = false.
        AbandonedMinutes = 30,
    },

    ---------------------------------------------------------------------------
    -- Police gate
    -- City cars spawn locked. Lockpicking one is blocked unless at least
    -- MinOnline cops (matching one of Jobs) are online. If RequireOnDuty is
    -- true only on-duty cops count.
    ---------------------------------------------------------------------------
    Police = {
        Jobs              = { 'police', 'lscso' },
        MinOnline         = 1,
        RequireOnDuty     = true,
        NotEnoughCopsText = 'The streets are too quiet... maybe try later.',
    },

    ---------------------------------------------------------------------------
    -- Vehicle pool
    -- Per-model upper limit. For each model picked this round, a random
    -- count between 1 and maxActive is spawned - it's a ceiling, not a
    -- fixed amount.
    ---------------------------------------------------------------------------
    Vehicles = {
        { model = 'm2',                   maxActive = 1 },
        { model = 'ToraChargerRedeyeDAWG', maxActive = 1 },
        { model = 'comet3',               maxActive = 1 },
        { model = 'comet5',               maxActive = 1 },
        { model = 'comet6',               maxActive = 1 },
        { model = 'comet7',               maxActive = 1 },
        { model = 'entity2',              maxActive = 1 },
        { model = 'sultanrs',             maxActive = 1 },
        { model = 'btype',                maxActive = 1 },
        { model = 'buffalo4',             maxActive = 1 },
        { model = 'broadway',             maxActive = 1 },
        { model = 'dominator3',           maxActive = 1 },
        { model = 'dominator9',           maxActive = 1 },
        { model = 'gauntlet4',            maxActive = 1 },
        { model = 'vstr',                 maxActive = 1 },
        { model = 'ct5vbw22',             maxActive = 1 },
        { model = 'gstgauntc2',           maxActive = 1 },
    },

    ---------------------------------------------------------------------------
    -- Parking spot pool
    -- Total locations should exceed the sum of all maxActive values so
    -- rotations actually pick different spots.
    ---------------------------------------------------------------------------
    Locations = {
        vec4(906.17, -58.69, 78.76, 60.12),
        vec4(928.74, -101.15, 78.76, 44.37),
        vec4(-216.4, 314.15, 96.95, 187.34),
        vec4(-391.66, 286.58, 84.86, 266.75),
        vec4(-1546.27, -421.35, 41.99, 48.8),
        vec4(-1217.47, -688.75, 25.9, 309.69),
        vec4(52.35, -1617.16, 29.41, 140.38),
        vec4(472.84, -899.37, 35.97, 68.48),
        vec4(228.4, -31.0, 69.72, 161.21),
        vec4(502.99, -610.07, 24.75, 264.3),
        vec4(-670.86, -752.54, 30.79, 184.71),
        vec4(-1526.35, -552.09, 33.31, 215.36),
        vec4(-1791.57, -499.78, 38.77, 299.97),
        vec4(-1228.91, -1231.39, 6.6, 20.92),
        vec4(-1519.54, -887.58, 9.68, 37.0),
        vec4(-2015.94, -335.01, 47.67, 238.57),
        vec4(-1981.87, -308.39, 47.67, 55.82),
        vec4(-1573.66, -285.17, 47.84, 318.15),
        vec4(-1304.55, -221.62, 46.61, 300.29),
        vec4(-185.03, 171.41, 69.89, 174.24),
        vec4(174.69, -1643.62, 28.86, 120.62),
        vec4(-139.14, -590.75, 31.99, 65.02),
        vec4(485.16, -1083.21, 28.77, 85.37),
        vec4(-304.98, -1207.12, 24.67, 1.69),
        vec4(-1279.75, -1303.77, 3.59, 113.66),
        vec4(-1141.56, -1451.46, 4.32, 36.42),
        vec4(-1148.27, -1563.08, 3.96, 38.2),
        vec4(-1111.29, -1501.76, 4.23, 217.65),
        vec4(387.59, -1295.2, 37.93, 231.03),
        vec4(465.8, -1315.65, 28.6, 211.21),
    },
}
