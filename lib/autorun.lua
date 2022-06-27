--load(http.Get("https://raw.githubusercontent.com/kuiyn/lua/main/lib/autorun.lua"))()

local ffi = ffi
local C, ffi_cdef, ffi_sizeof, ffi_cast, ffi_gc, ffi_string = ffi.C, ffi.cdef, ffi.sizeof, ffi.cast, ffi.gc, ffi.string
local table_concat = table.concat
local gui_Command = gui.Command

ffi_cdef "void free(void*)"
ffi_cdef "void* malloc(size_t)"
ffi_cdef "int _chdir(const char*)"
ffi_cdef "int _mkdir(const char*)"
ffi_cdef "char* _getcwd(char*, int)"

local function gcnew(t, n)
    local ptr = C.malloc(n * ffi_sizeof(t))
    ptr = ffi_cast(t .. "*", ptr)
    ptr = ffi_gc(ptr, C.free)
    return ptr
end

local function gcfree(ptr)
    C.free(ffi_gc(ptr, nil))
end

local function chdir(path)
    return C._chdir(path) == 0
end

local function getcwd()
    local buf = gcnew("char", 260)
    C._getcwd(buf, 260)
    return ffi_string(buf), gcfree(buf)
end

local function mkdir(path)
    if C._mkdir(path) ~= 0 then
        return nil, 'Couldn\'t create the directory: "' .. path .. '"'
    else
        return true
    end
end

ffi_cdef "typedef struct FILE FILE"
ffi_cdef "long ftell(FILE*)"
ffi_cdef "int fclose(FILE*)"
ffi_cdef "int fseek(FILE*, long, int)"
ffi_cdef "FILE* fopen(const char*, const char*)"
ffi_cdef "size_t fread(void*, size_t, size_t, FILE*)"
ffi_cdef "size_t fwrite(const void*, size_t, size_t, FILE*)"

local function readfile(name)
    local fp = ffi_gc(C.fopen(name, "rb"), C.fclose)
    if fp == nil then
        return nil, name .. ": No such file or directory", 2
    end
    C.fseek(fp, 0, 2)
    local sz = C.ftell(fp)
    C.fseek(fp, 0, 0)
    local buf = gcnew("uint8_t", sz)
    C.fread(buf, sz, 1, fp)
    C.fclose(fp)
    ffi_gc(fp, nil)
    return ffi_string(buf, sz), gcfree(buf)
end

