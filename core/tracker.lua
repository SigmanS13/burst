local skillchains = require('data.skillchains');

local M = {};
M.__index = M;

local action_messages = {
    [2] = true, [103] = true, [110] = true, [185] = true, [187] = true,
    [188] = true, [238] = true, [317] = true, [802] = true,
};
local pet_messages = { [110] = true, [317] = true };

function M.new(skills)
    return setmetatable({
        skills = skills or {}, targets = {}, recent = {},
        stats = { parsed = 0, chains = 0, bursts = 0, actions = 0, parse_errors = 0, duplicates = 0, ignored_actors = 0 },
        last_event = 'Waiting for combat data.', last_layout = '', last_action = '',
    }, M);
end

local function skill_for(self, category, action_id, message)
    if (category == 3 and pet_messages[tonumber(message) or -1]) then category = 13; end
    local group = self.skills[category];
    return group and group[bit.band(tonumber(action_id) or 0, 0xFFFF)] or nil;
end

local function append_recent(self, event)
    table.insert(self.recent, 1, event);
    while (#self.recent > 12) do table.remove(self.recent); end
end

function M:clear(reason)
    self.targets = {};
    self.last_event = reason or 'Tracker cleared.';
end

function M:mark_duplicate()
    self.stats.duplicates = self.stats.duplicates + 1;
end

function M:mark_parse_error(reason)
    self.stats.parse_errors = self.stats.parse_errors + 1;
    self.last_event = 'Packet parse skipped: ' .. tostring(reason);
end

function M:process(packet, now, settings, local_server_id, resolve_name, is_allowed_actor)
    now = tonumber(now) or os.clock();
    local events = {};
    self.stats.parsed = self.stats.parsed + 1;
    self.last_layout = tostring(packet.layout or '');
    if (is_allowed_actor ~= nil and not is_allowed_actor(packet.actor_id)) then
        self.stats.ignored_actors = self.stats.ignored_actors + 1;
        return events;
    end

    for _, target in ipairs(packet.targets or {}) do
        local target_name = resolve_name and resolve_name(target.id) or ('Target ' .. tostring(target.id));
        local actor_name = resolve_name and resolve_name(packet.actor_id) or ('Actor ' .. tostring(packet.actor_id));
        for _, action in ipairs(target.actions or {}) do
            self.stats.actions = self.stats.actions + 1;
            local category = tonumber(packet.category) or 0;
            local skill = skill_for(self, category, packet.param, action.message);
            local skill_name = skill and skill.en or nil;
            local property = skillchains.from_additional_effect(action.additional_effect);

            if (property ~= nil) then
                local window = tonumber(settings.burst_window) or 10.0;
                local active = {
                    target_id = target.id, target_name = target_name,
                    property = property, elements = skillchains.elements(property),
                    opened_at = now, expires_at = now + window,
                    actor_id = packet.actor_id, closer = skill_name or 'Confirmed action',
                    success = nil, success_spell = nil, success_damage = nil,
                };
                self.targets[target.id] = active;
                self.stats.chains = self.stats.chains + 1;
                self.last_event = string.format('%s created on %s.', property, target_name);
                local event = { type = 'skillchain', chain = active, packet = packet, action = action };
                table.insert(events, event); append_recent(self, event);
            elseif skill ~= nil and action_messages[tonumber(action.message) or -1] then
                local starter = {
                    target_id = target.id, target_name = target_name, actor_id = packet.actor_id,
                    actor_name = actor_name,
                    name = skill.en, properties = skill.skillchain or {}, time = now,
                    missed = tonumber(action.reaction) == 8 or tonumber(action.message) == 188,
                };
                local existing = self.targets[target.id] or {};
                existing.starter = starter;
                self.targets[target.id] = existing;
                self.last_action = tostring(skill.en);
                self.last_event = string.format('%s used on %s.', skill.en, target_name);
                local event = { type = starter.missed and 'miss' or 'chain_step', step = starter, packet = packet, action = action };
                table.insert(events, event); append_recent(self, event);
            end

            if (category == 8 and tonumber(packet.actor_id) == tonumber(local_server_id)) then
                local spell = AshitaCore:GetResourceManager():GetSpellById(bit.band(tonumber(packet.param) or 0, 0xFFFF));
                local name = spell and spell.Name and tostring(spell.Name[1]):gsub('%z+$', '') or ('Spell ' .. tostring(packet.param));
                table.insert(events, { type = 'cast_start', target_id = target.id, spell = name, time = now });
                self.last_event = 'Manual cast started: ' .. name;
            end

            if (category == 4 and tonumber(packet.actor_id) == tonumber(local_server_id) and
                skillchains.magic_burst_messages[tonumber(action.message) or -1]) then
                local active = self.targets[target.id];
                if (active ~= nil and active.property ~= nil and now <= (active.expires_at + 1.0)) then
                    local spell = AshitaCore:GetResourceManager():GetSpellById(bit.band(tonumber(packet.param) or 0, 0xFFFF));
                    active.success = true;
                    active.success_spell = spell and spell.Name and tostring(spell.Name[1]):gsub('%z+$', '') or ('Spell ' .. tostring(packet.param));
                    active.success_damage = tonumber(action.param) or 0;
                    active.success_at = now;
                    self.stats.bursts = self.stats.bursts + 1;
                    self.last_event = string.format('Magic burst confirmed: %s.', active.success_spell);
                    local event = { type = 'magic_burst', chain = active, packet = packet, action = action };
                    table.insert(events, event); append_recent(self, event);
                end
            end
        end
    end
    return events;
end

function M:prune(now)
    now = tonumber(now) or os.clock();
    for id, target in pairs(self.targets) do
        local expires = tonumber(target.expires_at);
        local starter_time = target.starter and tonumber(target.starter.time) or nil;
        if (expires ~= nil and now > expires + 4.0) or
           (expires == nil and starter_time ~= nil and now > starter_time + 12.0) then
            self.targets[id] = nil;
        end
    end
end

function M:best_chain(current_target_id, target_policy)
    if (target_policy == 'current' and current_target_id ~= nil) then
        local value = self.targets[current_target_id];
        if (value ~= nil and value.property ~= nil) then return value; end
        return nil;
    end
    local best = nil;
    for _, value in pairs(self.targets) do
        if (value.property ~= nil and (best == nil or value.opened_at > best.opened_at)) then best = value; end
    end
    return best;
end

return M;
