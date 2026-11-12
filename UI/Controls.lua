-- Flat controls in the SquadRank theme: buttons, close cross, toggle switch, stepper, text
-- box and a smooth-scrolling area with a slim scroll bar. Built from plain frames and colour
-- textures only, so they look the same on every client and need no templates.
local _, ns = ...

local UI = ns.UI
local Anim = ns.Anim
local Util = ns.Util

local C = UI.C

local STYLES = {
	primary = { bg = C.accent, bgA = 0.85, text = { 1, 1, 1 } },
	ghost = { bg = { 1, 1, 1 }, bgA = 0.06, text = C.text },
	danger = { bg = C.bad, bgA = 0.18, text = { 1, 0.62, 0.58 } },
	link = { bg = { 1, 1, 1 }, bgA = 0, text = C.accent },
}

-- A flat button. style: "primary", "ghost" (default), "danger" or "link".
function UI.FlatButton(parent, text, width, height, onClick, style)
	local s = STYLES[style or "ghost"] or STYLES.ghost
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(width, height or 24)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	UI.SetColor(button.bg, s.bg, s.bgA)
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.08)
	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.label:SetPoint("CENTER")
	button.label:SetWidth(math.max(8, width - 8))
	button.label:SetWordWrap(false)
	UI.TruncationTooltip(button, button.label)
	button.label:SetTextColor(s.text[1], s.text[2], s.text[3])
	button:SetFontString(button.label)
	button:SetPushedTextOffset(0, -1)
	button:SetText(text)
	if onClick then
		button:SetScript("OnClick", ns.Safe("button", onClick))
	end
	return button
end

-- A thin cross that closes something. Drawn with two rotated bars, no art needed.
function UI.CloseButton(parent, onClick, size)
	size = size or 24
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	local hover = button:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, 0.08)
	button.bars = {}
	for i, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
		local bar = button:CreateTexture(nil, "ARTWORK")
		bar:SetSize(size * 0.55, 2)
		bar:SetPoint("CENTER")
		bar:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
		pcall(bar.SetRotation, bar, angle)
		button.bars[i] = bar
	end
	button:SetScript("OnEnter", function()
		for _, bar in ipairs(button.bars) do
			bar:SetColorTexture(1, 1, 1, 1)
		end
	end)
	button:SetScript("OnLeave", function()
		for _, bar in ipairs(button.bars) do
			bar:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
		end
	end)
	button:SetScript("OnClick", ns.Safe("close button", onClick))
	return button
end

-- A small rounded-looking pill with text (labels, counts, version).
function UI.Pill(parent, font)
	local pill = CreateFrame("Frame", nil, parent)
	pill.bg = UI.Fill(pill, C.cardHi)
	pill.text = pill:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightExtraSmall")
	pill.text:SetPoint("CENTER", 0, 0)
	pill:SetHeight(16)
	function pill.Set(_, text, color, alpha)
		pill.text:SetText(text)
		local width = pill.text:GetStringWidth()
		pill:SetWidth(math.max(16, (tonumber(width) or 20) + 12))
		if color then
			UI.SetColor(pill.bg, color, alpha or 0.22)
			pill.text:SetTextColor(
				math.min(1, color[1] + 0.2),
				math.min(1, color[2] + 0.2),
				math.min(1, color[3] + 0.2)
			)
		end
	end
	return pill
end

-- On/off switch with a knob that slides. get() returns the value, set(value) stores it.
function UI.Toggle(parent, get, set)
	local toggle = CreateFrame("Button", nil, parent)
	toggle:SetSize(38, 20)
	toggle.track = UI.Fill(toggle, C.cardHi)
	toggle.knob = toggle:CreateTexture(nil, "ARTWORK")
	toggle.knob:SetSize(14, 14)
	toggle.knob:SetColorTexture(1, 1, 1, 1)
	toggle.pos = 0
	local key = {}

	local function paint(p)
		toggle.knob:ClearAllPoints()
		toggle.knob:SetPoint("LEFT", 3 + 18 * p, 0)
		local off, on = C.cardHi, C.accent
		toggle.track:SetColorTexture(
			Anim.Lerp(0.2, on[1], p),
			Anim.Lerp(0.21, on[2], p),
			Anim.Lerp(0.24, on[3], p),
			Anim.Lerp(off[4] + 0.5, 0.9, p)
		)
	end

	function toggle.Sync(_, animated)
		local target = get() and 1 or 0
		local from = toggle.pos
		toggle.pos = target
		if animated and from ~= target then
			Anim.Tween(key, 0.16, function(p)
				paint(Anim.Lerp(from, target, p))
			end)
		else
			paint(target)
		end
	end

	toggle:SetScript(
		"OnClick",
		ns.Safe("toggle", function()
			set(not get())
			toggle:Sync(true)
		end)
	)
	toggle:Sync(false)
	return toggle
end

-- A number with - and + buttons. get() returns it, set(n) stores it.
function UI.Stepper(parent, get, set, low, high)
	local stepper = CreateFrame("Frame", nil, parent)
	stepper:SetSize(96, 22)
	local value = stepper:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	value:SetPoint("CENTER")
	local function sync()
		value:SetText(tostring(get()))
	end
	local function step(delta)
		return function()
			local n = Util.Clamp((tonumber(get()) or low) + delta, low, high)
			set(n)
			sync()
			Anim.Pop(value, 1.25)
		end
	end
	local minus = UI.FlatButton(stepper, "-", 26, 22, step(-1))
	minus:SetPoint("LEFT")
	local plus = UI.FlatButton(stepper, "+", 26, 22, step(1))
	plus:SetPoint("RIGHT")
	stepper.Sync = sync
	sync()
	return stepper
