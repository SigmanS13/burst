local skillchains = require('data.skillchains');

local M = {};

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '');
end

local function action_index(skills)
    local result = {};
    for _, entry in pairs((skills and skills[3]) or {}) do
        if (entry ~= nil and entry.en ~= nil) then result[tostring(entry.en):lower()] = entry; end
    end
    return result;
end

local function configured_actions(text, index)
    local result, seen = {}, {};
    for part in tostring(text or ''):gmatch('[^,;\n]+') do
        local name = trim(part);
        local entry = index[name:lower()];
        if (entry ~= nil and not seen[entry.en]) then
            seen[entry.en] = true;
            table.insert(result, entry);
        end
    end
    return result;
end

local function goal_score(result, settings, catalog)
    local info = skillchains.info[result];
    if (info == nil) then return -10000; end
    local score = info.level * 100;
    local goal = tostring(settings.goal or 'Auto');
    if (goal == 'Specific Skillchain') then
        if (result == tostring(settings.specific_skillchain)) then score = score + 1000; else score = score - 1000; end
    elseif (goal == 'Preferred Element') then
        if (skillchains.has_element(result, tostring(settings.preferred_element))) then score = score + 500; else score = score - 300; end
    elseif (goal == 'Preferred Spell') then
        local spell = catalog and catalog.by_name[tostring(settings.preferred_spell or ''):lower()] or nil;
        if (spell ~= nil and skillchains.has_element(result, spell.element)) then score = score + 700; else score = score - 400; end
    elseif (goal == 'Light / Darkness') then
        if (result == 'Light' or result == 'Darkness' or result == 'Radiance' or result == 'Umbra') then score = score + 500; else score = score - 300; end
    end
    return score;
end

