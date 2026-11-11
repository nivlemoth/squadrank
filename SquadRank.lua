-- SquadRank.lua (Complete Boss Encounter-Based Tracking System)

local addonName, ns = ...

ns.db = {}

local playerName, playerRealm = UnitName("player")
playerRealm = playerRealm or GetRealmName()
local playerFaction = UnitFactionGroup("player")
local playerKey = string.format("%s-%s-%s", playerRealm, playerName, playerFaction)

-- === Color Scheme ===
local COLORS = {
	primary = {r = 0.1, g = 0.3, b = 0.6, a = 0.9},
	secondary = {r = 0.2, g = 0.2, b = 0.3, a = 0.8},
	accent = {r = 0.0, g = 0.7, b = 1.0, a = 1.0},
	success = {r = 0.0, g = 0.8, b = 0.0, a = 1.0},
	warning = {r = 1.0, g = 0.8, b = 0.0, a = 1.0},
	danger = {r = 1.0, g = 0.2, b = 0.2, a = 1.0},
	background = {r = 0.05, g = 0.05, b = 0.1, a = 0.95},
	border = {r = 0.3, g = 0.6, b = 1.0, a = 0.8}
}

-- === Icon System ===
local ICONS = {
	squadrank = "Interface\\AddOns\\SquadRank\\squadrank",
	thumbup = "Interface\\AddOns\\SquadRank\\thumbup",
	neutral = "Interface\\AddOns\\SquadRank\\neutral",
	thumbdown = "Interface\\AddOns\\SquadRank\\thumbdown",
	settings = "Interface\\Icons\\Trade_Engineering",
	history = "Interface\\Icons\\INV_Scroll_08",
	squad = "Interface\\Icons\\Achievement_Character_Human_Male"
}

-- === Class Color System ===
local function GetClassColor(class)
	if not class then return 1, 1, 1 end
	
	local classColors = {
		WARRIOR = {r = 0.78, g = 0.61, b = 0.43},
		PALADIN = {r = 0.96, g = 0.55, b = 0.73},
		HUNTER = {r = 0.67, g = 0.83, b = 0.45},
		ROGUE = {r = 1.00, g = 0.96, b = 0.41},
		PRIEST = {r = 1.00, g = 1.00, b = 1.00},
		SHAMAN = {r = 0.00, g = 0.44, b = 0.87},
		MAGE = {r = 0.25, g = 0.78, b = 0.92},
		WARLOCK = {r = 0.53, g = 0.53, b = 0.93},
		MONK = {r = 0.00, g = 1.00, b = 0.59},
		DRUID = {r = 1.00, g = 0.49, b = 0.04},
		DEMONHUNTER = {r = 0.64, g = 0.19, b = 0.79},
		DEATHKNIGHT = {r = 0.77, g = 0.12, b = 0.23},
		EVOKER = {r = 0.20, g = 0.58, b = 0.50}
	}
	
	if C_ClassColor and C_ClassColor.GetClassColor then
		local classColor = C_ClassColor.GetClassColor(class)
		if classColor then
			return classColor.r, classColor.g, classColor.b
		end
	end
	
	local color = classColors[class]
	if color then
		return color.r, color.g, color.b
	end
	
	return 1, 1, 1
end

local function GetClassColoredName(name, class)
	local r, g, b = GetClassColor(class)
	return string.format("|cff%02x%02x%02x%s|r", r*255, g*255, b*255, name)
end

-- === Utility Functions ===
local function GetDateString()
	return date("%Y-%m-%d %H:%M")
end

local function FormatDateToMMDDYY(dateStr)
	if not dateStr then return "N/A" end
	local y, m, d, h, min = dateStr:match("^(%d+)%-(%d+)%-(%d+) (%d+):(%d+)")
	if y and m and d then
		return string.format("%02d/%02d/%02d %02d:%02d", tonumber(m), tonumber(d), tonumber(y:sub(-2)), tonumber(h), tonumber(min))
	end
	return dateStr
end

local function VoteIconAndText(vote)
	local voteMap = {
		GOOD = "|T" .. ICONS.thumbup .. ":16:16|t |cff00ff00GOOD|r",
		OK = "|T" .. ICONS.neutral .. ":16:16|t |cffffff00OK|r",
		BAD = "|T" .. ICONS.thumbdown .. ":16:16|t |cffff2222BAD|r"
	}
	return voteMap[vote] or "|cff888888None|r"
end

-- === Enhanced Instance Type Detection ===
local function GetInstanceTypeInfo(instanceType, difficulty)
	local typeInfo = {
		text = "Unknown",
		color = {r = 0.7, g = 0.7, b = 0.7}
	}
	
	if instanceType == "party" then
		if difficulty == 1 then
			typeInfo.text = "5-Man Normal"
			typeInfo.color = {r = 0.0, g = 1.0, b = 0.0}
		elseif difficulty == 2 then
			typeInfo.text = "5-Man Heroic"
			typeInfo.color = {r = 0.0, g = 0.4, b = 1.0}
		elseif difficulty >= 8 then
			local mythicLevel = difficulty - 7
			typeInfo.text = "Mythic+" .. mythicLevel
			typeInfo.color = {r = 0.6, g = 0.2, b = 1.0}
		end
	elseif instanceType == "raid" then
		if difficulty == 3 or difficulty == 4 then
			typeInfo.text = "Raid Normal"
			typeInfo.color = {r = 1.0, g = 0.5, b = 0.0}
		elseif difficulty == 5 or difficulty == 6 then
			typeInfo.text = "Raid Heroic"
			typeInfo.color = {r = 1.0, g = 0.0, b = 0.0}
		elseif difficulty == 7 or difficulty == 8 then
			typeInfo.text = "Raid Mythic"
			typeInfo.color = {r = 0.5, g = 0.0, b = 0.5}
		else
			typeInfo.text = "Raid"
			typeInfo.color = {r = 1.0, g = 0.8, b = 0.0}
		end
	elseif instanceType == "pvp" then
		typeInfo.text = "PvP"
		typeInfo.color = {r = 1.0, g = 0.2, b = 0.2}
	elseif instanceType == "arena" then
		typeInfo.text = "Arena"
		typeInfo.color = {r = 0.8, g = 0.0, b = 0.8}
	elseif instanceType == "scenario" then
		typeInfo.text = "Scenario"
		typeInfo.color = {r = 0.0, g = 0.8, b = 0.8}
	else
		typeInfo.text = "Open World"
		typeInfo.color = {r = 0.4, g = 0.8, b = 0.4}
	end
	
	return typeInfo
end

