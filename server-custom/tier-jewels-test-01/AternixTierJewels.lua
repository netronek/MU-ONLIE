-- Native jewel handler owns the inventory mutation and stone consumption.
-- Lua only grants or refuses use. Tested native convention: 0=continue, 1=block.
local config = require('Scripts\\AternixTierJewelsConfig')
local descriptors = {}
local logsWritten = 0

local function integer(value)
    return type(value) == 'number' and value == value
        and value >= 0 and value < math.huge and value % 1 == 0
end

local function log(message)
    if logsWritten >= (config.DebugLogLimit or 0) then return end
    logsWritten = logsWritten + 1
    if type(io) ~= 'table' or type(io.open) ~= 'function' then return end
    pcall(function()
        local file = io.open(config.LogPath, 'a')
        if file then file:write(message, '\n'); file:close() end
    end)
end

local function notice(aIndex, message)
    if type(NoticeSend) == 'function' then
        pcall(NoticeSend, aIndex, 0, message)
    end
end

local function reject(aIndex, jewelIndex, reason)
    log('BLOCK jewel=' .. tostring(jewelIndex) .. ' reason=' .. reason)
    notice(aIndex, reason)
    return 1
end

for index, descriptor in pairs(config.Jewels) do
    assert(integer(index) and type(descriptor) == 'table')
    assert(type(config.AllowedItems[descriptor.Tier]) == 'table')
    descriptors[index] = descriptor
end

-- The old universal jewel must never bypass S/X or weapon pricing.
-- Its existing A-only filtering is retained until a migration policy is chosen.
if config.LegacyJewelTier then
    assert(config.AllowedItems[config.LegacyJewelTier])
    descriptors[7416] = {
        Tier = config.LegacyJewelTier,
        MinimumBefore = 1, MaximumBefore = 5, Mask = 63
    }
end

function AternixTierJewels_OnReadScript()
    logsWritten = 0
    log('START AternixTierJewels; native mutation; exact whitelists; prices unset.')
end

function AternixTierJewels_OnUserItemUse(aIndex, sourceSlot, targetSlot)
    if not integer(aIndex) or not integer(sourceSlot)
        or not integer(targetSlot) then return 1 end

    local okSource, source =
        pcall(InventoryGetItemTable, aIndex, sourceSlot)
    if not okSource or type(source) ~= 'table'
        or not integer(source.Index) then return 1 end

    local descriptor = descriptors[source.Index]
    if not descriptor then return 0 end
    if source.Level ~= 0 or sourceSlot == targetSlot then
        return reject(aIndex, source.Index,
            'Pouzij kamen bez +levelu na jiny item.')
    end

    local okTarget, target =
        pcall(InventoryGetItemTable, aIndex, targetSlot)
    if not okTarget or type(target) ~= 'table'
        or not integer(target.Index) then
        return reject(aIndex, source.Index, 'Neplatny cilovy item.')
    end
    if not config.AllowedItems[descriptor.Tier][target.Index] then
        return reject(aIndex, source.Index,
            'Tento kamen je pouze pro kategorii ' .. descriptor.Tier .. '.')
    end

    local mask = target.NewOption
    if not integer(mask) or mask > descriptor.Mask then
        return reject(aIndex, source.Index, 'Nepodporovane Excellent opce.')
    end
    local count = 0
    while mask > 0 do
        count = count + mask % 2
        mask = math.floor(mask / 2)
    end
    if count < descriptor.MinimumBefore or count > descriptor.MaximumBefore then
        return reject(aIndex, source.Index,
            'Nespravny pocet Excellent opci pro tento kamen.')
    end

    log('ALLOW jewel=' .. tostring(source.Index)
        .. ' tier=' .. descriptor.Tier
        .. ' target=' .. tostring(target.Index)
        .. ' slot=' .. tostring(targetSlot)
        .. ' beforeEX=' .. tostring(target.NewOption)
        .. ' serial=' .. tostring(target.Serial))
    return 0
end

BridgeFunctionAttach('OnReadScript', 'AternixTierJewels_OnReadScript')
BridgeFunctionAttach('OnUserItemUse', 'AternixTierJewels_OnUserItemUse')
