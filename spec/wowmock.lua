-- A small fake of the WoW client API, just enough to load every file in the TOC and play
-- through a session in spec/smoke_spec.lua. Frames accept any method call. This checks
-- load order, nil accesses and our own logic; it cannot prove Blizzard's templates behave
-- the same way in the real client.
local mock = {}

local NIL_KEYS = { Inset = true, ScrollBar = true, EditBox = true, srTitle = true, srBuilt = true, srItem = true }

local methods = {}
local function noop() end

local frameMeta = {
	__index = function(_, key)
		if methods[key] then
			return methods[key]
		end
		if type(key) == "string" and key:match("^%u") and not NIL_KEYS[key] then
			return noop
		end
		return nil
	end,
}

local function newObject(kind, parent)
	local object = setmetatable({}, frameMeta)
	rawset(object, "mockKind", kind)
	rawset(object, "mockScripts", {})
	rawset(object, "mockShown", true)
	rawset(object, "mockText", "")
	rawset(object, "mockParent", parent)
	return object
end

function methods:Show()
	rawset(self, "mockShown", true)
end
function methods:Hide()
	rawset(self, "mockShown", false)
end
function methods:SetShown(shown)
	rawset(self, "mockShown", shown and true or false)
end
function methods:IsShown()
	return rawget(self, "mockShown")
end
function methods:SetText(text)
	rawset(self, "mockText", tostring(text or ""))
	local handler = rawget(self, "mockScripts").OnTextChanged
	if handler then
		handler(self)
	end
end
function methods:GetText()
	return rawget(self, "mockText")
end
function methods:SetScript(name, fn)
	rawget(self, "mockScripts")[name] = fn
end
function methods:HookScript(name, fn)
	rawget(self, "mockScripts")[name] = fn
end
function methods:GetScript(name)
	return rawget(self, "mockScripts")[name]
end
function methods:CreateFontString()
	return newObject("FontString", self)
end
function methods:CreateTexture()
	return newObject("Texture", self)
end
function methods:GetFontString()
	return newObject("FontString", self)
end
function methods:GetStringHeight()
	return 12
end
function methods:GetWidth()
	return 200
end
function methods:GetHeight()
	return 20
end
function methods:SetAlpha(alpha)
	rawset(self, "mockAlpha", alpha)
end
function methods:GetAlpha()
	return rawget(self, "mockAlpha") or 1
end
-- Animation groups finish at once: Play() runs the OnFinished script straight away.
function methods:CreateAnimationGroup()
	return newObject("AnimationGroup", self)
end
function methods:CreateAnimation(kind)
	return newObject(kind or "Animation", self)
end
function methods:Play()
	local handler = rawget(self, "mockScripts").OnFinished
	if handler then
		handler(self)
	end
end
function methods:RegisterEvent(event)
	mock.registered[event] = true
end

