local MM = Config.Minimap
if not MM then return end

-- Shared with client/main.lua (loaded first). custom = round minimap, false = stock GTA radar.
MinimapState = MinimapState or { custom = MM.enabled == true }

local RESOURCE_NAME = GetCurrentResourceName()
local TEXTURE_DICTIONARY = RESOURCE_NAME .. '_radar'

local nuiReady = false
local visibilityOverride = nil
local playerLoaded = false
local layout = nil
local layoutDirty = false
local prepared = false
local preparing = false
local failed = false
local stopped = false
local maskReady = false
local texturesInstalled = false
local scaleform = nil
local lastEnvironment = nil
local lastPayload = nil
local originalNorthAlpha = nil
-- After joining, the GTA radar finishes loading late and drops the layout we applied once.
-- Re-apply it a few times while the player is settling in.
local settleUntil = 0
local nextSettle = 0
local settleCount = 0
local nextDebug = 0

local function finite(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function isFrameworkLoaded()
    if Config.Framework == 'esx' then
        local ok, loaded = pcall(function()
            return exports['es_extended']:getSharedObject().IsPlayerLoaded()
        end)
        return ok and loaded == true
    end

    local ok, loaded = pcall(function() return LocalPlayer.state.isLoggedIn end)
    return ok and loaded == true
end

local function healthArmorMode(mode)
    if not scaleform or not HasScaleformMovieLoaded(scaleform) then return end

    BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(mode)
    EndScaleformMovieMethod()
end

local function satnavVisible(visible)
    if not scaleform or not HasScaleformMovieLoaded(scaleform) then return end

    BeginScaleformMovieMethod(scaleform, visible and 'SHOW_SATNAV' or 'HIDE_SATNAV')
    EndScaleformMovieMethod()
end

local function prepareNativeRadar()
    if prepared or preparing or failed then return prepared end

    preparing = true

    if not maskReady then
        local ok, texture = pcall(function()
            local dictionary = CreateRuntimeTxd(TEXTURE_DICTIONARY)
            return CreateRuntimeTextureFromImage(dictionary, 'mask', MM.maskFile)
        end)

        if not ok or not texture or texture == 0 then
            failed = true
            preparing = false
            print(('^1[%s] Could not load %s. The original GTA radar was left untouched.^7'):format(RESOURCE_NAME, MM.maskFile))
            return false
        end

        maskReady = true
    end

    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', TEXTURE_DICTIONARY, 'mask')
    AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', TEXTURE_DICTIONARY, 'mask')
    texturesInstalled = true

    UnlockMinimapPosition()
    SetMinimapClipType(1)

    if MM.hideNativeNorth then
        local northBlip = GetNorthRadarBlip()

        if northBlip and northBlip ~= 0 then
            originalNorthAlpha = originalNorthAlpha or GetBlipAlpha(northBlip)
            SetBlipAlpha(northBlip, 0)
        end
    end

    if (MM.hideHealthArmor or MM.hideNativeSatnav) and not scaleform then
        scaleform = RequestScaleformMovie('minimap')
        local deadline = GetGameTimer() + MM.scaleformTimeoutMs

        while not HasScaleformMovieLoaded(scaleform) and GetGameTimer() < deadline do
            Wait(25)
            if stopped then
                preparing = false
                return false
            end
        end

        if not HasScaleformMovieLoaded(scaleform) then
            print(('^3[%s] Minimap scaleform timed out; native satnav or health/armor bars may remain visible.^7'):format(RESOURCE_NAME))
        end
    end

    SetMinimapBlockWaypoint(false)
    if IsWaypointActive() then RefreshWaypoint() end

    prepared = true
    preparing = false
    layoutDirty = true
    return true
end

-- Gives the radar back to the stock GTA look and hands control to client/main.lua.
local function teardownNativeRadar()
    while preparing do Wait(50) end

    if prepared then
        if texturesInstalled then
            RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
            RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
            texturesInstalled = false
        end

        UnlockMinimapPosition()

        for name, values in pairs(MM.restoreComponents) do
            SetMinimapComponentPosition(name, 'L', 'B', values[1], values[2], values[3], values[4])
        end

        SetMinimapClipType(0)

        if MM.hideNativeSatnav then satnavVisible(true) end
        healthArmorMode(0)

        local northBlip = GetNorthRadarBlip()
        if northBlip and northBlip ~= 0 and originalNorthAlpha then
            SetBlipAlpha(northBlip, originalNorthAlpha)
        end

        prepared = false

        -- bigmap flash makes the game reload the radar with the original mask
        SetBigmapActive(true, false)
        Wait(0)
        SetBigmapActive(false, false)
    end

    TriggerEvent('muda:minimap:stock')
end

local function setCustomMinimap(state)
    state = state == true and MM.enabled == true
    if state == MinimapState.custom then return end

    MinimapState.custom = state
    lastPayload = nil
    SendNUIMessage({ action = 'coii:minimap:mode', custom = state })

    if state then
        layoutDirty = true -- the poll thread prepares the radar again
    else
        CreateThread(teardownNativeRadar)
    end
end

exports('SetCustomMinimap', setCustomMinimap)

local function currentEnvironment()
    local width, height = GetActiveScreenResolution()
    return ('%s:%s:%.4f:%.4f'):format(width, height, GetSafeZoneSize(), GetAspectRatio(false))
end

-- Stock GTA radar arrangement (the "Main" layout of client/main.lua). The visible part of the
-- radar is the mask rectangle; a layout the player placed in /hud is this arrangement
-- moved and scaled so that the mask lands on the chosen rectangle.
local STOCK_REF = { x = -0.02, y = 0.01, w = 0.1343, h = 0.1749 }
local STOCK_COMPONENTS = {
    minimap = { -0.03, -0.02, 0.1815, 0.207777 },
    minimap_mask = { -0.02, 0.01, 0.1343, 0.1749 },
    minimap_blur = { -0.04, -0.01, 0.3219, 0.2607 }
}

local function measureAligned()
    SetScriptGfxAlign(string.byte('L'), string.byte('B'))
    local originX, originY = GetScriptGfxPosition(0.0, 0.0)
    local extentX, extentY = GetScriptGfxPosition(1.0, 1.0)
    ResetScriptGfxAlign()

    local scaleX = extentX - originX
    local scaleY = extentY - originY

    if not finite(scaleX) or not finite(scaleY) or scaleX < 0.0001 or scaleY < 0.0001 then
        return nil
    end

    return originX, originY, scaleX, scaleY
end

-- Screen-fraction rectangle where the stock radar sits by default.
local function stockDefaultRect()
    local originX, originY, scaleX, scaleY = measureAligned()
    if not originX then return nil end

    local width = STOCK_REF.w * scaleX
    local height = STOCK_REF.h * scaleY
    local bottom = originY + STOCK_REF.y * scaleY

    return { left = originX + STOCK_REF.x * scaleX, top = bottom - height, width = width, height = height }
end

-- Called by client/main.lua whenever it wants the stock radar placed. true = a player layout was applied.
function ApplyUserStockLayout()
    local user = MinimapState.stockLayout
    if not user then return false end

    local originX, originY, scaleX, scaleY = measureAligned()
    if not originX then return false end

    local x1 = (user.left - originX) / scaleX
    local y1 = (user.top + user.height - originY) / scaleY
    local factorX = (user.width / scaleX) / STOCK_REF.w
    local factorY = (user.height / scaleY) / STOCK_REF.h

    for name, c in pairs(STOCK_COMPONENTS) do
        SetMinimapComponentPosition(name, 'L', 'B',
            x1 + (c[1] - STOCK_REF.x) * factorX,
            y1 + (c[2] - STOCK_REF.y) * factorY,
            c[3] * factorX,
            c[4] * factorY)
    end

    return true
end

local function applyMeasuredLayout()
    if not prepared or not layout or IsPauseMenuActive() or IsBigmapActive() then return end

    SetScriptGfxAlign(string.byte('L'), string.byte('B'))
    local originX, originY = GetScriptGfxPosition(0.0, 0.0)
    local extentX, extentY = GetScriptGfxPosition(1.0, 1.0)
    ResetScriptGfxAlign()

    local scaleX = extentX - originX
    local scaleY = extentY - originY

    if not finite(scaleX) or not finite(scaleY) or scaleX < 0.0001 or scaleY < 0.0001 then
        return
    end

    local x = (layout.left - originX) / scaleX
    local y = (layout.top + layout.height - originY) / scaleY
    local width = layout.width / scaleX
    local height = layout.height / scaleY

    SetMinimapComponentPosition('minimap', 'L', 'B', x, y, width, height)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', x, y, width, height)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', x, y, width, height)
    layoutDirty = false

    SetBigmapActive(true, false)
    Wait(0)
    SetBigmapActive(false, false)
    SetMinimapClipType(1)
