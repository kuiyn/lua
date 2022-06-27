local json = require "json"

local path = "data/database.json"
local db = json.decode(readfile(path) or "[]") or {}

local function read(key)
	return db[key]
end

local function write(key, value)
	db[key] = value
	writefile(path, json.encode(db))
end

return {
	read = read,
	write = write
}
