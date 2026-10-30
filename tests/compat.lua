-- Offline Lua 5.1 regression checks for client selection and normalized loot data.
local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local library = dofile("tests/library.lua")
local testLogger = {
    error = function(_, message)
        error(message)
    end,
    debug = function() end,
}

local function loadAddon(project, interface, history)
    WOW_PROJECT_MAINLINE = 1
    WOW_PROJECT_ID = project
    C_LootHistory = history
    GetBuildInfo = function()
        return "", "", "", interface
    end
    library.reset()
    local lib = library.load({
        after = function(path, lib)
            if path:match("/logger%.lua$") then
                lib.internal.logger = testLogger
            end
        end,
    })
    return lib.internal.api
end

GetLootRollItemInfo = function(id)
    if id == 99 then
        return nil
    end
    return 123, "Item", 2, 4, true, false, true, true, 1, nil, nil
end
GetLootRollItemLink = function()
    return "item:123"
end
GetLootRollTimeLeft = function(id)
    return id == 99 and 0 or 12000
end
GetActiveLootRollIDs = function()
    return { 10, 11, 99 }
end
LOOT_ROLL_INELIGIBLE_REASON1 = "Cannot need"
ITEM_QUALITY_COLORS = { [4] = { r = 0.6, g = 0.2, b = 0.8 } }
LOOT_BORDER_BY_QUALITY = { [4] = "loottoast-itemborder-purple" }
RAID_CLASS_COLORS = { MAGE = { colorStr = "ffabcdef" } }
local rolled
RollOnLoot = function(id, choice)
    rolled = { id, choice }
end
local players = {
    { "Need", "MAGE", 1, 87, true, true },
    { "Greed", "MAGE", 2, 12, false, false },
    { "DE", "MAGE", 3, 42, false, false },
    { "Pass", "MAGE", 0, nil, false, false },
    { "Waiting", "MAGE", nil, nil, false, false },
}
local items = { 11, 10 }
local history = {
    GetNumItems = function()
        return #items
    end,
    GetItem = function(index)
        return items[index], "item:123", items[index] == 10 and #players or 1
    end,
    GetPlayerInfo = function(index, player)
        if items[index] == 11 then
            return "Other drop", "MAGE", 3, 66, false, false
        end
        return unpack(players[player], 1, 6)
    end,
}
for _, project in ipairs({ 2, 5, 19 }) do
    local api = loadAddon(project, 11509, history)
    equal(api.client, "classic")
    equal(api.events.needRollResult, nil)
    equal(api.events.allRollsCancelled, nil)
    equal(#api.GetActiveRolls(), 2)
    equal(api.GetActiveRolls()[1].duration, 12000)
    local item = api.GetRollItem(10)
    equal(item.canTransmog, false)
    equal(item.canDisenchant, true)
    equal(item.reasonNeed, "Cannot need")
    equal(api.GetRollItem(99), nil)
    local choices = api.GetRollChoices(10)
    for _, choice in ipairs({ "need", "greed", "disenchant", "pass", "undecided" }) do
        equal(#choices[choice], 1)
    end
    equal(choices.need[1].roll, 87)
    equal(choices.need[1].isSelf, true)
    equal(choices.need[1].isWinner, true)
    items = { 10, 11 } -- History indices can change, even for identical links.
    equal(api.GetRollChoices(11).disenchant[1].name, "Other drop")
    equal(api.GetRollChoices(99), nil)
    api.Roll(10, api.RollType.Disenchant)
    equal(rolled[2], 3)
    equal(api.GetQualityBorderAtlas(4), "loottoast-itemborder-purple")
    equal(api.ColorizeName("Name", "MAGE"), "|cffabcdefName|r")

    local hooks = {}
    hooksecurefunc = function(name, fn)
        hooks[name] = fn
    end
    GroupLootFrame_OpenNewFrame = function() end
    GroupLootContainer = {}
    GroupLootFrame1 = {
        rollID = 10,
        shown = true,
        IsShown = function(self)
            return self.shown
        end,
    }
    GroupLootContainer_RemoveFrame = function(_, frame)
        frame.shown = false
    end
    local active = true
    api.HideBlizzardRollFrames(function()
        return active
    end)
    equal(GroupLootFrame1.shown, false)
    GroupLootFrame1.shown = true
    hooks.GroupLootFrame_OpenNewFrame(10)
    equal(GroupLootFrame1.shown, false)
    active = false
    GroupLootFrame1.shown = true
    hooks.GroupLootFrame_OpenNewFrame(10)
    equal(GroupLootFrame1.shown, true)
    active = true
    hooks.GroupLootFrame_OpenNewFrame(10)
    equal(GroupLootFrame1.shown, false)
end
equal(loadAddon(1, 120105, history):IsSupported(), false)
equal(loadAddon(2, 11509, {}):IsSupported(), false)
local encounterHistory = {
    GetSortedDropsForEncounter = function()
        return {}
    end,
}
equal(loadAddon(1, 120105, encounterHistory):IsSupported(), false)
local forever = loadAddon(1, 16001, encounterHistory)
equal(forever.client, "forever")
local active, hook, hookCount = true, nil, 0
GroupLootContainer_OpenNewFrame = function() end
hooksecurefunc = function(name, callback)
    equal(name, "GroupLootContainer_OpenNewFrame")
    hook, hookCount = callback, hookCount + 1
end
forever.HideBlizzardRollFrames(function()
    return active
end)
forever.HideBlizzardRollFrames(function()
    return active
end)
equal(hookCount, 1)
GroupLootFrame1.shown = true
hook(10)
equal(GroupLootFrame1.shown, false)
active = false
GroupLootFrame1.shown = true
hook(10)
equal(GroupLootFrame1.shown, true)
active = true
hook(10)
equal(GroupLootFrame1.shown, false)
print("Client compatibility checks passed (Era, Anniversary, Classic, Forever; retail excluded)")
