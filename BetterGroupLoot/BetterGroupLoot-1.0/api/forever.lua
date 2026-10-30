local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

-- WoW Forever (1.6, a client of the retail family). Rolls work as on every client
-- (START_LOOT_ROLL, GetLootRollItemInfo, RollOnLoot), but who chose what lives in the
-- encounter-based loot history (C_LootHistory.GetSortedDropsForEncounter), which knows nothing
-- about rollIDs; findDrop() pairs the two up.
local _, _, _, interface = GetBuildInfo()
if interface ~= 16001 or internal.api.client or not (C_LootHistory and C_LootHistory.GetSortedDropsForEncounter) then
    return
end

local impl = internal.api.CreateImplementation()

impl.events = {
    rollStarted = "START_LOOT_ROLL",
    rollCancelled = "CANCEL_LOOT_ROLL",
    allRollsCancelled = "CANCEL_ALL_LOOT_ROLLS",
    needRollResult = "MAIN_SPEC_NEED_ROLL",
    choicesChanged = {
        "LOOT_HISTORY_UPDATE_DROP",
        "LOOT_HISTORY_UPDATE_ENCOUNTER",
        "LOOT_HISTORY_CLEAR_HISTORY",
    },
}

-- Enum.EncounterLootDropRollState, with its documented values as a fallback.
local RollState = Enum and Enum.EncounterLootDropRollState
    or { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }

---@type table<number, BetterGroupLoot.Choice>
local choiceByState = {
    [RollState.NeedMainSpec] = "need",
    [RollState.NeedOffSpec] = "need",
    [RollState.Transmog] = "transmog",
    [RollState.Greed] = "greed",
    [RollState.NoRoll] = "undecided",
    [RollState.Pass] = "pass",
}

-- Rolls ------------------------------------------------------------------------------------------

function impl.GetActiveRolls()
    local rolls = {}
    for _, rollID in ipairs(GetActiveLootRollIDs() or {}) do
        rolls[#rolls + 1] = { rollID = rollID, duration = C_Loot.GetLootRollDuration(rollID) or 0 }
    end
    return rolls
end

-- Choices: rollID -> loot history drop ------------------------------------------------------------

-- rollID -> the drop it was paired with.
---@type table<number, {encounterID: number, lootListKey: number}>
local dropByRoll = {}

local function itemID(link)
    return link and tonumber(link:match("item:(%d+)"))
end

-- The history drop that belongs to a roll. The best candidate carries the roll's exact item link
-- and is still being rolled for; links can differ in their bonus fields, so the same item ID
-- counts too, and a finished drop is the last resort. Drops already paired with another open roll
-- are skipped, which tells two copies of the same item apart. A roll outside the loot history
-- (no encounter) finds nothing.
---@return {encounterID: number, lootListKey: number}?
local function findDrop(rollID)
    local link = GetLootRollItemLink(rollID)
    if not link then
        return nil
    end
    local id = itemID(link)

    local claimed = {}
    for otherRollID, ref in pairs(dropByRoll) do
        if otherRollID ~= rollID then
            claimed[ref.encounterID .. ":" .. ref.lootListKey] = true
        end
    end

    local best, bestScore = nil, 0
    for _, encounter in ipairs(C_LootHistory.GetAllEncounterInfos() or {}) do
        local encounterID = encounter.encounterID
        for _, drop in ipairs(C_LootHistory.GetSortedDropsForEncounter(encounterID) or {}) do
            if not claimed[encounterID .. ":" .. drop.lootListKey] then
                local score = 0
                if drop.itemHyperlink == link then
                    score = 2
                elseif id and itemID(drop.itemHyperlink) == id then
                    score = 1
                end
                if score > 0 and not drop.winner and not drop.allPassed then
                    score = score + 2
                end
                if score > bestScore then
                    best, bestScore = { encounterID = encounterID, lootListKey = drop.lootListKey }, score
                    if score == 4 then
                        return best
                    end
                end
            end
        end
    end
    return best
end

function impl.GetRollChoices(rollID)
    local ref = dropByRoll[rollID]
    local drop = ref and C_LootHistory.GetSortedInfoForDrop(ref.encounterID, ref.lootListKey)
    if not drop then
        -- Not paired yet (the history entry often arrives after START_LOOT_ROLL), or the pairing
        -- went stale because the history was cleared.
        ref = findDrop(rollID)
        dropByRoll[rollID] = ref
        drop = ref and C_LootHistory.GetSortedInfoForDrop(ref.encounterID, ref.lootListKey)
        if drop then
            internal.logger:debug("Roll %d is loot history drop %d:%d", rollID, ref.encounterID, ref.lootListKey)
        end
    end
    if not drop then
        return nil
    end

    local choices = internal.api.NewChoices()
    for _, info in ipairs(drop.rollInfos or {}) do
        local choice = choiceByState[info.state]
        if choice then
            local list = choices[choice]
            list[#list + 1] = {
                name = info.playerName,
                class = info.playerClass,
                roll = info.roll,
                isSelf = info.isSelf,
                isWinner = info.isWinner,
                offSpec = info.state == RollState.NeedOffSpec,
            }
        end
    end
    return choices
end

function impl.ForgetRoll(rollID)
    dropByRoll[rollID] = nil
end

-- Display helpers --------------------------------------------------------------------------------

-- In gamepad mode the client lists rolls in a panel of its own instead of the roll frames.
function impl.IsRollUIActive()
    return not (InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled())
end

-- The client opens its own roll frames (GroupLootFrame1-4) from START_LOOT_ROLL as well. Let it,
-- then close each one right away through the same container function it uses itself, so its
-- bookkeeping (waiting rolls, the bottom frame layout, alerts stacked above) stays consistent.
local blizzardFramesHidden = false
function impl.HideBlizzardRollFrames(isActive)
    if blizzardFramesHidden or not GroupLootContainer_OpenNewFrame then
        return
    end
    blizzardFramesHidden = true

    hooksecurefunc("GroupLootContainer_OpenNewFrame", function(rollID)
        if isActive and not isActive() then
            return
        end
        for i = 1, 4 do
            local frame = _G["GroupLootFrame" .. i]
            if frame and frame.rollID == rollID and frame:IsShown() then
                GroupLootContainer_RemoveFrame(GroupLootContainer, frame)
            end
        end
    end)
end

internal.api:Implement("forever", impl)