end

function RefreshMinimapLayout()
    layoutDirty = true
end

function SetMinimapVisible(state)
    if state == nil then
        visibilityOverride = nil
        return
    end

    visibilityOverride = state == true

    if not visibilityOverride and MinimapState.custom then
        DisplayRadar(false)
        SendNUIMessage({ action = 'coii:minimap:update', visible = false })
        lastPayload = nil
    end
end

exports('SetMinimapVisible', SetMinimapVisible)
exports('RefreshMinimapLayout', RefreshMinimapLayout)

local function resolveTextLabel(label)
    if not label or label == '' then return '' end

    local resolved = GetLabelText(label)
    if not resolved or resolved == '' or resolved == 'NULL' then return label end
    return resolved
end

local function getLocation(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = ''

    if streetHash and streetHash ~= 0 then
        street = GetStreetNameFromHashKey(streetHash)
    end

    local district = resolveTextLabel(GetNameOfZone(coords.x, coords.y, coords.z))
    return district ~= '' and district or 'San Andreas', street ~= '' and street or district
end

local function getWaypointDistance(coords)
    local waypoint = GetFirstBlipInfoId(8)
    if waypoint == 0 or not DoesBlipExist(waypoint) then return 0 end

    local destination = GetBlipInfoIdCoord(waypoint)
    local deltaX = coords.x - destination.x
    local deltaY = coords.y - destination.y
    local directDistance = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))

    if MM.useGpsRouteLength and type(GetGpsBlipRouteLength) == 'function' then
        local ok, routeDistance = pcall(GetGpsBlipRouteLength)
        if ok and finite(routeDistance) and routeDistance > 0 then return routeDistance end
    end

    return directDistance
