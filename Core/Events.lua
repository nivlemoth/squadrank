-- One event frame for the whole addon. Handlers are pcall-wrapped, events are counted for
-- the self-test, and work that touches the database can be deferred until combat ends.
local _, ns = ...

local Debug = ns.Debug
local Compat = ns.Compat

local Events = {
	handlers = {},
	counts = {},
	queued = {},
	queueOrder = {},
	tokens = {},
}
ns.Events = Events

local frame = CreateFrame("Frame")
Events.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
	Events.counts[event] = (Events.counts[event] or 0) + 1
	local list = Events.handlers[event]
	if list then
		for i = 1, #list do
			list[i](event, ...)
		end
	end
end)

-- Registers fn for an event. An event the client does not know is logged, not fatal.
function Events.On(event, label, fn)
	local list = Events.handlers[event]
	if not list then
		list = {}
		Events.handlers[event] = list
		local ok = pcall(frame.RegisterEvent, frame, event)
		if not ok then
			Debug.Log("WARN", "event could not be registered: %s", event)
		end
	end
	list[#list + 1] = ns.Safe(label .. ":" .. event, fn)
end

-- Runs fn now when out of combat; otherwise once, when combat ends. A later call with the
-- same key replaces the earlier queued one. Returns true if it ran immediately.
function Events.RunOutOfCombat(key, fn)
	if not Compat.InCombat() then
		ns.Try(key, fn)
		return true
	end
	if not Events.queued[key] then
		Events.queueOrder[#Events.queueOrder + 1] = key
	end
	Events.queued[key] = fn
	return false
end

-- Runs fn once, delay seconds after the last call with the same key.
function Events.Debounce(key, delay, fn)
	local token = (Events.tokens[key] or 0) + 1
	Events.tokens[key] = token
	C_Timer.After(delay, function()
		if Events.tokens[key] == token then
			ns.Try(key, fn)
		end
	end)
end

Events.On("PLAYER_REGEN_ENABLED", "Events", function()
	local order, queued = Events.queueOrder, Events.queued
	Events.queueOrder, Events.queued = {}, {}
	for _, key in ipairs(order) do
		Events.RunOutOfCombat(key, queued[key])
	end
end)

Events.On("PLAYER_REGEN_DISABLED", "Events", function() end)
