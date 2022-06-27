local ffi = require "ffi"
local client = require "client"
local vtable = require "vtable"

local gui_system = client.create_interface("vgui2.dll", "VGUI_System010")
local get_clipboard_text_count = vtable.bind(gui_system, 7, "int(__thiscall*)(void*)")
local set_clipboard_text = vtable.bind(gui_system, 9, "void(__thiscall*)(void*, const char*, int)")
local get_clipboard_text = vtable.bind(gui_system, 11, "int(__thiscall*)(void*, int, const char*, int)")

local char = ffi.typeof("char[?]")

local function get()
	local count = get_clipboard_text_count()

	if count > 0 then
		local char_arr = char(count)
		get_clipboard_text(0, char_arr, count)
		return ffi.string(char_arr, count - 1)
	end
end

local function set(str)
	local text = tostring(str)
	set_clipboard_text(text, #text)
	return text
end

return {
	get = get,
	set = set,
	paste = get,
	copy = set
}