end

local function wantsRadar(ped)
    if not playerLoaded then return false end
    if MM.hideInPauseMenu and (IsPauseMenuActive() or IsBigmapActive()) then return false end
    if MM.hideWhenDead and IsEntityDead(ped) then return false end
    if IsScreenFadedOut() then return false end
    if visibilityOverride ~= nil then return visibilityOverride end
    if not Config.AlwaysMap and not IsPedInAnyVehicle(ped, false) then return false end
    return true
end

local function payloadChanged(payload)
    if not lastPayload then return true end

    return payload.visible ~= lastPayload.visible
        or payload.heading ~= lastPayload.heading
        or payload.distance ~= lastPayload.distance
        or payload.district ~= lastPayload.district
        or payload.street ~= lastPayload.street
end

RegisterNUICallback('mmReady', function(data, callback)
    nuiReady = true
    SendNUIMessage({
        action = 'coii:minimap:configure',
        available = MM.enabled == true,
        stockDefault = stockDefaultRect(),
        ui = { leftVw = MM.leftVw, bottomVh = MM.bottomVh, scale = MM.scale, showLocation = MM.showLocation == true }
    })

    -- saved choice from the /hud dashboard (defaults to the round minimap)
    setCustomMinimap(not (type(data) == 'table' and data.custom == false))
    SendNUIMessage({ action = 'coii:minimap:mode', custom = MinimapState.custom })
    callback({ ok = true })
end)

