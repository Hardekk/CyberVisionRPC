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

local GameUI = require "libs/cp2077-cet-kit/GameUI"
local BetterUI = require "BetterUI"
local Handlers = require "Handlers"
local Localization = require "Localization"

---@enum GameStates
-- Edition of this build ("fr" or "en"); package.sh switches it for the English zip.
local EDITION = "fr"

local GameStates = {
    None = 0,
    MainMenu = 1,
    DeathMenu = 2,
    PauseMenu = 3,
    Playing = 4,
    Loading = 5
}

---@class CyberVisionRPC
local CyberVisionRPC = {
    ---@type PlayerPuppet Only available in Activity Handlers
    player = nil,
    gameState = GameStates.MainMenu,
    startedAt = 0,
    ---@type number|nil
    playthroughTime = nil, -- Available on save load
    elapsedInterval = 0,
    showUI = false,
    overlayOnGame = false,
    enabled = true,
    submitInterval = 1,
    style = "",
    showQuest = true,
    showQuestObjective = false,
    enableRadioExtIntegration = true,
    showPlaythroughTime = false,
    speedAsMPH = false,
    _configInitialized = false,
    ---@type Activity|nil
    activity = nil,
    GameStates = GameStates,
    _handlers = { },
    _initHandlersConfig = { },
    GameUtils = require("GameUtils"),
    Localization = Localization,
    RadioExt = nil
}

---@class Activity
---@field ApplicationId number
---@field Details string
---@field StartTimestamp number
---@field EndTimestamp number
---@field LargeImageKey string
---@field LargeImageText string
---@field SmallImageKey string
---@field SmallImageText string
---@field State string
---@field PartySize number
---@field PartyMax number

---@alias ActivityHandler fun(rpc:CyberVisionRPC, activity:Activity):boolean|nil

local function ConsoleLog(...)
    print("[ " .. os.date("%x %X") .. " ][ CyberVisionRPC ]:", table.concat({ ... }))
end

local function ConsoleWarn(...)
    print("[ " .. os.date("%x %X") .. " ][ CyberVisionRPC ][ WARN ]:", table.concat({ ... }))
end

---@param localeName string The name used internally by the Localization system to identify the locale
---@param locale table The key-value pairs defining the translation
---@return boolean ok Whether the locale was registered
---@return string|nil error The reason the locale was not registered, if any
function CyberVisionRPC.RegisterLocale(localeName, locale)
    return Localization:RegisterLocale(localeName, locale)
end

function CyberVisionRPC:GetREDInstance()
    return Game.GetScriptableSystemsContainer():Get("CyberVisionRPC.CyberVisionRPC")
end

function CyberVisionRPC:ResetConfig()
    self.enabled = true
    self.submitInterval = 5
    self.style = ""
    Localization:SetLocale(EDITION)
    self.showQuest = true
    self.showQuestObjective = false
    self.enableRadioExtIntegration = true
    self.showPlaythroughTime = false
    self.speedAsMPH = false
    self.homes = {}
    self:ConfigActivityHandlers(self._initHandlersConfig)
end

function CyberVisionRPC:SaveConfig()
    local handlers = {}
    for i=1, #self._handlers do
        local h = self._handlers[i]
        handlers[h.id] = { order = i, enabled = h.enabled }
    end

    local file = io.open("data/config.json", "w")
    file:write(json.encode({
        enabled = self.enabled,
        submitInterval = self.submitInterval,
        style = self.style,
        locale = Localization:GetCurrentLocale().name,
        edition = EDITION,
        showQuest = self.showQuest,
        showQuestObjective = self.showQuestObjective,
        enableRadioExtIntegration = self.enableRadioExtIntegration,
        showPlaythroughTime = self.showPlaythroughTime,
        speedAsMPH = self.speedAsMPH,
        handlers = handlers,
        homes = self.homes or {},
    }))
    io.close(file)
end