-- === Database Initialization ===
local function InitializeDB()
	SquadRankDB = SquadRankDB or {
		players = {},
		squadHistory = {},
		settings = {
			showMinimapIcon = true,
			showToast = true,
			autoAddFriends = false,
			minimapIconAngle = 0,
			toastPos = {x = 0, y = 100},
			filterClass = "ALL",
			filterRank = "ALL",
			filterRealm = "ALL",
			searchText = ""
		}
	}
	ns.db = SquadRankDB
end

-- === Import/Export System ===
StaticPopupDialogs["SQUADRANK_IMPORT_DATA"] = {
	text = "Paste your SquadRank data below:",
	button1 = "Import",
	button2 = "Cancel",
	hasEditBox = true,
	maxLetters = 10000,
	editBoxWidth = 400,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	OnAccept = function(self)
		local text = self.editBox:GetText()
		if text and text ~= "" then
			local entries = {strsplit(";", text)}
			local imported = 0
			
			for _, entry in ipairs(entries) do
				if entry ~= "" then
					local guid, name, realm, class, rank, count = strsplit(":", entry)
					if guid and name and realm and class and rank and count then
						ns.db.players[guid] = {
							name = name,
							realm = realm,
							class = class,
							lastRank = rank ~= "None" and rank or "",
							groupedCount = tonumber(count) or 0,
							lastGrouped = GetDateString(),
							lastLocation = "Imported",
							rankGood = 0,
							rankOk = 0,
							rankBad = 0,
							instanceHistory = {}
						}
						imported = imported + 1
					end
				end
			end
			
			print("SquadRank: Successfully imported " .. imported .. " player records!")
			
			if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
				SquadRank:RefreshPlayerHistory()
			end
		else
			print("SquadRank: No data to import.")
		end
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

StaticPopupDialogs["SQUADRANK_EXPORT_DATA"] = {
	text = "Your SquadRank data (copy this):",
	button1 = "Close",
	hasEditBox = true,
	maxLetters = 10000,
	editBoxWidth = 400,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	OnShow = function(self)
		local exportString = ""
		local count = 0
		
		for guid, data in pairs(ns.db.players or {}) do
			if count > 0 then exportString = exportString .. ";" end
			exportString = exportString .. string.format("%s:%s:%s:%s:%s:%d",
				guid,
				data.name or "Unknown",
				data.realm or "Unknown",
				data.class or "UNKNOWN",
				data.lastRank or "None",
				data.groupedCount or 0
			)
			count = count + 1
		end
		
		self.editBox:SetText(exportString)
		self.editBox:HighlightText()
		print("SquadRank: Exported " .. count .. " player records to clipboard")
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide()
	end
}

-- === FIXED Minimap Icon ===
local minimapIcon = nil
local isDragging = false

local function GetMinimapShape()
	if Minimap.SetArchBlobRingScalar or GetCVar("minimapShapeshiftTracking") == "0" then
		return "square"
	end
	return "round"
end

local function UpdateMinimapIconPosition()
	if not minimapIcon or not ns.db.settings then return end
	
	local angle = ns.db.settings.minimapIconAngle or 0
	local shape = GetMinimapShape()
	local radius = shape == "square" and 110 or 95
	local x, y
	
	if shape == "square" then
		local cos = math.cos(angle)
		local sin = math.sin(angle)
		local maxCoord = radius / math.max(math.abs(cos), math.abs(sin))
		x = cos * maxCoord
		y = sin * maxCoord
	else
		x = math.cos(angle) * radius
		y = math.sin(angle) * radius
	end
	
	minimapIcon:ClearAllPoints()
	minimapIcon:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapIcon()
	if minimapIcon then return end
	
	minimapIcon = CreateFrame("Button", "SquadRankMinimapIcon", Minimap)
	minimapIcon:SetSize(32, 32)
	minimapIcon:SetFrameStrata("MEDIUM")
	minimapIcon:SetFrameLevel(8)
	
	local texture = minimapIcon:CreateTexture(nil, "BACKGROUND")
	texture:SetTexture(ICONS.squadrank)
	texture:SetSize(20, 20)
	texture:SetPoint("CENTER")
	
	local border = minimapIcon:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54)
	border:SetPoint("TOPLEFT", 0, 0)
	border:SetVertexColor(1, 0.82, 0, 1)
	
	minimapIcon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	minimapIcon:EnableMouse(true)
	minimapIcon:SetMovable(true)
	minimapIcon:RegisterForDrag("LeftButton")
	
	minimapIcon:SetScript("OnDragStart", function(self)
		isDragging = true
		self:SetScript("OnUpdate", function(self)
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			px, py = px / scale, py / scale
			
			local angle = math.atan2(py - my, px - mx)
			ns.db.settings.minimapIconAngle = angle
			UpdateMinimapIconPosition()
		end)
	end)
	
	minimapIcon:SetScript("OnDragStop", function(self)
		isDragging = false
		self:SetScript("OnUpdate", nil)
	end)
	
	minimapIcon:SetScript("OnClick", function(_, button)
		if button == "LeftButton" and not isDragging then
			SquadRank:ToggleMainWindow()
		end
	end)
	
	minimapIcon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("|cff00bfffSquadRank|r")
		GameTooltip:AddLine("Left-click: Open SquadRank window", 1, 1, 1)
		GameTooltip:AddLine("Drag: Move icon around minimap", 0.7, 0.7, 0.7)
		GameTooltip:Show()
		self:SetAlpha(1)
	end)
	
	minimapIcon:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		self:SetAlpha(0.8)
	end)
	
	minimapIcon:SetAlpha(0.8)
	UpdateMinimapIconPosition()
end

-- === BOSS ENCOUNTER-BASED TRACKING SYSTEM ===
local currentInstanceRun = nil
local encounterPlayersAllTime = {}

local function GetPlayerRole(class)
	if not class then return "DPS" end
	
	local tankClasses = {WARRIOR = true, PALADIN = true, DEATHKNIGHT = true, DEMONHUNTER = true, MONK = true}
	local healerClasses = {PRIEST = true, PALADIN = true, SHAMAN = true, DRUID = true, MONK = true, EVOKER = true}
	
	if class == "PRIEST" or class == "SHAMAN" or class == "EVOKER" then
		return "HEALER"
	elseif class == "WARRIOR" or class == "DEATHKNIGHT" or class == "DEMONHUNTER" then
		return "TANK"
	elseif tankClasses[class] then
		return "TANK"
	elseif healerClasses[class] then
		return "HEALER"
	else
		return "DPS"
	end
end

