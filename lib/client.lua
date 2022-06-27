local ffi = require "ffi"
local vtable = require "vtable"

local C = ffi.C

ffi.cdef [[
    void* GetModuleHandleA(const char*);
    void* GetProcAddress(const char*, const char*);

    typedef struct {
        unsigned char r, g, b, a;
    } rgba;

    typedef struct
    {
        int64_t __pad0;
        union {
            int64_t xuid;
            struct {
                int xuidlow;
                int xuidhigh;
            };
        };
        char name[128];
        int userid;
        char guid[33];
        unsigned int friendsid;
        char friendsname[128];
        bool fakeplayer;
        bool ishltv;
        unsigned int customfiles[4];
        unsigned char filesdownloaded;
    } player_info_t;

    typedef struct {
        float x, y, z;
    } vector3;
]]

local ctype = {
    ["int[?]"] = ffi.typeof("int[?]"),
    ["float[?]"] = ffi.typeof("float[?]"),
    ["char[?]"] = ffi.typeof("char[?]"),
    ["void*"] = ffi.typeof("void*"),
    ["rgba"] = ffi.typeof("rgba"),
    ["player_info_t"] = ffi.typeof("player_info_t"),
    ["vector3"] = ffi.typeof("vector3")
}

local function assert(expression, level, message, ...)
    if (not expression) then
        local _, error_msg = pcall(error, message:format(...), level + 2)
        return client.error_log(error_msg, 3)
    end
end

local function inspect(expected, id, param)
    if type(param) ~= expected then
        return client.error_log(("bad argument #%d to '%s' (%s expected, got %s)"):format(id, debug.getinfo(2).name, expected, type(param)), 3)
    end
end

local create_interface_fn = ffi.typeof("void*(*)(const char*, int*)")
local function create_interface(module_name, interface_name)
    inspect("string", 1, module_name)
    inspect("string", 2, interface_name)

    local module_handle = C.GetModuleHandleA(module_name)
    assert(module_handle ~= nil, 2, "cannot load module '%s'", module_name)

    local proc_address = C.GetProcAddress(module_handle, "CreateInterface")
    local interface = ffi.cast(create_interface_fn, proc_address)(interface_name, nil)
    assert(interface ~= nil, 2, "cannot load interface '%s'", interface_name)

    return interface
end

