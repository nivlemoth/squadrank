-- /sr debug: a window with the debug report in a text box, ready to copy.
local _, ns = ...

local L = ns.L
local UI = ns.UI
local Debug = ns.Debug

local DebugPanel = {}
ns.DebugPanel = DebugPanel

local frame, editBox

local function refresh()
	local text = Debug.ReportText()
	Debug.Mirror()
	editBox:SetText(text)
	editBox:SetCursorPosition(0)
end

local function build()
	frame = UI.CreateWindow(600, 440, L.DEBUG_TITLE)

	local hint = UI.Text(frame.content, "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 2, 0)
	hint:SetText(L.DEBUG_HINT)

	local scroll = CreateFrame("ScrollFrame", nil, frame.content, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -18)
	scroll:SetPoint("BOTTOMRIGHT", -26, 32)

	editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetWidth(540)
	editBox:SetScript("OnEscapePressed", editBox.ClearFocus)
	scroll:SetScrollChild(editBox)

	local selftest = UI.Button(frame.content, L.BTN_SELFTEST, 130, 22, function()
		ns.SelfTest.Run()
		refresh()
	end)
	selftest:SetPoint("BOTTOMLEFT", 0, 2)

	local again = UI.Button(frame.content, L.BTN_REFRESH, 100, 22, refresh)
	again:SetPoint("LEFT", selftest, "RIGHT", 8, 0)
end

function DebugPanel.Show()
	if not frame then
		build()
	end
	refresh()
	frame:Show()
end