local function GetCurrentGroupPlayers()
	local players = {}
	if not IsInGroup() then return players end
	
	local numGroupMembers = GetNumGroupMembers()
	local myName = UnitName("player")
	local myRealm = GetRealmName()
	
	for i = 1, numGroupMembers do
		local unit
		if IsInRaid() then
			unit = "raid" .. i
		else
			if i == 1 then
				unit = "player"
			else
				unit = "party" .. (i - 1)
			end
		end

		if UnitExists(unit) and UnitIsPlayer(unit) then
			local fullName, realm = UnitName(unit)
			local class, classFilename = UnitClass(unit)
			local faction = UnitFactionGroup(unit)
			if fullName then
				local displayName = fullName
				if fullName:find("-") then
					displayName = fullName:match("^([^-]+)")
				end
				realm = realm or GetRealmName()
				local key = string.format("%s-%s-%s", realm, displayName, faction)
				
				-- Exclude current player
				if displayName ~= myName or realm ~= myRealm then
					players[key] = {
						name = displayName,
						realm = realm,
						class = classFilename or "UNKNOWN"
					}
				end
			end
		end
	end
	
	return players
end

local function StartInstanceRun()
	local instanceType, instanceName = "openworld", GetZoneText()
	local difficulty = 1
	local inInstance, type = IsInInstance()
	if inInstance then
		instanceName = GetInstanceInfo() or "Unknown Instance"
		instanceType = type or "unknown"
		difficulty = select(3, GetInstanceInfo()) or 1
	end

	local currentTime = GetDateString()
	local instanceKey = instanceName .. "-" .. instanceType .. "-" .. difficulty
	
	-- Delete any existing squads for this exact instance
	for squadId, data in pairs(ns.db.squadHistory) do
		if data.location == instanceName and data.type == instanceType and data.difficulty == difficulty then
			ns.db.squadHistory[squadId] = nil
			print("SquadRank: Removed old squad for " .. instanceName)
		end
	end
	
	currentInstanceRun = {
		instanceName = instanceName,
		instanceType = instanceType,
		difficulty = difficulty,
		startTime = currentTime,
		allPlayers = {},
		encountersStarted = 0
	}
	
	encounterPlayersAllTime = {}
	print("SquadRank: Started tracking instance run: " .. instanceName)
end

local function OnEncounterStart(encounterID, encounterName)
	if not currentInstanceRun then
		StartInstanceRun()
	end
	
	if currentInstanceRun then
		currentInstanceRun.encountersStarted = currentInstanceRun.encountersStarted + 1
		
		-- Get all players currently in the group during this encounter
		local currentPlayers = GetCurrentGroupPlayers()
		
		-- Add all current players to the all-time list for this instance
		for playerKey, playerData in pairs(currentPlayers) do
			encounterPlayersAllTime[playerKey] = playerData
		end
		
		print("SquadRank: Boss encounter started: " .. (encounterName or "Unknown") .. " (" .. encounterID .. ")")
		print("SquadRank: Tracking " .. table.getn(currentPlayers) .. " players for this encounter")
	end
end

local function OnEncounterEnd(encounterID, encounterName, success)
	if currentInstanceRun then
		local statusText = success and "SUCCESS" or "WIPE"
		print("SquadRank: Boss encounter ended: " .. (encounterName or "Unknown") .. " - " .. statusText)
	end
end

local function FinishInstanceRun()
	if not currentInstanceRun then return end
	
	-- Only create squad if we had encounters and players
	if currentInstanceRun.encountersStarted > 0 and next(encounterPlayersAllTime) then
		local currentTime = GetDateString()
		local squadId = currentTime .. "-" .. math.random(1000, 9999)
		
		-- Count players
		local playerCount = 0
		for _ in pairs(encounterPlayersAllTime) do
			playerCount = playerCount + 1
		end
		
		print("SquadRank: Creating squad for " .. currentInstanceRun.instanceName .. " with " .. playerCount .. " players from " .. currentInstanceRun.encountersStarted .. " encounters")
		
		ns.db.squadHistory[squadId] = {
			date = currentTime,
			location = currentInstanceRun.instanceName,
			type = currentInstanceRun.instanceType,
			difficulty = currentInstanceRun.difficulty,
			uniqueId = squadId,
			players = {},
			rating = "UNRATED",
			encountersCompleted = currentInstanceRun.encountersStarted
		}

		-- Add all players who participated in any encounter
		for pKey, pData in pairs(encounterPlayersAllTime) do
			-- Update player database
			if not ns.db.players[pKey] then
				ns.db.players[pKey] = {
					name = pData.name,
					realm = pData.realm,
					class = pData.class,
					groupedCount = 1,
					lastGrouped = currentTime,
					lastLocation = currentInstanceRun.instanceName,
					rankGood = 0,
					rankOk = 0,
					rankBad = 0,
					lastRank = "",
					instanceHistory = {}
				}
			else
				local entry = ns.db.players[pKey]
				entry.name = pData.name
				entry.realm = pData.realm
				entry.class = pData.class
				entry.groupedCount = (entry.groupedCount or 0) + 1
				entry.lastGrouped = currentTime
				entry.lastLocation = currentInstanceRun.instanceName
			end

			ns.db.squadHistory[squadId].players[pKey] = {
				name = pData.name,
				realm = pData.realm,
				class = pData.class,
				lastRank = ns.db.players[pKey] and ns.db.players[pKey].lastRank or ""
			}
		end
		
		print("SquadRank: Squad created successfully for " .. currentInstanceRun.instanceName)
	else
		print("SquadRank: No encounters completed in " .. currentInstanceRun.instanceName .. ", skipping squad creation")
	end
	
	-- Reset for next run
	currentInstanceRun = nil
	encounterPlayersAllTime = {}
end

