-- Target weakness fallbacks keyed only by values verified from Ashita's entity data.
--
-- Ashita v4 exposes entity.Race as a numeric client value. It does not expose the
-- ecosystem labels used by FFXI reference sites (Aquan, Undead, Plantoid, etc.).
-- Keep this table sparse until a numeric value and its weakness have both been
-- validated. Named NM exceptions belong in the user's weaknesses.lua file.

local M = {
    by_race = {},
    by_model = {},
};

-- Example of the required shape after a numeric race value is verified:
-- M.by_race[123] = { weak = { 'Lightning' } };

-- No documented Ashita v4 entity ModelId field is currently used by Burst.
-- This table is retained for forward-compatible, verified model mappings only.
-- M.by_model[1234] = { weak = { 'Ice' } };

return M;
