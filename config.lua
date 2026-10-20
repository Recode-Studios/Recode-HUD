Config = {}
Config.Framework = 'esx' -- 'esx' or 'qb'
Config.Inventory = 'qs' -- 'ox' (ox_inventory), 'qs' (qs-inventory), 'qb' (qb-inventory), 'none' (default framework balance)


Config.SettingsCommand = "hud" -- Command to open HUD settings
Config.AlwaysMap = true -- true: map always visible, false: map visible only in vehicle

-- Circular minimap with compass (replaces the old compass/location text and the stock radar layout).
Config.Minimap = {
    enabled = true, -- false = back to the old stock radar
    leftVw = 2.2,   -- distance from left edge (vw)
    bottomVh = 6.5, -- distance from bottom edge (vh), higher number = map moves up
    scale = 1.0,
    showLocation = false, -- zone + street name next to the map
    zoom = 1100,
    hideWhenDead = true,
    hideInPauseMenu = true,
    useGpsRouteLength = true, -- waypoint distance by GPS route instead of straight line

    maskFile = 'assets/radar-mask.png',
    centerPlayer = true,
    hideNativeNorth = true,
    hideNativeSatnav = true,
    hideHealthArmor = true,
    scaleformTimeoutMs = 5000,
    updateInterval = 200,
    environmentPollInterval = 500,

    -- Default radar layout restored on resource stop.
    restoreComponents = {
        minimap = { -0.0045, 0.002, 0.150, 0.188888 },
        minimap_mask = { 0.020, 0.032, 0.111, 0.159 },
        minimap_blur = { -0.030, 0.022, 0.266, 0.237 }
    }
}

-- Seatbelt icon under the speedometer (blinks red while unbuckled).
Config.Seatbelt = {
    enabled = true,
    key = 'B',        -- default key, players can rebind it in FiveM keybinds
    lockExit = true,  -- can't leave the vehicle while buckled
    warningSound = true,    -- beep while driving unbuckled
    warningSpeed = 10,      -- km/h above which the beep starts
    warningInterval = 3000  -- ms between beeps
}

Config.EnableHealth = true
Config.EnableArmor = true
Config.EnableHunger = true
Config.EnableThirst = true
Config.EnableStamina = true
Config.EnableWallet = true
Config.EnableBank = true
Config.EnableJob = true
Config.EnableLocation = true
Config.EnableVoice = true