-- === Toast Notification System ===
local function CreateMovableToast(playerKey, playerName, playerClass)
	local toast = CreateFrame("Frame", "SquadRankMovableToast", UIParent, "BackdropTemplate")
	toast:SetSize(280, 120)
	toast:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -50, -150)
	toast:SetMovable(true)
	toast:EnableMouse(true)
	toast:RegisterForDrag("LeftButton")
	toast:SetScript("OnDragStart", toast.StartMoving)
	toast:SetScript("OnDragStop", toast.StopMovingOrSizing)
	
	toast:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	toast:SetBackdropColor(COLORS.background.r, COLORS.background.g, COLORS.background.b, 0.95)
	toast:SetBackdropBorderColor(COLORS.accent.r, COLORS.accent.g, COLORS.accent.b, 1.0)
	toast:SetFrameStrata("DIALOG")

	local icon = toast:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICONS.squadrank)
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 8, -8)

	local title = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("LEFT", icon, "RIGHT", 5, 0)
	title:SetText("|cff00bfffPlayer Left|r")

	local playerText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	playerText:SetPoint("TOP", toast, "TOP", 0, -35)
	playerText:SetWidth(260)
	playerText:SetJustifyH("CENTER")

	if playerClass and playerClass ~= "UNKNOWN" then
		playerText:SetText(GetClassColoredName(playerName, playerClass))
	else
		playerText:SetText(playerName)
	end

	local instructText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	instructText:SetPoint("TOP", playerText, "BOTTOM", 0, -5)
	instructText:SetText("|cff888888Rate this player:|r")

	-- Rank buttons
	local goodBtn = CreateFrame("Button", nil, toast, "UIPanelButtonTemplate")
	goodBtn:SetSize(55, 25)
	goodBtn:SetPoint("BOTTOM", -65, 12)
	goodBtn:SetText("Good")
	goodBtn:SetScript("OnClick", function()
		if ns.db.players[playerKey] then
			ns.db.players[playerKey].lastRank = "GOOD"
			ns.db.players[playerKey].rankGood = (ns.db.players[playerKey].rankGood or 0) + 1
		end
		print("SquadRank: Rated " .. playerName .. " as |cff00ff00GOOD|r")
		toast:Hide()
		if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
			SquadRank:RefreshPlayerHistory()
		end
	end)

	local okBtn = CreateFrame("Button", nil, toast, "UIPanelButtonTemplate")
	okBtn:SetSize(55, 25)
	okBtn:SetPoint("BOTTOM", 0, 12)
	okBtn:SetText("OK")
	okBtn:SetScript("OnClick", function()
		if ns.db.players[playerKey] then
			ns.db.players[playerKey].lastRank = "OK"
			ns.db.players[playerKey].rankOk = (ns.db.players[playerKey].rankOk or 0) + 1
		end
		print("SquadRank: Rated " .. playerName .. " as |cffffff00OK|r")
		toast:Hide()
		if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
			SquadRank:RefreshPlayerHistory()
		end
	end)

	local badBtn = CreateFrame("Button", nil, toast, "UIPanelButtonTemplate")
	badBtn:SetSize(55, 25)
	badBtn:SetPoint("BOTTOM", 65, 12)
	badBtn:SetText("Bad")
	badBtn:SetScript("OnClick", function()
		if ns.db.players[playerKey] then
			ns.db.players[playerKey].lastRank = "BAD"
			ns.db.players[playerKey].rankBad = (ns.db.players[playerKey].rankBad or 0) + 1
		end
		print("SquadRank: Rated " .. playerName .. " as |cffff2222BAD|r")
		toast:Hide()
		if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
			SquadRank:RefreshPlayerHistory()
		end
	end)

	toast:Show()
	C_Timer.After(12, function()
		if toast and toast:IsShown() then
			toast:Hide()
		end
	end)
end

local function ShowToast(playerKey, playerName)
	if not ns.db.settings.showToast then return end
	local playerData = ns.db.players[playerKey]
	local playerClass = playerData and playerData.class or "UNKNOWN"
	CreateMovableToast(playerKey, playerName, playerClass)
end

-- === Player Leave Detection ===
local currentGroupMembers = {}

local function UpdateGroupMembers()
	local newMembers = {}
	if IsInGroup() then
		local numGroupMembers = GetNumGroupMembers()
		for i = 1, numGroupMembers do
			local unit
			if IsInRaid() then
				unit = "raid" .. i
			else
				if i == 1 then
					unit = "player"
				else
					unit = "party" .. (i - 1)
				end
			end

			if UnitExists(unit) and UnitIsPlayer(unit) then
				local fullName, realm = UnitName(unit)
				local faction = UnitFactionGroup(unit)
				if fullName then
					local displayName = fullName
					if fullName:find("-") then
						displayName = fullName:match("^([^-]+)")
					end
					realm = realm or GetRealmName()
					local key = string.format("%s-%s-%s", realm, displayName, faction)
					if key ~= playerKey then
						newMembers[key] = displayName
					end
				end
			end
		end
	end

	for key, name in pairs(currentGroupMembers) do
		if not newMembers[key] then
			ShowToast(key, name)
		end
	end

	currentGroupMembers = newMembers
end

-- === Main Window System ===
SquadRank = SquadRank or {}

function SquadRank:ToggleMainWindow()
	if not self.mainWindow then
		self:CreateMainWindow()
	end

	if self.mainWindow:IsShown() then
		self.mainWindow:Hide()
	else
		self.mainWindow:Show()
		self:RefreshCurrentTab()
	end
end

function SquadRank:CreateMainWindow()
	local frame = CreateFrame("Frame", "SquadRankMainWindow", UIParent, "BackdropTemplate")
	frame:SetSize(1100, 700)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	frame:SetBackdropColor(COLORS.background.r, COLORS.background.g, COLORS.background.b, COLORS.background.a)
	frame:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, COLORS.border.a)

	local header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	header:SetSize(1084, 80)
	header:SetPoint("TOP", 0, -8)
	header:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	header:SetBackdropColor(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, COLORS.primary.a)
	header:SetBackdropBorderColor(COLORS.accent.r, COLORS.accent.g, COLORS.accent.b, COLORS.accent.a)

	local titleIcon = header:CreateTexture(nil, "ARTWORK")
	titleIcon:SetTexture(ICONS.squadrank)
	titleIcon:SetSize(48, 48)
	titleIcon:SetPoint("LEFT", 20, 0)

	local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("LEFT", titleIcon, "RIGHT", 15, 5)
	title:SetText("|cff00bfffSquadRank|r")
	title:SetTextColor(COLORS.accent.r, COLORS.accent.g, COLORS.accent.b)

	local subtitle = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	subtitle:SetPoint("LEFT", titleIcon, "RIGHT", 15, -15)
	subtitle:SetText("Advanced Player Tracking System")
	subtitle:SetTextColor(1, 1, 1, 0.8)

	local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetSize(24, 24)
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)

	local tabContainer = CreateFrame("Frame", nil, frame)
	tabContainer:SetSize(1084, 50)
	tabContainer:SetPoint("TOP", header, "BOTTOM", 0, 0)

	local tabs = {}
	local tabData = {
		{text = "Player History", icon = ICONS.history, id = "players"},
		{text = "Squad History", icon = ICONS.squad, id = "squads"},
		{text = "Settings", icon = ICONS.settings, id = "settings"}
	}

	for i, data in ipairs(tabData) do
		local tab = CreateFrame("Button", nil, tabContainer, "BackdropTemplate")
		tab:SetSize(160, 40)
		local totalTabWidth = #tabData * 160 + (#tabData - 1) * 10
		local startX = (1084 - totalTabWidth) / 2
		tab:SetPoint("LEFT", startX + (i-1) * 170, 0)

		tab:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
			tile = true, tileSize = 16, edgeSize = 8,
			insets = { left = 2, right = 2, top = 2, bottom = 2 }
		})
		tab:SetBackdropColor(COLORS.secondary.r, COLORS.secondary.g, COLORS.secondary.b, COLORS.secondary.a)
		tab:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, 0.5)

		local tabIcon = tab:CreateTexture(nil, "ARTWORK")
		tabIcon:SetTexture(data.icon)
		tabIcon:SetSize(20, 20)
		tabIcon:SetPoint("LEFT", 10, 0)

		local tabText = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		tabText:SetPoint("LEFT", tabIcon, "RIGHT", 8, 0)
		tabText:SetText(data.text)

		tab.id = data.id
		tab.icon = tabIcon
		tab.text = tabText

		tab:SetScript("OnClick", function()
			SquadRank:SelectTab(data.id)
		end)

		tab:SetScript("OnEnter", function(self)
			if self.id ~= SquadRank.activeTab then
				self:SetBackdropColor(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.6)
			end
		end)

		tab:SetScript("OnLeave", function(self)
			if self.id ~= SquadRank.activeTab then
				self:SetBackdropColor(COLORS.secondary.r, COLORS.secondary.g, COLORS.secondary.b, COLORS.secondary.a)
			end
		end)

		tabs[data.id] = tab
	end

	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 16, -138)
	content:SetPoint("BOTTOMRIGHT", -16, 16)

	self:CreatePlayerHistoryFrame(content)
	self:CreateSquadHistoryFrame(content)
	self:CreateSettingsFrame(content)

	self.mainWindow = frame
	self.tabs = tabs
	self:SelectTab("players")
