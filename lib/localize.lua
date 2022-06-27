local vtable = require "vtable"
local client = require "client"

local char_buffer = ffi.typeof("char[?]")
local localize_interface = client.create_interface("localize.dll", "Localize_001")
local localize_find_safe = vtable.bind(localize_interface, 12, "wchar_t*(__thiscall*)(void*, const char*)")
local localize_convert_unicode_to_ansi = vtable.bind(localize_interface, 16, "int(__thiscall*)(void*, wchar_t*, char*, int)")

local function localize(str, buf_size)
    local res = localize_find_safe(str)
    local size = buf_size or 1024
    local char = char_buffer(size)
    localize_convert_unicode_to_ansi(res, char, size)
    return char ~= nil and ffi.string(char) or nil
end

return setmetatable(
    {
        localize = localize
    },
    {
        __call = function(tbl, ...)
            return localize(...)
        end
    }
)
