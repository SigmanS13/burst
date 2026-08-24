local ffi = require('ffi');

local M = {
    spell_cache = {},
    spell_cache_built = false,
    blu = { initialized = false, available = false, offset = nil, error = nil },
};

local job_names = {
    [0] = 'NON', [1] = 'WAR', [2] = 'MNK', [3] = 'WHM', [4] = 'BLM',
    [5] = 'RDM', [6] = 'THF', [7] = 'PLD', [8] = 'DRK', [9] = 'BST',
    [10] = 'BRD', [11] = 'RNG', [12] = 'SAM', [13] = 'NIN', [14] = 'DRG',
    [15] = 'SMN', [16] = 'BLU', [17] = 'COR', [18] = 'PUP', [19] = 'DNC',
    [20] = 'SCH', [21] = 'GEO', [22] = 'RUN',
};

local blocking_buffs = {
    [0] = 'KO\'d', [2] = 'asleep', [6] = 'silenced', [7] = 'petrified',
    [10] = 'stunned', [14] = 'charmed', [17] = 'charmed', [28] = 'terrorized',
    [29] = 'muted', [193] = 'asleep', [262] = 'under Omerta',
};

local function clean_name(value)
    return tostring(value or ''):gsub('%z+$', '');
end

function M.player()
    return AshitaCore:GetMemoryManager():GetPlayer();
end

function M.local_server_id()
    local party = AshitaCore:GetMemoryManager():GetParty();
    return party and (tonumber(party:GetMemberServerId(0)) or 0) or 0;
end

function M.job_text()
    local player = M.player();
    if (player == nil) then return 'Unknown'; end
    return string.format('%s%d/%s%d', job_names[player:GetMainJob()] or '?', player:GetMainJobLevel(),
        job_names[player:GetSubJob()] or '?', player:GetSubJobLevel());
end

function M.character_name()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then return 'Unknown'; end
    return clean_name(party:GetMemberName(0));
end

function M.profile_key()
    local player = M.player();
    local name = M.character_name();
    if (player == nil or name == nil or name == '' or name == 'Unknown') then return nil; end
    return name .. '|' .. (job_names[tonumber(player:GetMainJob()) or 0] or 'NON');
end

function M.current_mp()
    local party = AshitaCore:GetMemoryManager():GetParty();
    return party and (tonumber(party:GetMemberMP(0)) or 0) or 0;
end

function M.blocking_status()
    local player = M.player();
    if (player == nil) then return 'player data unavailable'; end
    for _, buff in pairs(player:GetBuffs() or {}) do
        local reason = blocking_buffs[tonumber(buff) or -1];
        if (reason ~= nil) then return reason; end
    end
    return nil;
end

function M.entity_by_server_id(server_id)
    server_id = tonumber(server_id) or 0;
    if (server_id == 0) then return nil, nil; end
    for index = 0, 2303 do
        local entity = GetEntity(index);
        if (entity ~= nil and tonumber(entity.ServerId) == server_id) then return entity, index; end
    end
    return nil, nil;
end

function M.current_target()
    local target_manager = AshitaCore:GetMemoryManager():GetTarget();
    if (target_manager == nil) then return nil; end
    local index = target_manager:GetTargetIndex(0);
    local entity = GetEntity(index);
    if (entity == nil or tonumber(entity.ServerId) == 0) then return nil; end
    local race = tonumber(entity.Race);
    return {
        id = tonumber(entity.ServerId), index = index, entity = entity,
        name = clean_name(entity.Name), hpp = tonumber(entity.HPPercent) or 0,
        distance = math.sqrt(math.max(0, tonumber(entity.Distance) or 0)),
        race = race, race_id = race,
    };
end

function M.target_by_id(server_id)
    local entity, index = M.entity_by_server_id(server_id);
    if (entity == nil) then return nil; end
    local race = tonumber(entity.Race);
    return {
        id = tonumber(entity.ServerId), index = index, entity = entity,
        name = clean_name(entity.Name), hpp = tonumber(entity.HPPercent) or 0,
        distance = math.sqrt(math.max(0, tonumber(entity.Distance) or 0)),
        race = race, race_id = race,
    };