end

function SquadRank:SelectTab(tabId)
	self.activeTab = tabId

	for id, tab in pairs(self.tabs) do
		if id == tabId then
			tab:SetBackdropColor(COLORS.accent.r, COLORS.accent.g, COLORS.accent.b, 0.8)
			tab.text:SetTextColor(1, 1, 1, 1)
		else
			tab:SetBackdropColor(COLORS.secondary.r, COLORS.secondary.g, COLORS.secondary.b, COLORS.secondary.a)
			tab.text:SetTextColor(0.8, 0.8, 0.8, 1)
		end
	end

	if self.playerHistoryFrame then self.playerHistoryFrame:Hide() end
	if self.squadHistoryFrame then self.squadHistoryFrame:Hide() end
	if self.settingsFrame then self.settingsFrame:Hide() end

	if tabId == "players" and self.playerHistoryFrame then
		self.playerHistoryFrame:Show()
		self:RefreshPlayerHistory()
	elseif tabId == "squads" and self.squadHistoryFrame then
		self.squadHistoryFrame:Show()
		self:RefreshSquadHistory()
	elseif tabId == "settings" and self.settingsFrame then
		self.settingsFrame:Show()
	end
end

function SquadRank:GetPlayerRole(class)
	return GetPlayerRole(class)
end

local function GetInstanceIcon(instanceType)
	if instanceType == "party" then
		return "Interface\\LFGFrame\\UI-LFG-ICON-DUNGEON"
	elseif instanceType == "raid" then
		return "Interface\\LFGFrame\\UI-LFG-ICON-RAID"
	elseif instanceType == "pvp" or instanceType == "arena" then
		return "Interface\\PVPFrame\\PVP-Currency-Conquest"
	elseif instanceType == "scenario" then
		return "Interface\\LFGFrame\\UI-LFG-ICON-SCENARIO"
	else
		return "Interface\\WorldMap\\WorldMap-Icon"
	end
end

local function CreatePlayerRankingDialog(playerKey, playerName, playerClass)
	local dialog = CreateFrame("Frame", "SquadRankPlayerDialog", UIParent, "BackdropTemplate")
	dialog:SetSize(300, 180)
	dialog:SetPoint("CENTER")
	
	dialog:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 32, edgeSize = 16,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	dialog:SetBackdropColor(COLORS.background.r, COLORS.background.g, COLORS.background.b, COLORS.background.a)
	dialog:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, COLORS.border.a)
	dialog:SetFrameStrata("DIALOG")

	local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -15)
	title:SetText("|cff00bfffRank Player|r")

	local playerText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	playerText:SetPoint("TOP", title, "BOTTOM", 0, -15)
	if playerClass and playerClass ~= "UNKNOWN" then
		playerText:SetText(GetClassColoredName(playerName, playerClass))
	else
		playerText:SetText(playerName)
	end

	local goodBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	goodBtn:SetSize(80, 30)
	goodBtn:SetPoint("BOTTOM", -90, 30)
	goodBtn:SetText("|T" .. ICONS.thumbup .. ":16:16|t Good")
	goodBtn:SetScript("OnClick", function()
		if ns.db.players[playerKey] then
			ns.db.players[playerKey].lastRank = "GOOD"
			ns.db.players[playerKey].rankGood = (ns.db.players[playerKey].rankGood or 0) + 1
		end
		print("SquadRank: Ranked " .. playerName .. " as |cff00ff00GOOD|r")
		dialog:Hide()
		if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
			SquadRank:RefreshPlayerHistory()
		end
	end)

	local okBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	okBtn:SetSize(80, 30)
	okBtn:SetPoint("BOTTOM", 0, 30)
	okBtn:SetText("|T" .. ICONS.neutral .. ":16:16|t OK")
	okBtn:SetScript("OnClick", function()
		if ns.db.players[playerKey] then
			ns.db.players[playerKey].lastRank = "OK"
			ns.db.players[playerKey].rankOk = (ns.db.players[playerKey].rankOk or 0) + 1
		end
		print("SquadRank: Ranked " .. playerName .. " as |cffffff00OK|r")
		dialog:Hide()
		if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
			SquadRank:RefreshPlayerHistory()
		end
	end)

	local badBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	badBtn:SetSize(80, 30)
	badBtn:SetPoint("BOTTOM", 90, 30)
	badBtn:SetText("|T" .. ICONS.thumbdown .. ":16:16|t Bad")
	badBtn:SetScript("OnClick", function()
		if ns.db.players[playerKey] then
			ns.db.players[playerKey].lastRank = "BAD"
			ns.db.players[playerKey].rankBad = (ns.db.players[playerKey].rankBad or 0) + 1
		end
		print("SquadRank: Ranked " .. playerName .. " as |cffff2222BAD|r")
		dialog:Hide()
		if SquadRank.mainWindow and SquadRank.mainWindow:IsShown() then
			SquadRank:RefreshPlayerHistory()
		end
	end)

	local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
	cancelBtn:SetSize(60, 25)
	cancelBtn:SetPoint("TOP", badBtn, "BOTTOM", 0, -10)
	cancelBtn:SetText("Cancel")
	cancelBtn:SetScript("OnClick", function()
		dialog:Hide()
	end)

	dialog:Show()
	C_Timer.After(15, function()
		if dialog and dialog:IsShown() then
			dialog:Hide()
		end
	end)
