local isClassic = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC;
local addonName, addonTable = ...
local standalone = (addonName == 'BetterGroupLoot');

-- if standalone and not isClassic then return; end

local lib = LibStub:NewLibrary("BetterGroupLoot-1.0", 1);

if not lib then
    return -- already loaded and no upgrade necessary
end

local defaults = {
    scale = 1,
    anchorFrame = 'UIParent',
    customAnchorFrame = '',
    anchor = 'BOTTOM',
    anchorParent = 'BOTTOM',
    x = 425, -- 0
    y = 200 -- 152 = default blizz
};
lib.Defaults = defaults;

---@class frame
local frame = CreateFrame("Frame");
lib.frame = frame;
lib.Defaults = defaults
lib.IsStandalone = standalone

function frame:SetDefaults()
    for k, v in pairs(defaults) do BetterGroupLootDB[k] = v; end
end

function frame:AddMissingKeys()
    for k, v in pairs(defaults) do if BetterGroupLootDB[k] == nil then BetterGroupLootDB[k] = v; end end
end

function frame:SetState(state)
    if not standalone then frame:Embed() end
    for k, v in pairs(state) do BetterGroupLootDB[k] = v; end

    self:Update()
end

function frame:Update()
    -- print('update')
    -- local state = self.state;
    local state = BetterGroupLootDB;
    if not state then return end

    local parent;
    -- if DF.Settings.ValidateFrame(state.customAnchorFrame) then
    --     parent = _G[state.customAnchorFrame]
    -- else
    --     parent = _G[state.anchorFrame]
    -- end
    parent = UIParent;

    local preview = self.PreviewRoll;
    preview:ClearAllPoints()
    preview:SetPoint(state.anchor, parent, state.anchorParent, state.x, state.y)
    -- preview:SetScale(state.scale)
    preview:SetScale(1)

    local f = _G['GroupLootContainer']
    f.ignoreFramePositionManager = true;
    f:ClearAllPoints()
    f:SetPoint('BOTTOM', preview, 'BOTTOM', 0, 0)
end

frame:SetScript("OnEvent", function(self, event, ...)
    -- print(event, ...)
    return self[event](self, event, ...);
end)

-- standalone uses PLAYER_LOGIN
-- embeded adds the functionality when you call SetState() 
if standalone then frame:RegisterEvent("PLAYER_LOGIN") end

function frame:PLAYER_LOGIN(event, ...)
    -- print(event, ...)

    if type(BetterGroupLootDB) ~= 'table' then
        -- print('BetterGroupLootDB: new DB!')
        BetterGroupLootDB = {}
        frame:SetDefaults()
    end
    lib.BetterGroupLootDB = BetterGroupLootDB;
    self.BetterGroupLootDB = BetterGroupLootDB;
    self:AddMissingKeys()

    self:ChangeGroupLootContainer()
    self:AddEventFunctions()
    self:RegisterEvent('PLAYER_ENTERING_WORLD')
    self:RegisterEvent('START_LOOT_ROLL')
    self:RegisterEvent('LOOT_HISTORY_ROLL_CHANGED')
    self:RegisterEvent('LOOT_HISTORY_ROLL_COMPLETE')
    self:RegisterEvent('LOOT_ROLLS_COMPLETE')

    self:Update()
end

function frame:Embed()
    if frame.IsEmbeded then return false; end

    frame:PLAYER_LOGIN('EMBED')

    frame.IsEmbeded = true;
    return true;
end

function frame:ChangeGroupLootContainer()
    local fakeRoll = CreateFrame('Frame', 'BetterGroupLootContainerPreview', UIParent)
    fakeRoll:SetSize(256, 100)
    self.PreviewRoll = fakeRoll

    -- local fakePreview = CreateFrame('Frame', 'DragonflightUIEditModeGroupLootContainerFakeLootPreview', fakeRoll,
    --                                 'DFEditModePreviewGroupLootTemplate')
    -- fakePreview:SetPoint('CENTER')
    -- self:UpdateGroupLootFrameStyleSimple(fakePreview)

    -- fakeRoll.FakePreview = fakePreview

    for i = 1, 4 do
        local f = _G['GroupLootFrame' .. i]
        self:UpdateGroupLootFrameStyleSimple(f);
        f:SetScript('OnEnter', function()
        end)
    end
end

function frame:AddEventFunctions()
    -- local events = {
    --     'PLAYER_ENTERING_WORLD', 'START_LOOT_ROLL', 'LOOT_HISTORY_ROLL_CHANGED', 'LOOT_HISTORY_ROLL_COMPLETE',
    --     'LOOT_ROLLS_COMPLETE'
    -- }

    local function UpdateFunc()
        for i = 1, 4 do
            local f = _G['GroupLootFrame' .. i];
            self:UpdateAllButtons(f);
        end
    end

    function self:PLAYER_ENTERING_WORLD()
        UpdateFunc()
    end

    function self:START_LOOT_ROLL()
        UpdateFunc()
    end

    function self:LOOT_HISTORY_ROLL_CHANGED()
        UpdateFunc()
    end

    function self:LOOT_HISTORY_ROLL_COMPLETE()
        UpdateFunc()
    end

    function self:LOOT_ROLLS_COMPLETE()
        UpdateFunc()
    end
