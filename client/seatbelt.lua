local SB = Config.Seatbelt
if not SB or not SB.enabled then return end

local EXIT_VEHICLE_CONTROL = 75
local belted = false
local lastSent = 0
local lastBeep = 0

local function seatbeltAvailable(vehicle)
    if vehicle == 0 then return false end

    local class = GetVehicleClass(vehicle)
    -- motorcycles, bicycles, boats, helicopters, planes, trains have no seatbelt
    return not (class == 8 or class == 13 or class == 14 or class == 15 or class == 16 or class == 21)
end

local function sendState(vehicle)
    SendNUIMessage({
        type = 'updateSeatbelt',
        available = seatbeltAvailable(vehicle),
        on = belted,
        key = SB.key
    })
    lastSent = GetGameTimer()
end

local function setBelted(state)
    state = state == true
    if belted == state then return end

    belted = state
    LocalPlayer.state:set('seatbelt', belted, true)
    sendState(GetVehiclePedIsIn(PlayerPedId(), false))
end

RegisterCommand('seatbelt', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if not seatbeltAvailable(vehicle) then return end

    setBelted(not belted)
    PlaySoundFrontend(-1, belted and 'Faster_Click' or 'Click_Fail', 'RESPAWN_ONLINE_SOUNDSET', true)
end, false)

RegisterKeyMapping('seatbelt', 'Toggle seatbelt', 'keyboard', SB.key)

-- Other scripts can drive the state: TriggerEvent('muda:seatbelt:set', true)
AddEventHandler('muda:seatbelt:set', setBelted)
exports('IsSeatbeltOn', function() return belted end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle == 0 or IsEntityDead(ped) then
            setBelted(false)
        end

        if belted and SB.lockExit then
            DisableControlAction(0, EXIT_VEHICLE_CONTROL, true)
        end

        -- warning beep while driving unbuckled
        if SB.warningSound and not belted and vehicle ~= 0 and seatbeltAvailable(vehicle)
            and GetEntitySpeed(vehicle) * 3.6 >= SB.warningSpeed
            and GetGameTimer() - lastBeep >= SB.warningInterval then
            PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
            lastBeep = GetGameTimer()
        end

        -- resend now and then: the NUI may have been (re)loaded after the last message
        if GetGameTimer() - lastSent > 1000 then
            sendState(vehicle)
        end

        Wait(belted and SB.lockExit and 0 or 200)
    end
end)
