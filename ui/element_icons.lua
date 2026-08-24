local ffi = require('ffi');
local imgui = require('imgui');

local M = {
    textures = {},
    error = nil,
    render_disabled = false,
};

local files = {
    Wind = 'wind.png',
    Fire = 'fire.png',
    Water = 'water.png',
    Ice = 'ice.png',
    Lightning = 'lightning.png',
    Light = 'light.png',
    Dark = 'dark.png',
    Earth = 'earth.png',
};

local function release_all()
    for key, texture in pairs(M.textures) do
        if (texture ~= nil) then texture:Release(); end
        M.textures[key] = nil;
    end
end

function M.load(addon_path)
    release_all();
    M.error = nil;
    M.render_disabled = false;
    local ok, d3d8 = pcall(require, 'd3d8');
    if (not ok or d3d8 == nil) then M.error = 'd3d8 library unavailable'; return false; end
    local device = d3d8.get_device();
    if (device == nil) then M.error = 'Direct3D device unavailable'; return false; end

    for element, filename in pairs(files) do
        local pointer = ffi.new('IDirect3DTexture8*[1]');
        local path = tostring(addon_path) .. '\\assets\\elements\\' .. filename;
        local loaded, result = pcall(function ()
            return ffi.C.D3DXCreateTextureFromFileA(device, path, pointer);
        end);
        if (loaded and result == ffi.C.S_OK and pointer[0] ~= nil) then
            M.textures[element] = ffi.cast('IDirect3DTexture8*', pointer[0]);
        else
            M.error = 'One or more element textures could not be loaded.';
        end
    end
    return M.count() == 8;
end

function M.unload()
    release_all();
end

function M.count()
    local count = 0;
    for _ in pairs(M.textures) do count = count + 1; end
    return count;
end

function M.has(element)
    return not M.render_disabled and M.textures[tostring(element or '')] ~= nil;
end

function M.draw(element, size)
    if (M.render_disabled) then return false; end
    local texture = M.textures[tostring(element or '')];
    if (texture == nil) then return false; end
    local ok = pcall(imgui.Image, texture, { size, size });
    if (not ok) then
        M.render_disabled = true;
        M.error = 'This Ashita ImGui build rejected the element texture.';
        return false;
    end
    return true;
end

function M.draw_at(element, x, y, size)
    imgui.SetCursorScreenPos({ x, y });
    return M.draw(element, size);
end

return M;