function CyberVisionRPC:LoadConfig()
    local ok = pcall(function ()
        local file = io.open("data/config.json", "r")
        local configText = file:read("*a")
        io.close(file)

        local config = json.decode(configText)
        if type(config.enabled) == "boolean" then
            self.enabled = config.enabled
        end

        if type(config.submitInterval) == "number" then
            self.submitInterval = config.submitInterval
        end

        if type(config.style) == "string" then
            self.style = config.style
        end

        -- Only reuse the saved language if it was saved by this same edition
        if type(config.locale) == "string" and config.edition == EDITION then
            if not Localization:SetLocale(config.locale) then
                ConsoleLog("Couldn't set '", config.locale, "' as main locale.")
            end
        end

        if type(config.showQuest) == "boolean" then
            self.showQuest = config.showQuest
        end

        if type(config.showQuestObjective) == "boolean" then
            self.showQuestObjective = config.showQuestObjective
        end

        if type(config.enableRadioExtIntegration) == "boolean" then
            self.enableRadioExtIntegration = config.enableRadioExtIntegration
        end

        if type(config.showPlaythroughTime) == "boolean" then
            self.showPlaythroughTime = config.showPlaythroughTime
        end

        if type(config.speedAsMPH) == "boolean" then
            self.speedAsMPH = config.speedAsMPH
        end

        if type(config.handlers) == "table" then
            self:ConfigActivityHandlers(config.handlers)
        end

        if type(config.homes) == "table" then
            self.homes = {}
            for _, h in ipairs(config.homes) do
                if type(h) == "table" and type(h.x) == "number" and type(h.y) == "number" and type(h.z) == "number" then
                    table.insert(self.homes, { x = h.x, y = h.y, z = h.z })
                end
            end
        end
    end)
    
    if not ok then
        self:SaveConfig()
    end
end

function CyberVisionRPC:SubmitActivity()
    local red = self:GetREDInstance()
    if not red then
        return
    elseif self.activity then
        red:UpdateActivity(self.activity)
    else
        red:ClearActivity()
    end
end

