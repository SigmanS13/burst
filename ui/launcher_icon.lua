local ffi = require('ffi');
local imgui = require('imgui');

local M = {
    texture = nil,
    error = nil,
    render_disabled = false,
};

local function release_texture()
    if (M.texture ~= nil) then M.texture:Release(); end
    M.texture = nil;
end

function M.load(path)
    release_texture();
    M.error = nil;
    M.render_disabled = false;
    if (path == nil or tostring(path) == '') then M.error = 'Launcher artwork unavailable'; return false; end

    local ok, d3d8 = pcall(require, 'd3d8');
    if (not ok or d3d8 == nil) then M.error = 'd3d8 library unavailable'; return false; end
    local device = d3d8.get_device();
    if (device == nil) then M.error = 'Direct3D device unavailable'; return false; end

    local pointer = ffi.new('IDirect3DTexture8*[1]');
    local loaded, result = pcall(function ()
        return ffi.C.D3DXCreateTextureFromFileA(device, tostring(path), pointer);
    end);
    if (loaded and result == ffi.C.S_OK and pointer[0] ~= nil) then
        M.texture = ffi.cast('IDirect3DTexture8*', pointer[0]);
        return true;
    end
    M.error = 'Launcher artwork could not be loaded';
    return false;
end

function M.unload()
    release_texture();
end

function M.has()
    return not M.render_disabled and M.texture ~= nil;
end

function M.draw(width, height)
    if (not M.has()) then return false; end
    -- Ashita v4's ImGui binding expects the numeric Direct3D texture ID, not the
    -- LuaJIT cdata pointer wrapper. Passing the wrapper renders a solid white quad.
    local texture_id = tonumber(ffi.cast('uint32_t', M.texture));
    if (texture_id == nil or texture_id == 0) then
        M.error = 'Launcher texture handle is invalid';
        return false;
    end
    local ok = pcall(imgui.Image, texture_id, { width, height or width },
        { 0, 0 }, { 1, 1 }, { 1, 1, 1, 1 });
    if (not ok) then
        M.render_disabled = true;
        M.error = 'This Ashita ImGui build rejected the launcher texture';
        return false;
    end
    return true;
end

return M;
