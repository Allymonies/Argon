local function getSearchStrings(obj)
    local searchString = ""
    local function addSearchString(str)
        if str then
            searchString = searchString .. " " .. str
        end
    end
    for k, v in pairs(obj) do
        if type(v) == "table" then
            local subString = getSearchStrings(v)
            addSearchString(subString)
        else
            addSearchString(tostring(v))
        end
    end
    return searchString
end

return getSearchStrings