RegisterNUICallback('mmMode', function(data, callback)
    setCustomMinimap(not (type(data) == 'table' and data.custom == false))
    callback({ ok = true })
end)

-- Position of the stock GTA radar chosen in the /hud layout editor (or reset = default).
RegisterNUICallback('mmStockLayout', function(data, callback)
    local previous = MinimapState.stockLayout
    local nextLayout = nil

    if type(data) == 'table' and data.reset ~= true
        and finite(data.left) and finite(data.top)
        and finite(data.width) and finite(data.height)
        and data.width > 0.01 and data.height > 0.01
        and data.left >= -0.5 and data.top >= -0.5
        and data.left + data.width <= 1.5 and data.top + data.height <= 1.5 then
        nextLayout = { left = data.left, top = data.top, width = data.width, height = data.height }
    end

    local changed = (previous == nil) ~= (nextLayout == nil)
    if previous and nextLayout then
        local tolerance = 0.0005
        changed = math.abs(previous.left - nextLayout.left) > tolerance
            or math.abs(previous.top - nextLayout.top) > tolerance
            or math.abs(previous.width - nextLayout.width) > tolerance
            or math.abs(previous.height - nextLayout.height) > tolerance
    end

    MinimapState.stockLayout = nextLayout
    callback({ ok = true })

    if changed and not MinimapState.custom then
        TriggerEvent('muda:minimap:stock')
    end
end)

RegisterNUICallback('mmLayout', function(data, callback)
    local valid = type(data) == 'table'
        and finite(data.left) and finite(data.top)
        and finite(data.width) and finite(data.height)
        and data.left >= 0 and data.top >= 0
        and data.width > 0.01 and data.height > 0.01
        and data.left + data.width <= 1.001
        and data.top + data.height <= 1.001

    if not valid then
        callback({ ok = false, error = 'invalid_layout' })
        return
    end

    layout = { left = data.left, top = data.top, width = data.width, height = data.height }
    layoutDirty = true
    callback({ ok = true })
end)

RegisterNetEvent(Config.Framework == 'esx' and 'esx:playerLoaded' or 'QBCore:Client:OnPlayerLoaded', function()
    playerLoaded = true
    layoutDirty = true
    settleUntil = GetGameTimer() + 12000
    settleCount = 0
    nextSettle = GetGameTimer() + 2000
end)

RegisterNetEvent(Config.Framework == 'esx' and 'esx:onPlayerLogout' or 'QBCore:Client:OnPlayerUnload', function()
    playerLoaded = false
    lastPayload = nil
    if MinimapState.custom then DisplayRadar(false) end
end)

CreateThread(function()
    while not stopped do
        local frameworkLoaded = isFrameworkLoaded()
        if frameworkLoaded ~= playerLoaded then
            playerLoaded = frameworkLoaded
            if playerLoaded then
                layoutDirty = true
                settleUntil = GetGameTimer() + 12000
                settleCount = 0
                nextSettle = GetGameTimer() + 2000
            end
        end

        if MinimapState.custom then
            if playerLoaded and nuiReady and layout and not prepared and not failed then
                prepareNativeRadar()
            end

            if prepared then
                local environment = currentEnvironment()
                if environment ~= lastEnvironment then
                    lastEnvironment = environment
                    layoutDirty = true
                end

                local now = GetGameTimer()
                -- only two re-applies (each one flashes the radar): once the screen is
                -- visible, and once more a few seconds later
                if settleCount < 2 and now < settleUntil and now >= nextSettle and layout and not IsScreenFadedOut() then
                    settleCount = settleCount + 1
                    nextSettle = now + 4000
                    layoutDirty = true
                end

                if layoutDirty then applyMeasuredLayout() end
            end
        elseif MinimapState.stockLayout then
            -- stock radar placed by the player: follow resolution / safe zone changes
            local environment = currentEnvironment()
            if environment ~= lastEnvironment then
                lastEnvironment = environment
                TriggerEvent('muda:minimap:stock')
            end
        end

        Wait(MM.environmentPollInterval)
    end
end)

