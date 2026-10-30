local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

local api = internal.api

-- The roll frames: one per running roll, stacked on a movable anchor. Unlocking shows the anchor
-- with a few preview rolls, so the frames can be dragged into place.

local FRAME_WIDTH, FRAME_HEIGHT = 277, 67
local NEED_ROLL_RESULT_SECONDS = 5 -- how long the own Need roll's number stays up

-- Preview rolls: a few well-known items and a made-up group.
local PREVIEW_ITEMS = { 19019, 17182, 22631 }
local PREVIEW_PLAYERS = {
    { "Thrall", "SHAMAN" },
    { "Jaina", "MAGE" },
    { "Varian", "WARRIOR" },
    { "Tyrande", "PRIEST" },
    { "Rexxar", "HUNTER" },
    { "Valeera", "ROGUE" },
    { "Malfurion", "DRUID" },
    { "Uther", "PALADIN" },
    { "Guldan", "WARLOCK" },
}
local PREVIEW_DURATION = 60000

---@class BetterGroupLoot.Rolls
---@field host table the normalized Start options
---@field logger BetterGroupLoot.Logger
---@field strings table<string, string> tooltip text
---@field eventFrame Frame
---@field eventHandlers table<string, string> event -> method name
---@field active boolean
---@field editMode table? Optional Edit Mode registration retained across disable/enable
---@field anchor Frame
---@field mover Button
---@field pool table Object pool of private roll frames
---@field frames BetterGroupLootRollFrameMixin[] shown frames in stacking order: real rolls, then previews
---@field unlocked boolean
local module = {}
-- lib:Start calls this only after claiming ownership.
function module:Initialize(host)
    self.host = host
    self.frames = {}
    self.unlocked = false
    self.eventHandlers = {}
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self[self.eventHandlers[event]](self, event, ...)
    end)
    self:CreateAnchor()
    local count = 0
    self.pool = CreateObjectPool(function()
        count = count + 1
        local frame = internal.CreateRollFrame(self.anchor, host.prefix .. "RollFrame" .. count)
        frame.controller = self
        return frame
    end, function(_, frame)
        frame:Reset()
    end)
    self:ApplySettings()
end

function module:GetProfile()
    return self.host.getProfile()
end

-- Game events call the named method with (event, ...), like AceEvent.
---@param event string
---@param method string
function module:RegisterEvent(event, method)
    self.eventHandlers[event] = method
    self.eventFrame:RegisterEvent(event)
end

function module:UnregisterAllEvents()
    self.eventFrame:UnregisterAllEvents()
    wipe(self.eventHandlers)
end

function module:RefreshOptions()
    if self.host.changed then
        self.host.changed()
    end
end

function module:Start()
    if self.active then
        return
    end
    self.active = true
    self.anchor:Show()
    api.HideBlizzardRollFrames(function()
        return self.active
    end)

    local events = api.events
    self:RegisterEvent(events.rollStarted, "OnRollStarted")
    self:RegisterEvent(events.rollCancelled, "OnRollCancelled")
    if events.allRollsCancelled then
        self:RegisterEvent(events.allRollsCancelled, "OnAllRollsCancelled")
    end
    if events.needRollResult then
        self:RegisterEvent(events.needRollResult, "OnNeedRollResult")
    end
    for _, event in ipairs(events.choicesChanged) do
        self:RegisterEvent(event, "UpdateChoices")
    end
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "SyncActiveRolls")

    self:SyncActiveRolls()
    if self.editMode then
        self:RegisterEvent("PLAYER_REGEN_DISABLED", "RefreshEditMode")
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshEditMode")
        self:RefreshEditMode()
    end
end

-- The first OnProfileRefresh runs before OnInitialize, hence the guard.
function module:OnProfileRefresh()
    if self.anchor then
        self:ApplySettings()
        if self.editMode then
            self:RefreshEditMode()
        end
    end
end

-- Anchor and position -----------------------------------------------------------------------------

function module:CreateAnchor()
    local anchor = CreateFrame("Frame", self.host.prefix .. "Anchor", UIParent)
    anchor:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    anchor:SetFrameStrata("DIALOG")
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    self.anchor = anchor

    -- Covers the first roll slot while unlocked: drag to move, right-click to lock.
    local mover = CreateFrame("Button", nil, anchor)
    mover:SetAllPoints()
    mover:SetFrameLevel(anchor:GetFrameLevel() + 20)
    mover:RegisterForDrag("LeftButton")
    mover:RegisterForClicks("RightButtonUp")
    mover:Hide()

    local background = mover:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.1, 0.4, 1, 0.45)

    local label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText(self.host.moverText or (self.host.prefix .. "\n|cffd0d0d0Drag to move, right-click to lock|r"))

    mover:SetScript("OnDragStart", function()
        anchor:StartMoving()
    end)
    mover:SetScript("OnDragStop", function()
        anchor:StopMovingOrSizing()
        self:SavePosition()
    end)
    mover:SetScript("OnClick", function()
        self:SetUnlocked(false)
    end)
    self.mover = mover