local function writefile(name, ...)
    local fp = ffi_gc(C.fopen(name, "wb"), C.fclose)
    if fp == nil then
        return nil
    end
    local str = ""
    for k, v in pairs({...}) do
        str = str .. v
    end
    C.fwrite(str, #str, 1, fp)
    C.fclose(fp)
    ffi_gc(fp, nil)
    return true
end

local function loadfile(filename)
    local f = readfile(filename)
    return f and load(f)
end

local function setpath()
    local path = getcwd()
    for k, v in pairs({".\\?", "\\lib\\?", "\\lib\\?\\init"}) do
        package.path = package.path .. ("%s.lua;"):format((k > 1 and path or "") .. v)
    end
end

local function utils_load()
    do
        _G.string.split = function(self, sep)
            local st = {}
            self:gsub(
                "[^" .. sep .. "]+",
                function(c)
                    st[#st + 1] = c
                end
            )
            return st
        end
    end

    do
        _G.math.clamp = function(val, min, max)
            return val > max and max or val < min and min or val
        end
    end
end

local function download_lib()
    gui_Command [[lua.run 
    local function circle_outline(x, y, r, g, b, a, radius, start_degrees, percentage, thickness, accuracy)
        local ts = radius - thickness
        local pi = math.pi / 180
        local ac = accuracy or 1
        local sa = math.floor(start_degrees)

        draw.Color(r, g, b, a)
        for i = sa, math.floor(sa + math.abs(percentage * 360) - ac), ac do
            local cos_1 = math.cos(i * pi)
            local sin_1 = math.sin(i * pi)
            local cos_2 = math.cos((i + ac) * pi)
            local sin_2 = math.sin((i + ac) * pi)

            local xa = x + cos_1 * radius
            local ya = y + sin_1 * radius
            local xb = x + cos_2 * radius
            local yb = y + sin_2 * radius
            local xc = x + cos_1 * ts
            local yc = y + sin_1 * ts
            local xd = x + cos_2 * ts
            local yd = y + sin_2 * ts

            draw.Triangle(xa, ya, xb, yb, xc, yc)
            draw.Triangle(xc, yc, xb, yb, xd, yd)
        end
    end

    local libs = {
        'base64',
        'callbacks',
        'client',
        'clipboard',
        'csgo_weapons',
        'cvar',
        'database',
        'easing',
        'gif_decoder',
        'http',
        'images',
        'json',
        'localize',
        'md5',
        'panorama',
        'renderer',
        'surface',
        'vtable'
    }

    gui.Reference('menu'):SetActive(false)
    callbacks.Register(
        'Draw',
        'download_lib',
        function()
            local w, h = draw.GetScreenSize()
            draw.Color(200, 40, 40, 55)
            draw.FilledRect(0, 0, w, h)

            local realtime = globals.RealTime() * 1.5
            local start_degrees = realtime % 2 <= 1 and 0 or realtime % 1 * 370
            local percentage = realtime % 2 <= 1 and realtime % 1 or 1 - realtime % 1

            circle_outline(w * 0.5, h * 0.5, 200, 60, 40, 255, 15, start_degrees, percentage, 5)

            local text = 'https://aimware.net'
            local tw = draw.GetTextSize(text)
            draw.Color(255, 255, 255)
            draw.Text(w * 0.5 - tw * 0.5, h * 0.95, text)
        end
    )

    mkdir('lib')
    for i = 1, #libs do
        local v = libs[i]
        local path = ('./lib/%s.lua'):format(v)
        http.Get(
            ('https://gitee.com/qi_ux/lua/raw/master/lib/%s.lua'):format(v),
            function(body)
                writefile(path, body)
                if i == #libs then
                    callbacks.Unregister('Draw', 'download_lib')
                    gui.Reference('menu'):SetActive(true)
                end
            end
        )
    end
    ]]
end

local function searchpath(name, path, sep, rep)
    sep = (sep or "."):gsub("(%p)", "%%%1")
    rep = (rep or "\\"):gsub("(%%)", "%%%1")
    local pname = name:gsub(sep, rep):gsub("(%%)", "%%%1")
    local msg = {}
    for subpath in path:gmatch("[^;]+") do
        local fpath = subpath:gsub("%?", pname)
        local f = loadfile(fpath)
        if f then
            return f
        end
        msg[#msg + 1] = "\n\tno file '" .. fpath .. "'"
    end
    return nil, table_concat(msg)
end

local function loader_loaded(name)
    return searchpath(name, package.path)
end

local function loader_preload(name)
    local preload = package.preload[name]
    if not preload then
        return nil, ("\n\tno field package.preload['%s']"):format(name)
    end
    return preload
end

local function require(name)
    local loaded = package.loaded[name]
    local preload = package.preload[name]

    if not (loaded or preload) then
        local le, le_err = loader_loaded(name)
        local pl, pl_err = loader_preload(name)

        if le then
            local _le = le() or true
            package.loaded[name] = _le
            return _le
        elseif pl then
            local _pl = pl() or true
            package.preload[name] = _pl
            return _pl
        else
            return nil, ("\n%s:\x20%s\n"):format(debug.getinfo(2).short_src, debug.traceback(pl_err .. le_err, 2))
        end
    end

    return loaded or preload and preload()
end

local function init()
    _G.chdir = chdir
    _G.getcwd = getcwd
    _G.mkdir = mkdir
    _G.readfile = readfile
    _G.writefile = writefile
    _G.loadfile = loadfile

    _G.package = {}
    _G.package.config = "\\\n;\n?\n!\n-"
    _G.package.path = ""
    _G.package.preload = {}
    _G.package.loaded = {
        _G = _G,
        bit = _G.bit,
        coroutine = _G.coroutine,
        debug = _G.debug,
        ffi = _G.ffi,
        math = _G.math,
        os = _G.os,
        package = _G.package,
        string = _G.string,
        table = _G.table
    }
    _G.package.searchpath = searchpath
    _G.require = require

    local _, b = getcwd():gsub("aimware", "aimware")
    if b == 0 then
        mkdir("aimware")
        chdir("aimware")
    end

    setpath()
    utils_load()
    download_lib()
end

init()
