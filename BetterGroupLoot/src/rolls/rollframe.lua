---@type string, BetterGroupLoot
local _, app = ...

local api = app.api

local L = {
    need = NEED or "Need",
    greed = GREED or "Greed",
    transmog = TRANSMOGRIFICATION or "Transmog",
    disenchant = ROLL_DISENCHANT or "Disenchant",
    pass = PASS or "Pass",
    undecided = "Undecided",
    offSpec = "off spec",
    noData = "No roll data yet.",
    nobody = "Nobody yet.",
}

-- Which choices a button counts and lists. Greed and Transmog are the same tier (one or the other
-- is offered per player), so each shows both.
---@type table<string, BetterGroupLoot.Choice[]>
local BUTTON_CHOICES = {
    need = { "need" },
    greed = { "greed", "transmog" },
    transmog = { "transmog", "greed" },
    pass = { "pass" },
}

local DISABLED_ALPHA = 0.35

---@param tooltip GameTooltip
---@param choice BetterGroupLoot.Choice
---@param rollers BetterGroupLoot.Roller[]
---@return boolean added
local function addChoiceSection(tooltip, choice, rollers)
    if #rollers == 0 then
        return false
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(
        ("%s (%d)"):format(L[choice], #rollers),
        NORMAL_FONT_COLOR.r,
        NORMAL_FONT_COLOR.g,
        NORMAL_FONT_COLOR.b
    )
    for _, roller in ipairs(rollers) do
        local name = api.ColorizeName(roller.name, roller.class)
        if roller.offSpec then
            name = name .. " |cff808080(" .. L.offSpec .. ")|r"
        end
        local color = roller.isWinner and GREEN_FONT_COLOR or HIGHLIGHT_FONT_COLOR
        tooltip:AddDoubleLine(name, roller.roll and tostring(roller.roll) or "", 1, 1, 1, color.r, color.g, color.b)
    end
    return true
end

-- Roll button -----------------------------------------------------------------------------------

---@class BetterGroupLootRollButtonMixin : Button
---@field choice string need, greed, transmog or pass (XML KeyValue)
---@field rollType number api.RollType (XML KeyValue)
---@field Count FontString
---@field reason string? why the button is disabled
BetterGroupLootRollButtonMixin = {}

---@param allowed boolean
---@param reason string?
function BetterGroupLootRollButtonMixin:SetAllowed(allowed, reason)
    self:SetEnabled(allowed)
    self:SetAlpha(allowed and 1 or DISABLED_ALPHA)
    self:GetNormalTexture():SetDesaturated(not allowed)
    self.reason = not allowed and reason or nil
end

function BetterGroupLootRollButtonMixin:OnClick()
    self:GetParent():OnRollButtonClick(self)
end

function BetterGroupLootRollButtonMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L[self.choice], HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
    if self.reason then
        GameTooltip:AddLine(self.reason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true)
    end
    self:GetParent():AddChoicesToTooltip(GameTooltip, BUTTON_CHOICES[self.choice])
    GameTooltip:Show()
end

function BetterGroupLootRollButtonMixin:OnLeave()
    GameTooltip:Hide()
end

-- Roll frame ------------------------------------------------------------------------------------

-- Shows either a real roll (SetRoll) or a preview (SetPreview, for positioning the frames).
---@class BetterGroupLootRollFrameMixin : Frame
---@field NeedButton BetterGroupLootRollButtonMixin
---@field GreedButton BetterGroupLootRollButtonMixin
---@field TransmogButton BetterGroupLootRollButtonMixin
---@field PassButton BetterGroupLootRollButtonMixin
---@field buttons BetterGroupLootRollButtonMixin[]
---@field rollID number? the real roll shown, nil for a preview
---@field preview BetterGroupLoot.Preview? the preview shown, nil for a real roll
---@field item BetterGroupLoot.RollItem?
---@field choices BetterGroupLoot.RollChoices?
---@field duration number milliseconds
---@field finishing boolean? showing the own Need roll's result; buttons and timer are done
BetterGroupLootRollFrameMixin = {}

-- A fake roll for the unlocked (preview) mode; see rolls.lua.
---@class BetterGroupLoot.Preview
---@field item BetterGroupLoot.RollItem
---@field itemID number
---@field choices BetterGroupLoot.RollChoices
---@field duration number milliseconds
---@field timeLeft number milliseconds, counts down and starts over

function BetterGroupLootRollFrameMixin:OnLoad()
    self.buttons = { self.NeedButton, self.GreedButton, self.TransmogButton, self.PassButton }
    self.duration = 0
end

-- Pool resetter: back to an empty, hidden frame.
function BetterGroupLootRollFrameMixin:Reset()
    self:Hide()
    self:ClearAllPoints()
    self.rollID = nil
    self.preview = nil
    self.item = nil
    self.choices = nil
    self.finishing = nil
    self.RollResult:Hide()
end

---@param rollID number
---@param duration number milliseconds
---@return boolean ok false if the roll has no item (anymore)
function BetterGroupLootRollFrameMixin:SetRoll(rollID, duration)
    local item = api.GetRollItem(rollID)
    if not item then
        return false
    end
    self.rollID = rollID
    self.preview = nil
    self.duration = duration > 0 and duration or api.GetRollTimeLeft(rollID)
    self:SetItem(item)
    self:UpdateChoices()
    return true
end

---@param preview BetterGroupLoot.Preview
function BetterGroupLootRollFrameMixin:SetPreview(preview)
    self.rollID = nil
    self.preview = preview
    self.duration = preview.duration
    self:SetItem(preview.item)
    self:UpdateChoices()
end

---@param item BetterGroupLoot.RollItem
function BetterGroupLootRollFrameMixin:SetItem(item)
    self.item = item
    self.finishing = nil
    self.RollResult:Hide()

    self.IconFrame.Icon:SetTexture(item.texture)
    self.IconFrame.IconBorder:SetAtlas(api.GetQualityBorderAtlas(item.quality))
    self.IconFrame.Count:SetText(item.count)
    self.IconFrame.Count:SetShown(item.count > 1)

    local r, g, b = api.GetQualityColor(item.quality)
    self.Name:SetText(item.name)
    self.Name:SetVertexColor(r, g, b)
    self.Border:SetVertexColor(r, g, b)

    self.NeedButton:Show()
    self.NeedButton:SetAllowed(item.canNeed, item.reasonNeed)
    self.PassButton:Show()
    self.PassButton:SetAllowed(true)
    self.TransmogButton:SetShown(item.canTransmog)
    self.TransmogButton:SetAllowed(true)
    self.GreedButton:SetShown(not item.canTransmog)
    self.GreedButton:SetAllowed(item.canGreed, item.reasonGreed)

    self.Timer:SetMinMaxValues(0, math.max(self.duration, 1))
    self.Timer:SetFrameLevel(math.max(self:GetFrameLevel() - 1, 0))
    self:OnUpdate(0)
end

-- Re-reads who chose what and updates the counts and an open button tooltip.
function BetterGroupLootRollFrameMixin:UpdateChoices()
    if self.preview then
        self.choices = self.preview.choices
    elseif self.rollID then
        self.choices = api.GetRollChoices(self.rollID)
    else
        self.choices = nil
    end

    local choices = self.choices
    for _, button in ipairs(self.buttons) do
        local text = ""
        if choices then
            local count = 0
            for _, choice in ipairs(BUTTON_CHOICES[button.choice]) do
                count = count + #choices[choice]
            end
            text = tostring(count)
        end
        button.Count:SetText(text)
        if GameTooltip:IsOwned(button) then
            button:OnEnter()
        end
    end
end

---@param tooltip GameTooltip
---@param choiceList BetterGroupLoot.Choice[]
function BetterGroupLootRollFrameMixin:AddChoicesToTooltip(tooltip, choiceList)
    local choices = self.choices
    if not choices then
        tooltip:AddLine(" ")
        tooltip:AddLine(L.noData, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
        return
    end

    local any = false
    for _, choice in ipairs(choiceList) do
        any = addChoiceSection(tooltip, choice, choices[choice]) or any
    end
    if not any then
        tooltip:AddLine(" ")
        tooltip:AddLine(L.nobody, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
    end
    if app.db.profile.showUndecided then
        addChoiceSection(tooltip, "undecided", choices.undecided)
    end
end

---@param button BetterGroupLootRollButtonMixin
function BetterGroupLootRollFrameMixin:OnRollButtonClick(button)
    if self.rollID and not self.finishing then
        api.Roll(self.rollID, button.rollType)
    end
end

-- The client rolled the own Need right away: show the number instead of the buttons.
---@param roll number
---@param isWinning boolean
function BetterGroupLootRollFrameMixin:ShowNeedRoll(roll, isWinning)
    self.finishing = true
    for _, button in ipairs(self.buttons) do
        button:Hide()
    end
    self.Timer:SetValue(0)
    local color = isWinning and GREEN_FONT_COLOR or RED_FONT_COLOR
    self.RollResult.Text:SetText(color:WrapTextInColorCode(tostring(roll)))
    self.RollResult:Show()
end

---@param icon Button
function BetterGroupLootRollFrameMixin:OnIconEnter(icon)
    GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
    if self.rollID then
        api.SetItemTooltip(GameTooltip, self.rollID)
    elseif self.preview then
        GameTooltip:SetItemByID(self.preview.itemID)
    end
    GameTooltip:Show()
end

function BetterGroupLootRollFrameMixin:OnIconClick()
    if self.rollID then
        api.HandleModifiedItemClick(self.rollID)
    elseif self.item and self.item.link then
        HandleModifiedItemClick(self.item.link)
    end
end

---@param elapsed number seconds
function BetterGroupLootRollFrameMixin:OnUpdate(elapsed)
    if self.finishing then
        return
    end
    local timeLeft
    if self.preview then
        local preview = self.preview
        preview.timeLeft = preview.timeLeft - elapsed * 1000
        if preview.timeLeft <= 0 then
            preview.timeLeft = preview.duration
        end
        timeLeft = preview.timeLeft
    elseif self.rollID then
        timeLeft = api.GetRollTimeLeft(self.rollID)
    else
        return
    end
    self.Timer:SetValue(timeLeft)
end
