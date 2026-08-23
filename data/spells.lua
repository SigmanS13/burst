-- Curated damaging spell families used by the advisor. Availability, MP, recast,
-- job level, BLU set status, range, and real cast time are validated at runtime.

local M = { entries = {} };

local function add(name, element, family, tier, score)
    table.insert(M.entries, {
        name = name, element = element, family = family,
        tier = tier or 1, score = score or (tier or 1) * 10,
    });
end

local romans = { '', ' II', ' III', ' IV', ' V', ' VI' };
local singles = {
    Fire = 'Fire', Blizzard = 'Ice', Aero = 'Wind', Stone = 'Earth',
    Thunder = 'Lightning', Water = 'Water',
};
for base, element in pairs(singles) do
    for tier = 1, 6 do add(base .. romans[tier], element, 'Elemental', tier, tier * 12); end
end

local aoe = {
    Firaga = 'Fire', Blizzaga = 'Ice', Aeroga = 'Wind', Stonega = 'Earth',
    Thundaga = 'Lightning', Waterga = 'Water',
};
for base, element in pairs(aoe) do
    for tier = 1, 5 do add(base .. romans[tier], element, 'Elemental AoE', tier, tier * 10 - 2); end
end

local ra = {
    Fira = 'Fire', Blizzara = 'Ice', Aera = 'Wind', Stonera = 'Earth',
    Thundara = 'Lightning', Watera = 'Water',
};
for base, element in pairs(ra) do
    for tier = 1, 3 do add(base .. romans[tier], element, 'Elemental AoE', tier, tier * 10 - 1); end
end

for name, element in pairs({
    Firaja = 'Fire', Blizzaja = 'Ice', Aeroja = 'Wind', Stoneja = 'Earth',
    Thundaja = 'Lightning', Waterja = 'Water',
}) do add(name, element, 'Elemental AoE', 5, 52); end

for name, element in pairs({
    Flare = 'Fire', ['Flare II'] = 'Fire', Freeze = 'Ice', ['Freeze II'] = 'Ice',
    Tornado = 'Wind', ['Tornado II'] = 'Wind', Quake = 'Earth', ['Quake II'] = 'Earth',
    Burst = 'Lightning', ['Burst II'] = 'Lightning', Flood = 'Water', ['Flood II'] = 'Water',
}) do add(name, element, 'Ancient Magic', name:find('II', 1, true) and 2 or 1, name:find('II', 1, true) and 58 or 38); end

for name, element in pairs({
    Pyrohelix = 'Fire', Cryohelix = 'Ice', Anemohelix = 'Wind', Geohelix = 'Earth',
    Ionohelix = 'Lightning', Hydrohelix = 'Water', Luminohelix = 'Light', Noctohelix = 'Dark',
}) do
    add(name, element, 'Helix', 1, 34);
    add(name .. ' II', element, 'Helix', 2, 48);
end

for base, element in pairs({
    Katon = 'Fire', Hyoton = 'Ice', Huton = 'Wind', Doton = 'Earth',
    Raiton = 'Lightning', Suiton = 'Water',
}) do
    add(base .. ': Ichi', element, 'Ninjutsu', 1, 14);
    add(base .. ': Ni', element, 'Ninjutsu', 2, 26);
    add(base .. ': San', element, 'Ninjutsu', 3, 40);
end

add('Banish', 'Light', 'Divine', 1, 10);
add('Banish II', 'Light', 'Divine', 2, 20);
add('Banish III', 'Light', 'Divine', 3, 32);
add('Banishga', 'Light', 'Divine', 1, 8);
add('Banishga II', 'Light', 'Divine', 2, 18);
add('Banishga III', 'Light', 'Divine', 3, 29);
add('Holy', 'Light', 'Divine', 3, 34);
add('Holy II', 'Light', 'Divine', 5, 52);
add('Drain', 'Dark', 'Dark Magic', 1, 18);
add('Drain II', 'Dark', 'Dark Magic', 3, 34);
add('Drain III', 'Dark', 'Dark Magic', 5, 52);
add('Impact', 'Dark', 'Dark Magic', 5, 45);
add('Kaustra', 'Dark', 'Dark Magic', 5, 54);
add('Comet', 'Dark', 'Dark Magic', 5, 56);
add('Meteor', 'Dark', 'Dark Magic', 6, 62);

-- Magical Blue Magic. Deliberately excludes self-destructive and purely physical spells.
local blue = {
    { 'Bomb Toss', 'Fire', 16 }, { 'Fire Breath', 'Fire', 18 }, { 'Heat Breath', 'Fire', 26 },
    { 'Firespit', 'Fire', 30 }, { 'Blazing Bound', 'Fire', 38 }, { 'Thermal Pulse', 'Fire', 42 },
    { 'Gates of Hades', 'Fire', 48 }, { 'Searing Tempest', 'Fire', 58 },
    { 'Ice Break', 'Ice', 20 }, { 'Frost Breath', 'Ice', 24 }, { 'Polar Roar', 'Ice', 34 },
    { 'Spectral Floe', 'Ice', 58 },
    { 'Hecatomb Wave', 'Wind', 20 }, { 'Mysterious Light', 'Wind', 24 },
    { 'Leafstorm', 'Wind', 36 }, { 'Subduction', 'Wind', 46 }, { 'Silent Storm', 'Wind', 58 },
    { 'Magnetite Cloud', 'Earth', 18 }, { 'Sandspin', 'Earth', 20 },
    { 'Cimicine Discharge', 'Earth', 32 }, { 'Entomb', 'Earth', 58 },
    { 'Blitzstrahl', 'Lightning', 18 }, { 'Mind Blast', 'Lightning', 30 },
    { 'Charged Whisker', 'Lightning', 46 }, { 'Thunderbolt', 'Lightning', 48 },
    { 'Anvil Lightning', 'Lightning', 58 },
    { 'Cursed Sphere', 'Water', 18 }, { 'Maelstrom', 'Water', 24 }, { 'Regurgitation', 'Water', 30 },
    { 'Corrosive Ooze', 'Water', 34 }, { 'Water Bomb', 'Water', 38 },
    { 'Nectarous Deluge', 'Water', 48 }, { 'Scouring Spate', 'Water', 58 },
    { 'Radiant Breath', 'Light', 22 }, { 'Magic Hammer', 'Light', 32 },
    { 'Retinal Glare', 'Light', 42 }, { 'Blinding Fulgor', 'Light', 58 },
    { 'Death Ray', 'Dark', 20 }, { 'Eyes On Me', 'Dark', 28 }, { 'Dark Orb', 'Dark', 38 },
    { "Everyone's Grudge", 'Dark', 42 }, { 'Palling Salvo', 'Dark', 48 }, { 'Tenebral Crush', 'Dark', 58 },
};
for _, entry in ipairs(blue) do add(entry[1], entry[2], 'Blue Magic', math.max(1, math.floor(entry[3] / 12)), entry[3]); end

table.sort(M.entries, function (a, b)
    if (a.element ~= b.element) then return a.element < b.element; end
    if (a.family ~= b.family) then return a.family < b.family; end
    if (a.score ~= b.score) then return a.score > b.score; end
    return a.name < b.name;
end);

M.by_name = {};
for _, entry in ipairs(M.entries) do M.by_name[entry.name:lower()] = entry; end

M.families = { 'Any', 'Elemental', 'Elemental AoE', 'Ancient Magic', 'Helix', 'Ninjutsu', 'Divine', 'Dark Magic', 'Blue Magic' };
M.elements = { 'Auto', 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' };

return M;
