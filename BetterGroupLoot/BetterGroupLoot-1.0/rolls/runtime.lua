local lib = LibStub("BetterGroupLoot-1.0")
local internal = lib.internal
if not internal.loading then
    return
end

-- What a host passes to lib:Start. Only `name` is required.
---@class BetterGroupLoot.StartOptions
---@field name string the host addon: frame prefix (<prefix>Anchor, <prefix>RollFrame1, ...) and log tag
---@field prefix string? frame prefix when `name` is not a valid global identifier
---@field logger BetterGroupLoot.Logger? needs debug/error/chat with format args; default lib:CreateLogger(name)
---@field getProfile (fun(): BetterGroupLoot.Profile)? the current settings, resolved on every call; default an unsaved copy of lib.defaults
---@field defaultPosition {x: number, y: number}? reset position for profile.position; default lib.defaults.position
---@field applyPosition fun(anchor: Frame)? with savePosition/resetPosition: the host owns position and scale
---@field savePosition fun(anchor: Frame)?
---@field resetPosition fun(anchor: Frame)?
---@field strings table<string, string>? overrides for the tooltip text (see internal.DefaultStrings)
---@field moverText string? label of the legacy unlock mover
---@field changed fun()? a setting changed from within the library (dragged, unlocked)

local function copy(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and copy(value) or value
    end
    return result
end

-- The ownership record: one per UI session, shared with older releases through the global.
---@return table?
local function currentOwner()
    return internal.owner or _G.BetterGroupLootRuntimeOwner
end

---@return table? owner the ownership record once some host started the library
function lib:GetOwner()
    return currentOwner()
end

-- Starts the group loot frames for one host. The first host to start owns them until reload,
-- whatever its version; any other host gets `nil, owner` and nothing is created for it. The owner
-- starting again (after Stop) gets its controller back. An unsupported client returns
-- `nil, { reason = "unsupported" }` without reserving ownership.
---@param options BetterGroupLoot.StartOptions
---@return BetterGroupLoot.Rolls? controller
---@return table? owner when not started: { prefix, version, reason }
function lib:Start(options)
    assert(type(options) == "table" and type(options.name) == "string", "Start needs options with a name")
    local prefix = options.prefix or options.name
    local owner = currentOwner()
    if owner then
        if owner == internal.owner and owner.prefix == prefix and owner.controller then
            owner.controller:Start()
            return owner.controller
        end
        return nil, owner
    end
    if not internal.api:IsSupported() then
        return nil, { reason = "unsupported" }
    end
    assert(type(prefix) == "string" and prefix:match("^[%a_][%w_]*$"), "Invalid frame prefix")
    local custom = options.applyPosition or options.savePosition or options.resetPosition
    if custom then
        assert(
            type(options.applyPosition) == "function"
                and type(options.savePosition) == "function"
                and type(options.resetPosition) == "function",
            "Position callbacks must be supplied together"
        )
    end
    assert(not _G[prefix .. "Anchor"], "Frame prefix already in use")

    local getProfile = options.getProfile
    if getProfile == nil then
        local profile = copy(lib.defaults)
        getProfile = function()
            return profile
        end
    end
    assert(type(getProfile) == "function", "getProfile must be a function")
    local strings = internal.DefaultStrings()
    for key, value in pairs(options.strings or {}) do
        strings[key] = value
    end
    local host = {
        prefix = prefix,
        getProfile = getProfile,
        defaultPosition = options.defaultPosition or (not custom and copy(lib.defaults.position) or nil),
        applyPosition = options.applyPosition,
        savePosition = options.savePosition,
        resetPosition = options.resetPosition,
        moverText = options.moverText,
        changed = options.changed,
    }

    owner = { prefix = prefix, version = 1, minor = lib.minor, reason = "owned" }
    internal.owner = owner
    _G.BetterGroupLootRuntimeOwner = owner
    local controller = setmetatable({}, { __index = internal.RollController })
    controller.logger = options.logger or lib:CreateLogger(options.name)
    controller.strings = strings
    internal.logger = controller.logger
    -- Keep a failed startup reserved too: partially installed hooks must not compete.
    controller:Initialize(host)
    controller:Start()
    owner.controller = controller
    return controller
end

-- The last file of this copy: later copies see a finished library.
internal.loading = nil
