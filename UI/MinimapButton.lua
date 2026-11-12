-- A round button on the edge of the minimap, made by hand (no libraries). Left-click opens
-- SquadRank, right-click opens its settings, drag moves it around the minimap. A gold dot
-- with a soft pulse shows when players are waiting to be rated.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Anim = ns.Anim
local Debug = ns.Debug

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local C = UI.C
local button
local pendingCount = 0

local function position(angle)
	local map = _G.Minimap
	local radians = math.rad(angle or 200)
	local radius = ((tonumber((map:GetWidth())) or 140) / 2) + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", map, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function cursorAngle()
	local map = _G.Minimap
	local mx, my = map:GetCenter()
	local x, y = GetCursorPosition()
	local scale = map:GetEffectiveScale() or 1
	if not (mx and my and x and y) then
		return nil
	end
	return math.deg(math.atan2(y / scale - my, x / scale - mx)) % 360
end

local function showTooltip(self)
	if not GameTooltip then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(L.ADDON, 1, 1, 1)
	if pendingCount > 0 then
		GameTooltip:AddLine(
			ns.Locale.Count("MINIMAP_PENDING", pendingCount, pendingCount),
			C.gold[1],
			C.gold[2],
			C.gold[3]
		)
	end
	GameTooltip:AddLine(L.MINIMAP_LEFT, C.muted[1], C.muted[2], C.muted[3])
	GameTooltip:AddLine(L.MINIMAP_RIGHT, C.muted[1], C.muted[2], C.muted[3])
	GameTooltip:AddLine(L.MINIMAP_DRAG, C.muted[1], C.muted[2], C.muted[3])
	GameTooltip:Show()
end

local function build()
	local map = _G.Minimap
	if type(map) ~= "table" or not map.GetCenter then
		Debug.notes.minimap = "no Minimap frame"
		return false
	end
	button = CreateFrame("Button", nil, map)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((map:GetFrameLevel() or 1) + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(24, 24)
	background:SetPoint("CENTER")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER")
	icon:SetTexture("Interface\\Icons\\INV_Misc_GroupLooking")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon
	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(52, 52)
	border:SetPoint("TOPLEFT")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local dot = button:CreateTexture(nil, "OVERLAY", nil, 2)
	dot:SetSize(8, 8)
	dot:SetPoint("TOPRIGHT", -3, -3)
	UI.SetColor(dot, C.gold)
	dot:Hide()
	button.dot = dot
	button.pulse = Anim.Pulse(dot, 0.35, 1, 0.8)

	button:SetScript(
		"OnClick",
		ns.Safe("minimap click", function(_, mouse)
			if mouse == "RightButton" then
				ns.Hub.Toggle("settings")
			else
				ns.Hub.Toggle()
			end
		end)
	)
	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		if GameTooltip then
			GameTooltip:Hide()
		end
		self:SetScript("OnUpdate", function()
			local angle = cursorAngle()
			if angle then
				ns.db.settings.minimapAngle = angle
				position(angle)
			end
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	Debug.notes.minimap = "ok"
	return true
end

-- Shows or hides the button from the settings and updates the "waiting" dot.
-- pending: players waiting to be rated (counted by the hub when not given).
function MinimapButton.Update(pending)
	if not ns.db then
		return
	end
	local settings = ns.db.settings
	if not settings.minimapButton then
		if button then
			button:Hide()
		end
		return
	end
	if not button and not build() then
		return
	end
	position(settings.minimapAngle)
	button:Show()
	pendingCount = pending or (ns.Hub and ns.Hub.PendingCount()) or 0
	local waiting = pendingCount > 0
	if waiting and not button.dot:IsShown() then
		button.dot:Show()
		if button.pulse then
			button.pulse:Play()
		end
	elseif not waiting and button.dot:IsShown() then
		button.dot:Hide()
		if button.pulse then
			button.pulse:Stop()
		end
	end
end

function MinimapButton.IsShown()
	return button ~= nil and button:IsShown() and true or false
end
