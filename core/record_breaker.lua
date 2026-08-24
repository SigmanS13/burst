-- Passive personal single-damage record tracker for incoming action packet 0x028.
-- This module only evaluates already-parsed server results; it never sends an action.

local M = {};

-- These retail action-message variants explicitly describe damage dealt by the
-- packet actor to its target. Counter, retaliation, spikes, skillchain-only,
-- drain, healing, status-tick, and additional-effect messages are excluded.
local damage_messages = {
    [1] = true, [2] = true, [67] = true, [77] = true, [110] = true,
    [157] = true, [185] = true, [197] = true, [252] = true,
    [264] = true, [265] = true, [317] = true, [352] = true,
    [353] = true, [379] = true, [413] = true, [522] = true,
    [576] = true, [577] = true, [648] = true, [650] = true,
    [747] = true,
};

local function clean_name(value)
    return tostring(value or ''):gsub('%z+$', '');
end

local function resource_name(resource)
    if (resource == nil or resource.Name == nil) then return nil; end
    local value = resource.Name[1] or resource.Name[0] or resource.Name;
    value = clean_name(value);
    return value ~= '' and value or nil;
end

function M.character_key(name)
    name = clean_name(name):match('^%s*(.-)%s*$');
    if (name == '' or name:lower() == 'unknown') then return nil; end
    return name:lower();
end

function M.is_damage_message(message)
    return damage_messages[tonumber(message) or -1] == true;
end

function M.action_name(packet, action, skills, resources)
    local category = tonumber(packet and packet.category) or 0;
    local action_id = (tonumber(packet and packet.param) or 0) % 0x10000;
    local message = tonumber(action and action.message) or 0;

    if (category == 1) then return message == 67 and 'Critical Hit' or 'Melee Attack'; end
    if (category == 2) then return 'Ranged Attack'; end

    local skill_category = category;
    if (category == 3 and (message == 110 or message == 317)) then skill_category = 13; end
    local group = skills and skills[skill_category] or nil;
    local known = group and group[action_id] or nil;
    if (known ~= nil and known.en ~= nil) then return clean_name(known.en); end

    if (resources ~= nil and category == 4) then
        local ok, spell = pcall(function () return resources:GetSpellById(action_id); end);
        local name = ok and resource_name(spell) or nil;
        if (name ~= nil) then return name; end
    end

    if (resources ~= nil and (category == 6 or category == 14 or category == 15)) then
        local ok, ability = pcall(function () return resources:GetAbilityById(action_id); end);
        local name = ok and resource_name(ability) or nil;
        if (name ~= nil) then return name; end
    end

    if (category == 4) then return 'Spell'; end
    if (category == 3) then return 'Weaponskill'; end
    if (category == 6 or category == 14 or category == 15) then return 'Ability'; end
    return 'Damage';
end

function M.process(packet, local_server_id, character_name, records, resolve_name, skills, resources, timestamp)
    if (packet == nil or tonumber(packet.actor_id) ~= tonumber(local_server_id)) then return nil; end
    local key = M.character_key(character_name);
    if (key == nil or type(records) ~= 'table') then return nil; end

    local previous = records[key];
    local previous_damage = type(previous) == 'table' and (tonumber(previous.damage) or 0) or 0;
    local best = nil;

    for _, target in ipairs(packet.targets or {}) do
        for _, action in ipairs(target.actions or {}) do
            local damage = tonumber(action.param) or 0;
            if (damage > previous_damage and M.is_damage_message(action.message) and
                (best == nil or damage > best.damage)) then
                best = {
                    damage = damage,
                    action = M.action_name(packet, action, skills, resources),
                    target = resolve_name and resolve_name(target.id) or ('Target ' .. tostring(target.id)),
                    target_id = target.id,
                    message = tonumber(action.message),
                };
            end
        end
    end

    if (best == nil) then return nil; end
    best.character = clean_name(character_name);
    best.previous_damage = previous_damage;
    best.achieved_at = tonumber(timestamp) or os.time();
    records[key] = {
        damage = best.damage,
        action = best.action,
        target = best.target,
        achieved_at = best.achieved_at,
        character = best.character,
    };
    return best;
end

return M;