function M.build(skills, player_state, settings, catalog)
    local index = action_index(skills);
    local participants = {};
    if (settings.use_local ~= false) then
        table.insert(participants, { name = player_state.character_name(), confidence = 'Exact', actions = player_state.available_weaponskills(skills), local_player = true });
    end
    for slot = 1, 3 do
        local profile = settings.participants and settings.participants[slot] or nil;
        if (profile ~= nil and profile.enabled == true and trim(profile.name) ~= '') then
            table.insert(participants, {
                name = trim(profile.name), confidence = 'Configured', local_player = false,
                actions = configured_actions(profile.weaponskills, index),
            });
        end
    end

    local recovery_actions = {};
    for _, owner in ipairs(participants) do
        for _, action in ipairs(owner.actions) do
            table.insert(recovery_actions, {
                owner = owner.name, name = action.en, properties = action.skillchain or {},
                confidence = owner.confidence,
            });
        end
    end

    local results, seen = {}, {};
    for _, opener_owner in ipairs(participants) do
        for _, closer_owner in ipairs(participants) do
            if (settings.allow_same_player ~= false or opener_owner ~= closer_owner) then
                for _, opener in ipairs(opener_owner.actions) do
                    for _, closer in ipairs(closer_owner.actions) do
                        if (opener.en ~= closer.en or opener_owner ~= closer_owner) then
                            local result, level = skillchains.resolve(opener.skillchain, closer.skillchain);
                            if (result ~= nil) then
                                local key = opener_owner.name .. '|' .. opener.en .. '|' .. closer_owner.name .. '|' .. closer.en .. '|' .. result;
                                if (not seen[key]) then
                                    seen[key] = true;
                                    local score = goal_score(result, settings, catalog);
                                    if (opener_owner.local_player) then score = score + 4; end
                                    if (closer_owner.local_player) then score = score + 8; end
                                    if (opener_owner == closer_owner) then score = score - 6; end
                                    table.insert(results, {
                                        opener = opener.en, opener_owner = opener_owner.name,
                                        closer = closer.en, closer_owner = closer_owner.name,
                                        result = result, level = level, elements = skillchains.elements(result),
                                        score = score,
                                        confidence = opener_owner.confidence == 'Exact' and closer_owner.confidence == 'Exact' and 'Exact' or 'Configured',
                                        opener_properties = opener.skillchain or {}, closer_properties = closer.skillchain or {},
                                        recovery_actions = recovery_actions,
                                        mage_name = settings.mage_mode == 'Me' and player_state.character_name() or trim(settings.mage_name),
                                    });
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    table.sort(results, function (a, b)
        if (a.score ~= b.score) then return a.score > b.score; end
        if (a.level ~= b.level) then return a.level > b.level; end
        if (a.result ~= b.result) then return a.result < b.result; end
        return a.opener < b.opener;
    end);
    local limited = {};
    for i = 1, math.min(20, #results) do limited[i] = results[i]; end
    return limited, participants;
end

function M.activate(plan)
    if (plan == nil) then return nil; end
    local copy = {};
    for key, value in pairs(plan) do copy[key] = value; end
    copy.stage = 1;
    copy.started_at = os.clock();
    copy.message = string.format('%s: %s', copy.opener_owner, copy.opener);
    copy.completed = false;
    return copy;
end

local function same_name(left, right)
    return tostring(left or ''):lower() == tostring(right or ''):lower();
end

local function owner_matches(expected, observed)
    return observed == nil or observed == '' or same_name(expected, observed);
end

local function recover(active, step)
    if (active.target_id ~= nil and tonumber(active.target_id) ~= tonumber(step.target_id)) then return false; end
    local best = nil;
    for _, candidate in ipairs(active.recovery_actions or {}) do
        local result, level = skillchains.resolve(step.properties or {}, candidate.properties or {});
        if (result ~= nil) then
            local score = (tonumber(level) or 0) * 100;
            if (result == active.result) then score = score + 500; end
            if (candidate.confidence == 'Exact') then score = score + 10; end
            if (best == nil or score > best.score) then
                best = { action = candidate, result = result, level = level, score = score };
            end
        end
    end
    if (best == nil) then return false; end
    active.opener = step.name;
    active.opener_owner = step.actor_name or 'Observed player';
    active.opener_properties = step.properties or {};
    active.closer = best.action.name;
    active.closer_owner = best.action.owner;
    active.closer_properties = best.action.properties;
    active.result = best.result;
    active.level = best.level;
    active.elements = skillchains.elements(best.result);
    active.target_id = step.target_id;
    active.opener_at = step.time or os.clock();
    active.stage = 2;
    active.message = string.format('RECOVERY — %s: %s', active.closer_owner, active.closer);
    return true;
end

function M.handle_event(active, event, mode)
    if (active == nil or event == nil) then return active, nil; end
    if (event.type == 'chain_step' and event.step ~= nil) then
        local name = tostring(event.step.name or '');
        local actor = event.step.actor_name;
        if (active.stage == 1 and name == active.opener and owner_matches(active.opener_owner, actor)) then
            active.stage = 2;
            active.target_id = event.step.target_id;
            active.opener_at = event.step.time or os.clock();
            active.message = string.format('%s: %s — PREPARE', active.closer_owner, active.closer);
            return active, 'opener';
        elseif (active.stage == 2 and name == active.closer and
            owner_matches(active.closer_owner, actor) and
            (active.target_id == nil or tonumber(active.target_id) == tonumber(event.step.target_id))) then
            active.stage = 3;
            active.message = 'WAITING FOR CONFIRMED ' .. tostring(active.result):upper();
            return active, 'closer';
        elseif (tostring(mode) == 'Adaptive Coach' and recover(active, event.step)) then
            return active, 'recovered';
        elseif (active.stage == 2) then
            active.unexpected = name;
            active.message = 'UNEXPECTED: ' .. name;
            return active, 'unexpected';
        end
    elseif (event.type == 'skillchain' and event.chain ~= nil) then
        if (event.chain.property == active.result) then
            active.stage = 4;
            active.completed = true;
            active.completed_at = os.clock();
            active.message = tostring(active.result):upper() .. ' CREATED — HOLD WEAPONSKILLS';
            return active, 'complete';
        elseif (active.stage >= 2) then
            active.stage = 4;
            active.completed = true;
            active.completed_at = os.clock();
            active.message = tostring(event.chain.property):upper() .. ' CREATED — PLAN CHANGED';
            return active, 'changed';
        end
    elseif (event.type == 'miss') then
        active.stage = 1;
        active.message = 'CHAIN STEP MISSED — RESTART';
        return active, 'miss';
    end
    return active, nil;
end

return M;
