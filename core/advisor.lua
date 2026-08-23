local catalog = require('data.spells');

local M = {};

local function contains(values, wanted)
    for _, value in ipairs(values or {}) do if (value == wanted) then return true; end end
    return false;
end

function M.recommend(chain, settings, player_state, target, now)
    now = tonumber(now) or os.clock();
    if (chain == nil) then return { status = 'idle', reason = 'WAITING FOR A CONFIRMED SKILLCHAIN', valid = {}, rejected = {} }; end
    if (target == nil) then return { status = 'blocked', reason = 'SKILLCHAIN TARGET IS NOT LOADED', valid = {}, rejected = {} }; end
    if (settings.target_policy == 'current') then
        local current = player_state.current_target();
        if (current == nil) then return { status = 'blocked', reason = 'NO CURRENT TARGET', valid = {}, rejected = {} }; end
        if (tonumber(current.id) ~= tonumber(chain.target_id)) then
            return { status = 'blocked', reason = 'WRONG TARGET — SKILLCHAIN IS ON ' .. tostring(chain.target_name), valid = {}, rejected = {} };
        end
    end

    local remaining = math.max(0, (tonumber(chain.expires_at) or now) - now);
    local disabled = settings.disabled_spells or {};
    local preferred_element = tostring(settings.preferred_element or 'Auto');
    local preferred_family = tostring(settings.preferred_family or 'Any');
    local safety = tonumber(settings.safety_margin) or 0.60;
    local blu_set = nil;
    local valid, rejected = {}, {};

    for _, entry in ipairs(catalog.entries) do
        if (not disabled[entry.name]) and contains(chain.elements, entry.element) then
            if (entry.family == 'Blue Magic' and blu_set == nil) then blu_set = player_state.set_blu_spells(); end
            local ok, reason, spell, cast_time, cost, range = player_state.check_spell(entry, settings, target, blu_set);
            local candidate = {
                entry = entry, name = entry.name, element = entry.element, family = entry.family,
                spell = spell, cast_time = tonumber(cast_time) or 0, mp = tonumber(cost) or 0,
                range = tonumber(range) or 0, reason = reason,
            };
            if (ok) then
                candidate.latest_start = remaining - candidate.cast_time - safety;
                candidate.score = tonumber(entry.score) or 0;
                if (preferred_element ~= 'Auto' and preferred_element == entry.element) then candidate.score = candidate.score + 120; end
                if (preferred_family ~= 'Any' and preferred_family == entry.family) then candidate.score = candidate.score + 30; end
                if (candidate.latest_start < 0) then
                    candidate.reason = string.format('TOO LATE — NEEDS %.1fs', candidate.cast_time + safety);
                    table.insert(rejected, candidate);
                else
                    -- Practicality wins as the window closes. Fast spells receive a growing bonus.
                    candidate.score = candidate.score + math.max(0, 5.0 - candidate.cast_time) * (remaining < 5.0 and 8 or 2);
                    table.insert(valid, candidate);
                end
            else
                table.insert(rejected, candidate);
            end
        end
    end

    table.sort(valid, function (a, b)
        if (a.score ~= b.score) then return a.score > b.score; end
        if (a.cast_time ~= b.cast_time) then return a.cast_time < b.cast_time; end
        return a.name < b.name;
    end);
    table.sort(rejected, function (a, b) return (a.entry.score or 0) > (b.entry.score or 0); end);

    if (#valid == 0) then
        local reason = rejected[1] and rejected[1].reason or 'NO ENABLED SPELL MATCHES THESE ELEMENTS';
        return { status = 'blocked', reason = reason, valid = valid, rejected = rejected, remaining = remaining };
    end
    return {
        status = remaining <= 2.0 and 'urgent' or 'ready', reason = 'CAST NOW',
        best = valid[1], alternates = { valid[2], valid[3] }, valid = valid,
        rejected = rejected, remaining = remaining,
    };
end

return M;
