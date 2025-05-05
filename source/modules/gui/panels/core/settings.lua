local PANEL = {}

local log = require("log")
local json = require("serializer.json")
local notification = require("notification")

require("extensions.math")

function PANEL:Initialize()
	self:super()

	--self:SetTitle("Settings")
	--self:DockPadding(1, 32, 1, 1)
	--self:SetHideOnClose(true)
	self:DockPadding(0, 0, 0, 0)
	self:SetSize(148 + 16, 256)
	self:Center()
	self:SetBackgroundColor(color(0, 0, 0, 100))

	local LEFT = self:Add("Panel")
	LEFT:DockMargin(0,0,0,0)
	LEFT:DockPadding(4,4,4,4)
	LEFT:SetBorderColor(color_clear)
	LEFT:SetBackgroundColor(color_clear)
	LEFT:SetWidth(164)
	LEFT:Dock(DOCK_LEFT)

	local GLABEL = LEFT:Add("Label")
	GLABEL:SetText("General")
	GLABEL:SetTextAlignment("center")
	GLABEL:SizeToText()
	GLABEL:SetHeight(14)
	GLABEL:Dock(DOCK_TOP)
	GLABEL:SetTextColor(color_white)
	GLABEL:SetShadowDistance(1)
	GLABEL:SetShadowColor(color_black)
	GLABEL:SetFont("fonts/melee-bold.otf", 14)

	if love.system.getOS() == "Windows" then
		self.DEBUG = LEFT:Add("Checkbox")
		self.DEBUG:SetText("Debug console")
		self.DEBUG:Dock(DOCK_TOP)

		function self.DEBUG:OnToggle(on)
			love.console(on)
		end
	end

	self.DELTA_FRAMES = LEFT:Add("Checkbox")
	self.DELTA_FRAMES:SetText("Delta as Frames")
	self.DELTA_FRAMES:Dock(DOCK_TOP)

	if love.supportsGameCapture() then
		local TLABEL = LEFT:Add("Label")
		TLABEL:SetText("Transparency")
		TLABEL:SizeToText()
		TLABEL:Dock(DOCK_TOP)
		TLABEL:SetTextColor(color_white)
		TLABEL:SetShadowDistance(1)
		TLABEL:SetShadowColor(color_black)
		TLABEL:SetFont("fonts/melee-bold.otf", 12)

		self.TRANSPARENCY = LEFT:Add("Slider")
		self.TRANSPARENCY:SetValue(100)
		self.TRANSPARENCY:Dock(DOCK_TOP)

		function self.TRANSPARENCY:OnValueChanged(i)
			TLABEL:SetText(("Transparency - %d%%"):format(i))
		end
	end

	self.CONFIGDIR = LEFT:Add("Button")
	self.CONFIGDIR:SetText("Open config directory")
	self.CONFIGDIR:Dock(DOCK_TOP)

	function self.CONFIGDIR:OnClick()
		love.system.openURL(("file://%s"):format(love.filesystem.getSaveDirectory()))
	end

	self.m_sFileName = "config.json"

	local VLABEL = LEFT:Add("Label")
	VLABEL:SetText(love.getMOverlayVersion())
	VLABEL:SetTextAlignment("center")
	VLABEL:SizeToText()
	VLABEL:SetHeight(18)
	VLABEL:Dock(DOCK_TOP)
	VLABEL:SetTextColor(color_white)
	VLABEL:SetShadowDistance(1)
	VLABEL:SetShadowColor(color_black)
	VLABEL:SetFont("fonts/melee-bold.otf", 12)
end

function PANEL:Toggle()
	self:SetVisible(not self:IsVisible())
	if not self:IsVisible() then
		self:OnClosed()
	end
	self:Center()
end

function PANEL:GetSaveTable()
	return {
		["debugging"] = self:IsDebugging(),
		["transparency"] = self:GetTransparency(),
		["deltaframes"] = self:ShowDeltaFrames(),
	}
end

function PANEL:IsDebugging()
	return self.DEBUG and self.DEBUG:IsToggled() or false
end

function PANEL:GetTransparency()
	return self.TRANSPARENCY and self.TRANSPARENCY:GetValue() or nil
end

function PANEL:ShowDeltaFrames()
	return self.DELTA_FRAMES and self.DELTA_FRAMES:IsToggled() or false
end

function PANEL:OnClosed()
	self:SaveSettings()
end

function PANEL:NeedsWrite()
	for k,v in pairs(self:GetSaveTable()) do
		-- Return true if the last known settings state differs from the current
		if self.m_tSettings[k] == nil or self.m_tSettings[k] ~= v then
			return true
		end
	end
	return false
end

function PANEL:SaveSettings()
	if not self:NeedsWrite() then return end -- Stop if we don't need to write any changes
	local f, err = filesystem.newFile(self.m_sFileName, "w")
	if f then
		notification.warning(("Writing to %s"):format(self.m_sFileName))
		self.m_tSettings = self:GetSaveTable()
		f:write(json.encode(self.m_tSettings, true))
		f:flush()
		f:close()
	else
		notification.error(("Failed writing to %s (%s)"):format(self.m_sFileName, err))
	end
end

function PANEL:LoadSettings()
	local settings = self:GetSaveTable()

	local f = filesystem.newFile(self.m_sFileName, "r")
	if f then
		for k,v in pairs(json.decode(f:read())) do
			if settings[k] ~= nil then
				settings[k] = v
			end
		end
		f:close()
	end

	self.m_tSettings = settings

	if self.DEBUG then self.DEBUG:SetToggle(love.hasConsole() or settings["debugging"] or false) end
	if self.TRANSPARENCY then self.TRANSPARENCY:SetValue(settings["transparency"] or 100) end
	if self.DELTA_FRAMES then self.DELTA_FRAMES:SetToggle(settings["deltaframes"] or false) end
end

gui.register("Settings", PANEL, "Panel")