local function find_signature(module_name, pattern)
    inspect("string", 1, module_name)
    inspect("string", 2, pattern)

    assert(C.GetModuleHandleA(module_name) ~= nil, 2, "cannot load module '%s'", module_name)

    local str = ""
    for i = 1, #pattern do
        str = ("%s%s\x20"):format(str, ("%02X"):format(pattern:sub(i):byte()):gsub("CC", "??"))
    end

    local o_pattern = str:sub(0, #str - 1)
    local signature = mem.FindPattern(module_name, o_pattern)
    assert(signature ~= nil, 2, "cannot load signature '%s'", o_pattern)

    return ffi.cast(ctype["void*"], signature)
end

local engine_cvar = create_interface("vstdlib.dll", "VEngineCvar007")
local engine_client = create_interface("engine.dll", "VEngineClient014")

local native = {
    console_color_print_format = vtable.bind(engine_cvar, 25, "void(*)(void*, void*, const char*, ...)"),
    console_print_format = vtable.bind(engine_cvar, 26, "void(*)(void*, const char*, ...)"),
    get_screen_size = vtable.bind(engine_client, 5, "void(__thiscall*)(void*, int*, int*)"),
    get_player_info = vtable.bind(engine_client, 8, "bool(__thiscall*)(void*, int, void*)"),
    get_player_for_userid = vtable.bind(engine_client, 9, "int(__thiscall*)(void*, int)"),
    con_is_visible = vtable.bind(engine_client, 11, "bool(__thiscall*)(void*)"),
    get_local_player = vtable.bind(engine_client, 12, "int(__thiscall*)(void*)"),
    get_view_angles = vtable.bind(engine_client, 18, "void(__thiscall*)(void*, void*)"),
    set_view_angles = vtable.bind(engine_client, 19, "void(__thiscall*)(void*, void*)"),
    get_max_clientsd = vtable.bind(engine_client, 20, "int(__thiscall*)(void*)"),
    is_in_game = vtable.bind(engine_client, 26, "bool(__thiscall*)(void*)"),
    is_connected = vtable.bind(engine_client, 27, "bool(__thiscall*)(void*)"),
    get_game_directory = vtable.bind(engine_client, 36, "const char*(__thiscall*)(void*)"),
    get_level_name = vtable.bind(engine_client, 52, "const char*(__thiscall*)(void*)"),
    get_level_name_short = vtable.bind(engine_client, 53, "const char*(__thiscall*)(void*)"),
    get_map_group_name = vtable.bind(engine_client, 54, "const char*(__thiscall*)(void*)"),
    net_channel_info = vtable.bind(engine_client, 78, "void*(__thiscall*)(void*)"),
    get_ui_language = vtable.bind(engine_client, 97, "void(__thiscall*)(void*, char*, int)"),
    execute_client_cmd = vtable.bind(engine_client, 108, "void(__thiscall*)(void*, const char*)")
}

local aimware_rgab = ctype.rgba(200, 40, 40, 255)
local function log(msg, ...)
    inspect("string", 1, msg)

    local str = ""
    for k, v in pairs({msg, ...}) do
        inspect("string", k, v)
        str = str .. v .. "\x20\x20\x20\x20"
    end

    native.console_color_print_format(aimware_rgab, "[Aimware]\x20")
    native.console_print_format("%s\n", str)
end

local function color_log(r, g, b, msg, ...)
    inspect("number", 1, r)
    inspect("number", 2, g)
    inspect("number", 3, b)
    inspect("string", 4, msg)

    local str = ""
    for k, v in pairs({msg, ...}) do
        inspect("string", 4 + k, v)
        str = str .. v .. "\x20\x20\x20\x20"
    end

    native.console_print_format(ctype.rgba(r, g, b, 255), "%s\n", str)
end

local error_rgba = ctype.rgba(255, 90, 90, 255)
local function error_log(msg, level)
    inspect("string", 1, msg)

    native.console_color_print_format(error_rgba, "%s:\x20%s\n\n", debug.getinfo(level or 2).short_src, debug.traceback(msg, level or 2))
    error()
end

local screen_size_width = ctype["int[?]"](1)
local screen_size_height = ctype["int[?]"](1)
local function screen_size()
    native.get_screen_size(screen_size_width, screen_size_height)
    return screen_size_width[0], screen_size_height[0]
end

local player_info_t = ctype.player_info_t()
local function player_info(idx)
    inspect("number", 1, idx)

    native.get_player_info(idx, player_info_t)

    local steam_id = player_info_t.xuidlow
    local name = ffi.string(player_info_t.name)
    local userid = player_info_t.userid
    local friendsid = player_info_t.friendsid
    local files_downloaded = player_info_t.filesdownloaded

    return {
        raw = player_info_t,
        steam_id = steam_id ~= 0 and steam_id or nil,
        name = name ~= "" and name or nil,
        userid = userid ~= 0 and userid or nil,
        friendsid = friendsid ~= 0 and friendsid or nil,
        is_bot = player_info_t.fakeplayer,
        is_hltv = player_info_t.ishltv,
        files_downloaded = files_downloaded ~= 0 and files_downloaded or nil
    }
end

local function userid_to_entindex(userid)
    inspect("number", 1, userid)

    local entindex = native.get_player_for_userid(userid)
    return entindex ~= 0 and entindex or nil
end

local function console_visible()
    return native.con_is_visible()
end

local function get_local_player()
    return native.get_local_player()
end

local camera_angles_t = ctype.vector3()
local function camera_angles(pitch, yaw, roll)
    native.get_view_angles(camera_angles_t)

    if pitch or yaw or roll then
        inspect("number", 1, pitch)
        inspect("number", 2, yaw)
        if roll then
            inspect("number", 3, roll)
        end

        camera_angles_t.x = pitch or camera_angles_t.x
        camera_angles_t.y = yaw or camera_angles_t.y
        camera_angles_t.z = roll or camera_angles_t.z

        native.set_view_angles(camera_angles_t)
    end

    return camera_angles_t.x, camera_angles_t.y, camera_angles_t.z
end

local function maxplayers()
    return native.get_max_clientsd()
end

local function is_in_game()
    return native.is_in_game()
end

local function is_connected()
    return native.is_connected()
end

local function game_dir()
    return ffi.string(native.get_game_directory())
end

local function mapname()
    return ffi.string(native.get_level_name())
end

local function mapnames()
    return ffi.string(native.get_level_name_short())
end

local function net_channel()
    local get_name = vtable.thunk(0, "const char*(__thiscall*)(void*)")
    local get_address = vtable.thunk(1, "const char*(__thiscall*)(void*)")
    local get_time = vtable.thunk(2, "float(__thiscall*)(void*)")
    local get_time_connected = vtable.thunk(3, "float(__thiscall*)(void*)")
    local get_buffer_size = vtable.thunk(4, "int(__thiscall*)(void*)")
    local get_data_rate = vtable.thunk(5, "int(__thiscall*)(void*)")
    local is_loopback = vtable.thunk(6, "bool(__thiscall*)(void*)")
    local is_timing_out = vtable.thunk(7, "bool(__thiscall*)(void*)")
    local is_playback = vtable.thunk(8, "bool(__thiscall*)(void*)")
    local get_latency = vtable.thunk(9, "float(__thiscall*)(void*, int)")
    local get_avg_latency = vtable.thunk(10, "float(__thiscall*)(void*, int)")
    local get_avg_loss = vtable.thunk(11, "float(__thiscall*)(void*, int)")
    local get_avg_choke = vtable.thunk(12, "float(__thiscall*)(void*, int)")
    local get_avg_date = vtable.thunk(13, "float(__thiscall*)(void*, int)")
    local get_avg_packets = vtable.thunk(14, "float(__thiscall*)(void*, int)")
    local get_total_data = vtable.thunk(15, "int(__thiscall*)(void*, int)")
    local get_sequence_number = vtable.thunk(16, "int(__thiscall*)(void*, int)")
    local is_valid_packet = vtable.thunk(17, "bool(__thiscall*)(void*, int, int)")
    local get_packet_time = vtable.thunk(18, "float(__thiscall*)(void*, int, int)")
    local get_packet_bytes = vtable.thunk(19, "int(__thiscall*)(void*, int, int, int)")
    local get_stream_progress = vtable.thunk(20, "bool(__thiscall*)(void*, int, int*, int*)")
    local get_time_since_last_received = vtable.thunk(22, "float(__thiscall*)(void*)")
    local get_command_interpolation_amount = vtable.thunk(23, "float(__thiscall*)(void*, int, int)")
    local get_packet_response_latency = vtable.thunk(24, "void(__thiscall*)(void*, int, int, int*, int*)")
    local get_remote_frame_rate = vtable.thunk(25, "void(__thiscall*)(void*, float*, float*, float*)")
    local get_timeout_seconds = vtable.thunk(26, "float(__thiscall*)(void*)")

    local net_chan_mt = {}
    net_chan_mt.__index = net_chan_mt

    function net_chan_mt:__tostring()
        if not self.net_chan then
            return
        end

        return "cdata<INetChannelInfo" .. tostring(self.net_chan):sub(11, 25)
    end

    function net_chan_mt:get_name()
        if not self.net_chan then
            return
        end

        return ffi.string(get_name(self.net_chan))
    end

    function net_chan_mt:get_address()
        if not self.net_chan then
            return
        end

        return ffi.string(get_address(self.net_chan))
    end

    function net_chan_mt:get_time()
        if not self.net_chan then
            return
        end

        return get_time(self.net_chan)
    end

    function net_chan_mt:get_time_connected()
        if not self.net_chan then
            return
        end

        return get_time_connected(self.net_chan)
    end

    function net_chan_mt:get_buffer_size()
        if not self.net_chan then
            return
        end

        return get_buffer_size(self.net_chan)
    end

    function net_chan_mt:get_data_rate()
        if not self.net_chan then
            return
        end

        return get_data_rate(self.net_chan)
    end

    function net_chan_mt:is_loopback()
        if not self.net_chan then
            return
        end

        return is_loopback(self.net_chan)
    end

    function net_chan_mt:is_timing_out()
        if not self.net_chan then
            return
        end

        return is_timing_out(self.net_chan)
    end

    function net_chan_mt:is_playback()
        if not self.net_chan then
            return
        end

        return is_playback(self.net_chan)
    end

    function net_chan_mt:get_latency(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_latency(self.net_chan, flow)
    end

    function net_chan_mt:get_avg_latency(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_avg_latency(self.net_chan, flow)
    end

    function net_chan_mt:get_avg_loss(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_avg_loss(self.net_chan, flow)
    end

    function net_chan_mt:get_avg_choke(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_avg_choke(self.net_chan, flow)
    end

    function net_chan_mt:get_avg_date(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_avg_date(self.net_chan, flow)
    end

    function net_chan_mt:get_avg_packets(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_avg_packets(self.net_chan, flow)
    end

    function net_chan_mt:get_total_data(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_total_data(self.net_chan, flow)
    end

    function net_chan_mt:get_sequence_number(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        return get_sequence_number(self.net_chan, flow)
    end

    function net_chan_mt:is_valid_packet(flow, frame)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)
        inspect("number", 2, frame)

        return is_valid_packet(self.net_chan, flow, frame)
    end

    function net_chan_mt:get_packet_time(flow, frame)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)
        inspect("number", 2, frame)

        return get_packet_time(self.net_chan, flow, frame)
    end

    function net_chan_mt:get_packet_bytes(flow, frame, group)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)
        inspect("number", 2, frame)
        inspect("number", 3, group)

        return get_packet_bytes(self.net_chan, flow, frame, group)
    end

    local received, total = ctype["int[?]"](1), ctype["int[?]"](1)
    function net_chan_mt:get_stream_progress(flow)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)

        get_stream_progress(self.net_chan, flow, received, total)
        return received[0], total[0]
    end

    function net_chan_mt:get_time_since_last_received()
        if not self.net_chan then
            return
        end

        return get_time_since_last_received(self.net_chan)
    end

    function net_chan_mt:get_command_interpolation_amount(flow, frame)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)
        inspect("number", 2, frame)

        return get_command_interpolation_amount(self.net_chan, flow, frame)
    end

    local pn_latency_msecs = ctype["int[?]"](1)
    local pn_choke = ctype["int[?]"](1)

    function net_chan_mt:get_packet_response_latency(flow, frame)
        if not self.net_chan then
            return
        end

        inspect("number", 1, flow)
        inspect("number", 2, frame)

        get_packet_response_latency(self.net_chan, flow, frame, pn_latency_msecs, pn_choke)
        return pn_latency_msecs[0], pn_choke[0]
    end

    local pfl_frame_time = ctype["float[?]"](1)
    local pfl_frame_time_std_deviation = ctype["float[?]"](1)
    local pfl_frame_start_time_std_deviation = ctype["float[?]"](1)
    function net_chan_mt:get_remote_frame_rate()
        if not self.net_chan then
            return
        end

        get_remote_frame_rate(self.net_chan, pfl_frame_time, pfl_frame_time_std_deviation, pfl_frame_start_time_std_deviation)
        return pfl_frame_time[0], pfl_frame_time_std_deviation[0], pfl_frame_start_time_std_deviation[0]
    end

    function net_chan_mt:get_timeout_seconds()
        if not self.net_chan then
            return
        end

        return get_timeout_seconds(self.net_chan)
    end

    return function()
        local net_chan = native.net_channel_info()

        return setmetatable(
            {
                net_chan = net_chan ~= nil and net_chan or nil
            },
            net_chan_mt
        )
    end
end

local function mapgroup()
    return ffi.string(native.get_map_group_name())
end

local ui_language = ctype["char[?]"](20)
local function language()
    native.get_ui_language(ui_language, 20)
    return ffi.string(ui_language)
end

local function exec(cmd, ...)
    inspect("string", 1, cmd)

    local cmds = ""
    for k, v in pairs({cmd, ...}) do
        inspect("string", k, v)
        cmds = cmds .. v
    end

    native.execute_client_cmd(cmds)
end

local function random_int(min, max)
    inspect("number", 1, min)
    inspect("number", 2, max)

    math.randomseed(tostring(os.time() + common.Time()):reverse():sub(1, 6))
    return math.random(min, max)
end

local function random_float(min, max)
    inspect("number", 1, min)
    inspect("number", 2, max)

    math.randomseed(tostring(os.time() + common.Time()):reverse():sub(1, 6))
    return math.random(min, max) + math.random()
end

local old_clan_tag = ""
local set_clan_tag_fn = ffi.cast("int(__fastcall*)(const char*)", find_signature("engine.dll", "\x53\x56\x57\x8B\xDA\x8B\xF9\xFF\x15"))

local function set_clan_tag(...)
    local clan_tag = ""
    for k, v in pairs({...}) do
        inspect("string", k, v)
        clan_tag = clan_tag .. v
    end

    if clan_tag ~= old_clan_tag then
        set_clan_tag_fn(clan_tag)
        old_clan_tag = clan_tag
    end
    return old_clan_tag
end

client.create_interface = create_interface
client.find_signature = find_signature

client.log = log
client.color_log = color_log
client.error_log = error_log

client.screen_size = screen_size
client.player_info = player_info
client.userid_to_entindex = userid_to_entindex
client.console_visible = console_visible
client.get_local_player = get_local_player
client.camera_angles = camera_angles
client.maxplayers = maxplayers
client.is_in_game = is_in_game
client.is_connected = is_connected
client.game_dir = game_dir
client.mapname = mapname
client.mapnames = mapnames
client.mapgroup = mapgroup
client.net_channel = net_channel()
client.language = language
client.exec = exec

client.random_int = random_int
client.random_float = random_float

client.set_clan_tag = set_clan_tag

gui.Command(
    "lua.run local function a(b,c,d)local e for f,g in pairs(c)do if b==g then e=d[f]break end end return e end function client.set_event_callback(h,i)local j=a(h,{'paint','esp','model','model_ghost','model_backtrack','setup_command','game_event','user_message','string_cmd','aimbot','shutdown'},{'Draw','DrawESP','DrawModel','DrawModelGhost','DrawModelBacktrack','CreateMove','FireGameEvent','DispatchUserMessage','SendStringCmd','AimbotTarget','Unload'})if j then return callbacks.Register(j,tostring(i),i)elseif h:find('aim_')then local k callbacks.Register('AimbotTarget',function(l)k=l and l:GetName()and true or false end)client.AllowListener('weapon_fire')client.AllowListener('player_hurt')return callbacks.Register('FireGameEvent',tostring(i),function(l)if k then local j=l:GetName()local m=client.GetLocalPlayerIndex()local n=client.GetPlayerIndexByUserID(l:GetInt('attacker'))local o=client.GetPlayerIndexByUserID(l:GetInt('userid'))if h:find('fire')and j=='weapon_fire'and o==m then i(l)end if h:find('hit')and j=='player_hurt'and n==m and o~=m then i(l)end end end)else client.AllowListener(h)return callbacks.Register('FireGameEvent',tostring(i),function(l)if l:GetName()==h then i(l)end end)end end function client.unset_event_callback(h,i)local j=a(h,{'paint','esp','model','model_ghost','model_backtrack','setup_command','game_event','user_message','string_cmd','aimbot','shutdown'},{'Draw','DrawESP','DrawModel','DrawModelGhost','DrawModelBacktrack','CreateMove','FireGameEvent','DispatchUserMessage','SendStringCmd','AimbotTarget','Unload'})return callbacks.Unregister(j or'FireGameEvent',tostring(i))end"
)

return client
