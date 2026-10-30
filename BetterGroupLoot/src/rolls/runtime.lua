---@type string, BetterGroupLoot
local _, app = ...

-- One cooperative owner across standalone and embedded copies, including different
-- revisions. Never replace an existing owner or compare versions to take over.
function app.StartGroupLoot(host)
    if _G.BetterGroupLootRuntimeOwner then
        local owner = _G.BetterGroupLootRuntimeOwner
        if owner == app.runtimeOwner and owner.controller then
            owner.controller:Start()
            return owner.controller
        end
        return nil, owner
    end
    if not app.api:IsSupported() then
        return nil, { reason = "unsupported" }
    end
    assert(type(host.prefix) == "string" and host.prefix:match("^[%a_][%w_]*$"), "Invalid frame prefix")
    assert(type(host.getProfile) == "function", "A current-profile getter is required")
    assert(
        host.defaultPosition or (host.applyPosition and host.savePosition and host.resetPosition),
        "Default position or complete position binding required"
    )
    if host.applyPosition or host.savePosition or host.resetPosition then
        assert(
            type(host.applyPosition) == "function"
                and type(host.savePosition) == "function"
                and type(host.resetPosition) == "function",
            "Position callbacks must be supplied together"
        )
    end
    assert(not _G[host.prefix .. "Anchor"], "Frame prefix already in use")
    local owner = { prefix = host.prefix, version = 1, reason = "owned" }
    _G.BetterGroupLootRuntimeOwner = owner
    app.runtimeOwner = owner
    local controller = setmetatable({}, { __index = app.RollController })
    LibStub("AceEvent-3.0"):Embed(controller)
    -- Keep a failed startup reserved too: partially installed hooks must not compete.
    controller:Initialize(host)
    controller:Start()
    owner.controller = controller
    return controller
end
