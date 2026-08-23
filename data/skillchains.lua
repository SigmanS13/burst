local M = {};

M.properties = {
    [1] = 'Light', [2] = 'Darkness', [3] = 'Gravitation', [4] = 'Fragmentation',
    [5] = 'Distortion', [6] = 'Fusion', [7] = 'Compression', [8] = 'Liquefaction',
    [9] = 'Induration', [10] = 'Reverberation', [11] = 'Transfixion',
    [12] = 'Scission', [13] = 'Detonation', [14] = 'Impaction',
    [15] = 'Radiance', [16] = 'Umbra',
};

M.info = {
    Radiance = { level = 4, elements = { 'Fire', 'Wind', 'Lightning', 'Light' } },
    Umbra = { level = 4, elements = { 'Earth', 'Ice', 'Water', 'Dark' } },
    Light = { level = 3, elements = { 'Fire', 'Wind', 'Lightning', 'Light' },
        Light = { level = 4, result = 'Light' } },
    Darkness = { level = 3, elements = { 'Earth', 'Ice', 'Water', 'Dark' },
        Darkness = { level = 4, result = 'Darkness' } },
    Gravitation = { level = 2, elements = { 'Earth', 'Dark' },
        Distortion = { level = 3, result = 'Darkness' },
        Fragmentation = { level = 2, result = 'Fragmentation' } },
    Fragmentation = { level = 2, elements = { 'Wind', 'Lightning' },
        Fusion = { level = 3, result = 'Light' },
        Distortion = { level = 2, result = 'Distortion' } },
    Distortion = { level = 2, elements = { 'Ice', 'Water' },
        Gravitation = { level = 3, result = 'Darkness' },
        Fusion = { level = 2, result = 'Fusion' } },
    Fusion = { level = 2, elements = { 'Fire', 'Light' },
        Fragmentation = { level = 3, result = 'Light' },
        Gravitation = { level = 2, result = 'Gravitation' } },
    Compression = { level = 1, elements = { 'Dark' },
        Transfixion = { level = 1, result = 'Transfixion' },
        Detonation = { level = 1, result = 'Detonation' } },
    Liquefaction = { level = 1, elements = { 'Fire' },
        Impaction = { level = 2, result = 'Fusion' },
        Scission = { level = 1, result = 'Scission' } },
    Induration = { level = 1, elements = { 'Ice' },
        Reverberation = { level = 2, result = 'Fragmentation' },
        Compression = { level = 1, result = 'Compression' },
        Impaction = { level = 1, result = 'Impaction' } },
    Reverberation = { level = 1, elements = { 'Water' },
        Induration = { level = 1, result = 'Induration' },
        Impaction = { level = 1, result = 'Impaction' } },
    Transfixion = { level = 1, elements = { 'Light' },
        Scission = { level = 2, result = 'Distortion' },
        Reverberation = { level = 1, result = 'Reverberation' },
        Compression = { level = 1, result = 'Compression' } },
    Scission = { level = 1, elements = { 'Earth' },
        Liquefaction = { level = 1, result = 'Liquefaction' },
        Reverberation = { level = 1, result = 'Reverberation' },
        Detonation = { level = 1, result = 'Detonation' } },
    Detonation = { level = 1, elements = { 'Wind' },
        Compression = { level = 2, result = 'Gravitation' },
        Scission = { level = 1, result = 'Scission' } },
    Impaction = { level = 1, elements = { 'Lightning' },
        Liquefaction = { level = 1, result = 'Liquefaction' },
        Detonation = { level = 1, result = 'Detonation' } },
};

M.skillchain_messages = {
    [288] = true, [289] = true, [290] = true, [291] = true, [292] = true,
    [293] = true, [294] = true, [295] = true, [296] = true, [297] = true,
    [298] = true, [299] = true, [300] = true, [301] = true,
    [385] = true, [386] = true, [387] = true, [388] = true, [389] = true,
    [390] = true, [391] = true, [392] = true, [393] = true, [394] = true,
    [395] = true, [396] = true, [397] = true,
    [767] = true, [768] = true, [769] = true, [770] = true,
};

M.magic_burst_messages = {
    [252] = true, -- damaging magic / divine magic
    [267] = true, [268] = true, [271] = true, -- non-damage burst result variants
    [274] = true, [275] = true, -- Drain / Aspir
};

function M.from_additional_effect(effect)
    if (effect == nil or not M.skillchain_messages[tonumber(effect.message) or -1]) then return nil; end
    local code = bit.band(tonumber(effect.damage) or 0, 0x3F);
    return M.properties[code];
end

function M.elements(property)
    local entry = M.info[property];
    return entry and entry.elements or {};
end

function M.resolve(active_properties, closer_properties)
    for _, first in ipairs(active_properties or {}) do
        local source = M.info[first];
        if (source ~= nil) then
            for _, second in ipairs(closer_properties or {}) do
                local result = source[second];
                if (result ~= nil) then
                    return result.result, result.level, first, second;
                end
            end
        end
    end
    return nil;
end

function M.has_element(property, element)
    for _, value in ipairs(M.elements(property)) do
        if (value == element) then return true; end
    end
    return false;
end

return M;