CreateThread(function()
    while not stopped do
        if MinimapState.custom then
            local visible = prepared and wantsRadar(PlayerPedId())
            DisplayRadar(visible)

            if visible then
                SetMinimapClipType(1)

                if MM.centerPlayer then
                    UnlockMinimapPosition()
                    CenterPlayerOnRadarThisFrame()
                end

                if MM.hideNativeSatnav then satnavVisible(false) end
                if MM.hideHealthArmor then healthArmorMode(3) end
                SetRadarZoom(MM.zoom)
            end

            -- Debug + watchdog: radar should be on screen but the game is not rendering it
            -- (happens right after joining) -> reload it with the bigmap flash.
            local now = GetGameTimer()
            if now >= nextDebug then
                nextDebug = now + 3000
                if not (prepared and visible) or settleCount < 2 then
                    print(('^3[%s] minimap: custom=%s nuiReady=%s playerLoaded=%s layout=%s prepared=%s failed=%s visible=%s override=%s^7'):format(
                        RESOURCE_NAME, tostring(MinimapState.custom), tostring(nuiReady), tostring(playerLoaded),
                        tostring(layout ~= nil), tostring(prepared), tostring(failed), tostring(visible), tostring(visibilityOverride)))
                end

                if visible and not IsPauseMenuActive() and not IsBigmapActive()
                    and type(IsMinimapRendering) == 'function' and not IsMinimapRendering() then
                    print(('^3[%s] minimap: not rendering, reloading radar^7'):format(RESOURCE_NAME))
                    layoutDirty = true
                end
            end

            Wait(prepared and 0 or 100)
        else
            Wait(250)
        end
    end
end)

CreateThread(function()
    while not stopped do
        local ped = PlayerPedId()
        local visible = MinimapState.custom and prepared and wantsRadar(ped)
        local payload = {
            action = 'coii:minimap:update',
            visible = visible,
            heading = 0,
            distance = 0,
            district = '',
            street = ''
        }

        if visible then
            local coords = GetEntityCoords(ped)
            local district, street = getLocation(coords)

            -- The radar rotates with the gameplay camera, so the compass follows it too.
            payload.heading = math.floor((-GetGameplayCamRot(2).z + 0.5) % 360)
            payload.distance = math.floor(getWaypointDistance(coords) + 0.5)
            payload.district = district
            payload.street = street
        end

        if nuiReady and payloadChanged(payload) then
            SendNUIMessage(payload)
            lastPayload = payload
        end

        Wait(MM.updateInterval)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= RESOURCE_NAME then return end
    stopped = true

    if texturesInstalled then
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
        RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    end

    UnlockMinimapPosition()

    if prepared then
        for name, values in pairs(MM.restoreComponents) do
            SetMinimapComponentPosition(name, 'L', 'B', values[1], values[2], values[3], values[4])
        end

        SetMinimapClipType(0)

        if MM.hideNativeSatnav then satnavVisible(true) end

        healthArmorMode(0)
        local northBlip = GetNorthRadarBlip()
        if northBlip and northBlip ~= 0 and originalNorthAlpha then
            SetBlipAlpha(northBlip, originalNorthAlpha)
        end
    end

    DisplayRadar(true)

    if scaleform then SetScaleformMovieAsNoLongerNeeded(scaleform) end
end)