end

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

function frame:UpdateGroupLootFrameStyleSimple(f)
    f:SetWidth(243) -- 243
    f:SetHeight(84) -- 84

    -- art
    do
        local corner = _G[f:GetName() .. "Corner"]
        corner:Hide()

        local decoration = _G[f:GetName() .. "Decoration"]
        local slotTexture = _G[f:GetName() .. "SlotTexture"]

        local iconSize = 38;
        local iconFrame = f.IconFrame
        iconFrame:SetSize(iconSize, iconSize)
        iconFrame:ClearAllPoints()
        iconFrame:SetPoint('CENTER', slotTexture, 'CENTER', 0, 0)

        local icon = iconFrame.Icon
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        icon:SetPoint('CENTER', iconFrame, 'CENTER', 0, 0)

        local mask = iconFrame:CreateMaskTexture('BetterGroupLootIconMask')
        iconFrame.Mask = mask
        mask:SetAllPoints(icon)
        mask:SetTexture('Interface\\Addons\\BetterGroupLoot\\Textures\\maskNew')
        mask:SetSize(45, 45)
        icon:AddMaskTexture(mask)

        local iconOverlay = self:AddOverlayToFrame(iconFrame)
        iconOverlay:SetPoint('TOPLEFT', icon, 'TOPLEFT', 0, 0)
        iconOverlay:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 0, 0)

        self:UpdateOverlayQuality(iconFrame, 4)
    end

    -- buttons
    do
        local btnSize = 28; -- 32
        local padding = 2;

        local fontFile, height, flags = GameFontHighlight:GetFont()
        local newFontSize = 14;

        local texCoords = {
            [0] = {1.05, -0.1, 1.05, -0.1}, -- pass
            [1] = {0.05, 1.05, -0.05, .95}, -- need
            [2] = {0.05, 1.0, -0.025, 0.85} -- greed
        }

        local function updateTexCoords(btn, rollType)
            local left, right, top, bottom = unpack(texCoords[rollType])

            btn:GetNormalTexture():SetTexCoord(left, right, top, bottom)
            btn:GetHighlightTexture():SetTexCoord(left, right, top, bottom)
            btn:GetPushedTexture():SetTexCoord(left, right, top, bottom)
        end

        local pass = f.PassButton;
        local need = f.NeedButton;
        local greed = f.GreedButton

        -- pass
        do
            pass:SetSize(btnSize, btnSize)
            pass:ClearAllPoints()
            -- pass:SetPoint('RIGHT', f, 'RIGHT', -14, 0)
            pass:SetPoint('TOPRIGHT', f, 'TOPRIGHT', -14, -14)
            pass:SetNormalTexture('Interface\\Buttons\\UI-GroupLoot-Pass-Up')
            pass:SetHighlightTexture('Interface\\Buttons\\UI-GroupLoot-Pass-Highlight')
            pass:SetPushedTexture('Interface\\Buttons\\UI-GroupLoot-Pass-Down')
            updateTexCoords(pass, 0)

            local text = pass:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
            text:SetFont(fontFile, newFontSize, 'OUTLINE')
            text:SetPoint('BOTTOMRIGHT', pass, 'BOTTOMRIGHT', 2, -2)
            text:SetText('11')
            pass.DFText = text;

            pass:SetMotionScriptsWhileDisabled(true)
            pass:SetScript('OnEnter', function()
                GameTooltip:SetOwner(pass, "ANCHOR_RIGHT");
                GameTooltip:SetText(PASS);
                -- if (not pass:IsEnabled()) then
                --     GameTooltip:AddLine(pass.reason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
                --     GameTooltip:Show();
                -- end
                self:AddTooltipLines(pass, 0, false)
            end)
        end

        -- greed
        do
            greed:SetSize(btnSize, btnSize)
            greed:ClearAllPoints()
            -- greed:SetPoint('RIGHT', pass, 'LEFT', -padding, 0)
            greed:SetPoint('TOP', need, 'BOTTOM', 0, -padding)
            updateTexCoords(greed, 2)

            local text = greed:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
            text:SetFont(fontFile, newFontSize, 'OUTLINE')
            text:SetPoint('BOTTOMRIGHT', greed, 'BOTTOMRIGHT', 2, -2)
            text:SetText('11')
            greed.DFText = text;

            greed:SetMotionScriptsWhileDisabled(true)
            greed:SetScript('OnEnter', function()
                GameTooltip:SetOwner(greed, "ANCHOR_RIGHT");
                GameTooltip:SetText(GREED);
                if (not greed:IsEnabled()) then
                    GameTooltip:AddLine(greed.reason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
                    GameTooltip:Show();
                end
                self:AddTooltipLines(greed, 2, false)
            end)
        end

        -- need
        do
            need:SetSize(btnSize, btnSize)
            need:ClearAllPoints()
            -- need:SetPoint('RIGHT', greed, 'LEFT', -padding, 0)
            need:SetPoint('RIGHT', pass, 'LEFT', -padding, 0)
            updateTexCoords(need, 1)

            local text = need:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
            text:SetFont(fontFile, newFontSize, 'OUTLINE')
            text:SetPoint('BOTTOMRIGHT', need, 'BOTTOMRIGHT', 2, -2)
            text:SetText('11')
            need.DFText = text;

            need:SetMotionScriptsWhileDisabled(true)
            need:SetScript('OnEnter', function()
                GameTooltip:SetOwner(need, "ANCHOR_RIGHT");
                GameTooltip:SetText(NEED);
                if (not need:IsEnabled()) then
                    GameTooltip:AddLine(need.reason, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
                    GameTooltip:Show();
                end
                self:AddTooltipLines(need, 1, false)
            end)
        end
    end
end

function frame:UpdateAllButtons(f)
    if not f then return end
    local rollID = f.rollID
    if not rollID then return end

    local tableNeed, tableGreed, tablePass, tableDiss, tableNone, tableData = self:CreateTableForRollID(rollID)

    local needText = f.NeedButton.DFText
    if needText then
        if tableNeed then
            needText:SetText(tostring(#tableNeed))
        else
            needText:SetText('*')
        end
    end

    local greedText = f.GreedButton.DFText
    if greedText then
        if tableGreed then
            greedText:SetText(tostring(#tableGreed))
        else
            greedText:SetText('*')
        end
    end

    local passText = f.PassButton.DFText
    if passText then
        if tableGreed then
            passText:SetText(tostring(#tablePass))
        else
            passText:SetText('*')
        end
    end

    if tableData then
        local link = tableData[2]
        if link then
            local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
                  itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expansionID, setID,
                  isCraftingReagent = C_Item.GetItemInfo(link)
            self:UpdateOverlayQuality(f.IconFrame, itemQuality or 1)
        else
            self:UpdateOverlayQuality(f.IconFrame, 1)
        end
    end
end

-- rollType    number - (0:pass, 1:need, 2:greed, 3:disenchant)

function frame:CreateTableForRollID(rollID)
    local numPlayers;
    local itemIDx = 1;
    local tableData = {}
    while true do
        -- rollID, itemLink, numPlayers, isDone, winnerIdx, isMasterLoot = C_LootHistory.GetItem(itemIdx)
        local rID, _, num, _, _, _ = C_LootHistory.GetItem(itemIDx)
        if not rID then
            return nil;
        elseif rID == rollID then
            numPlayers = num;
            tableData = {C_LootHistory.GetItem(itemIDx)}
            break
        end
        itemIDx = itemIDx + 1;
    end

    local tableNeed = {}
    local tableGreed = {}
    local tablePass = {}
    local tableDiss = {}
    local tableNone = {}

    for i = 1, numPlayers do
        --
        local name, class, rollType, roll, isWinner, isMe = C_LootHistory.GetPlayerInfo(itemIDx, i)
        local data = {name = name, class = class, id = i};
        -- print(name, class, rollType)

        if rollType ~= nil then
            if rollType == 0 then
                table.insert(tablePass, data)
            elseif rollType == 1 then
                table.insert(tableNeed, data)
            elseif rollType == 2 then
                table.insert(tableGreed, data)
            elseif rollType == 3 then
                table.insert(tableDiss, data)
            end
        else
            table.insert(tableNone, data)
        end
    end

    -- TODO: SORT

    return tableNeed, tableGreed, tablePass, tableDiss, tableNone, tableData;
end

local function AddRollLines(t)
    if #t < 1 then return end
    for k, v in ipairs(t) do
        --
        local str = frame:GetClassColoredText(v.name, v.class) or '???'
        GameTooltip:AddLine(string.format(' %s', str))
    end
end

function frame:AddTooltipLines(f, btnType, showAll)
    local rollID = f:GetParent().rollID
    if not rollID then return end

    local tableNeed, tableGreed, tablePass, tableDiss, tableNone = self:CreateTableForRollID(rollID)
    if not tableNeed then return end

    GameTooltip:AddLine('    ')

    if #tableNeed ~= 0 and (showAll or btnType == 1) then
        --
        GameTooltip:AddLine(NEED)
        AddRollLines(tableNeed)
    end

    if #tableGreed ~= 0 and (showAll or btnType == 2) then
        --
        GameTooltip:AddLine(GREED)
        AddRollLines(tableGreed)
    end

    if #tableDiss ~= 0 and (showAll or btnType == 3) then
        --
        GameTooltip:AddLine(ROLL_DISENCHANT)
        AddRollLines(tableDiss)
    end

    if #tablePass ~= 0 and (showAll or btnType == 0) then
        --
        GameTooltip:AddLine(PASS)
        AddRollLines(tablePass)
    end

    if showAll or true then
        --
        GameTooltip:AddLine('Undecided')
        AddRollLines(tableNone)
    end

    GameTooltip:Show()
end
