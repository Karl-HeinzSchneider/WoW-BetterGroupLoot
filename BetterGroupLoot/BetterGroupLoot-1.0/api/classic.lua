local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

-- Era/Hardcore/SoD, Anniversary and progression Classic share roll-indexed history.
-- The exported tree also contains unused mainline files; select the runtime API.
if
    internal.api.client
    or WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
    or not (C_LootHistory and C_LootHistory.GetNumItems and C_LootHistory.GetItem and C_LootHistory.GetPlayerInfo)
then
    return
end

local impl = internal.api.CreateImplementation()
impl.events = {
    rollStarted = "START_LOOT_ROLL",
    rollCancelled = "CANCEL_LOOT_ROLL",
    choicesChanged = { "LOOT_HISTORY_FULL_UPDATE", "LOOT_HISTORY_ROLL_CHANGED", "LOOT_HISTORY_ROLL_COMPLETE" },
}

local choiceByType = { [0] = "pass", [1] = "need", [2] = "greed", [3] = "disenchant" }

function impl.GetActiveRolls()
    local rolls = {}
    for _, rollID in ipairs(GetActiveLootRollIDs() or {}) do
        local remaining = impl.GetRollTimeLeft(rollID)
        if remaining > 0 then
            rolls[#rolls + 1] = { rollID = rollID, duration = remaining }
        end
    end
    return rolls
end

function impl.GetRollChoices(rollID)
    -- Indices change when history is cleared or pruned. Resolve by rollID every time,
    -- rather than pairing by link (two identical drops can roll simultaneously).
    for itemIndex = 1, C_LootHistory.GetNumItems() do
        local id, _, numPlayers = C_LootHistory.GetItem(itemIndex)
        if id == rollID then
            local choices = internal.api.NewChoices()
            for playerIndex = 1, numPlayers or 0 do
                local name, class, rollType, roll, isWinner, isSelf =
                    C_LootHistory.GetPlayerInfo(itemIndex, playerIndex)
                if name then
                    local choice = choiceByType[rollType] or "undecided"
                    local list = choices[choice]
                    list[#list + 1] = {
                        name = name,
                        class = class,
                        roll = roll,
                        isWinner = isWinner and true or false,
                        isSelf = isSelf and true or false,
                    }
                end
            end
            return choices
        end
    end
end

function impl.ForgetRoll() end

function impl.IsRollUIActive()
    return true
end

local hidden = false
function impl.HideBlizzardRollFrames(isActive)
    if hidden or not GroupLootFrame_OpenNewFrame or not GroupLootContainer_RemoveFrame then
        return
    end
    hidden = true
    local function closeFrames(rollID)
        if isActive and not isActive() then
            return
        end
        for index = 1, NUM_GROUP_LOOT_FRAMES or 4 do
            local frame = _G["GroupLootFrame" .. index]
            if frame and frame:IsShown() and (not rollID or frame.rollID == rollID) then
                GroupLootContainer_RemoveFrame(GroupLootContainer, frame)
            end
        end
    end
    hooksecurefunc("GroupLootFrame_OpenNewFrame", closeFrames)
    closeFrames()
end

internal.api:Implement("classic", impl)