end

function SquadRank:CreatePlayerHistoryFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:Hide()

	local filterFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	filterFrame:SetSize(1068, 60)
	filterFrame:SetPoint("TOP", 0, 0)
	filterFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 16, edgeSize = 8,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	filterFrame:SetBackdropColor(COLORS.secondary.r, COLORS.secondary.g, COLORS.secondary.b, 0.6)
	filterFrame:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, 0.4)

	local searchLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	searchLabel:SetPoint("LEFT", 25, 15)
	searchLabel:SetText("Search:")

	local searchBox = CreateFrame("EditBox", nil, filterFrame, "InputBoxTemplate")
	searchBox:SetSize(180, 25)
	searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript("OnTextChanged", function()
		ns.db.settings.searchText = searchBox:GetText()
		SquadRank:RefreshPlayerHistory()
	end)

	local classLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	classLabel:SetPoint("LEFT", 300, 15)
	classLabel:SetText("Class:")

	local classDropdown = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
	classDropdown:SetSize(120, 25)
	classDropdown:SetPoint("LEFT", classLabel, "RIGHT", 10, 0)
	classDropdown:SetText(ns.db.settings.filterClass or "ALL")

	local rankLabel = filterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	rankLabel:SetPoint("LEFT", 520, 15)
	rankLabel:SetText("Rank:")

	local rankDropdown = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
	rankDropdown:SetSize(100, 25)
	rankDropdown:SetPoint("LEFT", rankLabel, "RIGHT", 10, 0)
	rankDropdown:SetText(ns.db.settings.filterRank or "ALL")

	local clearBtn = CreateFrame("Button", nil, filterFrame, "UIPanelButtonTemplate")
	clearBtn:SetSize(80, 25)
	clearBtn:SetPoint("RIGHT", -25, 15)
	clearBtn:SetText("Clear")
	clearBtn:SetScript("OnClick", function()
		if searchBox then
			searchBox:SetText("")
			searchBox:ClearFocus()
		end
		ns.db.settings.searchText = ""
		ns.db.settings.filterClass = "ALL"
		ns.db.settings.filterRank = "ALL"
		if classDropdown then classDropdown:SetText("ALL") end
		if rankDropdown then rankDropdown:SetText("ALL") end
		SquadRank:RefreshPlayerHistory()
		print("SquadRank: Filters cleared")
	end)

	local dataFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	dataFrame:SetPoint("TOPLEFT", 0, -70)
	dataFrame:SetPoint("BOTTOMRIGHT", 0, 0)
	dataFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 16, edgeSize = 8,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	dataFrame:SetBackdropColor(0.05, 0.05, 0.1, 0.9)
	dataFrame:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, 0.3)

	local headerFrame = CreateFrame("Frame", nil, dataFrame)
	headerFrame:SetSize(1060, 30)
	headerFrame:SetPoint("TOP", 0, -8)

	local headers = {
		{text = "Player Name", x = 20},
		{text = "Realm", x = 200},
		{text = "Class", x = 310},
		{text = "Role", x = 430},
		{text = "Last Grouped", x = 510},
		{text = "Last Seen", x = 670},
		{text = "Rating", x = 820}
	}

	for _, header in ipairs(headers) do
		local text = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("LEFT", header.x, 0)
		text:SetText("|cffffff00" .. header.text .. "|r")
	end

	local clickHint = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	clickHint:SetPoint("RIGHT", -10, 0)
	clickHint:SetText("|cff888888Click player to rank|r")

	local scrollFrame = CreateFrame("ScrollFrame", nil, dataFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 8, -38)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

	local scrollChild = CreateFrame("Frame")
	scrollChild:SetSize(scrollFrame:GetWidth(), 1)
	scrollFrame:SetScrollChild(scrollChild)

	self.playerHistoryFrame = frame
	self.playerScrollChild = scrollChild
	self.playerSearchBox = searchBox
end

