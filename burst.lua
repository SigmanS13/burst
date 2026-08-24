addon.name      = 'burst';
addon.author    = 'Sigman';
addon.version   = '0.1.1';
addon.desc      = 'Manual magic-burst advisor and optional skillchain coach for Ashita v4.';
addon.link      = '';

-- burst is intentionally advice-only. It never injects commands or outgoing action packets.

require('common');
local imgui = require('imgui');
local settings = require('settings');
local chat = require('chat');
local ffi = require('ffi');

local action_packet = require('core.action_packet');
local player_state = require('core.player_state');
local Tracker = require('core.tracker');
local advisor = require('core.advisor');
local planner = require('core.planner');
local skillchains = require('data.skillchains');
local spell_catalog = require('data.spells');
local skills = require('data.skills');
local ui_theme = require('ui.theme');

local default_settings = T{
    enabled = true,
    profiles_enabled = true,
    profiles = T{},
    advisor = T{
        target_policy = 'current', -- current / any
        preferred_element = 'Auto',
        preferred_family = 'Any',
        mp_reserve = 100,
        max_range = 21.0,
        disabled_spells = T{},
    },
    timing = T{
        burst_window = 10.0,
        fast_cast = 50.0,
        latency = 0.20,
        safety_margin = 0.60,
        post_window_linger = 0.50,
    },
    assist = T{
        mode = 'Off', -- Off / Planner / Coach / Adaptive Coach
        mage_mode = 'Me', -- Me / Named Party Member / Generic Mage Profile
        mage_name = 'Mage',
        goal = 'Auto',
        preferred_spell = 'Thunder V',
        specific_skillchain = 'Light',
        preferred_element = 'Lightning',
        go_delay = 2.0,
        close_window = 6.0,
        use_local = true,
        allow_same_player = true,
        participants = T{
            T{ enabled = false, name = 'Partner 1', weaponskills = '' },
            T{ enabled = false, name = 'Partner 2', weaponskills = '' },
            T{ enabled = false, name = 'Partner 3', weaponskills = '' },
        },
    },
    packet = T{ layout = 'auto' },
    overlay = T{
        position_x = 480, position_y = 260,
        card_opacity = 0.88, card_scale = 1.0,
        edge_enabled = true, edge_intensity = 0.72,
        reduced_motion = false, show_alternates = true,
    },
    ui = T{
        theme = 'vana_tactical', scale_preset = 'auto', custom_scale = 1.0,
        launcher_enabled = true, launcher_position_x = -1, launcher_position_y = -1,
        launcher_size = 58, controller_enabled = true, controller_layout = 'xinput',
    },
    sound = T{
        enabled = false, burst_open = 'None', burst_success = 'None',
    },
};

burst = T{
    settings = nil,
    tracker = Tracker.new(skills),
    is_gui_open = T{ false },
    main_tab = T{ 1 },
    options_section = T{ 1 },
    gui_size_initialized = false,
    theme = nil,
    recommendation = nil,
    current_chain = nil,
    active_plan = nil,
    plans = {},
    selected_plan = 1,
    selected_spell = nil,
    spell_search = T{ '' },
    spell_element_filter = T{ 0 },
    preview_visible = false,
    preview_state = nil,
    preview_drag_active = false,
    preview_drag_x = nil,
    preview_drag_y = nil,
    next_position_save = nil,
    sound_files = T{ 'None' },
    debug = false,
    packet_signatures = {},
    profile_key = nil,
    ui = T{
        launcher_initialized = false, launcher_press = false, launcher_dragged = false,
        launcher_mouse_x = nil, launcher_mouse_y = nil, next_launcher_save = nil,
    },
};

local function ensure_settings()
    local s = burst.settings;
    if (s.profiles_enabled == nil) then s.profiles_enabled = true; end
    if (s.profiles == nil) then s.profiles = T{}; end
    if (s.advisor == nil) then s.advisor = T{}; end
    if (s.timing == nil) then s.timing = T{}; end
    if (s.assist == nil) then s.assist = T{}; end
    if (s.packet == nil) then s.packet = T{}; end
    if (s.overlay == nil) then s.overlay = T{}; end
    if (s.ui == nil) then s.ui = T{}; end
    if (s.sound == nil) then s.sound = T{}; end
    for key, value in pairs(default_settings.advisor) do if (s.advisor[key] == nil) then s.advisor[key] = value; end end
    for key, value in pairs(default_settings.timing) do if (s.timing[key] == nil) then s.timing[key] = value; end end
    for key, value in pairs(default_settings.assist) do if (s.assist[key] == nil) then s.assist[key] = value; end end
    for key, value in pairs(default_settings.packet) do if (s.packet[key] == nil) then s.packet[key] = value; end end
    for key, value in pairs(default_settings.overlay) do if (s.overlay[key] == nil) then s.overlay[key] = value; end end
    for key, value in pairs(default_settings.ui) do if (s.ui[key] == nil) then s.ui[key] = value; end end
    for key, value in pairs(default_settings.sound) do if (s.sound[key] == nil) then s.sound[key] = value; end end
    if (s.advisor.disabled_spells == nil) then s.advisor.disabled_spells = T{}; end
    if (s.assist.participants == nil) then s.assist.participants = T{}; end
    for slot = 1, 3 do
        if (s.assist.participants[slot] == nil) then
            s.assist.participants[slot] = T{ enabled = false, name = 'Partner ' .. slot, weaponskills = '' };
        end
    end
end

local function clone_table(value)
    if (type(value) ~= 'table') then return value; end
    local result = T{};
    for key, item in pairs(value) do result[key] = clone_table(item); end
    return result;
end

local function capture_profile(key)
    if (burst.settings == nil or burst.settings.profiles_enabled ~= true or key == nil) then return; end
    burst.settings.profiles[key] = T{
        advisor = clone_table(burst.settings.advisor),
        timing = clone_table(burst.settings.timing),
    };
end

local function sync_profile()
    if (burst.settings == nil or burst.settings.profiles_enabled ~= true) then return; end
    local key = player_state.profile_key();
    if (key == nil) then return; end
    if (burst.profile_key == key) then return; end
    capture_profile(burst.profile_key);
    burst.profile_key = key;
    local saved = burst.settings.profiles[key];
    if (saved ~= nil) then
        burst.settings.advisor = clone_table(saved.advisor or burst.settings.advisor);
        burst.settings.timing = clone_table(saved.timing or burst.settings.timing);
        ensure_settings();
    else
        capture_profile(key);
    end
    settings.save('burst_settings');
end

local function save_settings()
    capture_profile(burst.profile_key);
    settings.save('burst_settings');
end

local function get_ui_scale()
    local ui = burst.settings.ui;
    if (ui.scale_preset == '1440p') then return 1.0; end
    if (ui.scale_preset == '1080p') then return 0.75; end
    if (ui.scale_preset == 'custom') then return math.max(0.60, math.min(1.75, tonumber(ui.custom_scale) or 1.0)); end
    local display = imgui.GetIO().DisplaySize;
    return math.max(0.70, math.min(1.35, (tonumber(display.y) or 1080) / 1440));
end

-- Warn 2.2.0 guards this helper because it is optional in some Ashita v4
-- Dear ImGui builds. Cosmetic scaling must never break the render callback.
local function set_ui_font_scale(value)
    if (type(imgui.SetWindowFontScale) == 'function') then
        imgui.SetWindowFontScale(value);
    end
end

local function reload_theme()
    burst.theme = ui_theme.load(addon.path, burst.settings.ui.theme);
end

local function color_alpha(color, alpha)
    return { color[1], color[2], color[3], math.max(0, math.min(1, alpha or color[4] or 1)) };
end

local element_colors = {
    Fire = { 1.00, 0.28, 0.16, 1.0 }, Ice = { 0.30, 0.88, 1.00, 1.0 },
    Wind = { 0.38, 1.00, 0.48, 1.0 }, Earth = { 0.78, 0.62, 0.24, 1.0 },
    Lightning = { 0.78, 0.40, 1.00, 1.0 }, Water = { 0.20, 0.55, 1.00, 1.0 },
    Light = { 1.00, 0.96, 0.72, 1.0 }, Dark = { 0.42, 0.28, 0.72, 1.0 },
};

local skillchain_colors = {
    Radiance = { 1.00, 0.90, 0.45, 1.0 }, Umbra = { 0.54, 0.30, 0.82, 1.0 },
    Light = { 1.00, 0.88, 0.48, 1.0 }, Darkness = { 0.50, 0.30, 0.76, 1.0 },
    Fragmentation = { 0.36, 0.76, 1.00, 1.0 }, Distortion = { 0.38, 0.82, 0.94, 1.0 },
    Fusion = { 1.00, 0.48, 0.20, 1.0 }, Gravitation = { 0.66, 0.38, 0.82, 1.0 },
};

--------------------------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------------------------

