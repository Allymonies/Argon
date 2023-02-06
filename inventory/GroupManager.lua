
---@class GroupManager
local GroupManager = {
    groups = {},
    nbtMatches = {},
}

local GroupManager_mt = { __index = GroupManager }

---@return GroupManager
function GroupManager.new()
    local self = setmetatable({}, GroupManager_mt)
    return self
end

function GroupManager:addGroup(label, predicates, items, inventoryManager)
    table.insert(self.groups, {
        id = os.epoch("utc") + #self.groups,
        label = label,
        predicates = predicates,
        items = items,
    })
    if inventoryManager then
        local nbtDetails = inventoryManager:getNbtDetails()
        self:compareNBTDetailsToGroup(nbtDetails, self.groups[#self.groups])
    end
    return self.groups[#self.groups]
end

function GroupManager:compareNBTDetailToGroups(nbtDetails)
    for _, group in ipairs(self.groups) do
        self:compareNBTDetailsToGroup({[nbtDetails.nbt] = nbtDetails}, group)
    end
end

function GroupManager:compareNBTDetailsToGroup(nbtDetails, group)
    for nbtHash, nbtData in pairs(nbtDetails) do
        if self:matchesGroup(nbtData, group) then
            self:addMatchToGroup(nbtHash, group)
        end
    end
    return true
end

function GroupManager:matchesGroup(nbtData, group)
    if type(nbtData) ~= "table" then
        return false
    end
    if nbtData[1] then
        return self:matchesGroup(nbtData[1], group)
    end
    for k,v in pairs(group) do
        if type(v) == "table" then
            if not self:matchesGroup(nbtData[k], v) then
                return false
            end
        elseif nbtData[k] == nil or nbtData[k] ~= v then
            return false
        end
    end
    return true
end

function GroupManager:addMatchToGroup(nbtHash, group)
    if not group.matches then
        group.matches = {}
    end
    group.matches[nbtHash] = true
    if not self.nbtMatches[nbtHash] then
        self.nbtMatches[nbtHash] = {}
    end
    table.insert(self.nbtMatches[nbtHash], group.id)
end

function GroupManager:itemTypeInGroup(itemType, group)
    local matchesGroup = not group.items or (type(group.items) == "string" and group.items == itemType)
    if not matchesGroup and type(group.items) == "table" then
        for _, groupItem in ipairs(group.items) do
            if groupItem == itemType then
                matchesGroup = true
                break
            end
        end
    end
    return matchesGroup
end

function GroupManager:getGroupItems(group)
    if not group.items then
        return {}
    elseif type(group.items) == "string" then
        return {group.items}
    else
        return group.items
    end
end

function GroupManager:getGroups()
    return self.groups
end

function GroupManager:getGroup(id)
    for _, group in ipairs(self.groups) do
        if group.id == id then
            return group
        end
    end
    return nil
end

function GroupManager:getNbtMatches()
    return self.nbtMatches
end

function GroupManager:getGroupMatches(nbtHash)
    return self.nbtMatches[nbtHash]
end

return GroupManager