---Use this method within the onTweak CET event
---@param handlerId string An id which UNIQUELY identifies the provided handler
---@param handler ActivityHandler
---@param enabledByDefault boolean|nil
function CyberVisionRPC:SetActivityHandler(handlerId, handler, enabledByDefault)
    enabledByDefault = enabledByDefault == nil and true or (enabledByDefault and true or false)
    if self._handlers[handlerId] then
        ConsoleWarn("Handler: ", handlerId, " is being overridden.")

        self._handlers[handlerId] = handler
        for i=#self._handlers, 1, -1 do
            local h = self._handlers[i]
            if h.id == handlerId then
                h.enabled = enabledByDefault
                h.handler = handler
                break
            end
        end
        self._initHandlersConfig[handlerId].enabled = enabledByDefault
    else
        self._handlers[handlerId] = handler
        table.insert(self._handlers, { id = handlerId, enabled = enabledByDefault, handler = handler })
        self._initHandlersConfig[handlerId] = { order = #self._handlers, enabled = enabledByDefault }
    end
end

---@param handlerId string
function CyberVisionRPC:DelActivityHandler(handlerId)
    if not self._handlers[handlerId] then return; end
    self._handlers[handlerId] = nil
    for i=#self._handlers, 1, -1 do
        if self._handlers[i].id == handlerId then
            table.remove(self._handlers, i)
            break
        end
    end

    local removedOrder = self._initHandlersConfig[handlerId].order
    self._initHandlersConfig[handlerId] = nil

    for k, handlerConfig in next, self._initHandlersConfig do
        if handlerConfig.order > removedOrder then
            handlerConfig.order = handlerConfig.order - 1
        end
    end
end

function CyberVisionRPC:IsActivityHandlerEnabled(handlerId)
    if not self._handlers[handlerId] then return false; end
    for i=#self._handlers, 1, -1 do
        if self._handlers[i].id == handlerId then
            return self._handlers[i].enabled
        end
    end
    return false
end

function CyberVisionRPC:GetActivityHandlerComparator(orders)
    return function (a, b)
        local prioA = orders[a.id]
        if type(prioA) == "table"  then prioA = prioA.order; end
        if type(prioA) ~= "number" then return false; end

        local prioB = orders[b.id]
        if type(prioB) == "table"  then prioB = prioB.order; end
        if type(prioB) ~= "number" then return true; end

        return prioA < prioB
    end
end

function CyberVisionRPC:SortActivityHandlersBy(orders)
    -- I don't really like sorting them directly, change it if it causes any issue
    table.sort(self._handlers, self:GetActivityHandlerComparator(orders))
end

function CyberVisionRPC:ConfigActivityHandlers(config)
    self:SortActivityHandlersBy(config)
    for i=1, #self._handlers do
        local h = self._handlers[i]
        local handlerConfig = config[h.id]
        if type(handlerConfig) == "table" and type(handlerConfig.enabled) == "boolean" then
            h.enabled = handlerConfig.enabled
        end
    end
end

---@param handler ActivityHandler
function CyberVisionRPC:AddActivityHandler(handler)
    -- Deprecated because an id is necessary to preserve handler order
    ConsoleWarn("Usage of deprecated method CyberVisionRPC:AddActivityHandler(), use :SetActivityHandler instead.")
    return handler
end

---@param handler ActivityHandler
function CyberVisionRPC:RemoveActivityHandler(handler)
    ConsoleWarn("Usage of deprecated method CyberVisionRPC:RemoveActivityHandler(), use :DelActivityHandler instead.")
end

function CyberVisionRPC:GetGenderImageKey(gender)
    return "cybervision"
end

function CyberVisionRPC:GetRadioExtActiveStation()
    if not self.enableRadioExtIntegration then return nil; end
    if self.RadioExt and self.RadioExt.radioManager and self.RadioExt.radioManager.managerV then
        local stationData = self.RadioExt.radioManager.managerV:getActiveStationData()
        if not stationData then return nil; end
        if stationData.isStream then
            return {
                radioName = stationData.station,
                songName = self.Localization:Get("RadioExt.Stream.Song")
            }
        end
        return {
            radioName = stationData.station,
            songName = stationData.track:match(".*[\\/](.+)%.") or ""
        }
    end
    return nil
end

function CyberVisionRPC:UpdateGameState()
    -- We assume the player is in the MainMenu by default
    -- GameUI does not detect the transition from DeathMenu to MainMenu
    -- However, GameUI.IsDetached() does return true
    local newState = GameStates.MainMenu
    if GameUI.IsLoading() or GameUI.IsFastTravel() then
        newState = GameStates.Loading
    elseif GameUI.IsMenu() then
        if GameUI.GetMenu() == "MainMenu" then
            newState = GameStates.MainMenu
        elseif GameUI.GetMenu() == "DeathMenu" then
            newState = GameStates.DeathMenu
        elseif GameUI.GetMenu() == "PauseMenu" then
            newState = GameStates.PauseMenu
        elseif not GameUI.IsDetached() then
            newState = GameStates.Playing
        end
    elseif not GameUI.IsDetached() then
        newState = GameStates.Playing
    end
    -- Update at the end in case some other mod has a reference to this mod.
    -- Don't really know if mods run on different threads.
    -- If not, congrats to CET for being well optimized.
    self.gameState = newState
end

local function Event_OnTweak()
    ConsoleLog("Registering extra locales.")
    local ok, error = CyberVisionRPC.RegisterLocale("it", require "locales/it")
    if not ok then
        ConsoleLog("Failed to register Italian translation: ", error)
    end
end

local function Event_OnInit()
    CyberVisionRPC:ResetConfig() -- Loads default settings
    CyberVisionRPC:LoadConfig()
    CyberVisionRPC._configInitialized = true

    CyberVisionRPC.startedAt = os.time() * 1e3

    if RadioExt then
        CyberVisionRPC.RadioExt = GetMod("radioExt")
    end

    ObserveAfter("MenuScenario_SingleplayerMenu", "OnEnterScenario", function ()
        local metadata = Game.GetSystemRequestsHandler():GetLatestSaveMetadata()
        if metadata then
            CyberVisionRPC.playthroughTime = metadata.playthroughTime
            return
        end
        CyberVisionRPC.playthroughTime = nil
    end)

    ObserveAfter("gsmBaseRequestsHandler", "LoadLastCheckpoint", function (handler)
        local metadata = handler:GetLatestSaveMetadata()
        if metadata then
            CyberVisionRPC.playthroughTime = metadata.playthroughTime
            return
        end
        CyberVisionRPC.playthroughTime = nil
    end)

    ObserveAfter("LoadGameMenuGameController", "LoadGame", function (controller, item)
        if item.metadata then
            CyberVisionRPC.playthroughTime = item.metadata.playthroughTime
            return
        end
        CyberVisionRPC.playthroughTime = nil
    end)

    -- GameUI.Listen(function() end)
    -- Don't add listeners for all Events of GameUI
    GameUI.OnFastTravel(function () end)
    GameUI.OnLoading(function () end)
    GameUI.OnSession(function () end)
    GameUI.OnMenu(function () end)
    -- These listeners will force GameUI to update its state
    -- So that CyberVisionRPC:UpdateGameState() can directly query GameUI

    ConsoleLog("Mod Initialized!")
end

local function Event_OnUpdate(dt)
    if not CyberVisionRPC.enabled then
        if CyberVisionRPC.activity then
            CyberVisionRPC.activity = nil
            CyberVisionRPC:SubmitActivity()
        end
        return
    end

    local red = CyberVisionRPC:GetREDInstance()
    if not red then return; end

    CyberVisionRPC.elapsedInterval = CyberVisionRPC.elapsedInterval + dt
    if CyberVisionRPC.elapsedInterval >= CyberVisionRPC.submitInterval then
        CyberVisionRPC.elapsedInterval = 0

        CyberVisionRPC:UpdateGameState()
        -- CyberVisionRPC.gameState can't be GameStates.None after calling CyberVisionRPC:UpdateGameState()
        -- Though this check will remain to be future-proof.
        if CyberVisionRPC.gameState == GameStates.None then
            if CyberVisionRPC.activity then
                CyberVisionRPC.activity = nil
                CyberVisionRPC:SubmitActivity()
            end 
            return
        end

        ---@type Activity
        local activity = red:CreateDefaultActivity()
        activity.StartTimestamp = CyberVisionRPC.startedAt

        CyberVisionRPC.player = Game.GetPlayer()
        for i=#CyberVisionRPC._handlers, 1, -1 do
            local h = CyberVisionRPC._handlers[i]
            if h.enabled and h.handler(CyberVisionRPC, activity) then
                break
            end
        end

        CyberVisionRPC.activity = activity
        CyberVisionRPC:SubmitActivity()
    end
end

local function Event_OnShutdown()
    CyberVisionRPC.activity = nil
    CyberVisionRPC:SubmitActivity()
    if CyberVisionRPC._configInitialized then
        CyberVisionRPC:SaveConfig()
    end
end

local function Event_OnDraw()
    if not (CyberVisionRPC.showUI or CyberVisionRPC.overlayOnGame) then return; end

    if ImGui.Begin("CyberVision - Discord RPC") then
        ImGui.Text(Localization:Get("UI.Config.Activity.Label"))
        ImGui.SameLine()
        if BetterUI.FitButtonN(1, Localization:Get("UI.Config.ForceUpdate")) then
            CyberVisionRPC.elapsedInterval = CyberVisionRPC.submitInterval + 1
        end

        ImGui.Separator()
        CyberVisionRPC.enabled = ImGui.Checkbox(Localization:Get("UI.Config.Enabled"), CyberVisionRPC.enabled)
        
        do
            local newValue, changed = BetterUI.DragFloat(
                Localization:Get("UI.Config.SubmitInterval"),
                CyberVisionRPC.submitInterval, 0.01, 1, 3600, "%.2f")
            if changed then
                CyberVisionRPC.submitInterval = math.max(newValue, 1)
            end
        end

        if ImGui.Checkbox(Localization:Get("UI.Config.PLStyle"), CyberVisionRPC.style == "PL") then
            CyberVisionRPC.style = "PL"
        else
            CyberVisionRPC.style = ""
        end

        CyberVisionRPC.showQuest = ImGui.Checkbox(Localization:Get("UI.Config.ShowQuest"), CyberVisionRPC.showQuest)
        if CyberVisionRPC.showQuest then
            CyberVisionRPC.showQuestObjective = ImGui.Checkbox(Localization:Get("UI.Config.ShowQuestObjective"), CyberVisionRPC.showQuestObjective)
        end

        if CyberVisionRPC.RadioExt and CyberVisionRPC:IsActivityHandlerEnabled("DiscordRPC2.Radio") then
            CyberVisionRPC.enableRadioExtIntegration = ImGui.Checkbox(
                Localization:Get("UI.Config.EnableRadioExtIntegration"),
                CyberVisionRPC.enableRadioExtIntegration)
        end
        CyberVisionRPC.showPlaythroughTime = ImGui.Checkbox(Localization:Get("UI.Config.ShowPlaythroughTime"), CyberVisionRPC.showPlaythroughTime)
        CyberVisionRPC.speedAsMPH = ImGui.Checkbox(Localization:Get("UI.Config.SpeedAsMPH"), CyberVisionRPC.speedAsMPH)

        ImGui.Separator()
        CyberVisionRPC.homes = CyberVisionRPC.homes or {}
        ImGui.Text(Localization:GetFormatted("CyberVision.UI.Homes", { count = #CyberVisionRPC.homes }))
        if ImGui.Button(Localization:Get("CyberVision.UI.SetHome")) and CyberVisionRPC.player then
            local ok, pos = pcall(function() return CyberVisionRPC.player:GetWorldPosition() end)
            if ok and pos then
                table.insert(CyberVisionRPC.homes, { x = pos.x, y = pos.y, z = pos.z })
                CyberVisionRPC:SaveConfig()
            end
        end
        ImGui.SameLine()
        if ImGui.Button(Localization:Get("CyberVision.UI.ClearHomes")) then
            CyberVisionRPC.homes = {}
            CyberVisionRPC:SaveConfig()
        end

        if ImGui.CollapsingHeader(Localization:Get("UI.Config.Activities")) then
            ImGui.TextWrapped(Localization:Get("UI.Config.Activities.Description"))
            for i=1, #CyberVisionRPC._handlers do
                ImGui.PushID(CyberVisionRPC._handlers[i].id)

                if i > 1 then
                    if BetterUI.SquareButton("<") then
                        local tmp = CyberVisionRPC._handlers[i]
                        CyberVisionRPC._handlers[i]   = CyberVisionRPC._handlers[i-1]
                        CyberVisionRPC._handlers[i-1] = tmp
                    end
                else
                    BetterUI.SquareButton(" ")
                end

                ImGui.SameLine()
                if i < #CyberVisionRPC._handlers then
                    if BetterUI.SquareButton(">") then
                        local tmp = CyberVisionRPC._handlers[i]
                        CyberVisionRPC._handlers[i]   = CyberVisionRPC._handlers[i+1]
                        CyberVisionRPC._handlers[i+1] = tmp
                    end
                else
                    BetterUI.SquareButton(" ")
                end

                ImGui.SameLine()
                local h = CyberVisionRPC._handlers[i]
                h.enabled = ImGui.Checkbox(Localization:Get("UI.Config.Activities.Item." .. h.id), h.enabled)

                ImGui.PopID()
            end
        end

        ImGui.Separator()
        ImGui.PushID("Language")
        
        local currentLocale = Localization:GetCurrentLocale()
        ImGui.Text("Language:")
        ImGui.SameLine()
        ImGui.PushItemWidth(ImGui.GetContentRegionAvail())
        if ImGui.BeginCombo("", currentLocale.displayName) then
            local locales = Localization:GetLocales()

            for _, locale in next, locales do
                local selected = locale.name == currentLocale.name
                if ImGui.Selectable(locale.displayName, selected) and not selected then
                    Localization:SetLocale(locale.name)
                end
            end

            ImGui.EndCombo()
        end
        ImGui.PopItemWidth()

        ImGui.PopID()
        ImGui.Separator()

        ImGui.Text(Localization:Get("UI.Config.Label"))
        ImGui.SameLine()

        if BetterUI.FitButtonN(3, Localization:Get("UI.Config.Load")) then CyberVisionRPC:LoadConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(2, Localization:Get("UI.Config.Save")) then CyberVisionRPC:SaveConfig(); end
        ImGui.SameLine()

        if BetterUI.FitButtonN(1, Localization:Get("UI.Config.Reset")) then CyberVisionRPC:ResetConfig(); end
        ImGui.Separator()

        if ImGui.CollapsingHeader("Debug") then
            CyberVisionRPC.overlayOnGame = ImGui.Checkbox("Overlay on Game", CyberVisionRPC.overlayOnGame)
            ImGui.Separator()

            local red = CyberVisionRPC:GetREDInstance()
            if red then
                ImGui.Text("Discord Running: " .. (red:IsRunning() and "Yes" or "No"))
                ImGui.Text("Connected to Discord: " .. (red:IsConnected() and "Yes" or "No"))
                if red:IsOk() then
                    ImGui.Text("Discord Game SDK Error: No")
                else
                    ImGui.Text("Discord Game SDK Error: Yes (code=" .. tostring(red:GetLastRunCallbacksResult()) .. ")")
                end
            else
                ImGui.Text("redscript instance not found.")
            end

            ImGui.Separator()
            ImGui.Text("Mod Integrations:")
            ImGui.Bullet()
            ImGui.TextWrapped("RadioExt: " .. (CyberVisionRPC.RadioExt and "Found" or "Not Found"))

            if CyberVisionRPC.activity then
                ImGui.Separator()
                local activityFields = {
                    "Details",
                    "State",
                    "LargeImageKey",
                    "LargeImageText",
                    "SmallImageKey",
                    "SmallImageText"
                }
    
                for _, fieldName in next, activityFields do
                    ImGui.Text(fieldName .. ":")
                    ImGui.SameLine()
                    ImGui.TextWrapped(CyberVisionRPC.activity[fieldName] or "")
                end
            end
        end
        ImGui.Separator()
    end
    ImGui.End()
end

local function Event_OnOverlayOpen()
    CyberVisionRPC.showUI = true
end

local function Event_OnOverlayClose()
    CyberVisionRPC.showUI = false
end

function CyberVisionRPC:Init()
    Handlers:RegisterHandlers(CyberVisionRPC)
    registerForEvent("onTweak", Event_OnTweak)
    registerForEvent("onInit", Event_OnInit)
    registerForEvent("onUpdate", Event_OnUpdate)
    registerForEvent("onShutdown", Event_OnShutdown)
    registerForEvent("onDraw", Event_OnDraw)
    registerForEvent("onOverlayOpen", Event_OnOverlayOpen)
    registerForEvent("onOverlayClose", Event_OnOverlayClose)
    return self
end

return CyberVisionRPC:Init()
