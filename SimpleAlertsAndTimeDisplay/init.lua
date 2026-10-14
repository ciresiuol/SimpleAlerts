local SimpleAlerts = {}
local cetopen = false
local inkHelper = require("modules/InkWidgetHelper.lua")
local gameRes = {X = 1920, Y = 1080}

local alertQueue = {}
local activeAlert = nil
local alertTimer = 0

local alertWidgets = {
    background = nil,
    textContainer = nil,
    textLines = {}
}

local isInCombat = false
local isInScanner = false
local isInVehicle = false

local userSettings = {
    dateTimeDisplayOn = true,
    showDateInCombat = false,
    showDateInScanner = false,
    showDateInVehicle = true,
    dateTimeFontSize = 35,
    clockIs24Hr = false,
    dateIs2077 = true,
    dateIsEuro = false,
    includeBg = true,
}
local isDateTimeVisible = false
local nextDateTimeUpdate = 0
local DATE_TIME_UPDATE_INTERVAL = 1.0

local settingsFile = "UserSettings.json"

function saveUserSettings()
    local file = io.open(settingsFile, "w")
    if file then
        file:write(json.encode(userSettings))
        file:close()
    end
end

function loadUserSettings()
    local file = io.open(settingsFile, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local loaded = json.decode(content)
        if type(loaded) == "table" then
            for k, v in pairs(userSettings) do
                if loaded[k] == nil then
                    loaded[k] = v
                end
            end
            userSettings = loaded
        end
    end
end

registerForEvent("onOverlayOpen", function()
    cetopen = true
end)

registerForEvent("onOverlayClose", function()
    cetopen = false
end)

registerForEvent("onDraw", function()
    if not cetopen then return end
    ImGui.Begin("Simple Alerts Date And Time", ImGuiWindowFlags.AlwaysAutoResize)
    userSettings.dateTimeDisplayOn, changedDateTime = ImGui.Checkbox("Enable Date/Time Display When No Messages Are Displayed", userSettings.dateTimeDisplayOn)
    if changedDateTime then
        if not userSettings.dateTimeDisplayOn and isDateTimeVisible then
            inkHelper.setVisibility(alertWidgets, false, userSettings)
            isDateTimeVisible = false
        end
        saveUserSettings()
    end
    if userSettings.dateTimeDisplayOn then
        userSettings.showDateInCombat, changed = ImGui.Checkbox("Show Date/Time While In Combat", userSettings.showDateInCombat)
        if changed then
            if isInCombat and not userSettings.showDateInCombat and userSettings.dateTimeDisplayOn and isDateTimeVisible then
                inkHelper.setVisibility(alertWidgets, false, userSettings)
                isDateTimeVisible = false
            end
            saveUserSettings()
        end
        userSettings.showDateInScanner, changed = ImGui.Checkbox("Show Date/Time While In Scanner", userSettings.showDateInScanner)
        if changed then
            if isInScanner and not userSettings.showDateInScanner and userSettings.dateTimeDisplayOn and isDateTimeVisible then
                inkHelper.setVisibility(alertWidgets, false, userSettings)
                isDateTimeVisible = false
            end
            saveUserSettings()
        end
        userSettings.showDateInVehicle, changed = ImGui.Checkbox("Show Date/Time While In Vehicle", userSettings.showDateInVehicle)
        if changed then
            if isInVehicle and not userSettings.showDateInVehicle and userSettings.dateTimeDisplayOn and isDateTimeVisible then
                inkHelper.setVisibility(alertWidgets, false, userSettings)
                isDateTimeVisible = false
            end
            saveUserSettings()
        end
        userSettings.includeBg, changed = ImGui.Checkbox("Include background Widget", userSettings.includeBg)
        if changed then
            inkHelper.setVisibility(alertWidgets, true, userSettings)
            saveUserSettings()
        end
        ImGui.SetNextItemWidth(gameRes.X / 8)
        userSettings.dateTimeFontSize, changed = ImGui.SliderInt("Date/Time Font Size", userSettings.dateTimeFontSize, 20, 40)
        if changed then
            saveUserSettings()
        end
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.Text("Note: Font size changes take up to one full second to apply.")
            ImGui.EndTooltip()
        end
        if ImGui.TreeNode("Time/Date Format Options") then
            userSettings.clockIs24Hr, changed = ImGui.Checkbox("Use 24 Hour Clock Format", userSettings.clockIs24Hr)
            if changed then
                saveUserSettings()
            end
            userSettings.dateIs2077, changed = ImGui.Checkbox("Use 2077 As Current Year", userSettings.dateIs2077)
            if changed then
                saveUserSettings()
            end
            userSettings.dateIsEuro, changed = ImGui.Checkbox("Use Day/Month/Year Format", userSettings.dateIsEuro)
            if changed then
                saveUserSettings()
            end
            ImGui.TreePop()
        end
    end
    ImGui.End()
end)

local PADDING = 20 -- Base padding (1080p)
local MAX_CHAR = 250 -- Increased character limit since line breaks are now supported
local FONT_SIZE = 35 -- Base font size (1080p)
local DUMMY_ALERT_HEIGHT = 60 -- Only used for initial widget creation before dynamic sizing

local function createAlertWidgets(parent)
    alertWidgets = inkHelper.createAlertWidgets(parent, PADDING, DUMMY_ALERT_HEIGHT, userSettings)
end

local function showNextAlert()
    if #alertQueue == 0 then return end
    activeAlert = table.remove(alertQueue, 1)
    alertTimer = Game.GetEngineTime():ToFloat() + activeAlert.duration
    local text = activeAlert.text ~= nil and type(activeAlert.text) == "string" and activeAlert.text or nil
    if not text then return end
    local vSize = activeAlert.vSize or FONT_SIZE
    inkHelper.setAlertWidgetProperties(alertWidgets, text, vSize, gameRes, PADDING, userSettings) 
end

registerForEvent("onInit", function()
    loadUserSettings()
    gameRes = Game.GetUISystem() and Game.GetUISystem():GetCurrentWindowSize() or gameRes
    inkHelper.setVisibility(alertWidgets, false, userSettings)

    alertWidgets.background = nil
    alertWidgets.textContainer = nil
    alertWidgets.textLines = {}
    isDateTimeVisible = false
    nextDateTimeUpdate = 0
    
    alertQueue = {}
    activeAlert = nil
    alertTimer = 0

    local parent = GameInstance.GetInkSystem() and GameInstance.GetInkSystem():GetLayer("inkHUDLayer") and GameInstance.GetInkSystem():GetLayer("inkHUDLayer"):GetVirtualWindow() or nil
    if parent and not alertWidgets.background then
        createAlertWidgets(parent)
    end

    --Alert message that will display if mods are reloaded while in-game
    SimpleAlerts.ShowAlert("SimpleAlerts_Welcome", "SimpleAlerts Mod Has Re-initialized", 5, userSettings.dateTimeFontSize)

    Observe("inkMenuScenario", "SwitchToScenario", function(_, _, _)
        gameRes = Game.GetUISystem() and Game.GetUISystem():GetCurrentWindowSize() or gameRes
    end)

    Observe("PlayerPuppet", "OnCombatStateChanged", function(this, newState)
        isInCombat = newState == 1
    end)

    ObserveAfter("PlayerPuppet", "OnMountingEvent", function(this, evt)
        isInVehicle = this.mountedVehicle ~= nil or false
    end)

    ObserveAfter("PlayerPuppet", "OnUnmountingEvent", function(this, evt)
        isInVehicle = this.mountedVehicle ~= nil or false
    end)

    Observe("PlayerPuppet", "OnVisionStateChange", function(this, newState)
        isInScanner = newState >= 1
    end)

    Observe("MinimapContainerController", "OnPlayerAttach", function(_, _)
        gameRes = Game.GetUISystem() and Game.GetUISystem():GetCurrentWindowSize() or gameRes
        inkHelper.setVisibility(alertWidgets, false, userSettings)

        isInVehicle = GetPlayer().mountedVehicle ~= nil or false

        alertWidgets.background = nil
        alertWidgets.textContainer = nil
        alertWidgets.textLines = {}
        
        alertQueue = {}
        activeAlert = nil
        alertTimer = 0
        isDateTimeVisible = false
        nextDateTimeUpdate = 0

        local parent = GameInstance.GetInkSystem() and GameInstance.GetInkSystem():GetLayer("inkHUDLayer") and GameInstance.GetInkSystem():GetLayer("inkHUDLayer"):GetVirtualWindow() or nil
        if parent and not alertWidgets.background then
            createAlertWidgets(parent)
        end
    end)
end)

registerForEvent("onUpdate", function()
    local currTime = Game.GetEngineTime():ToFloat()
    
    -- 1. Alert message cleanup/advancement
    if activeAlert and currTime >= alertTimer then
        inkHelper.setVisibility(alertWidgets, false, userSettings)
        activeAlert = nil
    end

    -- 2. Check for next alert to show
    if not activeAlert and #alertQueue > 0 then
        -- Hide the date/time display if it's currently showing, before showing the new alert
        if isDateTimeVisible then
            inkHelper.setVisibility(alertWidgets, false, userSettings)
            isDateTimeVisible = false
        end
        showNextAlert()
    end

    -- 3. Date/Time Display Logic (runs only if no alert is active/queued)
    if not activeAlert and #alertQueue == 0 then
        local shouldShowDateTime = userSettings.dateTimeDisplayOn

        -- Conditions to HIDE the date/time display
        -- If an activity is active AND the setting to show it is false, then shouldShowDateTime is set to false
        if shouldShowDateTime and isInCombat and not userSettings.showDateInCombat then
            shouldShowDateTime = false
        end
        
        if shouldShowDateTime and isInScanner and not userSettings.showDateInScanner then
            shouldShowDateTime = false
        end
        
        if shouldShowDateTime and isInVehicle and not userSettings.showDateInVehicle then
            shouldShowDateTime = false
        end

        if shouldShowDateTime then
            local justBecameVisible = false
            
            if not isDateTimeVisible then
                -- Safety check to ensure widgets exist before attempting to draw
                local parent = GameInstance.GetInkSystem() and GameInstance.GetInkSystem():GetLayer("inkHUDLayer") and GameInstance.GetInkSystem():GetLayer("inkHUDLayer"):GetVirtualWindow() or nil
                if parent and not alertWidgets.background then 
                    createAlertWidgets(parent)
                end
                if alertWidgets.background then
                    isDateTimeVisible = true
                    justBecameVisible = true -- Flag to force immediate update
                end
            end

            -- Update the UI only if it just became visible or the 1-second interval has passed
            if isDateTimeVisible and (justBecameVisible or currTime >= nextDateTimeUpdate) then
                nextDateTimeUpdate = currTime + DATE_TIME_UPDATE_INTERVAL -- Set next update time
                
                -- Get system date/time
                local systemTime = os.time()
                
                -- Date: MM/DD (system date) + 2077 (fixed year)
                local datePart = userSettings.dateIs2077 and os.date("%m/%d", systemTime) .. "/2077" or os.date("%m/%d/%Y", systemTime)
                if userSettings.dateIsEuro then
                    datePart = userSettings.dateIs2077 and os.date("%d/%m", systemTime) .. "/2077" or os.date("%d/%m/%Y", systemTime)
                end
                
                -- Time: 12-hour format (HH:MM AM/PM)
                local timePart = not userSettings.clockIs24Hr and os.date("%I:%M %p", systemTime) or os.date("%H:%M", systemTime)
                
                -- Format: "Current Date: MM/DD/2077 - Current Time: 12:00"
                --local text = string.format("Current Date: %s/2077 - Current Time: %s", datePart, timePart)
                local text = string.format("Current Date: %s - Current Time: %s", datePart, timePart)
                
                -- MODIFIED: Use the new function to update the text if the widget exists
                local updated = inkHelper.updateSingleLineText(alertWidgets, text, userSettings)

                -- If the text wasn't updated (i.e., this is the first run after creation/recreation
                -- or if font size changed), use the full properties setter to ensure text widget exists
                -- and sizes are correct.

                if not updated then 
                    inkHelper.setAlertWidgetProperties(alertWidgets, text, userSettings.dateTimeFontSize, gameRes, PADDING, userSettings)
                end
            end
        elseif isDateTimeVisible then
            -- Hide the date/time display if it was visible but the condition is now false
            inkHelper.setVisibility(alertWidgets, false, userSettings)
            isDateTimeVisible = false
        end
    end
end)