end

function M.is_alliance_actor(server_id)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then return false; end
    for i = 0, 17 do
        if (party:GetMemberIsActive(i) == 1) then
            if (tonumber(party:GetMemberServerId(i)) == tonumber(server_id)) then return true; end
            local member = GetEntity(party:GetMemberTargetIndex(i));
            if (member ~= nil and tonumber(member.PetTargetIndex) and tonumber(member.PetTargetIndex) > 0) then
                local pet = GetEntity(member.PetTargetIndex);
                if (pet ~= nil and tonumber(pet.ServerId) == tonumber(server_id)) then return true; end
            end
        end
    end
    return false;
end

local function build_spell_cache()
    if (M.spell_cache_built) then return; end
    local resources = AshitaCore:GetResourceManager();
    for id = 0, 2048 do
        local spell = resources:GetSpellById(id);
        if (spell ~= nil and spell.Name ~= nil and spell.Name[1] ~= nil) then
            local key = clean_name(spell.Name[1]):lower();
            if (key ~= '') then M.spell_cache[key] = spell; end
        end
    end
    M.spell_cache_built = true;
end

function M.find_spell(name)
    if (name == nil or name == '') then return nil; end
    build_spell_cache();
    return M.spell_cache[tostring(name):lower()];
end

local function job_usable(spell, player)
    if (spell == nil or player == nil or spell.LevelRequired == nil) then return false; end
    local main_job, sub_job = tonumber(player:GetMainJob()) or 0, tonumber(player:GetSubJob()) or 0;
    local main_required = tonumber(spell.LevelRequired[main_job + 1]) or 0xFF;
    local sub_required = tonumber(spell.LevelRequired[sub_job + 1]) or 0xFF;
    local main_ok = main_required > 0 and main_required < 0xFF and (tonumber(player:GetMainJobLevel()) or 0) >= main_required;
    local sub_ok = sub_required > 0 and sub_required < 0xFF and (tonumber(player:GetSubJobLevel()) or 0) >= sub_required;
    return main_ok or sub_ok;
end

local function has_buff(wanted)
    local player = M.player();
    if (player == nil) then return false; end
    for _, buff in pairs(player:GetBuffs() or {}) do if (tonumber(buff) == tonumber(wanted)) then return true; end end
    return false;
end

