-- Motion helpers. Tween drives values frame by frame (heights, offsets, alpha) from one
-- OnUpdate frame that sleeps when idle. Pop and Pulse use Blizzard animation groups, which
-- run on the client side and cost nothing in Lua. Every helper degrades to "no animation".
local _, ns = ...

local Debug = ns.Debug

local Anim = {}
ns.Anim = Anim

local driver = CreateFrame("Frame")
local tweens = {}

function Anim.EaseOut(t)
	local u = 1 - t
	return 1 - u * u * u
end

local function onUpdate(_, elapsed)
	local finished = {}
	for key, tween in pairs(tweens) do
		tween.elapsed = tween.elapsed + (elapsed or 0)
		local t = tween.duration > 0 and math.min(1, tween.elapsed / tween.duration) or 1
		local ok, err = pcall(tween.step, Anim.EaseOut(t))
		if not ok then
			Debug.Error("tween " .. tostring(key), err)
			t = 1
		end
		if t >= 1 then
			finished[#finished + 1] = key
		end
	end
	for _, key in ipairs(finished) do
		local tween = tweens[key]
		tweens[key] = nil
		if tween and tween.done then
			ns.Try("tween done", tween.done)
		end
	end
	if next(tweens) == nil then
		driver:SetScript("OnUpdate", nil)
	end
end

-- Calls step(p) every frame with p eased from 0 to 1 over `duration` seconds, then done().
-- Starting a tween with a key already running replaces it (its done() is not called).
function Anim.Tween(key, duration, step, done)
	tweens[key] = { elapsed = 0, duration = duration, step = step, done = done }
	driver:SetScript("OnUpdate", onUpdate)
end

function Anim.Cancel(key)
	tweens[key] = nil
end

function Anim.Lerp(a, b, p)
	return a + (b - a) * p
end

-- Fades a frame in from its current alpha.
function Anim.FadeIn(frame, duration, key)
	local from = frame:IsShown() and (frame:GetAlpha() or 0) or 0
	frame:SetAlpha(from)
	frame:Show()
	Anim.Tween(key or frame, duration or 0.18, function(p)
		frame:SetAlpha(Anim.Lerp(from, 1, p))
	end)
end

-- Fades a frame out, hides it, then calls onDone.
function Anim.FadeOut(frame, duration, onDone, key)
	if not frame:IsShown() then
		if onDone then
			onDone()
		end
		return
	end
	local from = frame:GetAlpha() or 1
	Anim.Tween(key or frame, duration or 0.14, function(p)
		frame:SetAlpha(Anim.Lerp(from, 0, p))
	end, function()
		frame:Hide()
		frame:SetAlpha(1)
		if onDone then
			onDone()
		end
	end)
end

-- A quick "settle" scale: the region starts slightly larger and eases back to normal size.
function Anim.Pop(region, size)
	local group = region.srPop
	if group == nil then
		local ok = pcall(function()
			group = region:CreateAnimationGroup()
			local scale = group:CreateAnimation("Scale")
			scale:SetScaleFrom(size or 1.35, size or 1.35)
			scale:SetScaleTo(1, 1)
			scale:SetOrigin("CENTER", 0, 0)
			scale:SetDuration(0.22)
			scale:SetSmoothing("OUT")
		end)
		region.srPop = ok and group or false
	end
	if region.srPop then
		region.srPop:Stop()
		region.srPop:Play()
	end
end

-- A slow, endless alpha breathing on a region (a glow). Returns the group so it can be stopped.
function Anim.Pulse(region, low, high, period)
	local group
	local ok = pcall(function()
		group = region:CreateAnimationGroup()
		group:SetLooping("BOUNCE")
		local alpha = group:CreateAnimation("Alpha")
		alpha:SetFromAlpha(low or 0.15)
		alpha:SetToAlpha(high or 0.7)
		alpha:SetDuration(period or 0.9)
		alpha:SetSmoothing("IN_OUT")
	end)
	return ok and group or nil
end
