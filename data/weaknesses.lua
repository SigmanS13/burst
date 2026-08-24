local families = require('data.mob_families');

local M = {
    overrides = {},
    load_status = {
        state = 'not_loaded', path = nil, entries = 0, warnings = {}, error = nil,
    },
};

local canonical_elements = {
    fire = 'Fire', ice = 'Ice', wind = 'Wind', earth = 'Earth',
    lightning = 'Lightning', thunder = 'Lightning', water = 'Water',
    light = 'Light', dark = 'Dark', void = 'Dark',
};

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '');
end

local function normalized_name(value)
    return trim(value):lower();
end

local function file_exists(path)
    if (path == nil or path == '') then return false; end
    if (ashita ~= nil and ashita.fs ~= nil and ashita.fs.exists ~= nil) then
        local ok, exists = pcall(function () return ashita.fs.exists(path); end);
        if (ok) then return exists == true; end
    end
    local handle = io.open(path, 'rb');
    if (handle == nil) then return false; end
    handle:close();
    return true;
end

local function normalize_profile(profile, label, warnings)
    if (type(profile) ~= 'table' or type(profile.weak) ~= 'table') then
        table.insert(warnings, tostring(label) .. ': expected { weak = { ... } }');
        return nil;
    end
    local weak, seen = {}, {};
    for _, raw in ipairs(profile.weak) do
        local element = canonical_elements[trim(raw):lower()];
        if (element == nil) then
            table.insert(warnings, tostring(label) .. ': ignored unknown element "' .. tostring(raw) .. '"');
        elseif (not seen[element]) then
            seen[element] = true;
            table.insert(weak, element);
        end
    end
    -- An empty list is meaningful: it explicitly suppresses a lower-priority fallback.
    return { weak = weak };
end

function M.normalize_overrides(raw)
    local normalized, warnings, count = {}, {}, 0;
    if (type(raw) ~= 'table') then
        return normalized, { 'override file must return a table' }, count;
    end
    for name, profile in pairs(raw) do
        local key = normalized_name(name);
        if (key == '') then
            table.insert(warnings, 'ignored an override with an empty target name');
        else
            local clean = normalize_profile(profile, tostring(name), warnings);
            if (clean ~= nil) then
                normalized[key] = clean;
                count = count + 1;
            end
        end
    end
    return normalized, warnings, count;
end

function M.load_overrides(path)
    M.overrides = {};
    M.load_status = { state = 'missing', path = path, entries = 0, warnings = {}, error = nil };
    if (not file_exists(path)) then return false, 'missing'; end

    local chunk, load_error = loadfile(path);
    if (chunk == nil) then
        M.load_status.state = 'error';
        M.load_status.error = tostring(load_error or 'unable to load file');
        return false, M.load_status.error;
    end
    -- The override format is data-only. Do not grant community files access to addon globals.
    if (type(setfenv) == 'function') then setfenv(chunk, {}); end
    local ok, result = pcall(chunk);
    if (not ok) then
        M.load_status.state = 'error';
        M.load_status.error = tostring(result);
        return false, M.load_status.error;
    end

    local normalized, warnings, count = M.normalize_overrides(result);
    M.overrides = normalized;
    M.load_status = {
        state = 'loaded', path = path, entries = count, warnings = warnings, error = nil,
    };
    return true, count;
end

function M.lookup(target, override_table)
    if (type(target) ~= 'table') then return nil, nil; end
    local overrides = override_table or M.overrides;
    local override = overrides[normalized_name(target.name)];
    if (override ~= nil) then return override, 'override'; end

    local model_id = tonumber(target.model_id);
    if (model_id ~= nil and families.by_model[model_id] ~= nil) then
        return families.by_model[model_id], 'model';
    end
    local race = tonumber(target.race or target.race_id);
    if (race ~= nil and families.by_race[race] ~= nil) then
        return families.by_race[race], 'race';
    end
    return nil, nil;
end

function M.canonical_element(value)
    return canonical_elements[trim(value):lower()];
end

return M;
