---@type string, BetterGroupLoot
local _, app = ...

local function CreateRollButton(parent, choice, rollType, texture)
    local button = CreateFrame("Button", nil, parent)
    Mixin(button, app.RollButtonMixin)
    button:SetSize(32, 32)
    button:SetMotionScriptsWhileDisabled(true)
    button.choice = choice
    button.rollType = rollType
    button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.Count:SetJustifyH("RIGHT")
    button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -2)
    button:SetNormalTexture(texture .. "-Up")
    button:SetHighlightTexture(texture .. "-Highlight")
    button:GetHighlightTexture():SetBlendMode("ADD")
    button:SetPushedTexture(texture .. "-Down")
    button:SetScript("OnClick", function(self)
        self:OnClick()
    end)
    button:SetScript("OnEnter", function(self)
        self:OnEnter()
    end)
    button:SetScript("OnLeave", function(self)
        self:OnLeave()
    end)
    return button
end

-- Private frame construction: no globally named XML templates or mixins.
function app.CreateRollFrame(parent, name)
    local frame = CreateFrame("Frame", name, parent)
    Mixin(frame, app.RollFrameMixin)
    frame:Hide()
    frame:SetSize(277, 67)
    local background = frame:CreateTexture(nil, "BACKGROUND", nil)
    frame.Background = background
    background:SetTexture("Interface\\LootFrame\\LootToast")
    background:SetAllPoints()
    background:SetTexCoord(0.28222656, 0.55273438, 0.30859375, 0.57031250)
    local border = frame:CreateTexture(nil, "BORDER", nil)
    frame.Border = border
    border:SetTexture("Interface\\LootFrame\\LootToast")
    border:SetSize(286, 76)
    border:SetPoint("CENTER", border:GetParent(), "CENTER", 0, 0)
    border:SetTexCoord(0.00097656, 0.28027344, 0.43750000, 0.73437500)
    local itemName = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    frame.Name = itemName
    itemName:SetJustifyH("LEFT")
    itemName:SetJustifyV("MIDDLE")
    itemName:SetSize(125, 30)
    itemName:SetPoint("TOPLEFT", itemName:GetParent(), "TOPLEFT", 60, -15)
    local iconFrame = CreateFrame("Button", nil, frame)
    frame.IconFrame = iconFrame
    iconFrame:SetSize(34, 34)
    iconFrame:SetPoint("TOPLEFT", iconFrame:GetParent(), "TOPLEFT", 10, -11)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK", nil)
    iconFrame.Icon = icon
    icon:SetAllPoints()
    local itemCount = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    iconFrame.Count = itemCount
    itemCount:SetJustifyH("RIGHT")
    itemCount:Hide()
    itemCount:SetPoint("BOTTOMRIGHT", itemCount:GetParent(), "BOTTOMRIGHT", -5, 0)
    local iconBorder = iconFrame:CreateTexture(nil, "OVERLAY", nil)
    iconFrame.IconBorder = iconBorder
    iconBorder:SetAtlas("loottoast-itemborder-green")
    iconBorder:SetSize(42, 42)
    iconBorder:SetPoint("CENTER", iconBorder:GetParent(), "CENTER", 0, -2)
    iconFrame:SetScript("OnEnter", function(self, ...)
        self:GetParent():OnIconEnter(self)
    end)
    iconFrame:SetScript("OnLeave", function(self, ...)
        GameTooltip:Hide()
    end)
    iconFrame:SetScript("OnClick", function(self, ...)
        self:GetParent():OnIconClick()
    end)
    local need = CreateRollButton(frame, "need", 1, "Interface\\Buttons\\UI-GroupLoot-Dice")
    frame.NeedButton = need
    need:SetPoint("TOPLEFT", need:GetParent(), "TOPLEFT", 202, -7)
    local pass = CreateRollButton(frame, "pass", 0, "Interface\\Buttons\\UI-GroupLoot-Pass")
    frame.PassButton = pass
    pass:SetPoint("LEFT", pass:GetParent().NeedButton, "RIGHT", 6, 2)
    local greed = CreateRollButton(frame, "greed", 2, "Interface\\Buttons\\UI-GroupLoot-Coin")
    frame.GreedButton = greed
    greed:SetPoint("TOP", greed:GetParent().NeedButton, "BOTTOM", 0, 5)
    local transmog = CreateRollButton(frame, "transmog", 4, "Interface\\Buttons\\UI-GroupLoot-Coin")
    frame.TransmogButton = transmog
    transmog:SetPoint("CENTER", transmog:GetParent().GreedButton, "CENTER", 0, 0)
    transmog:Hide()
    local disenchant = CreateRollButton(frame, "disenchant", 3, "Interface\\Buttons\\UI-GroupLoot-DE")
    frame.DisenchantButton = disenchant
    disenchant:SetPoint("TOP", disenchant:GetParent().PassButton, "BOTTOM", 0, 5)
    disenchant:Hide()
    local timer = CreateFrame("StatusBar", nil, frame)
    frame.Timer = timer
    timer:SetMinMaxValues(0, 60000)
    timer:SetValue(0)
    timer:SetSize(190, 8)
    timer:SetPoint("BOTTOMLEFT", timer:GetParent(), "BOTTOMLEFT", 3, 2)
    local timerBackground = timer:CreateTexture(nil, "BACKGROUND", nil)
    timer.Background = timerBackground
    timerBackground:SetAllPoints()
    timerBackground:SetColorTexture(0, 0, 0)
    timer:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
    timer:SetStatusBarColor(1.0, 1.0, 0)
    local rollResult = CreateFrame("Frame", nil, frame)
    frame.RollResult = rollResult
    rollResult:SetAllPoints()
    rollResult:Hide()
    local resultText = rollResult:CreateFontString(nil, "OVERLAY", "Game32Font")
    rollResult.Text = resultText
    resultText:SetPoint("CENTER", resultText:GetParent():GetParent().NeedButton, "CENTER", 19, -13)
    frame:SetScript("OnUpdate", function(self, ...)
        self:OnUpdate(...)
    end)
    frame:OnLoad()
    return frame
end