end

-- Position, scale and stacking from the profile.
function module:ApplySettings()
    if self.host.applyPosition then
        self.host.applyPosition(self.anchor)
        self:Layout()
        return
    end
    local profile = self:GetProfile()
    local scale = profile.scale
    self.anchor:SetScale(scale)
    if self.editMode and self.editMode.followDefaultScale then
        local default = self.editMode.defaultPosition
        default.x = self.host.defaultPosition.x / scale
        default.y = self.host.defaultPosition.y / scale
    end
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("BOTTOM", UIParent, "BOTTOM", profile.position.x / scale, profile.position.y / scale)
    self:Layout()
end

-- Stores where the anchor was dragged to, as the profile's bottom-center offset in UIParent units.
function module:SavePosition()
    if self.host.savePosition then
        self.host.savePosition(self.anchor)
        self:ApplySettings()
        self:RefreshOptions()
        return
    end
    local anchor = self.anchor
    local scale = anchor:GetScale()
    local position = self:GetProfile().position
    position.x = math.floor(anchor:GetCenter() * scale - UIParent:GetWidth() / 2 + 0.5)
    position.y = math.floor(anchor:GetBottom() * scale + 0.5)
    self:ApplySettings()
    self:RefreshOptions()
end

function module:ResetPosition()
    if self.host.resetPosition then
        self.host.resetPosition(self.anchor)
        self:ApplySettings()
        self:RefreshOptions()
        return
    end
    local defaults = self.host.defaultPosition
    local position = self:GetProfile().position
    position.x = defaults.x
    position.y = defaults.y
    self:ApplySettings()
    self:RefreshOptions()
end

function module:Layout()
    local profile = self:GetProfile()
    local step = FRAME_HEIGHT + profile.spacing
    for index, frame in ipairs(self.frames) do
        local offset = (index - 1) * step
        frame:ClearAllPoints()
        if profile.growUp then
            frame:SetPoint("BOTTOM", self.anchor, "BOTTOM", 0, offset)
        else
            frame:SetPoint("TOP", self.anchor, "TOP", 0, -offset)
        end
    end
end

-- Frames ----------------------------------------------------------------------------------------

---@param rollID number
---@return BetterGroupLootRollFrameMixin?
function module:FindFrame(rollID)
    for _, frame in ipairs(self.frames) do
        if frame.rollID == rollID then
            return frame
        end
    end
end

-- Real rolls stack below the previews.
---@param frame BetterGroupLootRollFrameMixin
function module:InsertFrame(frame)
    local index = #self.frames + 1
    if not frame.preview then
        for i, other in ipairs(self.frames) do
            if other.preview then
                index = i
                break
            end
        end
    end
    table.insert(self.frames, index, frame)
    self:Layout()
    frame:Show()
end

---@param frame BetterGroupLootRollFrameMixin
function module:RemoveFrame(frame)
    if frame.rollID then
        api.ForgetRoll(frame.rollID)
    end
    for i, other in ipairs(self.frames) do
        if other == frame then
            table.remove(self.frames, i)
            break
        end
    end
    self.pool:Release(frame)
    self:Layout()
end

---@param rollID number
---@param duration number milliseconds
function module:AddRoll(rollID, duration)
    if not api.IsRollUIActive() or self:FindFrame(rollID) then
        return
    end
    local frame = self.pool:Acquire() --[[@as BetterGroupLootRollFrameMixin]]
    if not frame:SetRoll(rollID, duration or 0) then
        self.pool:Release(frame)
        self.logger:debug("Roll %d has no item", rollID)
        return
    end
    self.logger:debug("Roll %d started: %s", rollID, frame.item.link or frame.item.name)
    self:InsertFrame(frame)
end

-- Events ----------------------------------------------------------------------------------------

function module:OnRollStarted(_, rollID, duration)
    self:AddRoll(rollID, duration)
end

function module:OnRollCancelled(_, rollID)
    local frame = self:FindFrame(rollID)
    -- A frame showing the own Need roll's result goes away on its own timer.
    if frame and not frame.finishing then
        self:RemoveFrame(frame)
    end
end

function module:OnAllRollsCancelled()
    for i = #self.frames, 1, -1 do
        local frame = self.frames[i]
        if frame.rollID then
            self:RemoveFrame(frame)
        end
    end
end

function module:OnNeedRollResult(_, rollID, roll, isWinning)
    local frame = self:FindFrame(rollID)
    if not frame then
        return
    end
    frame:ShowNeedRoll(roll, isWinning)
    C_Timer.After(NEED_ROLL_RESULT_SECONDS, function()
        -- The pool may have handed the frame to another roll meanwhile.
        if frame.rollID == rollID and frame.finishing then
            self:RemoveFrame(frame)
        end
    end)
