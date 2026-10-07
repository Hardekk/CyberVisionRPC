--[[
Copyright (c) 2025 [Marco4413](https://github.com/Marco4413/CP77-DiscordRPC2)

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
]]

local GameUtils = require "GameUtils"
local GameUI = require "libs/cp2077-cet-kit/GameUI"

local Handlers = { }

---@generic T
---@param mod CyberVisionRPC
---@param activity Activity
---@param activityVars T
---@return T
function Handlers.SetCommonInfo(mod, activity, activityVars)
    if not activityVars then activityVars = {}; end
    local level = GameUtils.GetLevel(mod.player)
    local lifepath = GameUtils.GetLifePath(mod.player)
    activityVars.level = level.level
    activityVars.streetCred = level.streetCred
    activityVars.lifepath = mod.Localization:Get("Common.LifePath." .. (lifepath or "?"))

    local lifepathKey = lifepath and lifepath:lower() or ""
    -- Fresh Start ("New Start") registers its life path with enumName "Count": Corpo + Nomad
    if lifepathKey == "count" or lifepathKey == "newstart" then lifepathKey = "corpomad"; end
    local knownLifepath = lifepathKey == "nomad" or lifepathKey == "streetkid"
        or lifepathKey == "corporate" or lifepathKey == "corpomad"
    -- In game: life path character as the main image, CyberVision logo as the badge
    activity.LargeImageKey = knownLifepath and lifepathKey or "cybervision"
    local amb = Handlers.GetAmbience(mod)
    activityVars.time = amb.time
    activityVars.weather = amb.weather
    activity.LargeImageText = mod.Localization:GetFormatted(
        (amb.time and amb.weather) and "Common.LargeImageText.Ambience" or "Common.LargeImageText", activityVars)
    activity.SmallImageKey = knownLifepath and "cybervision" or ""
    if mod.showPlaythroughTime and mod.playthroughTime then
        activityVars.playthroughTime = math.floor(mod.playthroughTime / 3600)
        activity.SmallImageText = mod.Localization:GetFormatted("Common.SmallImageText.WPlaythroughTime", activityVars)
    else
        activity.SmallImageText = mod.Localization:GetFormatted("Common.SmallImageText", activityVars)
    end

    return activityVars
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Loading(mod, activity)
    if mod.gameState == mod.GameStates.Loading then
        activity.Details = mod.Localization:Get("Loading.Details")
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.MainMenu(mod, activity)
    if mod.gameState == mod.GameStates.MainMenu then
        activity.Details = mod.Localization:Get("MainMenu.Details")
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.PauseMenu(mod, activity)
    if mod.gameState == mod.GameStates.PauseMenu and mod.player then
        local activityVars = Handlers.SetCommonInfo(mod, activity)
        activity.Details = mod.Localization:GetFormatted("PauseMenu.Details", activityVars)
        activity.State = ""
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.DeathMenu(mod, activity)
    if mod.gameState == mod.GameStates.DeathMenu then
        activity.LargeImageKey = "deathmenu"
        activity.Details = mod.Localization:Get("DeathMenu.Details")
        activity.State = mod.Localization:Get("DeathMenu.State")
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Combat(mod, activity)
    if mod.gameState == mod.GameStates.Playing and mod.player and mod.player:IsInCombat() then
        local healthArmor = GameUtils.GetHealthArmor(mod.player)
        local weaponName = GameUtils.GetWeaponName(mod.player:GetActiveWeapon())
        local activityVars = Handlers.SetCommonInfo(mod, activity, {
            maxHealth = healthArmor.maxHealth,
            health = healthArmor.health,
            armor = healthArmor.armor,
            weapon = weaponName
        })
        
        activity.Details = mod.Localization:GetFormatted("Combat.Details", activityVars)
        local foe = Handlers.GetSpecialFoe(mod)
        if foe then
            activityVars.foe = foe.name
            activity.Details = mod.Localization:GetFormatted(
                foe.cyberpsycho and "CyberVision.Combat.Cyberpsycho" or "CyberVision.Combat.Boss", activityVars)
                .. " · " .. activityVars.health .. "/" .. activityVars.maxHealth
                .. mod.Localization:Get("CyberVision.HP")
        end
        activity.State = weaponName and
            mod.Localization:GetFormatted("Combat.State.Weapon", activityVars) or
            mod.Localization:GetFormatted("Combat.State.NoWeapon", activityVars)
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Driving(mod, activity)
    if mod.gameState == mod.GameStates.Playing and mod.player then
        local vehicle = Game.GetMountedVehicle(mod.player)
        local vehicleName = GameUtils.GetVehicleName(vehicle)
        if vehicleName and vehicle:IsPlayerDriver() then
            local speedUnit = mod.speedAsMPH and "mph" or "km/h"
            local vehicleSpeed, goingForward = GameUtils.GetVehicleSpeed(vehicle)
            -- 1.609344 is the conversion factor from mph to km/h
            if not mod.speedAsMPH then vehicleSpeed = vehicleSpeed * 1.609344; end
            -- local vehicleSpeed = math.floor(vehicle:GetCurrentSpeed() * (mod.speedAsMPH and 2.23693629192 or 3.6) + .5)
            local activityVars = Handlers.SetCommonInfo(mod, activity, {
                vehicle = vehicleName,
                speed = math.floor(vehicleSpeed + .5),
                speedUnit = speedUnit
            })
            
            activity.Details = mod.Localization:GetFormatted("Driving.Details", activityVars)
            if vehicleSpeed >= 1 then
                if goingForward then
                    activity.State = mod.Localization:GetFormatted("Driving.State.Forward", activityVars)
                else
                    activity.State = mod.Localization:GetFormatted("Driving.State.Backwards", activityVars)
                end
            else
                activity.State = mod.Localization:GetFormatted("Driving.State.Parked", activityVars)
            end
            return true
        end
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Radio(mod, activity)
    if mod.gameState == mod.GameStates.Playing and mod.player then
        local vehicle = Game.GetMountedVehicle(mod.player)
        local vehicleName = GameUtils.GetVehicleName(vehicle)
        if vehicleName and vehicle:IsPlayerDriver() and vehicle:IsRadioReceiverActive() then
            local radioName
            local songName

            local radioExtStation = mod:GetRadioExtActiveStation();
            if radioExtStation then
                radioName = radioExtStation.radioName
                songName = radioExtStation.songName
            else
                radioName = Game.GetLocalizedTextByKey(vehicle:GetRadioReceiverStationName())
                songName = Game.GetLocalizedTextByKey(vehicle:GetRadioReceiverTrackName())
                if #songName == 0 then return false; end
            end

            local activityVars = Handlers.SetCommonInfo(mod, activity, { radio = radioName, song = songName, vehicle = vehicleName })

            activity.Details = mod.Localization:GetFormatted("Radio.Details.Vehicle", activityVars)
            activity.State = mod.Localization:GetFormatted("Radio.State.Vehicle", activityVars)
            return true
        end

        local pocketRadio = mod.player:GetPocketRadio()
        if pocketRadio and pocketRadio:IsActive() then
            local radioName
            local songName

            local radioExtStation = mod:GetRadioExtActiveStation();
            if radioExtStation then
                radioName = radioExtStation.radioName
                songName = radioExtStation.songName
            else
                radioName = Game.GetLocalizedTextByKey(pocketRadio:GetStationName())
                songName = Game.GetLocalizedTextByKey(pocketRadio:GetTrackName())
                if #songName == 0 then return false; end
            end

            local activityVars = Handlers.SetCommonInfo(mod, activity, { radio = radioName, song = songName })

            activity.Details = mod.Localization:GetFormatted("Radio.Details", activityVars)
            activity.State = mod.Localization:GetFormatted("Radio.State", activityVars)
            return true
        end
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Playing(mod, activity)
    if mod.gameState == mod.GameStates.Playing and mod.player then
        local questShown = false
        if mod.showQuest then
            local questInfo = GameUtils.GetActiveQuest()
            if questInfo.name then
                questShown = true
                local activityVars = Handlers.SetCommonInfo(mod, activity, {
                    quest = questInfo.name,
                    objective = questInfo.objective
                })
                if not (mod.showQuestObjective and activityVars.objective) then activityVars.objective = ""; end
                activity.Details = mod.Localization:GetFormatted("Playing.Details", activityVars)
                if questInfo.type then
                    local label = mod.Localization:Get("CyberVision.QuestType." .. questInfo.type)
                    if label and label ~= "" and not label:find("CyberVision.QuestType", 1, true) then
                        activity.Details = label .. " · " .. activity.Details
                    end
                end
                activity.State = mod.Localization:GetFormatted("Playing.State", activityVars)
            end
        end

        if not questShown then
            local district = GameUtils.GetDistrict()
            local activityVars = Handlers.SetCommonInfo(mod, activity, {
                district = district.main,
                subDistrict = district.sub
            })

            if district.main then
                if district.sub then
                    activity.Details = mod.Localization:GetFormatted("Playing.Details.Roaming.SubDistrict", activityVars)
                    activity.State = mod.Localization:GetFormatted("Playing.State.Roaming.SubDistrict", activityVars)
                else
                    activity.Details = mod.Localization:GetFormatted("Playing.Details.Roaming.District", activityVars)
                    activity.State = mod.Localization:GetFormatted("Playing.State.Roaming.District", activityVars)
                end
            else
                activity.Details = mod.Localization:GetFormatted("Playing.Details.Roaming", activityVars)
                activity.State = mod.Localization:GetFormatted("Playing.State.Roaming", activityVars)
            end
        end

        return true
    end
end


-- ===== CyberVision ambience (heure + météo, compatible Nova City / Weather Switcher) =====

local WEATHER_KEYS = {
    { "toxic",     "Weather.Toxic" },
    { "acid",      "Weather.Toxic" },
    { "sandstorm", "Weather.Sandstorm" },
    { "pollution", "Weather.Pollution" },
    { "storm",     "Weather.Storm" },
    { "heavy_rain","Weather.Rain" },
    { "rain",      "Weather.Rain" },
    { "drizzle",   "Weather.Rain" },
    { "fog",       "Weather.Fog" },
    { "mist",      "Weather.Fog" },
    { "snow",      "Weather.Snow" },
    { "heavy_cloud","Weather.Cloudy" },
    { "cloud",     "Weather.Cloudy" },
    { "overcast",  "Weather.Cloudy" },
    { "clear",     "Weather.Clear" },
    { "sunny",     "Weather.Clear" },
}

function Handlers.GetAmbience(mod)
    local res = {}
    pcall(function()
        local t = Game.GetTimeSystem():GetGameTime()
        res.time = string.format("%02d:%02d", t:Hours(), t:Minutes())
    end)
    pcall(function()
        local state = Game.GetWeatherSystem():GetWeatherState()
        local name = (Game.NameToString(state.name) or ""):lower()
        for _, kv in ipairs(WEATHER_KEYS) do
            if name:find(kv[1], 1, true) then
                res.weather = mod.Localization:Get("CyberVision." .. kv[2])
                break
            end
        end
    end)
    return res
end

-- ===== CyberVision =====

local DF_NEEDS = {
    { key = "Nutrition", cls = "DarkFuture.Needs.DFNutritionSystem" },
    { key = "Hydration", cls = "DarkFuture.Needs.DFHydrationSystem" },
    { key = "Energy",    cls = "DarkFuture.Needs.DFEnergySystem" },
    { key = "Nerve",     cls = "DarkFuture.Needs.DFNerveSystem" },
}

---Returns Dark Future needs (0-100) or nil if Dark Future isn't installed/ready.
function Handlers.GetDarkFutureNeeds()
    local ok, res = pcall(function()
        local container = Game.GetScriptableSystemsContainer()
        local needs = {}
        for _, n in ipairs(DF_NEEDS) do
            local sys = container:Get(n.cls)
            if not sys then return nil; end
            needs[n.key] = math.floor(sys:GetNeedValue() + 0.5)
        end
        return needs
    end)
    if ok then return res; end
    return nil
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.DarkFuture(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    if not Handlers.Playing(mod, activity) then return; end
    local needs = Handlers.GetDarkFutureNeeds()
    if not needs then return true; end
    local line = mod.Localization:GetFormatted("CyberVision.DarkFuture.State", {
        nutrition = needs.Nutrition, hydration = needs.Hydration,
        energy = needs.Energy, nerve = needs.Nerve
    })
    if activity.State and activity.State ~= "" then
        activity.State = activity.State .. " | " .. line
    else
        activity.State = line
    end
    return true
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Braindance(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    local ok, active = pcall(function()
        local defs = GetAllBlackboardDefs().Braindance
        return Game.GetBlackboardSystem():Get(defs):GetBool(defs.IsActive)
    end)
    if ok and active then
        Handlers.SetCommonInfo(mod, activity)
        activity.Details = mod.Localization:Get("CyberVision.Braindance.Details")
        activity.State = mod.Localization:Get("CyberVision.Braindance.State")
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.PhotoMode(mod, activity)
    if not mod.player then return; end
    local ok, active = pcall(function() return Game.GetPhotoModeSystem():IsPhotoModeActive() end)
    if ok and active then
        Handlers.SetCommonInfo(mod, activity)
        activity.Details = mod.Localization:Get("CyberVision.PhotoMode.Details")
        activity.State = mod.Localization:Get("CyberVision.PhotoMode.State")
        return true
    end
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.GetWantedLevel()
    -- HUD wanted bar first (matches the stars shown on screen), then PreventionSystem.
    local ok, lvl = pcall(function()
        local defs = GetAllBlackboardDefs().UI_WantedBar
        return Game.GetBlackboardSystem():Get(defs):GetInt(defs.CurrentWantedLevel)
    end)
    if ok and type(lvl) == "number" and lvl > 0 then return lvl; end
    ok, lvl = pcall(function()
        local ps = Game.GetScriptableSystemsContainer():Get("PreventionSystem")
        local stage = ps:GetHeatStage()
        return tonumber(stage) or EnumInt(stage)
    end)
    if ok and type(lvl) == "number" and lvl > 0 then return lvl; end
    return 0
end

function Handlers.Wanted(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    local stars = math.min(5, Handlers.GetWantedLevel())
    if stars <= 0 then return; end
    local wanted = mod.Localization:GetFormatted("CyberVision.Wanted.Details", {
        stars = string.rep("★", stars) .. string.rep("☆", 5 - stars)
    })
    if mod.player:IsInCombat() and Handlers.Combat(mod, activity) then
        -- Keep combat info on top, wanted level underneath
        activity.State = wanted
    else
        if not Handlers.DarkFuture(mod, activity) then Handlers.Playing(mod, activity) end
        activity.Details = wanted
    end
    return true
end


-- ===== CyberVision: boss / cyberpsycho detection =====

local lastFoe, lastFoeTime = nil, 0

local function classifyTarget(obj)
    if not obj then return nil; end
    local isNPC = false
    pcall(function() isNPC = obj:IsNPC() end)
    if not isNPC then return nil; end
    local alive = true
    pcall(function() alive = not obj:IsDead() end)
    if not alive then return nil; end

    local boss, psycho = false, false
    pcall(function()
        local r = tostring(obj:GetNPCRarity())
        if r:find("Boss", 1, true) or r:find("MaxTac", 1, true) then boss = true; end
    end)
    pcall(function()
        local rec = TweakDBInterface.GetCharacterRecord(obj:GetRecordID())
        if rec:TagsContains(CName.new("Cyberpsycho")) then psycho = true; end
        local cls = rec:CharacterType() and tostring(rec:CharacterType():Type()) or ""
        if cls:find("Cyberpsycho", 1, true) then psycho = true; end
    end)
    pcall(function() if obj:IsCharacterCyberpsycho() then psycho = true; end end)
    if not (boss or psycho) then return nil; end

    local name = nil
    pcall(function() name = obj:GetDisplayName() end)
    if not name or name == "" then
        pcall(function()
            local rec = TweakDBInterface.GetCharacterRecord(obj:GetRecordID())
            name = Game.GetLocalizedTextByKey(rec:DisplayName())
        end)
    end
    if not name or name == "" then return nil; end
    return { name = name, cyberpsycho = psycho }
end

---Boss or cyberpsycho the player is currently fighting (sticky for 30s).
function Handlers.GetSpecialFoe(mod)
    local foe = nil
    pcall(function()
        local obj = Game.GetTargetingSystem():GetLookAtObject(mod.player, false, false)
        foe = classifyTarget(obj)
    end)
    local now = os.clock()
    if foe then
        lastFoe, lastFoeTime = foe, now
        return foe
    end
    if lastFoe and now - lastFoeTime < 30 then return lastFoe; end
    lastFoe = nil
    return nil
end

-- ===== CyberVision: hacking, scanner, menus =====

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Hacking(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    local key = nil
    if GameUI.GetMenu() == "NetworkBreach" then
        key = "Breach"
    elseif GameUI.IsQuickHack() then
        key = "QuickHack"
    elseif GameUI.IsScanner() then
        local inCombat = false
        pcall(function() inCombat = mod.player:IsInCombat() end)
        key = inCombat and "ScannerCombat" or "Scanner"
    end
    if not key then return; end
    Handlers.SetCommonInfo(mod, activity)
    activity.Details = mod.Localization:Get("CyberVision.Hacking." .. key)
    activity.State = ""
    return true
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Shops(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    local menu, sub = GameUI.GetMenu(), GameUI.GetSubmenu()
    local key = nil
    if menu == "Vendor" then
        if sub == "RipperDoc" then key = "Ripperdoc"
        elseif sub == "Crafting" then key = "Crafting"
        else key = "Vendor" end
    elseif menu == "Stash" then
        key = "Stash"
    end
    if not key then return; end
    Handlers.SetCommonInfo(mod, activity)
    activity.Details = mod.Localization:Get("CyberVision.Shop." .. key)
    activity.State = ""
    return true
end

-- ===== CyberVision: resting / waiting (game time running much faster than real time) =====

local lastGameSecs, lastRealSecs, restingUntil = nil, nil, 0

local function updateRestDetection()
    local ok, gameSecs = pcall(function()
        return Game.GetTimeSystem():GetGameTimeStamp()
    end)
    local real = os.clock()
    if ok and type(gameSecs) == "number" then
        if lastGameSecs and lastRealSecs and real > lastRealSecs then
            local ratio = (gameSecs - lastGameSecs) / (real - lastRealSecs)
            -- Normal speed is ~8 game seconds per real second
            if ratio > 60 then restingUntil = real + 6; end
        end
        lastGameSecs, lastRealSecs = gameSecs, real
    end
    return real < restingUntil
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Resting(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    local resting = updateRestDetection()
    if not resting then return; end
    local inCombat = false
    pcall(function() inCombat = mod.player:IsInCombat() end)
    if inCombat then return; end
    if not Handlers.DarkFuture(mod, activity) then Handlers.Playing(mod, activity) end
    activity.Details = mod.Localization:Get(Handlers.IsAtHome(mod) and "CyberVision.Rest.Sleep" or "CyberVision.Rest.Wait")
    return true
end

-- ===== CyberVision: home (positions saved from the CET window) =====

local HOME_RADIUS = 30

function Handlers.GetPlayerPosition(mod)
    local ok, pos = pcall(function() return mod.player:GetWorldPosition() end)
    if ok and pos then return { x = pos.x, y = pos.y, z = pos.z }; end
    return nil
end

function Handlers.IsAtHome(mod)
    if not mod.homes or #mod.homes == 0 then return false; end
    local p = Handlers.GetPlayerPosition(mod)
    if not p then return false; end
    for _, h in ipairs(mod.homes) do
        local dx, dy, dz = p.x - h.x, p.y - h.y, p.z - h.z
        if dx*dx + dy*dy + dz*dz <= HOME_RADIUS * HOME_RADIUS then return true; end
    end
    return false
end

---@param mod CyberVisionRPC
---@param activity Activity
function Handlers.Home(mod, activity)
    if mod.gameState ~= mod.GameStates.Playing or not mod.player then return; end
    if not Handlers.IsAtHome(mod) then return; end
    local inCombat = false
    pcall(function() inCombat = mod.player:IsInCombat() end)
    if inCombat or Handlers.GetWantedLevel() > 0 then return; end
    if not Handlers.DarkFuture(mod, activity) then Handlers.Playing(mod, activity) end
    local district = GameUtils.GetDistrict()
    local where = district.sub or district.main
    activity.Details = where
        and mod.Localization:GetFormatted("CyberVision.Home.District", { district = where })
        or mod.Localization:Get("CyberVision.Home")
    return true
end

---@param mod CyberVisionRPC
function Handlers:RegisterHandlers(mod)
    mod:SetActivityHandler("DiscordRPC2.Playing",      self.Playing)
    mod:SetActivityHandler("CyberVision.DarkFuture",   self.DarkFuture)
    mod:SetActivityHandler("CyberVision.Home",         self.Home)
    mod:SetActivityHandler("CyberVision.Resting",      self.Resting)
    mod:SetActivityHandler("CyberVision.Combat",       self.Combat)
    mod:SetActivityHandler("CyberVision.Wanted",       self.Wanted)
    mod:SetActivityHandler("DiscordRPC2.Driving",      self.Driving, false)
    mod:SetActivityHandler("DiscordRPC2.Radio",        self.Radio,   false)
    mod:SetActivityHandler("CyberVision.Hacking",      self.Hacking)
    mod:SetActivityHandler("CyberVision.Shops",        self.Shops)
    mod:SetActivityHandler("CyberVision.Braindance",   self.Braindance)
    mod:SetActivityHandler("CyberVision.PhotoMode",    self.PhotoMode)
    mod:SetActivityHandler("DiscordRPC2.DeathMenu",    self.DeathMenu)
    mod:SetActivityHandler("DiscordRPC2.PauseMenu",    self.PauseMenu)
    mod:SetActivityHandler("DiscordRPC2.MainMenu",     self.MainMenu)
    mod:SetActivityHandler("DiscordRPC2.Loading",      self.Loading)
end

return Handlers