function SquadRank:RefreshPlayerHistory()
	if not self.playerScrollChild then return end

	local children = {self.playerScrollChild:GetChildren()}
	for _, child in ipairs(children) do
		if child then
			child:Hide()
			child:SetParent(nil)
		end
	end
	self.playerScrollChild:SetHeight(1)

	local yOffset = -5
	local index = 0
	local searchText = (ns.db.settings.searchText or ""):lower()

	local filteredPlayers = {}
	for key, data in pairs(ns.db.players or {}) do
		if key ~= playerKey and data.name and data.name ~= "Unknown" and data.name ~= playerName then
			local passesFilter = true

			if searchText ~= "" then
				local playerName = (data.name or ""):lower()
				if not playerName:find(searchText, 1, true) then
					passesFilter = false
				end
			end

			if ns.db.settings.filterClass and ns.db.settings.filterClass ~= "ALL" then
				if data.class ~= ns.db.settings.filterClass then
					passesFilter = false
				end
			end

			if ns.db.settings.filterRank and ns.db.settings.filterRank ~= "ALL" then
				if data.lastRank ~= ns.db.settings.filterRank then
					passesFilter = false
				end
			end

			if passesFilter then
				table.insert(filteredPlayers, {key = key, data = data})
			end
		end
	end

	table.sort(filteredPlayers, function(a, b)
		return (a.data.lastGrouped or "") > (b.data.lastGrouped or "")
	end)

	for _, playerInfo in ipairs(filteredPlayers) do
		local data = playerInfo.data
		local key = playerInfo.key
		index = index + 1

		local entry = CreateFrame("Button", nil, self.playerScrollChild, "BackdropTemplate")
		entry:SetSize(1040, 35)
		entry:SetPoint("TOPLEFT", 5, yOffset)

		if index % 2 == 0 then
			entry:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				tile = true, tileSize = 16,
				insets = { left = 0, right = 0, top = 0, bottom = 0 }
			})
			entry:SetBackdropColor(0.15, 0.15, 0.25, 0.4)
		else
			entry:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				tile = true, tileSize = 16,
				insets = { left = 0, right = 0, top = 0, bottom = 0 }
			})
			entry:SetBackdropColor(0.05, 0.05, 0.15, 0.2)
		end

		entry:SetScript("OnClick", function()
			CreatePlayerRankingDialog(key, data.name, data.class)
		end)

		entry:SetScript("OnEnter", function(self)
			self:SetBackdropColor(0.2, 0.3, 0.5, 0.6)
		end)

		entry:SetScript("OnLeave", function(self)
			if index % 2 == 0 then
				self:SetBackdropColor(0.15, 0.15, 0.25, 0.4)
			else
				self:SetBackdropColor(0.05, 0.05, 0.15, 0.2)
			end
		end)

		local nameText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		nameText:SetPoint("LEFT", 20, 0)
		nameText:SetWidth(175)
		nameText:SetJustifyH("LEFT")
		if data.class and data.class ~= "UNKNOWN" then
			nameText:SetText(GetClassColoredName(data.name or "Unknown", data.class))
		else
			nameText:SetText(data.name or "Unknown")
		end

		local realmText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		realmText:SetPoint("LEFT", 200, 0)
		realmText:SetWidth(105)
		realmText:SetJustifyH("LEFT")
		realmText:SetText(data.realm or "Unknown")

		local classText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		classText:SetPoint("LEFT", 310, 0)
		classText:SetWidth(115)
		classText:SetJustifyH("LEFT")
		if data.class then
			local r, g, b = GetClassColor(data.class)
			classText:SetTextColor(r, g, b)
			classText:SetText(data.class)
		else
			classText:SetText("Unknown")
		end

		local roleContainer = CreateFrame("Frame", nil, entry)
		roleContainer:SetPoint("LEFT", 430, 0)
		roleContainer:SetSize(75, 35)

		local roleIcon = roleContainer:CreateTexture(nil, "ARTWORK")
		roleIcon:SetSize(16, 16)
		roleIcon:SetPoint("LEFT", 5, 0)

		local roleText = roleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		roleText:SetPoint("LEFT", roleIcon, "RIGHT", 4, 0)
		roleText:SetWidth(50)
		roleText:SetJustifyH("LEFT")

		local role = self:GetPlayerRole(data.class)
		if role == "TANK" then
			roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
			roleText:SetTextColor(0.8, 0.6, 0.2)
			roleText:SetText("Tank")
		elseif role == "HEALER" then
			roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
			roleText:SetTextColor(0.2, 0.8, 0.2)
			roleText:SetText("Heal")
		else
			roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
			roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
			roleText:SetTextColor(0.8, 0.2, 0.2)
			roleText:SetText("DPS")
		end

		local dateText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		dateText:SetPoint("LEFT", 510, 0)
		dateText:SetWidth(155)
		dateText:SetJustifyH("LEFT")
		dateText:SetText(FormatDateToMMDDYY(data.lastGrouped))

		local lastSeenText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		lastSeenText:SetPoint("LEFT", 670, 0)
		lastSeenText:SetWidth(145)
		lastSeenText:SetJustifyH("LEFT")
		lastSeenText:SetText(data.lastLocation or "Unknown")

		local ratingText = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		ratingText:SetPoint("LEFT", 820, 0)
		ratingText:SetWidth(120)
		ratingText:SetJustifyH("LEFT")
		ratingText:SetText(VoteIconAndText(data.lastRank))

		yOffset = yOffset - 40
	end

	self.playerScrollChild:SetHeight(math.max(100, (index * 40) + 20))
end