local function init_blu_reader()
    if (M.blu.initialized) then return M.blu.available; end
    M.blu.initialized = true;
    local ok, address = pcall(function ()
        return ashita.memory.find(0, 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
    end);
    if (not ok or address == nil or address == 0) then
        M.blu.error = 'BLU spell-set signature not found'; return false;
    end
    local cast_ok, offset = pcall(function () return ffi.cast('uint32_t*', address); end);
    if (not cast_ok or offset == nil) then M.blu.error = 'BLU spell-set reader failed'; return false; end
    M.blu.offset = offset;
    M.blu.available = true;
    return true;
end

function M.set_blu_spells()
    local result = {};
    local player = M.player();
    if (player == nil) then return result, 'player data unavailable'; end
    local main_blu = player:GetMainJob() == 16;
    local sub_blu = player:GetSubJob() == 16;
    if (not main_blu and not sub_blu) then return result, 'BLU is not current main/sub job'; end
    if (not init_blu_reader()) then return result, M.blu.error; end
    local pointer = AshitaCore:GetPointerManager():Get('inventory');
    if (pointer == nil or pointer == 0) then return result, 'inventory pointer unavailable'; end
    pointer = ashita.memory.read_uint32(pointer);
    if (pointer == nil or pointer == 0) then return result, 'inventory buffer unavailable'; end
    local offset_value = tonumber(M.blu.offset[0]);
    if (offset_value == nil or offset_value == 0) then return result, 'BLU spell-set offset unavailable'; end
    local slot_offset = main_blu and 0x04 or 0xA0;
    local ok, slots = pcall(function ()
        return ashita.memory.read_array(pointer + offset_value + slot_offset, 0x14);
    end);
    if (not ok or slots == nil) then return result, 'failed to read BLU spell slots'; end
    for _, raw_id in ipairs(slots) do
        raw_id = tonumber(raw_id) or 0;
        if (raw_id > 0) then result[raw_id + 512] = true; end
    end
    return result, 'available';
end

function M.check_spell(entry, settings, target, blu_set)
    local player = M.player();
    if (player == nil) then return false, 'PLAYER DATA UNAVAILABLE'; end
    if (not player:HasSpellData()) then return false, 'SPELL DATA NOT LOADED'; end
    local spell = M.find_spell(entry.name);
    if (spell == nil) then return false, 'NOT IN RETAIL RESOURCES'; end
    if (not player:HasSpell(spell.Id)) then return false, 'NOT LEARNED', spell; end
    if (not job_usable(spell, player)) then return false, 'CURRENT JOB CANNOT CAST', spell; end
    if (tonumber(spell.Skill) == 43) then
        if (blu_set == nil) then blu_set = M.set_blu_spells(); end
        if (not blu_set[spell.Id]) then return false, 'BLUE MAGIC NOT SET', spell; end
        if (not has_buff(163) and not has_buff(165)) then return false, 'BURST AFFINITY / AZURE LORE NOT ACTIVE', spell; end
    end
    local blocked = M.blocking_status();
    if (blocked ~= nil) then return false, blocked:upper(), spell; end
    local mp = M.current_mp();
    local cost = tonumber(spell.ManaCost) or 0;
    local reserve = tonumber(settings.mp_reserve) or 0;
    if ((mp - cost) < reserve) then return false, string.format('MP RESERVE (%d - %d < %d)', mp, cost, reserve), spell; end
    local recast = AshitaCore:GetMemoryManager():GetRecast();
    if (recast ~= nil and recast:GetSpellTimer(spell.Id) > 0) then return false, 'ON RECAST', spell; end
    if (target == nil) then return false, 'NO VALID TARGET', spell; end
    if ((tonumber(target.hpp) or 0) <= 0) then return false, 'TARGET IS DEAD', spell; end
    if (target.entity == nil or target.entity.SpawnFlags == nil or bit.band(tonumber(target.entity.SpawnFlags) or 0, 0x10) == 0) then
        return false, 'TARGET IS NOT AN ENEMY', spell;
    end
    local range = 21.0;
    local ok, true_range = pcall(function () return AshitaCore:GetResourceManager():GetSpellRange(spell.Id, false); end);
    if (ok and tonumber(true_range) and tonumber(true_range) > 0) then range = tonumber(true_range); end
    if ((tonumber(target.distance) or 999) > math.min(range, tonumber(settings.max_range) or range)) then
        return false, string.format('TOO FAR (%.1f / %.1f)', target.distance, math.min(range, tonumber(settings.max_range) or range)), spell;
    end
    local raw_cast = tonumber(spell.CastTime) or 12;
    local fast_cast = math.max(0, math.min(80, tonumber(settings.fast_cast) or 0));
    local cast_time = (raw_cast / 4.0) * (1.0 - fast_cast / 100.0) + (tonumber(settings.latency) or 0.20);
    return true, 'AVAILABLE', spell, cast_time, cost, range;
end

function M.available_weaponskills(skills)
    local result = {};
    local player = M.player();
    if (player == nil) then return result; end
    for id, entry in pairs((skills and skills[3]) or {}) do
        if (entry ~= nil and player:HasWeaponSkill(id)) then table.insert(result, entry); end
    end
    table.sort(result, function (a, b) return tostring(a.en) < tostring(b.en); end);
    return result;
end

return M;
