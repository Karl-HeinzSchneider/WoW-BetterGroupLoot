---@type string, BetterGroupLoot
local _, app = ...

-- WoW Forever (1.6, a client of the retail family). Rolls work as on every client
-- (START_LOOT_ROLL, GetLootRollItemInfo, RollOnLoot), but who chose what lives in the
-- encounter-based loot history (C_LootHistory.GetSortedDropsForEncounter), which knows nothing
-- about rollIDs; findDrop() pairs the two up.
if app.api.client or not (C_LootHistory and C_LootHistory.GetSortedDropsForEncounter) then
    return
end

local log = app.logger

local impl = {}

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

local function ineligibleReason(allowed, code)
    if allowed or not code then
        return nil
    end
    return _G["LOOT_ROLL_INELIGIBLE_REASON" .. code]
end

function impl.GetRollItem(rollID)
    local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed, reasonDisenchant, _, canTransmog =
        GetLootRollItemInfo(rollID)
    if not name then
        return nil
    end

    ---@type BetterGroupLoot.RollItem
    local item = {
        name = name,
        texture = texture,
        link = GetLootRollItemLink(rollID),
        count = count or 1,
        quality = quality or 1,
        bindOnPickUp = bindOnPickUp and true or false,
        canNeed = canNeed and true or false,
        canGreed = canGreed and true or false,
        canTransmog = canTransmog and true or false,
        canDisenchant = canDisenchant and true or false,
        reasonNeed = ineligibleReason(canNeed, reasonNeed),
        reasonGreed = ineligibleReason(canGreed, reasonGreed),
        reasonDisenchant = ineligibleReason(canDisenchant, reasonDisenchant),
    }
    return item
end

function impl.GetRollTimeLeft(rollID)
    return GetLootRollTimeLeft(rollID) or 0
end

function impl.Roll(rollID, rollType)
    RollOnLoot(rollID, rollType)
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
            log:debug("Roll %d is loot history drop %d:%d", rollID, ref.encounterID, ref.lootListKey)
        end
    end
    if not drop then
        return nil
    end

    local choices = app.api.NewChoices()
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

function impl.SetItemTooltip(tooltip, rollID)
    tooltip:SetLootRollItem(rollID)
end

function impl.HandleModifiedItemClick(rollID)
    local link = GetLootRollItemLink(rollID)
    if link then
        HandleModifiedItemClick(link)
    end
end

function impl.GetQualityColor(quality)
    local color = (ColorManager and ColorManager.GetColorDataForItemQuality(quality)) or ITEM_QUALITY_COLORS[quality]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

function impl.GetQualityBorderAtlas(quality)
    local atlas = ColorManager
        and ColorManager.GetAtlasDataForLootBorderItemQuality
        and ColorManager.GetAtlasDataForLootBorderItemQuality(quality)
    return atlas or "loottoast-itemborder-white"
end

function impl.ColorizeName(name, class)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = class and colors[class]
    if color and color.colorStr then
        return "|c" .. color.colorStr .. name .. "|r"
    end
    return name
end

-- In gamepad mode the client lists rolls in a panel of its own instead of the roll frames.
function impl.IsRollUIActive()
    return not (InputUtil and InputUtil.IsGamepadUIEnabled and InputUtil.IsGamepadUIEnabled())
end

-- The client opens its own roll frames (GroupLootFrame1-4) from START_LOOT_ROLL as well. Let it,
-- then close each one right away through the same container function it uses itself, so its
-- bookkeeping (waiting rolls, the bottom frame layout, alerts stacked above) stays consistent.
local blizzardFramesHidden = false
function impl.HideBlizzardRollFrames()
    if blizzardFramesHidden or not GroupLootContainer_OpenNewFrame then
        return
    end
    blizzardFramesHidden = true

    hooksecurefunc("GroupLootContainer_OpenNewFrame", function(rollID)
        for i = 1, 4 do
            local frame = _G["GroupLootFrame" .. i]
            if frame and frame.rollID == rollID and frame:IsShown() then
                GroupLootContainer_RemoveFrame(GroupLootContainer, frame)
            end
        end
    end)
end

app.api:Implement("forever", impl)
