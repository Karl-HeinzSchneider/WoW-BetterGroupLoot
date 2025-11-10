-- TODO
local frame = CreateFrame("Frame");
-- color
do
    local base = 'Interface\\Addons\\BetterGroupLoot\\Textures\\'

    function frame:AddOverlayToFrame(frame)
        if frame.DFQuality then
            --
            -- print('already frame.DFQuality', frame:GetName())
            return frame.DFQuality
        end

        local tex = base .. 'whiteiconframeEdit'

        local overlay = frame:CreateTexture('BetterGroupLootQuality')
        overlay:SetDrawLayer('OVERLAY', 6)
        overlay:SetTexture(tex)
        overlay:SetSize(37, 37)
        -- overlay:SetTexCoord(0.32959, 0.349121, 0.000976562, 0.0400391)
        overlay:Hide()
        frame.DFQuality = overlay

        local subIcon = _G[(frame:GetName() or '******') .. 'SubIconTexture']

        if subIcon then subIcon:SetDrawLayer('OVERLAY', 7) end

        return overlay
    end

    local qualityToIconBorderAtlas = {
        [0] = {0.32959, 0.349121, 0.000976562, 0.0400391}, -- poor
        [1] = {0.32959, 0.349121, 0.000976562, 0.0400391}, -- common
        [2] = {0.411621, 0.431152, 0.0273438, 0.0664062}, -- uncommon
        [3] = {0.377441, 0.396973, 0.0273438, 0.0664062}, -- rare

        [4] = {0.579102, 0.598633, 0.0351562, 0.0742188}, -- epic
        [5] = {0.558594, 0.578125, 0.0351562, 0.0742188}, -- legendary

        [6] = {0.32959, 0.349121, 0.000976562, 0.0400391}, -- artifact
        [7] = {0.32959, 0.349121, 0.000976562, 0.0400391}, -- heirloom
        [8] = {0.32959, 0.349121, 0.000976562, 0.0400391} -- wow token
    };

    local DF_LE_ITEM_QUALITY_QUEST = #BAG_ITEM_QUALITY_COLORS + 1;
    local DF_LE_ITEM_QUALITY_POOR = 0;

    local DF_BAG_ITEM_QUALITY_COLORS = {}
    for i = 1, #BAG_ITEM_QUALITY_COLORS do DF_BAG_ITEM_QUALITY_COLORS[i] = BAG_ITEM_QUALITY_COLORS[i] end
    DF_BAG_ITEM_QUALITY_COLORS[DF_LE_ITEM_QUALITY_POOR] = {r = 0.1, g = 0.1, b = 0.1}
    DF_BAG_ITEM_QUALITY_COLORS[DF_LE_ITEM_QUALITY_QUEST] = {r = 1.0, g = 1.0, b = 0}

    function frame:UpdateOverlayQuality(frame, quality)
        if not frame.DFQuality then
            -- print('No frame.DFQuality:', frame:GetName(), quality)
            return
        end
        frame.DFQuality:Show()

        local color = DF_BAG_ITEM_QUALITY_COLORS[quality]
        if not color then
            color = DF_BAG_ITEM_QUALITY_COLORS[1]
            -- print('No Color:', frame:GetName(), quality)
        end
        -- print('color', color)
        frame.DFQuality:SetVertexColor(color.r, color.g, color.b, color.a)
        -- frame.DFQuality:SetTexCoord(unpack(qualityToIconBorderAtlas[quality]))
    end

    -- BLIZZ:
    local function GetClassColor(classFilename)
        local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS -- change for 'WeWantBlueShamans'

        local color = classColors[classFilename];
        if color then return color.r, color.g, color.b, color.colorStr; end

        return 1, 1, 1, "ffffffff";
    end

    function frame:GetClassColor(class, alpha)
        local r, g, b, hex = GetClassColor(class)
        if alpha then
            return r, g, b, alpha, hex
        else
            return r, g, b, 1, hex
        end
    end

    function frame:GetClassColoredText(str, class)
        if not str then return '' end
        local r, g, b, a, hex = self:GetClassColor(class)
        return "|r|c" .. hex .. str .. "|r"
    end
end

BetterGroupLootPreviewTemplateMixin = {}

local maxTimerValue = 42 * 1000; -- 60000

function BetterGroupLootPreviewTemplateMixin:OnLoad()
    -- print('DragonflightUIEditModeGroupLootContainerPreviewMixin:OnLoad()')
    self.Timer:SetMinMaxValues(0, maxTimerValue)

    self:SetNewItem(19431)
    -- self.TimerValue = fastrandom(0, 0.9 * maxTimerValue);
end

function BetterGroupLootPreviewTemplateMixin:OnShow()
    -- print('OnShow')
    self:SetNewItem(self:GetRandomItem())
    self.TimerValue = fastrandom(0, 0.9 * maxTimerValue);
end

do
    local alreadyRandom = {};
    local maxReroll = 5;
    local randomItemTable = {19431, 22691, 22589, 19356, 19909, 19019, 1728, 23054, 19395, 22954, 19379, 21663, 21126}
    local maxItems = #randomItemTable;

    function BetterGroupLootPreviewTemplateMixin:GetRandomItem()
        -- 19431
        local rand;

        for k = 1, maxReroll do
            rand = fastrandom(1, maxItems);
            -- print('rand', rand)
            if not alreadyRandom[rand] then
                alreadyRandom[rand] = true;
                return randomItemTable[rand]
            else
                -- print('REROLL', k, rand)
            end
        end
        return randomItemTable[rand]
    end
end

function BetterGroupLootPreviewTemplateMixin:SetNewItem(id)
    local item = Item:CreateFromItemID(id)

    item:ContinueOnItemLoad(function()
        local name = item:GetItemName()
        local icon = item:GetItemIcon()
        local quality = item:GetItemQuality()

        self.Name:SetText(name)
        local color = ITEM_QUALITY_COLORS[quality or 0];
        self.Name:SetVertexColor(color.r, color.g, color.b);
        -- self.Name:SetVertexColor(GameFontHighlight:GetTextColor());
        self.IconFrame.Icon:SetTexture(icon)
        self.IconFrame.Count:Hide();
        frame:UpdateOverlayQuality(self.IconFrame, quality)

        if self.NeedButton.DFText then
            local numMax = 40;
            local numNeed = fastrandom(0, numMax - 10)
            numMax = numMax - numNeed;
            local numGreed = fastrandom(0, numMax - 8)
            numMax = numMax - numGreed;
            local numPass = fastrandom(0, numMax)
            numMax = numMax - numPass;
            self.NeedButton.DFText:SetText(tostring(numNeed))
            self.GreedButton.DFText:SetText(tostring(numGreed))
            self.PassButton.DFText:SetText(tostring(numPass))
        end

        local bindOnPickUp = true;
        if (bindOnPickUp) then
            self:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = {left = 11, right = 12, top = 12, bottom = 11}
            });
            _G[self:GetName() .. "Corner"]:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Gold-Corner");
            _G[self:GetName() .. "Decoration"]:Show();
        else
            self:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = {left = 11, right = 12, top = 12, bottom = 11}
            });
            _G[self:GetName() .. "Corner"]:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Corner");
            _G[self:GetName() .. "Decoration"]:Hide();
        end
    end)

end

function BetterGroupLootPreviewTemplateMixin:OnUpdate(elapsed)
    self.TimerValue = self.TimerValue + elapsed * 1000

    if self.TimerValue >= maxTimerValue then
        self:SetNewItem(self:GetRandomItem())
        self.TimerValue = 0;
    end

    self.Timer:SetValue(self.TimerValue)
end

