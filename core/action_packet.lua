-- Passive parser for incoming FFXI action packet 0x028.
-- It supports retail/XiPackets and the older ten-bit target-count layout.

local M = {};

local function normalize_layout(value)
    value = tostring(value or 'auto'):lower();
    if (value ~= 'retail' and value ~= 'legacy') then return 'auto'; end
    return value;
end

function M.parse(data_raw, size, unpack_bits, layout_preference)
    if (data_raw == nil or type(unpack_bits) ~= 'function') then return nil, 'packet data unavailable'; end
    local maximum = (tonumber(size) or 0) * 8;
    if (maximum <= 150) then return nil, 'packet is too small'; end

    local malformed = false;
    local function read(offset, length)
        if ((offset + length) > maximum) then malformed = true; return 0; end
        local value = unpack_bits(data_raw, offset, length);
        return tonumber(value) or 0;
    end

    local retail_count = read(72, 6);
    local legacy_count = read(72, 10);
    local layout = normalize_layout(layout_preference);
    if (layout == 'auto') then
        layout = (retail_count == 0 and legacy_count > 0) and 'legacy' or 'retail';
    end
    local target_count = layout == 'legacy' and legacy_count or retail_count;
    if (target_count > 64) then return nil, 'implausible target count'; end

    local category = read(82, 4);
    local packet = {
        actor_id = read(40, 32),
        target_count = target_count,
        retail_target_count = retail_count,
        legacy_target_count = legacy_count,
        layout = layout,
        category = category,
        recast = read(118, 32),
        targets = {},
    };
    if (category == 8 or category == 9) then
        packet.param = read(86, 16);
        packet.group = read(102, 16);
    else
        packet.param = read(86, 32);
    end

    local offset = 150;
    for _ = 1, target_count do
        local target = { id = read(offset, 32), actions = {} };
        offset = offset + 32;
        target.action_count = read(offset, 4);
        offset = offset + 4;
        if (target.action_count > 8) then return nil, 'implausible action count'; end

        for _ = 1, target.action_count do
            local action = {};
            action.reaction = read(offset, 5); offset = offset + 5;
            action.animation = read(offset, 12); offset = offset + 12;
            action.special_effect = read(offset, 7); offset = offset + 7;
            action.knockback = read(offset, 3); offset = offset + 3;
            action.param = read(offset, 17); offset = offset + 17;
            action.message = read(offset, 10); offset = offset + 10;
            action.flags = read(offset, 31); offset = offset + 31;

            local has_additional = read(offset, 1) == 1; offset = offset + 1;
            if (has_additional) then
                local effect_animation = read(offset, 10);
                action.additional_effect = {
                    animation = effect_animation,
                    damage = effect_animation, -- compatibility alias for existing consumers
                    param = read(offset + 10, 17),
                    message = read(offset + 27, 10),
                };
                offset = offset + 37;
            end

            local has_spikes = read(offset, 1) == 1; offset = offset + 1;
            if (has_spikes) then
                action.spikes_effect = {
                    damage = read(offset, 10),
                    param = read(offset + 10, 14),
                    message = read(offset + 24, 10),
                };
                offset = offset + 34;
            end
            table.insert(target.actions, action);
        end
        table.insert(packet.targets, target);
    end

    if (malformed) then return nil, 'malformed action packet'; end
    return packet;
end

return M;
