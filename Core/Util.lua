-- Pure Lua helpers. No WoW API in this file, so it runs under the test runner.
local _, ns = ...

local Util = {}
ns.Util = Util

function Util.Trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Cuts a UTF-8 string to at most maxChars characters without splitting a multi-byte character.
function Util.Utf8Sub(s, maxChars)
	local count, i, len = 0, 1, #s
	while i <= len do
		local b = s:byte(i)
		local size = 1
		if b >= 240 then
			size = 4
		elseif b >= 224 then
			size = 3
		elseif b >= 192 then
			size = 2
		end
		if count + 1 > maxChars or i + size - 1 > len then
			return s:sub(1, i - 1)
		end
		count = count + 1
		i = i + size
	end
	return s
end

-- Makes untrusted text safe to store and display: removes every UI escape sequence
-- (textures, atlases, links, colors), all remaining pipes and control characters,
-- then trims and cuts to maxChars (default 140).
function Util.Sanitize(text, maxChars)
	if type(text) ~= "string" then
		return ""
	end
	local s = text
	s = s:gsub("||", "")
	s = s:gsub("|T.-|t", "")
	s = s:gsub("|A.-|a", "")
	s = s:gsub("|K.-|k", "")
	s = s:gsub("|H.-|h", "")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
	s = s:gsub("|cn.-:", "")
	s = s:gsub("|[cCrRnNhHtTaAkK]", "")
	s = s:gsub("|", "")
	s = s:gsub("%c", " ")
	s = s:gsub("%s+", " ")
	s = Util.Trim(s)
	return Util.Utf8Sub(s, maxChars or 140)
end

-- For text that came from the game client (names, instance names): show pipes literally.
function Util.Escape(s)
	if type(s) ~= "string" then
		return ""
	end
	return (s:gsub("|", "||"))
end

function Util.DeepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do
		copy[Util.DeepCopy(k, seen)] = Util.DeepCopy(v, seen)
	end
	return copy
end

function Util.Count(t)
	local n = 0
	if type(t) == "table" then
		for _ in pairs(t) do
			n = n + 1
		end
	end
	return n
end

-- Fills in keys that are missing from dst or have the wrong type. Never removes anything.
function Util.MergeDefaults(dst, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			Util.MergeDefaults(dst[k], v)
		elseif type(dst[k]) ~= type(v) then
			dst[k] = v
		end
	end
	return dst
end

function Util.Clamp(n, low, high)
	if n < low then
		return low
	elseif n > high then
		return high
	end
	return n
end

-- Fallback player key when no GUID is known. The suffix is whatever the client returns
-- as the second value of UnitName: a realm, or on Forever possibly a surname.
function Util.NameKey(name, suffix)
	local key = "n:" .. name:lower()
	if suffix and suffix ~= "" then
		key = key .. "-" .. suffix:lower()
	end
	return key
end

function Util.FullName(name, suffix)
	if suffix and suffix ~= "" then
		return name .. "-" .. suffix
	end
	return name
end

-- Splits text a user typed ("Name" or "Name-Suffix") into its two parts.
function Util.SplitTypedName(text)
	local s = Util.Sanitize(text, 64)
	if s == "" then
		return nil
	end
	local name, suffix = s:match("^([^%-]+)%-(.+)$")
	if name then
		return name, suffix
	end
	return s, nil
end

-- Short stable number for a string, used so debug output never contains identities.
function Util.Hash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 1000003
	end
	return h
end

-- Legacy SquadRank stored dates as "YYYY-MM-DD HH:MM" in local time.
function Util.ParseLegacyDate(text)
	if type(text) ~= "string" then
		return nil
	end
	local y, m, d, h, min = text:match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+)")
	if not y then
		return nil
	end
	return time({
		year = tonumber(y),
		month = tonumber(m),
		day = tonumber(d),
		hour = tonumber(h),
		min = tonumber(min),
		sec = 0,
	})
end
