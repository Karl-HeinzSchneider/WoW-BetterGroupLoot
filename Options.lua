-- Dont include this file when embeding in other addons
local addonName, addonTable = ...
if addonName ~= 'BetterGroupLoot' then return; end

local lib = LibStub:GetLibrary('BetterGroupLoot-1.0')

if not lib or lib.optionsSet then return; end
lib.optionsSet = true;

-- print('hook options!')
local frame = lib.frame;

local SettingsDefaultStringFormat = "\n\n(Default: |cff8080ff%s|r)"

local function SetupOptions()
    -- print('options!')

    local BetterGroupLootDB = BetterGroupLootDB;

    local function OnSettingChanged(setting, value)
        -- print("Setting changed:", setting:GetVariable(), value)
        -- DevTools_Dump({AuraDurationsDB})
        frame:Update()
    end

    local category = Settings.RegisterVerticalLayoutCategory("BetterGroupLoot")
    lib.addonCategory = category

    do
        local name = "Show Preview"
        local variable = "Show Preview"
        local variableKey = "showPreview"
        local variableTbl = BetterGroupLootDB
        local defaultValue = lib.Defaults.showPreview

        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue),
                                                      name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)

        local tooltip = "Displays the preview so you can adjust the position."
        tooltip = tooltip .. string.format(SettingsDefaultStringFormat, tostring(defaultValue))
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    do
        -- RegisterProxySetting example. This will run the GetValue and SetValue
        -- callbacks whenever access to the setting is required.

        local name = "X"
        local variable = "X"
        local defaultValue = lib.Defaults.x
        local minValue = -3000
        local maxValue = 3000
        local step = 1

        local function GetValue()
            return BetterGroupLootDB.x or defaultValue
        end

        local function SetValue(value)
            BetterGroupLootDB.x = value
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue,
                                                      GetValue, SetValue)
        setting:SetValueChangedCallback(OnSettingChanged)

        local tooltip = "Sets the X coordinate of the GroupLootFrame."
        tooltip = tooltip .. string.format(SettingsDefaultStringFormat, tostring(defaultValue))
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
        Settings.CreateSlider(category, setting, options, tooltip)
    end

    do
        -- RegisterProxySetting example. This will run the GetValue and SetValue
        -- callbacks whenever access to the setting is required.

        local name = "Y"
        local variable = "Y"
        local defaultValue = lib.Defaults.y
        local minValue = -3000
        local maxValue = 3000
        local step = 1

        local function GetValue()
            return BetterGroupLootDB.y or defaultValue
        end

        local function SetValue(value)
            BetterGroupLootDB.y = value
        end

        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue,
                                                      GetValue, SetValue)
        setting:SetValueChangedCallback(OnSettingChanged)

        local tooltip = "Sets the Y coordinate of the GroupLootFrame."
        tooltip = tooltip .. string.format(SettingsDefaultStringFormat, tostring(defaultValue))
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
        Settings.CreateSlider(category, setting, options, tooltip)
    end

    Settings.RegisterAddOnCategory(category)
end
hooksecurefunc(frame, 'PLAYER_LOGIN', SetupOptions)

