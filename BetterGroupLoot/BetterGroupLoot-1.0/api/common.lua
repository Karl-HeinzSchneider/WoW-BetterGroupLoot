local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

-- Shared roll operations; history and frame suppression remain client-specific.
function internal.api.CreateImplementation()
    local impl = {}
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
        local color = (
            ColorManager
            and ColorManager.GetColorDataForItemQuality
            and ColorManager.GetColorDataForItemQuality(quality)
        ) or ITEM_QUALITY_COLORS[quality]
        if color then
            return color.r, color.g, color.b
        end
        return 1, 1, 1
    end

    function impl.GetQualityBorderAtlas(quality)
        local atlas = ColorManager
            and ColorManager.GetAtlasDataForLootBorderItemQuality
            and ColorManager.GetAtlasDataForLootBorderItemQuality(quality)
        return atlas or (LOOT_BORDER_BY_QUALITY and LOOT_BORDER_BY_QUALITY[quality]) or "loottoast-itemborder-white"
    end

    function impl.ColorizeName(name, class)
        local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local color = class and colors[class]
        if color and color.colorStr then
            return "|c" .. color.colorStr .. name .. "|r"
        end
        return name
    end

    return impl
end