registerForEvent("onShutdown", function() --Reset everything on CET shutdown event
    inkHelper.setVisibility(alertWidgets, false, userSettings)

    alertWidgets.background = nil
    alertWidgets.textContainer = nil
    alertWidgets.textLines = {}
    
    alertQueue = {}
    activeAlert = nil
    alertTimer = 0
    isDateTimeVisible = false
    nextDateTimeUpdate = 0
end)



-- USER EXPOSED FUNCTIONS TO DISPLAY/HIDE MESSAGES

--[[
--Get the mod using:
local SimpleAlerts = GetMod("SimpleAlertsAndTimeDisplay")
]]

function SimpleAlerts.ShowAlert(alertID, text, duration, vSize)
    -- Unique Id (string, used to hide alerts before timer expires)
    -- Display text (string) - Can now contain multiple lines separated by \n or \r\n
    -- Duration (float, seconds)
    -- Vertical Size (integer, height of text in pixels at 1080P, but scales with resolution. Max size is 60.)
    -- NOTE: The vertical size of the background will always be dynamically calculated to fit lines + padding

    if not text or #text == 0 then return end
    text = text:sub(1, MAX_CHAR)
    local newVSize = vSize ~= nil and vSize or 35
    if newVSize > 60 then newVSize = 60 end
    local newDur = duration ~= nil and duration or 5
    if newDur > 10 then newDur = 10 end
    table.insert(alertQueue, {id = alertID, text = text, duration = newDur, vSize = newVSize})
end

function SimpleAlerts.HideAlert(alertID)
    if not alertID or type(alertID) ~= "string" then return end
    for i = #alertQueue, 1, -1 do
        if alertQueue[i].id == alertID then
            table.remove(alertQueue, i)
        end
    end
    if activeAlert and activeAlert.id == alertID then
        inkHelper.setVisibility(alertWidgets, false, userSettings)
        activeAlert = nil
        alertTimer = 0
    end
    if not activeAlert and #alertQueue > 0 then
        showNextAlert()
    end
end

return SimpleAlerts