ffi.cdef[[
    int __stdcall PlaySoundA(const char* pszSound, void* hmod, unsigned int fdwSound);
    void* __stdcall FindFirstFileA(const char* lpFileName, void* lpFindFileData);
    int __stdcall FindNextFileA(void* hFindFile, void* lpFindFileData);
    int __stdcall FindClose(void* hFindFile);
]];
local winmm, kernel32 = nil, nil;
pcall(function () winmm = ffi.load('winmm'); end);
pcall(function () kernel32 = ffi.load('kernel32'); end);
local SND_ASYNC, SND_NODEFAULT, SND_FILENAME = 0x0001, 0x0002, 0x00020000;

local function refresh_sounds(announce)
    local files, seen = { 'None' }, {};
    if (kernel32 ~= nil) then
        local data = ffi.new('uint8_t[?]', 320);
        local handle = kernel32.FindFirstFileA(addon.path .. '\\sounds\\*.wav', data);
        if (handle ~= ffi.cast('void*', -1)) then
            while (true) do
                local attributes = ffi.cast('uint32_t*', data)[0];
                if (bit.band(attributes, 0x10) == 0) then
                    local name = ffi.string(ffi.cast('char*', data) + 44);
                    local lower = name:lower();
                    if (lower:match('%.wav$') and not seen[lower]) then seen[lower] = true; table.insert(files, name); end
                end
                if (kernel32.FindNextFileA(handle, data) == 0) then break; end
            end
            kernel32.FindClose(handle);
        end
    end
    table.sort(files, function (a, b) if (a == 'None') then return true; end if (b == 'None') then return false; end return a:lower() < b:lower(); end);
    burst.sound_files = T{};
    for _, name in ipairs(files) do table.insert(burst.sound_files, name); end
    for _, key in ipairs({ 'burst_open', 'burst_success' }) do
        local wanted, found = tostring(burst.settings.sound[key] or 'None'):lower(), false;
        for _, name in ipairs(files) do if (name:lower() == wanted) then burst.settings.sound[key] = name; found = true; break; end end
        if (not found) then burst.settings.sound[key] = 'None'; end
    end
    if (announce) then print(chat.header(addon.name):append(chat.message(string.format('Found %d WAV sound file(s).', math.max(0, #files - 1))))); end
end

local function play_sound(name)
    if (burst.settings.sound.enabled ~= true or name == nil or name == 'None' or winmm == nil) then return; end
    local path = addon.path .. '\\sounds\\' .. tostring(name);
    local file = io.open(path, 'rb');
    if (file == nil) then return; end
    file:close();
    pcall(function () winmm.PlaySoundA(path, nil, bit.bor(SND_FILENAME, SND_ASYNC, SND_NODEFAULT)); end);
end

--------------------------------------------------------------------------------------------------
-- Combat state
--------------------------------------------------------------------------------------------------

local function entity_name(server_id)
    local target = player_state.target_by_id(server_id);
    return target and target.name or ('Target ' .. tostring(server_id));
end

local function combined_advisor_settings()
    local result = {};
    for key, value in pairs(burst.settings.advisor) do result[key] = value; end
    for key, value in pairs(burst.settings.timing) do result[key] = value; end
    return result;
end

local function update_recommendation()
    burst.tracker:prune(os.clock(), burst.settings.timing.post_window_linger);
    local current = player_state.current_target();
    local chain = burst.tracker:best_chain(current and current.id or nil, burst.settings.advisor.target_policy);
    burst.current_chain = chain;
    if (chain ~= nil and chain.success == true and chain.success_at ~= nil and os.clock() - chain.success_at <= 2.5) then
        burst.recommendation = { status = 'success', reason = 'MAGIC BURST CONFIRMED', remaining = 0, best = { name = chain.success_spell } };
        return;
    end
    local target = chain and player_state.target_by_id(chain.target_id) or nil;
    burst.recommendation = advisor.recommend(chain, combined_advisor_settings(), player_state, target, os.clock());
end

local function handle_tracker_events(events)
    for _, event in ipairs(events or {}) do
        if (event.type == 'skillchain') then play_sound(burst.settings.sound.burst_open); end
        if (event.type == 'magic_burst') then play_sound(burst.settings.sound.burst_success); end
        if (burst.active_plan ~= nil and burst.settings.assist.mode ~= 'Off' and burst.settings.assist.mode ~= 'Planner') then
            local result;
            burst.active_plan, result = planner.handle_event(burst.active_plan, event, burst.settings.assist.mode);
            if (result == 'complete' or result == 'changed') then
                -- The burst coach naturally takes priority once a chain is confirmed.
            end
        end
        if (burst.debug) then print(chat.header(addon.name):append(chat.message('Event: ' .. tostring(event.type)))); end
    end
end

local function packet_signature(e)
    local data = e.data_modified or e.data;
    if (type(data) == 'string') then return data; end
    return tostring(e.id) .. ':' .. tostring(e.size) .. ':' .. tostring(e.data_raw);
end

local function process_action_packet(e)
    local now = os.clock();
    local signature = packet_signature(e);
    local previous = burst.packet_signatures[signature];
    if (previous ~= nil and now - previous < 0.20) then burst.tracker:mark_duplicate(); return; end
    burst.packet_signatures[signature] = now;
    if (burst.tracker.stats.parsed % 100 == 0) then
        for key, timestamp in pairs(burst.packet_signatures) do if (now - timestamp > 2.0) then burst.packet_signatures[key] = nil; end end
    end
    local parsed, err = action_packet.parse(e.data_raw, e.size, function (raw, offset, length)
        return ashita.bits.unpack_be(raw, 0, offset, length);
    end, burst.settings.packet.layout);
    if (parsed == nil) then burst.tracker:mark_parse_error(err); return; end
    local events = burst.tracker:process(parsed, now, burst.settings.timing, player_state.local_server_id(), entity_name, player_state.is_alliance_actor);
    handle_tracker_events(events);
end

local function run_preview(kind)
    local now = os.clock();
    if (kind == 'success') then
        burst.preview_state = { status = 'success', property = 'Fragmentation', target = 'Apex Crab', spell = 'Thunder V',
            detail = 'MAGIC BURST CONFIRMED', elements = skillchains.elements('Fragmentation'), started = now };
    elseif (kind == 'blocked') then
        burst.preview_state = { status = 'blocked', property = 'Light', target = 'Shadow Lord', spell = nil,
            detail = 'NOT LEARNED', elements = skillchains.elements('Light'), remaining = 2.3, started = now };
    else
        burst.preview_state = { status = 'ready', property = 'Fragmentation', target = 'Apex Crab', spell = 'Thunder V',
            detail = 'CAST NOW', elements = skillchains.elements('Fragmentation'), remaining = 6.8, started = now };
    end
end

--------------------------------------------------------------------------------------------------
-- Overlay
--------------------------------------------------------------------------------------------------

local function draw_edges(display, color, alpha)
    local cfg = burst.settings.overlay;
    if (cfg.edge_enabled ~= true or (tonumber(cfg.edge_intensity) or 0) <= 0) then return; end
    local scale = get_ui_scale();
    local pulse = 1.0;
    if (cfg.reduced_motion ~= true) then pulse = 0.84 + 0.16 * math.abs(math.sin(os.clock() * math.pi * 1.35)); end
    local intensity = math.max(0, math.min(1, tonumber(cfg.edge_intensity) or 0.72));
    local outer = imgui.GetColorU32(color_alpha(color, 0.50 * intensity * pulse * alpha));
    local clear = imgui.GetColorU32(color_alpha(color, 0));
    local thickness = math.max(28, math.min(display.x, display.y) * 0.075 * scale);
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoInputs, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoBringToFrontOnFocus);
    imgui.SetNextWindowPos({ 0, 0 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ display.x, display.y }, ImGuiCond_Always);
    if (imgui.Begin('##burst_edge_effect', true, flags)) then
        local draw = imgui.GetWindowDrawList();
        draw:AddRectFilledMultiColor({ 0, 0 }, { display.x, thickness }, outer, outer, clear, clear);
        draw:AddRectFilledMultiColor({ 0, display.y - thickness }, { display.x, display.y }, clear, clear, outer, outer);
        draw:AddRectFilledMultiColor({ 0, 0 }, { thickness, display.y }, outer, clear, clear, outer);
        draw:AddRectFilledMultiColor({ display.x - thickness, 0 }, { display.x, display.y }, clear, outer, outer, clear);
    end
    imgui.End();
end

local function overlay_content()
    if (burst.preview_state ~= nil and os.clock() - burst.preview_state.started <= 8.0) then return burst.preview_state, true; end
    if (burst.active_plan ~= nil and burst.active_plan.completed_at ~= nil and
        os.clock() - burst.active_plan.completed_at > (tonumber(burst.settings.timing.burst_window) or 10.0) +
            math.max(0, tonumber(burst.settings.timing.post_window_linger) or 0.5)) then
        burst.active_plan = nil;
    end
    local chain, rec = burst.current_chain, burst.recommendation;
    if (chain ~= nil and chain.success ~= true and chain.expires_at ~= nil and os.clock() > chain.expires_at) then
        return {
            status = 'closed', property = chain.property, target = chain.target_name, confirmed = true,
            detail = 'WINDOW CLOSED', remaining = 0, elements = chain.elements,
        }, false;
    end
    if (chain ~= nil and burst.active_plan ~= nil and burst.active_plan.completed and burst.settings.assist.mage_mode ~= 'Me') then
        return {
            status = 'coach', property = chain.property, target = chain.target_name, confirmed = true,
            spell = tostring(burst.active_plan.mage_name or 'MAGE') .. ': BURST',
            detail = 'HOLD WEAPONSKILLS', remaining = math.max(0, chain.expires_at - os.clock()),
            elements = chain.elements,
        }, false;
    end
    if (burst.settings.enabled == true and chain ~= nil and rec ~= nil and rec.status ~= 'idle') then
        local state = { property = chain.property, target = chain.target_name, status = rec.status, confirmed = true,
            detail = rec.reason, remaining = rec.remaining, elements = chain.elements };
        if (rec.best ~= nil) then state.spell = rec.best.name; end
        if (rec.alternates ~= nil) then state.alternates = rec.alternates; end
        return state, false;
    end
    local mode = burst.settings.assist.mode;
    if (burst.active_plan ~= nil and mode ~= 'Off' and mode ~= 'Planner') then
        local plan = burst.active_plan;
        local spell = plan.stage == 1 and plan.opener or (plan.stage == 2 and plan.closer or nil);
        local detail = plan.stage == 1 and ('OPEN — ' .. plan.opener_owner) or plan.message;
        local remaining = nil;
        if (plan.stage == 2 and plan.opener_at ~= nil) then
            local elapsed = math.max(0, os.clock() - plan.opener_at);
            local go_delay = tonumber(burst.settings.assist.go_delay) or 2.0;
            local close_window = tonumber(burst.settings.assist.close_window) or 6.0;
            remaining = math.max(0, close_window - elapsed);
            detail = elapsed >= go_delay and ('GO — ' .. plan.closer_owner) or ('WAIT — ' .. plan.closer_owner);
        end
        return { status = plan.completed and 'success' or 'coach', property = plan.result,
            target = 'Skillchain Assist for ' .. tostring(plan.mage_name or 'Mage'), spell = spell,
            detail = detail, elements = plan.elements, remaining = remaining }, false;
    end
    return nil, false;
end

local function overlay_primary_text(state)
    if (state.status == 'success') then return 'MAGIC BURST CONFIRMED'; end
    if (state.status == 'closed') then return 'WINDOW CLOSED'; end
    if (state.spell ~= nil) then
        if (state.status == 'coach') then return tostring(state.spell):upper(); end
        return 'CAST ' .. tostring(state.spell):upper();
    end
    local detail = tostring(state.detail or 'WAIT');
    if (detail == 'NOT LEARNED') then return 'NO MATCHING SPELL LEARNED'; end
    if (detail:find('WRONG TARGET', 1, true)) then return 'WRONG TARGET'; end
    if (detail:find('TARGET IS NOT LOADED', 1, true)) then return 'TARGET NOT LOADED'; end
    if (detail:find('TOO LATE', 1, true)) then return 'TOO LATE TO BURST'; end
    if (#detail > 32) then return 'NO USABLE BURST SPELL'; end
    return detail;
end

local function overlay_secondary_text(state, primary)
    if (state.status == 'success') then
        return state.spell and (tostring(state.spell):upper() .. ' BURST SUCCESSFUL') or nil;
    end
    if (state.status == 'closed') then return 'The magic-burst window has ended.'; end
    if (state.spell ~= nil) then return tostring(state.detail or 'CAST NOW'); end
    if (tostring(state.detail or '') == 'NOT LEARNED') then
        return 'Learn or enable one of the burst elements shown above.';
    end
    if (tostring(state.detail or '') ~= primary) then return tostring(state.detail); end
    return nil;
end

local function render_overlay()
    local state, preview = overlay_content();
    local appearance_open = burst.is_gui_open[1] and burst.main_tab[1] == 3 and burst.options_section[1] == 4;
    if (not appearance_open and preview and burst.preview_state ~= nil and burst.preview_visible) then burst.preview_visible = false; end
    if (state == nil) then return; end
    local display = imgui.GetIO().DisplaySize;
    local cfg = burst.settings.overlay;
    local scale = get_ui_scale() * math.max(0.70, math.min(1.40, tonumber(cfg.card_scale) or 1.0));
    local element = state.elements and state.elements[1] or nil;
    local spell_element = nil;
    if (state.spell ~= nil) then
        local entry = spell_catalog.by_name[tostring(state.spell):lower()];
        if (entry ~= nil) then spell_element = entry.element; end
    end
    local chain_accent = (spell_element and element_colors[spell_element]) or skillchain_colors[state.property] or
        element_colors[element] or burst.theme.important;
    local accent = chain_accent;
    if (state.status == 'urgent' or state.status == 'blocked') then accent = burst.theme.danger;
    elseif (state.status == 'success') then accent = burst.theme.success;
    elseif (state.status == 'closed') then accent = burst.theme.text_muted; end

    if (preview or state.confirmed == true) then
        local edge_color = state.status == 'success' and burst.theme.success or chain_accent;
        local edge_alpha = state.status == 'closed' and 0.35 or (state.status == 'success' and 0.60 or 1.0);
        draw_edges(display, edge_color, edge_alpha);
    end

    local width, height = math.min(display.x * 0.68, 620 * scale), 196 * scale;
    local x = tonumber(cfg.position_x) or math.floor((display.x - width) / 2);
    local y = tonumber(cfg.position_y) or math.floor(display.y * 0.22);
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoMove);
    if (not (appearance_open and burst.preview_visible)) then flags = bit.bor(flags, ImGuiWindowFlags_NoInputs); end
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ width, height }, ImGuiCond_Always);
    if (imgui.Begin('##burst_live_card', true, flags)) then
        local wx, wy = imgui.GetWindowPos();
        local draw = imgui.GetWindowDrawList();
        local bg = color_alpha(burst.theme.window_bg, tonumber(cfg.card_opacity) or 0.88);
        draw:AddRectFilled({ wx, wy }, { wx + width, wy + height }, imgui.GetColorU32(bg), 7 * scale);
        draw:AddRectFilled({ wx, wy }, { wx + width, wy + 34 * scale }, imgui.GetColorU32(color_alpha(burst.theme.panel_alt, 0.97)), 7 * scale);
        draw:AddRectFilled({ wx + 16 * scale, wy + 78 * scale }, { wx + width - 16 * scale, wy + 145 * scale },
            imgui.GetColorU32(color_alpha(burst.theme.field_bg, 0.86)), 5 * scale);
        draw:AddRect({ wx, wy }, { wx + width, wy + height }, imgui.GetColorU32(burst.theme.brass), 7 * scale, 0, math.max(1, 1.25 * scale));
        draw:AddRectFilled({ wx, wy }, { wx + 6 * scale, wy + height }, imgui.GetColorU32(chain_accent), 5 * scale);
        draw:AddRectFilled({ wx + 16 * scale, wy + 151 * scale }, { wx + width - 16 * scale, wy + 162 * scale },
            imgui.GetColorU32(burst.theme.field_bg), 3 * scale);

        if (appearance_open and burst.preview_visible) then
            imgui.SetCursorScreenPos({ wx, wy }); imgui.InvisibleButton('##burst_preview_drag', { width, height });
            if (imgui.IsItemClicked(0)) then burst.preview_drag_active = true; burst.preview_drag_x, burst.preview_drag_y = imgui.GetMousePos(); end
            if (burst.preview_drag_active and imgui.IsMouseDown(0)) then
                local mx, my = imgui.GetMousePos();
                if (imgui.IsMouseDragging(0, 3)) then
                    cfg.position_x = math.floor(math.max(0, math.min(display.x - width, x + mx - burst.preview_drag_x)));
                    cfg.position_y = math.floor(math.max(0, math.min(display.y - height, y + my - burst.preview_drag_y)));
                    burst.next_position_save = os.clock() + 0.35;
                end
                burst.preview_drag_x, burst.preview_drag_y = mx, my;
            elseif (burst.preview_drag_active and imgui.IsMouseReleased(0)) then burst.preview_drag_active = false; end
        end

        imgui.SetCursorScreenPos({ wx + 20 * scale, wy + 8 * scale });
        imgui.TextColored(burst.theme.brass_hover, (state.confirmed ~= true and not preview) and 'SKILLCHAIN GOAL:' or 'SKILLCHAIN:');
        imgui.SameLine(); imgui.TextColored(chain_accent, tostring(state.property or 'BURST'):upper());
        imgui.SameLine(); imgui.TextColored(burst.theme.text_muted, '  ' .. tostring(state.target or ''));

        imgui.SetCursorScreenPos({ wx + 22 * scale, wy + 47 * scale });
        imgui.TextColored(burst.theme.text_muted, 'BURST ELEMENTS');
        local chip_x = wx + 132 * scale;
        for _, burst_element in ipairs(state.elements or {}) do
            local chip_color = element_colors[burst_element] or burst.theme.important;
            local chip_width = math.max(52, 22 + #tostring(burst_element) * 7.2) * scale;
            draw:AddRectFilled({ chip_x, wy + 42 * scale }, { chip_x + chip_width, wy + 68 * scale },
                imgui.GetColorU32(color_alpha(chip_color, 0.17)), 4 * scale);
            draw:AddRect({ chip_x, wy + 42 * scale }, { chip_x + chip_width, wy + 68 * scale },
                imgui.GetColorU32(color_alpha(chip_color, 0.78)), 4 * scale, 0, math.max(1, scale));
            draw:AddRectFilled({ chip_x + 5 * scale, wy + 48 * scale }, { chip_x + 8 * scale, wy + 62 * scale },
                imgui.GetColorU32(chip_color), 2 * scale);
            imgui.SetCursorScreenPos({ chip_x + 12 * scale, wy + 47 * scale });
            imgui.TextColored(chip_color, tostring(burst_element):upper());
            chip_x = chip_x + chip_width + 6 * scale;
        end

        local primary = overlay_primary_text(state);
        local secondary = overlay_secondary_text(state, primary);
        imgui.SetCursorScreenPos({ wx + 26 * scale, wy + 88 * scale });
        set_ui_font_scale(1.18 * scale);
        imgui.TextColored(burst.theme.text, primary);
        set_ui_font_scale(1.0);
        if (secondary ~= nil) then
            imgui.SetCursorScreenPos({ wx + 26 * scale, wy + 119 * scale });
            imgui.TextColored(state.status == 'blocked' and burst.theme.danger or accent, secondary);
        end

        local fraction = state.status == 'success' and 1 or 0;
        if (state.remaining ~= nil) then
            fraction = math.max(0, math.min(1, state.remaining / math.max(0.1, tonumber(burst.settings.timing.burst_window) or 10)));
            local badge_x = wx + width - 104 * scale;
            draw:AddRectFilled({ badge_x, wy + 88 * scale }, { wx + width - 24 * scale, wy + 135 * scale },
                imgui.GetColorU32(color_alpha(accent, 0.14)), 5 * scale);
            draw:AddRect({ badge_x, wy + 88 * scale }, { wx + width - 24 * scale, wy + 135 * scale },
                imgui.GetColorU32(color_alpha(accent, 0.72)), 5 * scale, 0, math.max(1, scale));
            imgui.SetCursorScreenPos({ badge_x + 12 * scale, wy + 92 * scale });
            set_ui_font_scale(1.08 * scale);
            imgui.TextColored(accent, string.format('%.1fs', math.max(0, state.remaining)));
            set_ui_font_scale(1.0);
            imgui.SetCursorScreenPos({ badge_x + 10 * scale, wy + 116 * scale });
            imgui.TextColored(burst.theme.text_muted, state.status == 'closed' and 'CLOSED' or 'REMAINING');
        end
        draw:AddRectFilled({ wx + 16 * scale, wy + 151 * scale },
            { wx + 16 * scale + (width - 32 * scale) * fraction, wy + 162 * scale }, imgui.GetColorU32(accent), 3 * scale);

        if (cfg.show_alternates and state.alternates ~= nil) then
            local names = {};
            for _, alt in ipairs(state.alternates) do if (alt ~= nil) then table.insert(names, alt.name); end end
            if (#names > 0) then
                imgui.SetCursorScreenPos({ wx + 22 * scale, wy + 171 * scale });
                imgui.TextColored(burst.theme.text_muted, 'Alternates: ' .. table.concat(names, '  ·  '));
            end
        end
    end
    imgui.End();
    if (burst.next_position_save ~= nil and os.clock() >= burst.next_position_save) then burst.next_position_save = nil; save_settings(); end
end

--------------------------------------------------------------------------------------------------
-- Dashboard tabs
--------------------------------------------------------------------------------------------------

local function combo_value(label, current, values, labels)
    local index = 0;
    for i, value in ipairs(values) do if (value == current) then index = i - 1; break; end end
    local selected = { index };
    if (imgui.Combo(label, selected, table.concat(labels or values, '\000') .. '\000\000')) then
        return values[selected[1] + 1] or values[1], true;
    end
    return current, false;
end

local function render_coach_tab()
    update_recommendation();
    imgui.TextColored(burst.theme.brass_hover, 'Magic Burst Coach');
    imgui.TextColored(burst.theme.text_muted, 'Observe the confirmed chain, check what is actually usable, then give one manual action.');
    imgui.Separator();
    local chain, rec = burst.current_chain, burst.recommendation;
    if (chain == nil) then
        imgui.TextColored(burst.theme.text_muted, 'Waiting for a confirmed skillchain on ' .. (burst.settings.advisor.target_policy == 'current' and 'your current target.' or 'a loaded target.'));
    else
        imgui.TextColored(burst.theme.brass_hover, tostring(chain.property):upper() .. ' — ' .. tostring(chain.target_name));
        imgui.Text('Burst elements: ' .. table.concat(chain.elements or {}, ' / '));
        imgui.Text(string.format('Window: %.1fs remaining', math.max(0, chain.expires_at - os.clock())));
        imgui.Separator();
        if (rec.status == 'success') then
            imgui.TextColored(burst.theme.success, 'MAGIC BURST CONFIRMED — ' .. tostring(chain.success_spell));
            if ((tonumber(chain.success_damage) or 0) > 0) then imgui.Text('Damage: ' .. tostring(chain.success_damage)); end
        elseif (rec.best ~= nil) then
            imgui.TextColored(element_colors[rec.best.element] or burst.theme.important, 'CAST ' .. rec.best.name:upper());
            imgui.Text(string.format('Estimated landing: %.2fs   Latest safe start: %.2fs', rec.best.cast_time, rec.best.latest_start));
            imgui.Text(string.format('MP: %d   Family: %s', rec.best.mp, rec.best.family));
            if (#rec.alternates > 0) then
                local alternatives = {};
                for _, value in ipairs(rec.alternates) do if (value ~= nil) then table.insert(alternatives, value.name); end end
                imgui.TextColored(burst.theme.text_muted, 'Alternates: ' .. table.concat(alternatives, ' · '));
            end
        else
            imgui.TextColored(burst.theme.danger, tostring(rec.reason or 'NO VALID SPELL'));
            if (rec.rejected and rec.rejected[1]) then imgui.TextColored(burst.theme.text_muted, rec.rejected[1].name .. ': ' .. tostring(rec.rejected[1].reason)); end
        end
    end
    imgui.Spacing(); imgui.Separator();
    if (imgui.Button('Test Fragmentation')) then run_preview('ready'); end
    imgui.SameLine(); if (imgui.Button('Test Blocked')) then run_preview('blocked'); end
    imgui.SameLine(); if (imgui.Button('Test Success')) then run_preview('success'); end
    imgui.Separator();
    imgui.TextColored(burst.theme.brass_hover, 'Recent Combat Recognition');
    imgui.BeginChild('burst_recent_events', { 0, 190 * get_ui_scale() }, ImGuiChildFlags_Borders);
    if (#burst.tracker.recent == 0) then imgui.TextColored(burst.theme.text_muted, 'No recognized skillchain events this session.'); end
    for _, event in ipairs(burst.tracker.recent) do
        if (event.type == 'skillchain') then
            imgui.TextColored(burst.theme.important, string.format('%s — %s', event.chain.property, event.chain.target_name));
        elseif (event.type == 'magic_burst') then
            imgui.TextColored(burst.theme.success, 'MAGIC BURST — ' .. tostring(event.chain.success_spell));
        elseif (event.step ~= nil) then
            imgui.TextColored(burst.theme.text_muted, tostring(event.step.name) .. ' → ' .. tostring(event.step.target_name));
        end
    end
    imgui.EndChild();
end

local function render_assist_tab()
    local cfg = burst.settings.assist;
    imgui.TextColored(burst.theme.brass_hover, 'Optional Skillchain Assist');
    imgui.TextColored(burst.theme.text_muted, 'Plans and coaches only. It never uses a weaponskill, changes equipment, targets, or sends party chat.');
    imgui.Separator();
    local mode_values = { 'Off', 'Planner', 'Coach', 'Adaptive Coach' };
    local new_mode, mode_changed = combo_value('Operating Mode##burst_assist_mode', cfg.mode, mode_values);
    if (mode_changed) then cfg.mode = new_mode; save_settings(); end
    local mage_values = { 'Me', 'Named Party Member', 'Generic Mage Profile' };
    local mage_mode, mage_changed = combo_value('Mage##burst_assist_mage', cfg.mage_mode, mage_values);
    if (mage_changed) then cfg.mage_mode = mage_mode; save_settings(); end
    if (cfg.mage_mode ~= 'Me') then
        local mage_buffer = { tostring(cfg.mage_name or '') };
        if (imgui.InputText('Mage Name / Profile##burst_assist_mage_name', mage_buffer, 64)) then cfg.mage_name = mage_buffer[1]; save_settings(); end
    end
    local goal_values = { 'Auto', 'Preferred Spell', 'Preferred Element', 'Specific Skillchain', 'Light / Darkness', 'Fastest Two-Step' };
    local new_goal, changed = combo_value('Goal##burst_assist_goal', cfg.goal, goal_values);
    if (changed) then cfg.goal = new_goal; save_settings(); end
    if (cfg.goal == 'Preferred Spell') then
        local spell_buffer = { tostring(cfg.preferred_spell or '') };
        if (imgui.InputText('Mage Preferred Spell##burst_assist_spell', spell_buffer, 64)) then cfg.preferred_spell = spell_buffer[1]; save_settings(); end
        local preferred = spell_catalog.by_name[tostring(cfg.preferred_spell or ''):lower()];
        imgui.TextColored(burst.theme.text_muted, preferred and ('Resolved burst element: ' .. preferred.element) or 'Spell is not in the advisor catalog yet.');
    elseif (cfg.goal == 'Preferred Element') then
        local values = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' };
        local value, did = combo_value('Mage Element##burst_assist_element', cfg.preferred_element, values);
        if (did) then cfg.preferred_element = value; save_settings(); end
    elseif (cfg.goal == 'Specific Skillchain') then
        local values = { 'Light', 'Darkness', 'Fragmentation', 'Distortion', 'Fusion', 'Gravitation', 'Liquefaction', 'Induration', 'Detonation', 'Scission', 'Impaction', 'Reverberation', 'Transfixion', 'Compression' };
        local value, did = combo_value('Desired Result##burst_assist_result', cfg.specific_skillchain, values);
        if (did) then cfg.specific_skillchain = value; save_settings(); end
    end
    local enabled = cfg.use_local == true;
    if (imgui.Checkbox('Use my learned weaponskills automatically', { enabled })) then cfg.use_local = not enabled; save_settings(); end
    local same = cfg.allow_same_player == true;
    if (imgui.Checkbox('Allow one player to perform both steps', { same })) then cfg.allow_same_player = not same; save_settings(); end
    local go_delay = { tonumber(cfg.go_delay) or 2.0 };
    if (imgui.SliderFloat('Closer GO Delay', go_delay, 0.0, 4.0, '%.1f sec')) then cfg.go_delay = go_delay[1]; save_settings(); end
    local close_window = { tonumber(cfg.close_window) or 6.0 };
    if (imgui.SliderFloat('Coach Window', close_window, 4.0, 10.0, '%.1f sec')) then cfg.close_window = close_window[1]; save_settings(); end
    imgui.TextColored(burst.theme.text_muted, 'Local availability is exact. Other players use the weaponskills you confirm below.');

    imgui.Separator(); imgui.TextColored(burst.theme.brass_hover, 'Party Profiles');
    for slot = 1, 3 do
        local profile = cfg.participants[slot];
        local on = profile.enabled == true;
        if (imgui.Checkbox('##burst_participant_' .. slot, { on })) then profile.enabled = not on; save_settings(); end
        imgui.SameLine();
        local name_buffer = { tostring(profile.name or '') };
        imgui.SetNextItemWidth(160 * get_ui_scale());
        if (imgui.InputText('Name##burst_participant_name_' .. slot, name_buffer, 64)) then profile.name = name_buffer[1]; save_settings(); end
        imgui.SameLine();
        local ws_buffer = { tostring(profile.weaponskills or '') };
        imgui.SetNextItemWidth(460 * get_ui_scale());
        if (imgui.InputText('Weaponskills##burst_participant_ws_' .. slot, ws_buffer, 2048)) then profile.weaponskills = ws_buffer[1]; save_settings(); end
    end
    imgui.TextColored(burst.theme.text_muted, 'Separate weaponskills with commas, for example: Savage Blade, Chant du Cygne, Black Halo');
    imgui.Separator();
    if (imgui.Button('Build Best Plans')) then
        burst.plans = planner.build(skills, player_state, cfg, spell_catalog);
        burst.selected_plan = 1;
        save_settings();
    end
    imgui.SameLine();
    if (imgui.Button('Cancel Active Plan')) then burst.active_plan = nil; end

    imgui.BeginChild('burst_plan_list', { 0, 225 * get_ui_scale() }, ImGuiChildFlags_Borders);
    if (#burst.plans == 0) then imgui.TextColored(burst.theme.text_muted, 'Build plans to see exact two-step routes for the selected mage goal.'); end
    for index, plan in ipairs(burst.plans) do
        local label = string.format('Lv.%d %s  |  %s: %s  →  %s: %s  [%s]##burst_plan_%d',
            plan.level, plan.result, plan.opener_owner, plan.opener, plan.closer_owner, plan.closer, plan.confidence, index);
        if (imgui.Selectable(label, burst.selected_plan == index)) then burst.selected_plan = index; end
    end
    imgui.EndChild();
    local selected = burst.plans[burst.selected_plan];
    if (selected ~= nil) then
        imgui.TextColored(burst.theme.brass_hover, 'Burst: ' .. table.concat(selected.elements, ' / '));
        imgui.SameLine();
        if (imgui.Button('Activate Coach')) then
            burst.active_plan = planner.activate(selected);
            if (cfg.mode == 'Off' or cfg.mode == 'Planner') then cfg.mode = 'Coach'; save_settings(); end
        end
    end
    if (burst.active_plan ~= nil) then imgui.TextColored(burst.theme.success, 'Active: ' .. tostring(burst.active_plan.message)); end
end

local function render_advisor_options()
    local cfg = burst.settings.advisor;
    imgui.TextColored(burst.theme.brass_hover, 'Advisor Behavior');
    local profiles = burst.settings.profiles_enabled == true;
    if (imgui.Checkbox('Per-Character / Main-Job Advisor Profiles', { profiles })) then
        burst.settings.profiles_enabled = not profiles;
        burst.profile_key = nil;
        if (burst.settings.profiles_enabled) then sync_profile(); else save_settings(); end
    end
    imgui.TextColored(burst.theme.text_muted, 'Active profile: ' .. tostring(burst.profile_key or 'waiting for player data'));
    local enabled = burst.settings.enabled == true;
    if (imgui.Checkbox('Enable Burst Coach', { enabled })) then burst.settings.enabled = not enabled; save_settings(); end
    local values, labels = { 'current', 'any' }, { 'Current Target Only', 'Most Recent Loaded Target' };
    local value, changed = combo_value('Target Policy##burst_target_policy', cfg.target_policy, values, labels);
    if (changed) then cfg.target_policy = value; save_settings(); end
    local element, did = combo_value('Preferred Element##burst_preferred_element', cfg.preferred_element, spell_catalog.elements);
    if (did) then cfg.preferred_element = element; save_settings(); end
    local family, did_family = combo_value('Preferred Spell Family##burst_preferred_family', cfg.preferred_family, spell_catalog.families);
    if (did_family) then cfg.preferred_family = family; save_settings(); end
    local reserve = { tonumber(cfg.mp_reserve) or 100 };
    if (imgui.SliderInt('MP Reserve', reserve, 0, 1000, '%d MP')) then cfg.mp_reserve = reserve[1]; save_settings(); end
    local range = { tonumber(cfg.max_range) or 21.0 };
    if (imgui.SliderFloat('Maximum Range', range, 5.0, 25.0, '%.1f yalms')) then cfg.max_range = range[1]; save_settings(); end
    imgui.Separator();
    imgui.TextColored(burst.theme.text_muted, 'Every recommendation must still pass learned spell, job level, BLU set, MP, recast, target, range, status, and landing-time checks.');
end

local function render_timing_options()
    local cfg = burst.settings.timing;
    imgui.TextColored(burst.theme.brass_hover, 'Timing and Cast Calibration');
    local window = { tonumber(cfg.burst_window) or 10.0 };
    if (imgui.SliderFloat('Burst Window', window, 7.0, 12.0, '%.1f sec')) then cfg.burst_window = window[1]; save_settings(); end
    local fc = { tonumber(cfg.fast_cast) or 50.0 };
    if (imgui.SliderFloat('Fast Cast Estimate', fc, 0, 80, '%.0f%%')) then cfg.fast_cast = fc[1]; save_settings(); end
    local latency = { tonumber(cfg.latency) or 0.20 };
    if (imgui.SliderFloat('Latency Allowance', latency, 0, 1.5, '%.2f sec')) then cfg.latency = latency[1]; save_settings(); end
    local safety = { tonumber(cfg.safety_margin) or 0.60 };
    if (imgui.SliderFloat('Safety Margin', safety, 0.1, 2.0, '%.2f sec')) then cfg.safety_margin = safety[1]; save_settings(); end
    local linger = { tonumber(cfg.post_window_linger) or 0.50 };
    if (imgui.SliderFloat('Post-Window Linger', linger, 0.0, 2.0, '%.2f sec')) then cfg.post_window_linger = linger[1]; save_settings(); end
    imgui.Separator();
    imgui.TextColored(burst.theme.text_muted, 'Retail resource cast times are read as CastTime / 4. Fast Cast, latency, and this safety margin are then applied before ranking.');
    imgui.TextColored(burst.theme.text_muted, 'Post-Window Linger controls how briefly WINDOW CLOSED remains visible after the timer reaches zero.');
end

local function filtered_spells()
    local result = {};
    local search = tostring(burst.spell_search[1] or ''):lower();
    local filter_index = tonumber(burst.spell_element_filter[1]) or 0;
    local element = filter_index == 0 and nil or spell_catalog.elements[filter_index + 1];
    for _, entry in ipairs(spell_catalog.entries) do
        if ((search == '' or entry.name:lower():find(search, 1, true) or entry.family:lower():find(search, 1, true)) and
            (element == nil or entry.element == element)) then table.insert(result, entry); end
    end
    return result;
end

local function render_spell_options()
    local disabled = burst.settings.advisor.disabled_spells;
    imgui.TextColored(burst.theme.brass_hover, 'Spell Catalog');
    imgui.TextColored(burst.theme.text_muted, 'Search, inspect, and disable individual recommendations without editing Lua.');
    imgui.InputText('Search Spells', burst.spell_search, 255);
    local labels = table.concat(spell_catalog.elements, '\000') .. '\000\000';
    imgui.Combo('Element Filter', burst.spell_element_filter, labels);
    local list = filtered_spells();
    imgui.BeginChild('burst_spell_list', { 390 * get_ui_scale(), 360 * get_ui_scale() }, ImGuiChildFlags_Borders);
    for _, entry in ipairs(list) do
        local prefix = disabled[entry.name] and '[OFF] ' or '[ON]  ';
        if (imgui.Selectable(prefix .. entry.name .. '##burst_spell_' .. entry.name, burst.selected_spell == entry.name)) then burst.selected_spell = entry.name; end
    end
    imgui.EndChild(); imgui.SameLine();
    imgui.BeginChild('burst_spell_detail', { 0, 360 * get_ui_scale() }, ImGuiChildFlags_Borders);
    local entry = burst.selected_spell and spell_catalog.by_name[burst.selected_spell:lower()] or nil;
    if (entry == nil) then
        imgui.TextColored(burst.theme.text_muted, 'Select a spell.');
    else
        imgui.TextColored(element_colors[entry.element] or burst.theme.important, entry.name);
        imgui.Text('Element: ' .. entry.element);
        imgui.Text('Family: ' .. entry.family);
        imgui.Text('Advisor power rank: ' .. tostring(entry.score));
        local off = disabled[entry.name] == true;
        if (imgui.Checkbox('Disable this recommendation', { off })) then disabled[entry.name] = not off and true or nil; save_settings(); end
        local spell = player_state.find_spell(entry.name);
        imgui.TextColored(burst.theme.text_muted, spell and string.format('Retail resource ID: %d  MP: %d  Base cast: %.2fs', spell.Id, spell.ManaCost, spell.CastTime / 4.0)
            or 'Not present in currently loaded retail resources.');
    end
    imgui.EndChild();
    if (imgui.Button('Enable Visible')) then for _, item in ipairs(list) do disabled[item.name] = nil; end save_settings(); end
    imgui.SameLine();
    if (imgui.Button('Disable Visible')) then for _, item in ipairs(list) do disabled[item.name] = true; end save_settings(); end
    imgui.SameLine();
    if (imgui.Button('Reset All Spell Choices')) then burst.settings.advisor.disabled_spells = T{}; save_settings(); end
end

local function render_appearance_options()
    local cfg, ui = burst.settings.overlay, burst.settings.ui;
    imgui.TextColored(burst.theme.brass_hover, 'Vana\'diel Tactical Interface');
    imgui.TextColored(burst.theme.text_muted, 'The burst card, screen-edge cue, launcher, scaling, and controller behavior follow Warn 2.2.0.');
    imgui.Separator();
    local preset_values = { 'auto', '1440p', '1080p', 'custom' };
    local preset_labels = { 'Auto (Display Height)', '1440p Baseline', '1080p Baseline', 'Custom' };
    local preset, changed = combo_value('Interface Scale##burst_scale', ui.scale_preset, preset_values, preset_labels);
    if (changed) then ui.scale_preset = preset; burst.gui_size_initialized = false; save_settings(); end
    if (ui.scale_preset == 'custom') then
        local custom = { tonumber(ui.custom_scale) or 1.0 };
        if (imgui.SliderFloat('Custom Interface Scale', custom, 0.60, 1.75, '%.2f')) then ui.custom_scale = custom[1]; burst.gui_size_initialized = false; save_settings(); end
    end
    imgui.TextColored(burst.theme.text_muted, string.format('Resolved scale: %.2fx', get_ui_scale()));
    local themes = ui_theme.list(addon.path);
    local selected_theme, theme_changed = combo_value('Theme##burst_theme', ui.theme, themes);
    if (theme_changed) then ui.theme = selected_theme; reload_theme(); save_settings(); end
    imgui.SameLine(); if (imgui.Button('Reload Theme')) then reload_theme(); end
    imgui.TextColored(burst.theme.text_muted, 'Data-only overrides: Ashita/config/addons/burst/themes/<name>/theme.txt');

    imgui.Separator(); imgui.TextColored(burst.theme.brass_hover, 'Launcher');
    local launcher = ui.launcher_enabled == true;
    if (imgui.Checkbox('Show Draggable B Launcher', { launcher })) then ui.launcher_enabled = not launcher; save_settings(); end
    local launcher_size = { tonumber(ui.launcher_size) or 58 };
    if (imgui.SliderFloat('Launcher Size', launcher_size, 36, 96, '%.0f px')) then ui.launcher_size = launcher_size[1]; save_settings(); end
    if (imgui.Button('Reset Launcher Position')) then ui.launcher_position_x = -1; ui.launcher_position_y = -1; burst.ui.launcher_initialized = false; save_settings(); end
    imgui.TextColored(burst.theme.text_muted, 'Click to open Burst. Drag normally to reposition it.');

    imgui.Separator(); imgui.TextColored(burst.theme.brass_hover, 'Live Burst Card');
    if (imgui.Button(burst.preview_visible and 'Hide Positioning Preview' or 'Show Positioning Preview')) then
        burst.preview_visible = not burst.preview_visible;
        if (burst.preview_visible) then run_preview('ready'); end
    end
    imgui.SameLine();
    if (imgui.Button('Reset Card Position')) then
        local display = imgui.GetIO().DisplaySize;
        cfg.position_x = math.floor((display.x - 620 * get_ui_scale()) / 2);
        cfg.position_y = math.floor(display.y * 0.22);
        burst.preview_visible = true; run_preview('ready'); save_settings();
    end
    imgui.TextColored(burst.theme.text_muted, 'The draggable preview closes when you leave Appearance.');
    local opacity = { tonumber(cfg.card_opacity) or 0.88 };
    if (imgui.SliderFloat('Burst Card Opacity', opacity, 0, 1, '%.2f')) then cfg.card_opacity = opacity[1]; save_settings(); end
    local card_scale = { tonumber(cfg.card_scale) or 1.0 };
    if (imgui.SliderFloat('Burst Card Scale', card_scale, 0.70, 1.40, '%.2f')) then cfg.card_scale = card_scale[1]; save_settings(); end
    local edges = cfg.edge_enabled == true;
    if (imgui.Checkbox('Enable Element-Colored Screen Edges', { edges })) then cfg.edge_enabled = not edges; save_settings(); end
    if (cfg.edge_enabled) then
        local intensity = { tonumber(cfg.edge_intensity) or 0.72 };
        if (imgui.SliderFloat('Edge Intensity', intensity, 0, 1, '%.2f')) then cfg.edge_intensity = intensity[1]; save_settings(); end
        if (imgui.Button('Test Edge Cue')) then burst.preview_visible = true; run_preview('ready'); end
        imgui.SameLine(); imgui.TextColored(burst.theme.text_muted, 'Shows a confirmed Fragmentation cue.');
    end
    local motion = cfg.reduced_motion == true;
    if (imgui.Checkbox('Reduced Motion', { motion })) then cfg.reduced_motion = not motion; save_settings(); end
    local alternates = cfg.show_alternates == true;
    if (imgui.Checkbox('Show Up To Two Alternates', { alternates })) then cfg.show_alternates = not alternates; save_settings(); end
    local pos = { math.floor(tonumber(cfg.position_x) or 480), math.floor(tonumber(cfg.position_y) or 260) };
    if (imgui.InputInt2('X / Y##burst_card_position', pos)) then cfg.position_x = pos[1]; cfg.position_y = pos[2]; save_settings(); end

    imgui.Separator(); imgui.TextColored(burst.theme.brass_hover, 'Controller Navigation');
    local controller = ui.controller_enabled == true;
    if (imgui.Checkbox('Enable Controller Navigation', { controller })) then ui.controller_enabled = not controller; save_settings(); end
    local layouts = { 'xinput', 'playstation', 'switch' };
    local labels = { 'Xbox / XInput', 'PlayStation / DirectInput', 'Switch Pro / DirectInput' };
    local layout, layout_changed = combo_value('Controller Layout##burst_controller', ui.controller_layout, layouts, labels);
    if (layout_changed) then ui.controller_layout = layout; save_settings(); end
end

local function render_sound_options()
    local cfg = burst.settings.sound;
    imgui.TextColored(burst.theme.brass_hover, 'Sound');
    local enabled = cfg.enabled == true;
    if (imgui.Checkbox('Enable Sounds', { enabled })) then cfg.enabled = not enabled; save_settings(); end
    if (imgui.Button('Refresh Sounds')) then refresh_sounds(true); end
    imgui.TextColored(burst.theme.text_muted, 'Drop standard WAV files into burst\\sounds, then refresh.');
    local values = {};
    for _, name in ipairs(burst.sound_files) do table.insert(values, name); end
    local opened, changed = combo_value('Burst Window Open##burst_sound_open', cfg.burst_open, values);
    if (changed) then cfg.burst_open = opened; save_settings(); end
    imgui.SameLine(); if (imgui.Button('Test##burst_test_open_sound')) then play_sound(cfg.burst_open); end
    local success, success_changed = combo_value('Magic Burst Confirmed##burst_sound_success', cfg.burst_success, values);
    if (success_changed) then cfg.burst_success = success; save_settings(); end
    imgui.SameLine(); if (imgui.Button('Test##burst_test_success_sound')) then play_sound(cfg.burst_success); end
end

local function diagnostics_results()
    local failures = {};
    local checks = 0;
    local function check(condition, label) checks = checks + 1; if (not condition) then table.insert(failures, label); end end
    local result = select(1, skillchains.resolve({ 'Fragmentation' }, { 'Fusion' }));
    check(result == 'Light', 'Fragmentation + Fusion should create Light');
    result = select(1, skillchains.resolve({ 'Distortion' }, { 'Gravitation' }));
    check(result == 'Darkness', 'Distortion + Gravitation should create Darkness');
    check(skillchains.from_additional_effect({ message = 291, damage = 4 }) == 'Fragmentation', 'Additional-effect property decode');
    check(skillchains.from_additional_effect({ message = 1, damage = 4 }) == nil, 'Reject non-skillchain additional effect');
    check(table.concat(skillchains.elements('Light'), ',') == 'Fire,Wind,Lightning,Light', 'Light burst-element list');
    check(#spell_catalog.entries >= 100, 'Spell catalog size');
    check(spell_catalog.by_name['thunder v'] ~= nil, 'Thunder V catalog entry');
    return checks, failures;
end

local function render_diagnostics_options()
    local stats = burst.tracker.stats;
    imgui.TextColored(burst.theme.brass_hover, 'Diagnostics');
    imgui.Text(string.format('Player: %s  —  %s', player_state.character_name(), player_state.job_text()));
    local target = player_state.current_target();
    imgui.Text(target and string.format('Target: %s  ID %u  %.1f yalms  %d%% HP', target.name, target.id, target.distance, target.hpp)
        or 'Target: none');
    imgui.Separator();
    imgui.Text(string.format('0x028 parsed: %d   duplicates: %d   parse errors: %d', stats.parsed, stats.duplicates, stats.parse_errors));
    imgui.Text(string.format('Actors ignored outside alliance/pets: %d', stats.ignored_actors or 0));
    imgui.Text(string.format('Actions examined: %d   confirmed chains: %d   confirmed bursts: %d', stats.actions, stats.chains, stats.bursts));
    imgui.Text('Last layout: ' .. tostring(burst.tracker.last_layout));
    imgui.TextWrapped('Last event: ' .. tostring(burst.tracker.last_event));
    imgui.Separator();
    local layout_values = { 'auto', 'retail', 'legacy' };
    local layout_labels = { 'Auto Detect', 'Retail / XiPackets', 'SimpleLog / DSP Legacy' };
    local layout, changed = combo_value('Action Packet Layout##burst_packet_layout', burst.settings.packet.layout, layout_values, layout_labels);
    if (changed) then burst.settings.packet.layout = layout; save_settings(); end
    if (imgui.Button('Run Synthetic Self-Tests')) then
        local count, failures = diagnostics_results();
        if (#failures == 0) then
            burst.tracker.last_event = string.format('All %d synthetic tests passed.', count);
            print(chat.header(addon.name):append(chat.message(burst.tracker.last_event)));
        else
            burst.tracker.last_event = string.format('%d/%d synthetic tests failed: %s', #failures, count, table.concat(failures, '; '));
            print(chat.header(addon.name):append(chat.error(burst.tracker.last_event)));
        end
    end
    imgui.SameLine(); if (imgui.Button('Clear Runtime State')) then burst.tracker:clear('Runtime state cleared from Diagnostics.'); burst.active_plan = nil; end
    local debug = burst.debug == true;
    if (imgui.Checkbox('Verbose Debug Chat', { debug })) then burst.debug = not debug; end
    imgui.Separator();
    imgui.TextColored(burst.theme.success, 'Automation boundary: PASSIVE / ADVICE ONLY');
    imgui.TextWrapped('No outgoing packet handler, command injection, /ma execution, target change, equipment change, action queue, retry, or scheduled combat action exists in this addon.');
end

local function render_options_tab()
    local sections = {
        { 'Advisor', render_advisor_options }, { 'Timing', render_timing_options },
        { 'Spells', render_spell_options }, { 'Appearance', render_appearance_options },
        { 'Sound', render_sound_options }, { 'Diagnostics', render_diagnostics_options },
    };
    imgui.BeginChild('burst_options_nav', { 175 * get_ui_scale(), 0 }, ImGuiChildFlags_Borders);
    imgui.TextColored(burst.theme.brass_hover, 'Options'); imgui.Separator();
    for index, section in ipairs(sections) do
        if (imgui.Selectable(section[1] .. '##burst_option_' .. index, burst.options_section[1] == index)) then
            burst.options_section[1] = index;
            if (index ~= 4) then burst.preview_visible = false; end
        end
    end
    imgui.EndChild(); imgui.SameLine();
    imgui.BeginChild('burst_options_content', { 0, 0 }, ImGuiChildFlags_Borders);
    (sections[burst.options_section[1]] or sections[1])[2]();
    imgui.EndChild();
end

--------------------------------------------------------------------------------------------------
-- Launcher and main window
--------------------------------------------------------------------------------------------------

local function render_launcher()
    local ui = burst.settings.ui;
    if (ui.launcher_enabled ~= true) then return; end
    local scale = get_ui_scale();
    local size = math.max(36, math.min(96, tonumber(ui.launcher_size) or 58)) * scale;
    local display = imgui.GetIO().DisplaySize;
    if (not burst.ui.launcher_initialized) then
        if ((tonumber(ui.launcher_position_x) or -1) < 0 or (tonumber(ui.launcher_position_y) or -1) < 0) then
            ui.launcher_position_x = 102 * scale;
            ui.launcher_position_y = math.max(20, display.y - size - 54 * scale);
        end
        burst.ui.launcher_initialized = true;
    end
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_NoMove);
    imgui.SetNextWindowPos({ ui.launcher_position_x, ui.launcher_position_y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ size, size }, ImGuiCond_Always);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    if (imgui.Begin('##burst_launcher', true, flags)) then
        local x, y = imgui.GetCursorScreenPos();
        local draw = imgui.GetWindowDrawList();
        draw:AddCircleFilled({ x + size / 2, y + size / 2 }, size * 0.46, imgui.GetColorU32(burst.theme.panel_bg), 48);
        draw:AddCircle({ x + size / 2, y + size / 2 }, size * 0.43, imgui.GetColorU32(burst.theme.brass), 48, math.max(2, scale * 2));
        draw:AddText({ x + size * 0.30, y + size * 0.22 }, imgui.GetColorU32(burst.theme.brass_hover), 'B');
        imgui.InvisibleButton('##burst_launcher_control', { size, size });
        if (imgui.IsItemClicked(0)) then burst.ui.launcher_press = true; burst.ui.launcher_dragged = false; burst.ui.launcher_mouse_x, burst.ui.launcher_mouse_y = imgui.GetMousePos(); end
        if (burst.ui.launcher_press and imgui.IsMouseDown(0)) then
            local mx, my = imgui.GetMousePos();
            if (imgui.IsMouseDragging(0, 3)) then
                burst.ui.launcher_dragged = true;
                ui.launcher_position_x = math.max(0, math.min(display.x - size, ui.launcher_position_x + mx - burst.ui.launcher_mouse_x));
                ui.launcher_position_y = math.max(0, math.min(display.y - size, ui.launcher_position_y + my - burst.ui.launcher_mouse_y));
                burst.ui.next_launcher_save = os.clock() + 0.35;
            end
            burst.ui.launcher_mouse_x, burst.ui.launcher_mouse_y = mx, my;
        elseif (burst.ui.launcher_press and imgui.IsMouseReleased(0)) then
            if (not burst.ui.launcher_dragged) then burst.is_gui_open[1] = not burst.is_gui_open[1]; if (burst.is_gui_open[1]) then refresh_sounds(false); end end
            burst.ui.launcher_press = false; burst.ui.launcher_dragged = false;
        elseif (not imgui.IsMouseDown(0)) then burst.ui.launcher_press = false; burst.ui.launcher_dragged = false; end
    end
    imgui.End(); imgui.PopStyleVar();
    if (burst.ui.next_launcher_save ~= nil and os.clock() >= burst.ui.next_launcher_save) then burst.ui.next_launcher_save = nil; save_settings(); end
end

local function render_config_window()
    if (not burst.is_gui_open[1]) then return; end
    local scale = get_ui_scale();
    if (not burst.gui_size_initialized) then imgui.SetNextWindowSize({ 1160 * scale, 820 * scale }); burst.gui_size_initialized = true; end
    imgui.SetNextWindowSizeConstraints({ 720 * scale, 600 * scale }, { FLT_MAX, FLT_MAX });
    ui_theme.push(burst.theme, scale);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse);
    if (imgui.Begin('BURST##burst_dashboard', burst.is_gui_open, flags)) then
        local wx, wy = imgui.GetWindowPos(); local ww, wh = imgui.GetWindowSize(); local draw = imgui.GetWindowDrawList();
        draw:AddRect({ wx, wy }, { wx + ww, wy + wh }, imgui.GetColorU32(burst.theme.brass), burst.theme.rounding * scale, 0, math.max(1, burst.theme.border_size * scale));
        draw:AddLine({ wx + 7 * scale, wy + 17 * scale }, { wx + 7 * scale, wy + 7 * scale }, imgui.GetColorU32(burst.theme.brass_dim), 2 * scale);
        draw:AddLine({ wx + 7 * scale, wy + 7 * scale }, { wx + 17 * scale, wy + 7 * scale }, imgui.GetColorU32(burst.theme.brass_dim), 2 * scale);
        set_ui_font_scale(1.28 * scale); imgui.TextColored(burst.theme.brass_hover, 'BURST'); set_ui_font_scale(1.0);
        imgui.TextColored(burst.theme.text_muted, 'VANA\'DIEL TACTICAL MAGIC-BURST ADVISOR');
        imgui.SameLine(); imgui.SetCursorPosX(math.max(imgui.GetCursorPosX(), ww - 45 * scale));
        if (imgui.Button('X##burst_close', { 28 * scale, 28 * scale })) then burst.is_gui_open[1] = false; burst.preview_visible = false; end
        imgui.Separator();
        local tabs = { 'BURST COACH', 'SKILLCHAIN ASSIST', 'OPTIONS' };
        for index, label in ipairs(tabs) do
            if (index > 1) then imgui.SameLine(); end
            if (burst.main_tab[1] == index) then imgui.PushStyleColor(ImGuiCol_Button, burst.theme.selected); end
            if (imgui.Button(label .. '##burst_tab_' .. index, { 195 * scale, 34 * scale })) then burst.main_tab[1] = index; if (index ~= 3 or burst.options_section[1] ~= 4) then burst.preview_visible = false; end end
            if (burst.main_tab[1] == index) then imgui.PopStyleColor(); end
        end
        imgui.Separator();
        imgui.BeginChild('burst_main_content', { 0, -28 * scale }, 0);
        if (burst.main_tab[1] == 1) then render_coach_tab(); elseif (burst.main_tab[1] == 2) then render_assist_tab(); else render_options_tab(); end
        imgui.EndChild(); imgui.Separator();
        imgui.TextColored(burst.theme.text_muted, burst.settings.ui.controller_enabled and 'Controller: LB/RB tabs   D-pad navigate   B/Circle close   •   Advice only'
            or 'Tip: click the B launcher to reopen Burst, or drag it to reposition it.');
    end
    imgui.End(); ui_theme.pop();
end

--------------------------------------------------------------------------------------------------
-- Controller and events
--------------------------------------------------------------------------------------------------

local function handle_controller(action)
    if (not burst.is_gui_open[1] or burst.settings.ui.controller_enabled ~= true) then return false; end
    if (action == 'tab_left') then burst.main_tab[1] = ((burst.main_tab[1] - 2) % 3) + 1;
    elseif (action == 'tab_right') then burst.main_tab[1] = (burst.main_tab[1] % 3) + 1;
    elseif (action == 'up' or action == 'down') and burst.main_tab[1] == 3 then
        local delta = action == 'up' and -1 or 1; burst.options_section[1] = ((burst.options_section[1] - 1 + delta) % 6) + 1;
    elseif (action == 'close') then burst.is_gui_open[1] = false; burst.preview_visible = false;
    else return false; end
    return true;
end

ashita.events.register('load', 'burst_load_cb', function ()
    burst.settings = settings.load(default_settings, 'burst_settings');
    ensure_settings(); sync_profile(); reload_theme(); refresh_sounds(false);
    settings.register('burst_settings', 'burst_settings_update_cb', function (new_settings)
        if (new_settings ~= nil) then burst.settings = new_settings; burst.profile_key = nil; ensure_settings(); sync_profile(); reload_theme(); end
    end);
    local checks, failures = diagnostics_results();
    print(chat.header(addon.name):append(chat.message(string.format('Loaded v%s — %d startup checks, %d failure(s). Advice only.', addon.version, checks, #failures))));
end);

ashita.events.register('unload', 'burst_unload_cb', function () save_settings(); end);

ashita.events.register('packet_in', 'burst_packet_in_cb', function (e)
    if (burst.settings == nil) then return; end
    if (e.id == 0x28) then process_action_packet(e);
    elseif (e.id == 0x0A or e.id == 0x0B) then burst.tracker:clear('Zone transition cleared combat state.'); burst.active_plan = nil; end
end);

ashita.events.register('command', 'burst_command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/burst')) then return; end
    e.blocked = true;
    if (#args == 1) then burst.is_gui_open[1] = not burst.is_gui_open[1]; if (burst.is_gui_open[1]) then refresh_sounds(false); end return; end
    local sub = tostring(args[2]):lower();
    if (sub == 'on') then burst.settings.enabled = true; save_settings(); print(chat.header(addon.name):append(chat.message('Burst Coach enabled.')));
    elseif (sub == 'off') then burst.settings.enabled = false; save_settings(); print(chat.header(addon.name):append(chat.warning('Burst Coach disabled.')));
    elseif (sub == 'test') then run_preview('ready');
    elseif (sub == 'debug') then burst.debug = not burst.debug; print(chat.header(addon.name):append(chat.message('Debug: ' .. (burst.debug and 'on' or 'off'))));
    elseif (sub == 'plan') then burst.main_tab[1] = 2; burst.is_gui_open[1] = true;
    elseif (sub == 'clear') then burst.tracker:clear('Combat state cleared by command.'); burst.active_plan = nil;
    else print(chat.header(addon.name):append(chat.message('Usage: /burst [on|off|test|debug|plan|clear]'))); end
end);

ashita.events.register('xinput_button', 'burst_xinput_cb', function (e)
    if (e == nil or e.injected == true or tonumber(e.state) ~= 1) then return; end
    local actions = { [0] = 'up', [1] = 'down', [5] = 'close', [8] = 'tab_left', [9] = 'tab_right', [13] = 'close' };
    local action = actions[tonumber(e.button)]; if (action ~= nil and handle_controller(action)) then e.blocked = true; end
end);

ashita.events.register('dinput_button', 'burst_dinput_cb', function (e)
    if (e == nil or e.injected == true or burst.settings == nil or not burst.is_gui_open[1]) then return; end
    if (burst.settings.ui.controller_layout == 'xinput') then return; end
    local button, state, action = tonumber(e.button), tonumber(e.state), nil;
    if (button == 32) then action = ({ [0] = 'up', [18000] = 'down' })[state];
    elseif (state == 128 or state == 1) then
        if (button == 52) then action = 'tab_left'; elseif (button == 53) then action = 'tab_right';
        elseif (burst.settings.ui.controller_layout == 'playstation' and button == 50) or
               (burst.settings.ui.controller_layout == 'switch' and button == 49) then action = 'close'; end
    end
    if (action ~= nil and handle_controller(action)) then e.blocked = true; end
end);

ashita.events.register('d3d_present', 'burst_present_cb', function ()
    if (burst.settings == nil or burst.theme == nil) then return; end
    sync_profile();
    update_recommendation();
    render_overlay(); render_launcher(); render_config_window();
end);