function SquadRank:CreateSquadHistoryFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:Hide()

	local dataFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	dataFrame:SetAllPoints()
	dataFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 16, edgeSize = 8,
		insets = { left = 4, right = 4, top = 4, bottom = 4 }
	})
	dataFrame:SetBackdropColor(0.05, 0.05, 0.1, 0.9)
	dataFrame:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, 0.3)

	local scrollFrame = CreateFrame("ScrollFrame", nil, dataFrame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 8, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

	local scrollChild = CreateFrame("Frame")
	scrollChild:SetSize(scrollFrame:GetWidth(), 1)
	scrollFrame:SetScrollChild(scrollChild)

	self.squadHistoryFrame = frame
	self.squadScrollChild = scrollChild
end

function SquadRank:RefreshSquadHistory()
	if not self.squadScrollChild then return end

	local children = {self.squadScrollChild:GetChildren()}
	for _, child in ipairs(children) do
		if child then
			child:Hide()
			child:SetParent(nil)
		end
	end
	self.squadScrollChild:SetHeight(1)

	local totalSquads = 0
	for _ in pairs(ns.db.squadHistory or {}) do
		totalSquads = totalSquads + 1
	end
	
	if totalSquads == 0 then
		local noDataText = self.squadScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		noDataText:SetPoint("CENTER", 0, 0)
		noDataText:SetText("|cff888888No squad history found.|r\n\n|cff666666Join a group to start tracking!|r")
		noDataText:SetJustifyH("CENTER")
		self.squadScrollChild:SetHeight(100)
		return
	end

	local yOffset = -20
	local index = 0
	
	local sortedSquads = {}
	for squadId, data in pairs(ns.db.squadHistory or {}) do
		table.insert(sortedSquads, {id = squadId, data = data})
	end
	
	table.sort(sortedSquads, function(a, b)
		return (a.data.date or "") > (b.data.date or "")
	end)
	
	for _, squadInfo in ipairs(sortedSquads) do
		local data = squadInfo.data
		
		local playerCount = 0
		for pKey, pData in pairs(data.players or {}) do
			playerCount = playerCount + 1
		end
		
		if playerCount > 0 then
			local instanceHeader = CreateFrame("Frame", nil, self.squadScrollChild, "BackdropTemplate")
			instanceHeader:SetSize(1040, 45)
			instanceHeader:SetPoint("TOPLEFT", 10, yOffset)
			instanceHeader:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
				tile = true, tileSize = 16, edgeSize = 8,
				insets = { left = 8, right = 8, top = 8, bottom = 8 }
			})
			instanceHeader:SetBackdropColor(COLORS.primary.r, COLORS.primary.g, COLORS.primary.b, 0.7)
			instanceHeader:SetBackdropBorderColor(COLORS.accent.r, COLORS.accent.g, COLORS.accent.b, 0.9)

			local instanceIcon = instanceHeader:CreateTexture(nil, "ARTWORK")
			instanceIcon:SetTexture(GetInstanceIcon(data.type))
			instanceIcon:SetSize(32, 32)
			instanceIcon:SetPoint("LEFT", 15, 0)

			local instanceTitle = instanceHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
			instanceTitle:SetPoint("LEFT", instanceIcon, "RIGHT", 15, 0)
			instanceTitle:SetText("|cff00bfff" .. (data.location or "Unknown Location") .. "|r")

			local playerCountText = instanceHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			playerCountText:SetPoint("RIGHT", -15, 0)
			playerCountText:SetTextColor(0.8, 0.8, 0.8)
			playerCountText:SetText(playerCount .. " players")

			yOffset = yOffset - 50
			index = index + 1

			local playerList = {}
			for pKey, pData in pairs(data.players or {}) do
				table.insert(playerList, {key = pKey, data = pData})
			end

			table.sort(playerList, function(a, b)
				local roleA = self:GetPlayerRole(a.data.class) or "DPS"
				local roleB = self:GetPlayerRole(b.data.class) or "DPS"
				local roleOrder = {TANK = 1, HEALER = 2, DPS = 3}
				return (roleOrder[roleA] or 3) < (roleOrder[roleB] or 3)
			end)

			for _, playerInfo in ipairs(playerList) do
				local playerData = playerInfo.data
				local pKey = playerInfo.key

				local playerRow = CreateFrame("Frame", nil, self.squadScrollChild, "BackdropTemplate")
				playerRow:SetSize(1040, 30)
				playerRow:SetPoint("TOPLEFT", 25, yOffset)
				playerRow:SetBackdrop({
					bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
					tile = true, tileSize = 16,
					insets = { left = 0, right = 0, top = 0, bottom = 0 }
				})
				playerRow:SetBackdropColor(0.05, 0.05, 0.15, 0.4)

				local roleIcon = playerRow:CreateTexture(nil, "ARTWORK")
				roleIcon:SetSize(20, 20)
				roleIcon:SetPoint("LEFT", 15, 0)

				local role = self:GetPlayerRole(playerData.class)
				if role == "TANK" then
					roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
					roleIcon:SetTexCoord(0, 19/64, 22/64, 41/64)
				elseif role == "HEALER" then
					roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
					roleIcon:SetTexCoord(20/64, 39/64, 1/64, 20/64)
				else
					roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
					roleIcon:SetTexCoord(20/64, 39/64, 22/64, 41/64)
				end

				local playerText = playerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				playerText:SetPoint("LEFT", roleIcon, "RIGHT", 12, 0)
				playerText:SetWidth(200)
				playerText:SetJustifyH("LEFT")

				local displayName = playerData.name or "Unknown"
				local displayRealm = playerData.realm or "Unknown"
				local fullDisplayName = displayName .. "-" .. displayRealm
				
				if playerData.class and playerData.class ~= "UNKNOWN" then
					playerText:SetText(GetClassColoredName(fullDisplayName, playerData.class))
				else
					playerText:SetText(fullDisplayName)
				end

				local roleText = playerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
				roleText:SetPoint("LEFT", 250, 0)
				roleText:SetWidth(80)
				roleText:SetJustifyH("LEFT")

				if role == "TANK" then
					roleText:SetTextColor(0.8, 0.6, 0.2)
					roleText:SetText("Tank")
				elseif role == "HEALER" then
					roleText:SetTextColor(0.2, 0.8, 0.2)
					roleText:SetText("Healer")
				else
					roleText:SetTextColor(0.8, 0.2, 0.2)
					roleText:SetText("DPS")
				end

				local rankText = playerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
				rankText:SetPoint("LEFT", 340, 0)
				rankText:SetWidth(150)
				rankText:SetJustifyH("LEFT")

				local currentPlayerData = ns.db.players[pKey]
				if currentPlayerData and currentPlayerData.lastRank and currentPlayerData.lastRank ~= "" then
					rankText:SetText(VoteIconAndText(currentPlayerData.lastRank))
				else
					rankText:SetText("|cff666666No Rating|r")
				end

				if playerData.replacedPlayer then
					local replacementText = playerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
					replacementText:SetPoint("LEFT", 500, 0)
					replacementText:SetTextColor(0.8, 0.8, 0.0)
					replacementText:SetText("(Replaced " .. (ns.db.players[playerData.replacedPlayer] and ns.db.players[playerData.replacedPlayer].name or "Unknown") .. ")")
				end

				yOffset = yOffset - 35
				index = index + 1
			end

			yOffset = yOffset - 15
		end
	end

	self.squadScrollChild:SetHeight(math.max(100, math.abs(yOffset) + 50))
end

function SquadRank:RefreshCurrentTab()
	if self.activeTab == "players" then
		self:RefreshPlayerHistory()
	elseif self.activeTab == "squads" then
		self:RefreshSquadHistory()
	end
end

function SquadRank:CreateSettingsFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:Hide()

	local settingsFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	settingsFrame:SetSize(700, 500)
	settingsFrame:SetPoint("CENTER")
	settingsFrame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\Glues\\Common\\TextPanel-Border",
		tile = true, tileSize = 16, edgeSize = 8,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	})
	settingsFrame:SetBackdropColor(COLORS.secondary.r, COLORS.secondary.g, COLORS.secondary.b, 0.8)
	settingsFrame:SetBackdropBorderColor(COLORS.border.r, COLORS.border.g, COLORS.border.b, 0.6)

	local title = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -20)
	title:SetText("|cff00bfffSquadRank Settings|r")

	local infoText = settingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	infoText:SetPoint("CENTER", 0, 0)
	infoText:SetText("Settings panel - Coming soon!")

	self.settingsFrame = frame
end

-- === Event Handler ===
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ENCOUNTER_START")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" and ... == addonName then
		InitializeDB()
		CreateMinimapIcon()
		print("|T" .. ICONS.squadrank .. ":16:16|t |cff00bfffSquadRank v2.0 ENCOUNTER-BASED|r loaded successfully!")
		print("Type |cffffff00/squadrank|r to open the main window")
		print("SquadRank: Now using boss encounters to group players!")
	elseif event == "ENCOUNTER_START" then
		local encounterID, encounterName = ...
		OnEncounterStart(encounterID, encounterName)
	elseif event == "ENCOUNTER_END" then
		local encounterID, encounterName, difficultyID, groupSize, success = ...
		OnEncounterEnd(encounterID, encounterName, success == 1)
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- Finish previous run when leaving instance
		if currentInstanceRun then
			FinishInstanceRun()
		end
	elseif event == "GROUP_ROSTER_UPDATE" then
		UpdateGroupMembers()
	end
end)

-- === Slash Commands ===
SLASH_SQUADRANK1 = "/squadrank"
SlashCmdList["SQUADRANK"] = function()
	SquadRank:ToggleMainWindow()
end

SLASH_SQUADRANKHELP1 = "/srhelp"
SlashCmdList["SQUADRANKHELP"] = function()
	print("|cff00bfffSquadRank Commands:|r")
	print("|cffffff00/squadrank|r - Open SquadRank window")
	print("|cffffff00/srhelp|r - Show this help")
	print("|cffffff00/srfinish|r - Manually finish current instance run")
end

SLASH_SQUADRANKFINISH1 = "/srfinish"
SlashCmdList["SQUADRANKFINISH"] = function()
	FinishInstanceRun()
	print("SquadRank: Manually finished instance run")
end
