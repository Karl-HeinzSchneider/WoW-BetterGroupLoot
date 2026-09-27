---@type string, BetterGroupLoot
local _, app = ...

local log = app.logger

-- The one place that talks to the game's loot API. The roll frames (src/rolls/) only use app.api
-- and the plain tables described below, so supporting another client means adding one file next
-- to forever.lua that provides the same functions, and listing it in the TOC.
--
-- Each client file decides at load time whether it fits the running client (by checking for the
-- API it needs, not by version numbers) and, if so, hands its functions to api:Implement(). The
-- first file that fits wins; api.client names it. None fitting leaves the addon inactive.

---@alias BetterGroupLoot.Choice "need"|"greed"|"transmog"|"disenchant"|"pass"|"undecided"

-- The item of one roll, as shown on a roll frame.
---@class BetterGroupLoot.RollItem
---@field name string
---@field texture string|number
---@field link string?
---@field count number
---@field quality number Enum.ItemQuality
---@field bindOnPickUp boolean
---@field canNeed boolean
---@field canGreed boolean
---@field canTransmog boolean
---@field canDisenchant boolean
---@field reasonNeed string? why Need is not allowed (localized), nil if it is
---@field reasonGreed string?
---@field reasonDisenchant string?

-- One player's choice on a roll.
---@class BetterGroupLoot.Roller
---@field name string
---@field class string? class file name ("WARRIOR"), for the class color
---@field roll number? the rolled number, once there is one
---@field isSelf boolean
---@field isWinner boolean
---@field offSpec boolean? chose Need for their off spec

-- Who chose what on one roll: a list of players per choice, in the order the client sorts them.
---@alias BetterGroupLoot.RollChoices table<BetterGroupLoot.Choice, BetterGroupLoot.Roller[]>

---@class BetterGroupLoot.ActiveRoll
---@field rollID number
---@field duration number milliseconds

-- The game events the roll frames listen to. Handlers get the payloads documented per field.
---@class BetterGroupLoot.ApiEvents
---@field rollStarted string (rollID, durationMs)
---@field rollCancelled string (rollID)
---@field allRollsCancelled string ()
---@field needRollResult string? (rollID, roll, isWinning); nil on a client without instant Need rolls
---@field choicesChanged string[] any payload; the roll frames re-read GetRollChoices

---@class BetterGroupLoot.Api
---@field client string? the implementation in use, nil when none fits this client
---@field events BetterGroupLoot.ApiEvents
---@field GetActiveRolls fun(): BetterGroupLoot.ActiveRoll[] rolls already running (after a /reload or loading screen)
---@field GetRollItem fun(rollID: number): BetterGroupLoot.RollItem? nil if the roll is gone
---@field GetRollTimeLeft fun(rollID: number): number milliseconds
---@field Roll fun(rollID: number, rollType: number) rollType from api.RollType
---@field GetRollChoices fun(rollID: number): BetterGroupLoot.RollChoices? nil while the client has no data for it
---@field ForgetRoll fun(rollID: number) the roll's frame is gone; drop anything cached for it
---@field SetItemTooltip fun(tooltip: GameTooltip, rollID: number)
---@field HandleModifiedItemClick fun(rollID: number) shift-click links, ctrl-click previews, ...
---@field GetQualityColor fun(quality: number): number, number, number
---@field GetQualityBorderAtlas fun(quality: number): string atlas for the icon border
---@field ColorizeName fun(name: string, class: string?): string
---@field IsRollUIActive fun(): boolean false when the client shows rolls in a UI we don't replace (gamepad mode)
---@field HideBlizzardRollFrames fun() stop the client's own roll frames from showing
local api = {}
app.api = api

-- The rollType argument of Roll(); the same numbers on every client so far.
api.RollType = {
    Pass = 0,
    Need = 1,
    Greed = 2,
    Disenchant = 3,
    Transmog = 4,
}

-- Every choice a RollChoices table has a list for.
api.CHOICES = { "need", "greed", "transmog", "disenchant", "pass", "undecided" }

-- An empty RollChoices table, for client files and the preview.
---@return BetterGroupLoot.RollChoices
function api.NewChoices()
    local choices = {}
    for _, choice in ipairs(api.CHOICES) do
        choices[choice] = {}
    end
    return choices
end

-- Everything a client file has to provide (see the class above).
local REQUIRED = {
    "GetActiveRolls",
    "GetRollItem",
    "GetRollTimeLeft",
    "Roll",
    "GetRollChoices",
    "ForgetRoll",
    "SetItemTooltip",
    "HandleModifiedItemClick",
    "GetQualityColor",
    "GetQualityBorderAtlas",
    "ColorizeName",
    "IsRollUIActive",
    "HideBlizzardRollFrames",
}

---@param client string
---@param impl table the functions of the class above, plus `events`
function api:Implement(client, impl)
    if self.client then
        return
    end
    for _, name in ipairs(REQUIRED) do
        if type(impl[name]) ~= "function" then
            log:error("The %s loot API is missing %s", client, name)
            return
        end
    end
    if type(impl.events) ~= "table" then
        log:error("The %s loot API is missing its events", client)
        return
    end
    for key, value in pairs(impl) do
        self[key] = value
    end
    self.client = client
end

---@return boolean
function api:IsSupported()
    return self.client ~= nil
end