-- Builds a fresh fake world and installs the globals. Returns the world table the test steers.
function mock.install()
	local world = {
		now = 1800000000,
		combat = false,
		units = {},
		instance = nil,
		timers = {},
		printed = {},
		frames = {},
		menus = {},
		popups = 0,
		secret = {},
	}
	mock.world = world
	mock.registered = {}

	_G.time = os.time
	_G.date = os.date
	_G.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		world.printed[#world.printed + 1] = table.concat(parts, " ")
	end
	_G.issecretvalue = function(value)
		return value == world.secret
	end

	_G.UIParent = newObject("Frame")
	_G.ChatFontNormal = {}
	_G.UNKNOWNOBJECT = "Unknown"
	_G.YES, _G.NO = "Yes", "No"
	_G.CreateFrame = function(kind, _, parent)
		local frame = newObject(kind, parent)
		world.frames[#world.frames + 1] = frame
		return frame
	end
	_G.GetLocale = function()
		return world.locale or "enUS"
	end
	_G.Minimap = newObject("Frame")
	_G.GetCursorPosition = function()
		return 0, 0
	end
	_G.ButtonFrameTemplate_HidePortrait = noop
	_G.ButtonFrameTemplate_HideButtonBar = noop

	_G.C_Timer = {
		After = function(delay, fn)
			world.timers[#world.timers + 1] = { delay = delay, fn = fn }
		end,
	}
	_G.GetServerTime = function()
		return world.now
	end
	_G.InCombatLockdown = function()
		return world.combat
	end
	_G.GetBuildInfo = function()
		return "1.60.1", "70888", "Nov 10 2026", 16001
	end
	_G.GetRealmName = function()
		return "Normal Realm"
	end
	_G.C_GameRules = {
		IsHardcoreActive = function()
			return false
		end,
	}
	_G.C_RestrictedActions = {
		IsAddOnRestrictionActive = function()
			return false
		end,
	}
	_G.C_ClassColor = {
		GetClassColor = function()
			return {
				WrapTextInColorCode = function(_, text)
					return "|cffaaaaaa" .. text .. "|r"
				end,
			}
		end,
	}
	_G.C_RecentAllies = nil
	_G.C_StringUtil = nil

	local function unit(token)
		return world.units[token]
	end
	_G.UnitExists = function(token)
		return unit(token) ~= nil
	end
	_G.UnitIsPlayer = function(token)
		return unit(token) ~= nil
	end
	_G.UnitIsUnit = function(a, b)
		return unit(a) ~= nil and unit(a) == unit(b)
	end
	_G.UnitName = function(token)
		local u = unit(token)
		if u then
			return u.name, u.suffix
		end
	end
	_G.UnitGUID = function(token)
		return unit(token) and unit(token).guid
	end
	_G.UnitClass = function(token)
		local u = unit(token)
		if u then
			return "Mage", u.class or "MAGE", 8
		end
	end
	_G.UnitLevel = function(token)
		return unit(token) and (unit(token).level or 20) or 0
	end
	_G.UnitFactionGroup = function(token)
		if unit(token) then
			return "Alliance", "Alliance"
		end
	end
	_G.UnitGroupRolesAssigned = function(token)
		return unit(token) and (unit(token).role or "NONE") or "NONE"
	end
	_G.IsInGroup = function()
		return world.units.party1 ~= nil or world.units.raid1 ~= nil
	end
	_G.IsInRaid = function()
		return world.units.raid1 ~= nil
	end
	_G.GetNumGroupMembers = function()
		local n = 0
		for token in pairs(world.units) do
			if token ~= "player" then
				n = n + 1
			end
		end
		return n > 0 and n + 1 or 0
	end
	_G.GetNumSubgroupMembers = function()
		return math.max(0, _G.GetNumGroupMembers() - 1)
	end
	_G.IsInInstance = function()
		if world.instance then
			return true, world.instance.type
		end
		return false, "none"
	end
	_G.GetZoneText = function()
		return world.zone or "Elwynn Forest"
	end
	_G.GetInstanceInfo = function()
		local i = world.instance
		if i then
			return i.name, i.type, 1, "Normal", i.maxPlayers or 5, 0, false, i.id, 5
		end
		return "Azeroth", "none", 0, "", 0, 0, false, 0, 0
	end

	_G.SlashCmdList = {}
	_G.StaticPopupDialogs = {}
	_G.StaticPopup_Show = function(which, _, _, data)
		world.popups = world.popups + 1
		_G.StaticPopupDialogs[which].OnAccept(nil, data)
	end

	-- Menus: record what the addon builds so the test can press an entry by its text.
	local function menuRoot()
		local root = { entries = {} }
		function root:CreateTitle() end
		function root:CreateDivider() end
		function root:CreateButton(text, fn)
			self.entries[text] = fn
		end
		function root:CreateRadio(text, _, setSelected)
			self.entries[text] = setSelected
		end
		return root
	end
	_G.MenuUtil = {
		CreateContextMenu = function(owner, generator)
			local root = menuRoot()
			generator(owner, root)
			world.lastMenu = root
		end,
	}
	_G.Menu = {
		ModifyMenu = function(tag, callback)
			world.menus[tag] = callback
		end,
	}
	mock.menuRoot = menuRoot

	local settingsObject = setmetatable({}, {
		__index = function()
			return noop
		end,
	})
	_G.Settings = {
		RegisterVerticalLayoutCategory = function()
			return settingsObject, settingsObject
		end,
		RegisterAddOnSetting = function()
			return settingsObject
		end,
		CreateCheckbox = noop,
		CreateSlider = noop,
		CreateSliderOptions = function()
			return {}
		end,
		RegisterAddOnCategory = noop,
	}
	_G.CreateSettingsButtonInitializer = function(_, _, onClick)
		world.settingsButtons = world.settingsButtons or {}
		table.insert(world.settingsButtons, onClick)
		return {}
	end
	_G.MinimalSliderWithSteppersMixin = nil

	-- ScrollBox is left out on purpose, so the simple list fallback gets exercised.
	_G.CreateScrollBoxListLinearView = nil
	_G.ScrollUtil = nil
	_G.CreateDataProvider = nil
	_G.ScrollBoxConstants = nil

	return world
end

-- Loads every Lua file listed in the TOC, in order, into one namespace. Returns the namespace.
function mock.loadAddon()
	local ns = {}
	for line in io.lines("SquadRank.toc") do
		local path = line:match("^%s*([%w_/\\]+%.lua)%s*$")
		if path then
			local chunk = assert(loadfile((path:gsub("\\", "/"))))
			chunk("SquadRank", ns)
		end
	end
	return ns
end

function mock.fire(ns, event, ...)
	local handler = ns.Events.frame:GetScript("OnEvent")
	handler(ns.Events.frame, event, ...)
end

-- Calls every OnUpdate script once with a long elapsed time, so running tweens finish.
function mock.tick()
	for _, frame in ipairs(mock.world.frames) do
		local handler = rawget(frame, "mockScripts").OnUpdate
		if handler then
			handler(frame, 10)
		end
	end
end

-- Runs queued short C_Timer callbacks (debounces and retries, up to 5 seconds), including
-- ones they schedule, for a few rounds, and lets animations finish. Longer timers (toast
-- timeouts, the 30-second run re-check) stay queued, as they would in a session that moves on.
function mock.flush(rounds)
	local world = mock.world
	for _ = 1, rounds or 4 do
		mock.tick()
		local timers = world.timers
		world.timers = {}
		for _, timer in ipairs(timers) do
			if timer.delay <= 5 then
				timer.fn()
			else
				world.timers[#world.timers + 1] = timer
			end
		end
	end
end

-- Runs every queued timer once, whatever its delay.
function mock.flushLong()
	local world = mock.world
	local timers = world.timers
	world.timers = {}
	for _, timer in ipairs(timers) do
		timer.fn()
	end
end

-- Presses a given button.
function mock.press(button)
	local handler = button:GetScript("OnClick")
	assert(handler, "button has no OnClick")
	handler(button, "LeftButton")
end

-- Presses the most recently created, visible button with this exact text.
function mock.click(text)
	local frames = mock.world.frames
	for i = #frames, 1, -1 do
		local frame = frames[i]
		if rawget(frame, "mockKind") == "Button" and frame:GetText() == text and frame:IsShown() then
			local parent, visible = rawget(frame, "mockParent"), true
			while parent do
				if not parent:IsShown() then
					visible = false
					break
				end
				parent = rawget(parent, "mockParent")
			end
			local handler = visible and frame:GetScript("OnClick")
			if handler then
				handler(frame, "LeftButton")
				return true
			end
		end
	end
	return false
end

return mock