end

function module:UpdateChoices()
    for _, frame in ipairs(self.frames) do
        if frame.rollID then
            frame:UpdateChoices()
        end
    end
end

-- After a loading screen or /reload: show running rolls, drop frames whose roll ended unseen.
function module:SyncActiveRolls()
    local active = {}
    for _, roll in ipairs(api.GetActiveRolls()) do
        active[roll.rollID] = true
        self:AddRoll(roll.rollID, roll.duration)
    end
    for i = #self.frames, 1, -1 do
        local frame = self.frames[i]
        if frame.rollID and not active[frame.rollID] and not frame.finishing then
            self:RemoveFrame(frame)
        end
    end
end

-- Unlock mode and previews ------------------------------------------------------------------------

---@param unlocked boolean
function module:SetUnlocked(unlocked)
    if not self.active then
        return
    end
    if unlocked and not api:IsSupported() then
        self.logger:chat("This client's loot API is not supported.")
        return
    end
    if self.unlocked == unlocked then
        return
    end
    self.unlocked = unlocked
    self:RefreshPreviews()
    self:RefreshOptions()
end

local function randomPreviewChoices()
    local choices = api.NewChoices()
    local picks = { "need", "greed", "pass", "undecided", "undecided" }
    picks[#picks + 1] = api.client == "forever" and "transmog" or "disenchant"
    for _, player in ipairs(PREVIEW_PLAYERS) do
        local choice = picks[math.random(#picks)]
        table.insert(choices[choice], {
            name = player[1],
            class = player[2],
            roll = choice == "need" and math.random(100) or nil,
            isSelf = false,
            isWinner = false,
        })
    end
    return choices
end

---@param index number
---@return BetterGroupLoot.Preview
local function newPreview(index)
    local itemID = PREVIEW_ITEMS[index]
    ---@type BetterGroupLoot.Preview
    local preview = {
        itemID = itemID,
        item = {
            name = RETRIEVING_ITEM_INFO or "...",
            texture = "Interface\\Icons\\INV_Misc_QuestionMark",
            count = 1,
            quality = Enum.ItemQuality.Epic,
            bindOnPickUp = true,
            canNeed = true,
            canGreed = true,
            -- The second preview demonstrates the adapter's additional choice.
            canTransmog = api.client == "forever" and index == 2,
            canDisenchant = api.client == "classic" and index == 2,
        },
        choices = randomPreviewChoices(),
        duration = PREVIEW_DURATION,
        timeLeft = math.random(PREVIEW_DURATION),
    }
    return preview
end

-- Keep the legacy mover and Edit Mode previews from creating duplicate stacks.
function module:RefreshPreviews()
    local registration = self.editMode
    local editing = registration and registration.library:IsInEditMode()
    local allowed = self.active and not (registration and InCombatLockdown and InCombatLockdown())
    self.mover:SetShown(allowed and self.unlocked and not editing)
    if registration and not registration.managePreviews then
        return
    end
    if allowed and (self.unlocked or editing) then
        self:ShowPreviews()
    else
        self:HidePreviews()
    end
end

function module:ShowPreviews()
    for _, frame in ipairs(self.frames) do
        if frame.preview then
            return
        end
    end
    for index = 1, #PREVIEW_ITEMS do
        local preview = newPreview(index)
        local frame = self.pool:Acquire() --[[@as BetterGroupLootRollFrameMixin]]
        frame:SetPreview(preview)
        self:InsertFrame(frame)

        -- Fill in the real item once the client has it cached.
        if C_Item.DoesItemExistByID(preview.itemID) then
            local item = Item:CreateFromItemID(preview.itemID)
            item:ContinueOnItemLoad(function()
                preview.item.name = item:GetItemName()
                preview.item.texture = item:GetItemIcon()
                preview.item.quality = item:GetItemQuality()
                preview.item.link = item:GetItemLink()
                if frame.preview == preview then
                    frame:SetItem(preview.item)
                end
            end)
        end
    end
end

function module:HidePreviews()
    for i = #self.frames, 1, -1 do
        local frame = self.frames[i]
        if frame.preview then
            self:RemoveFrame(frame)
        end
    end
end

-- Secure post-hooks cannot be removed. Keep ownership for this UI session, but make
-- hooks inert while stopped so Blizzard's frames work again. Restart reuses this instance.
function module:Stop()
    self.active = false
    self:UnregisterAllEvents()
    self.unlocked = false
    self.mover:Hide()
    self.anchor:Hide()
    for index = #self.frames, 1, -1 do
        self:RemoveFrame(self.frames[index])
    end
end

internal.RollController = module