end

-- A flat single-line text box with a placeholder.
function UI.TextBox(parent, width, height, placeholder, maxLetters)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(width, height or 24)
	holder.bg = UI.Fill(holder, { 0, 0, 0 }, 0.35)
	holder.line = holder:CreateTexture(nil, "BORDER")
	holder.line:SetPoint("BOTTOMLEFT")
	holder.line:SetPoint("BOTTOMRIGHT")
	holder.line:SetHeight(1)
	UI.SetColor(holder.line, C.line, 0.12)

	local box = CreateFrame("EditBox", nil, holder)
	box:SetPoint("TOPLEFT", 8, 0)
	box:SetPoint("BOTTOMRIGHT", -8, 0)
	box:SetFontObject(ChatFontNormal)
	box:SetAutoFocus(false)
	box:SetMaxLetters(maxLetters or 64)
	box:SetTextInsets(0, 0, 0, 0)

	local hint = holder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("LEFT", 8, 0)
	hint:SetText(placeholder or "")
	holder.hint = hint

	local function paintHint()
		hint:SetShown((box:GetText() or "") == "" and not box:HasFocus())
	end
	box:HookScript("OnEditFocusGained", function()
		UI.SetColor(holder.line, C.accent, 0.9)
		hint:Hide()
	end)
	box:HookScript("OnEditFocusLost", function()
		UI.SetColor(holder.line, C.line, 0.12)
		paintHint()
	end)
	box:HookScript("OnTextChanged", paintHint)
	box:SetScript("OnEscapePressed", box.ClearFocus)
	box:SetScript("OnEnterPressed", box.ClearFocus)
	holder.box = box
	holder.PaintHint = paintHint
	return holder, box
end

-- A scroll area whose mouse wheel glides instead of jumping, with a slim draggable bar.
-- Returns scroll, child. Call scroll:Reset() to jump to the top.
function UI.SmoothScroll(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT", -10, 0)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(10, 10)
	scroll:SetScrollChild(child)
	scroll:EnableMouseWheel(true)

	local track = CreateFrame("Frame", nil, parent)
	track:SetPoint("TOPRIGHT", 0, 0)
	track:SetPoint("BOTTOMRIGHT", 0, 0)
	track:SetWidth(4)
	UI.Fill(track, { 1, 1, 1 }, 0.04)
	local thumb = CreateFrame("Button", nil, track)
	thumb:SetWidth(4)
	thumb.tex = UI.Fill(thumb, { 1, 1, 1 }, 0.22)
	local key = {}
	local target = 0

	local function range()
		return math.max(0, tonumber((scroll:GetVerticalScrollRange())) or 0)
	end

	local function paintThumb()
		local max = range()
		local view = tonumber((scroll:GetHeight())) or 1
		track:SetShown(max > 1)
		if max <= 1 then
			return
		end
		local trackHeight = tonumber((track:GetHeight())) or view
		local size = math.max(24, trackHeight * view / (view + max))
		thumb:SetHeight(size)
		local offset = (trackHeight - size) * ((tonumber((scroll:GetVerticalScroll())) or 0) / max)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", track, "TOP", 0, -offset)
	end

	local function scrollTo(value, animated)
		target = Util.Clamp(value, 0, range())
		local from = tonumber((scroll:GetVerticalScroll())) or 0
		if not animated then
			Anim.Cancel(key)
			scroll:SetVerticalScroll(target)
			paintThumb()
			return
		end
		Anim.Tween(key, 0.22, function(p)
			scroll:SetVerticalScroll(Anim.Lerp(from, target, p))
			paintThumb()
		end)
	end

	scroll:SetScript("OnMouseWheel", function(_, delta)
		scrollTo(target - delta * 64, true)
	end)
	scroll:SetScript("OnScrollRangeChanged", function()
		if target > range() then
			scrollTo(range(), false)
		end
		paintThumb()
	end)
	scroll:HookScript("OnSizeChanged", paintThumb)

	thumb:SetScript("OnMouseDown", function()
		local _, startY = GetCursorPosition()
		local startScroll = tonumber((scroll:GetVerticalScroll())) or 0
		local scale = scroll:GetEffectiveScale() or 1
		thumb.tex:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
		thumb:SetScript("OnUpdate", function()
			local _, y = GetCursorPosition()
			local max = range()
			local trackHeight = tonumber((track:GetHeight())) or 1
			local movable = math.max(1, trackHeight - (tonumber((thumb:GetHeight())) or 24))
			scrollTo(startScroll + (startY - y) / scale * max / movable, false)
		end)
	end)
	thumb:SetScript("OnMouseUp", function()
		thumb:SetScript("OnUpdate", nil)
		thumb.tex:SetColorTexture(1, 1, 1, 0.22)
	end)

	function scroll.Reset()
		scrollTo(0, false)
	end
	function scroll.Repaint()
		paintThumb()
	end
	return scroll, child
end
