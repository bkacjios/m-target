love.filesystem.setRequirePath("?.lua;?/init.lua;modules/?.lua;modules/?/init.lua")

math.randomseed(love.timer.getTime())

-- Read version file and strip any trailing whitespace
local VERSION = love.filesystem.read("version.txt"):match("^(%S+)")

function love.getMOverlayVersion()
	return VERSION or "0.0.0"
end

require("console")
require("errorhandler")
require("extensions.love")

local log = require("log")
local melee = require("melee")
local memory = require("memory")
local perspective = require("perspective")
local notification = require("notification")

local targets = require("targets")

local color = require("util.color")
local gui = require("gui")

local ease = require("ease")

local graphics = love.graphics
local newImage = graphics.newImage

local PORT_FONT = graphics.newFont("fonts/melee-bold.otf", 42)
local WAITING_FONT = graphics.newFont("fonts/melee-bold.otf", 24)

local GRADIENT = newImage("textures/gradient.png")
local DOLPHIN = newImage("textures/dolphin.png")
local GAME = newImage("textures/game.png")
local MELEE = newImage("textures/meleedisk.png")
local MELEELABEL = newImage("textures/meleedisklabel.png")
local SHADOW = newImage("textures/shadow.png")

function love.updateTitle(str)
	love.window.setTitle(str)
end

function love.getTitleNoPort()
	return portless_title
end

function love.load(args, unfilteredArg)
	melee.loadtextures()
	gui.init()
	love.keyboard.setKeyRepeat(true)

	PANEL_SETTINGS = gui.create("Settings")
	PANEL_SETTINGS:LoadSettings()
	PANEL_SETTINGS:SetVisible(false)

	if memory.hasPermissions() then
		love.updateTitle("M'Target - Waiting for Dolphin...")
	else
		love.updateTitle("M'Target - Invalid permissions...")
		--notification.error()
	end
end

function love.update(dt)
	memory.update() -- Look for Dolphin.exe
	notification.update(8, 0)
	gui.update(dt)
end

function love.resize(w, h)
	gui.resize(w, h)
end

function love.joystickpressed(joy, but)
	gui.joyPressed(joy, but)
end

function love.joystickreleased(joy, but)
	gui.joyReleased(joy, but)
end

function love.keypressed(key, scancode, isrepeat)
	if key == "escape" and not isrepeat then
		PANEL_SETTINGS:Toggle()
	end

	gui.keyPressed(key, scancode, isrepeat)

	local num = tonumber(string.match(key, "kp(%d)") or key)

	if not PANEL_SETTINGS:IsVisible() and num and num >= 1 and num <= 4 then
		love.setPort(num)
		PORT_DISPLAY_OVERRIDE = nil
		CONTROLLER_PORT_DISPLAY = love.timer.getTime() + 1.5
	end
end

function love.keyreleased(key)
	gui.keyReleased(key)
end

function love.textinput(text)
	gui.textInput(text)
end

function love.mousemoved(x, y, dx, dy, istouch)
	gui.mouseMoved(x, y, dx, dy, istouch)
end

function love.mousepressed(x, y, button, istouch, presses)
	gui.mousePressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
	gui.mouseReleased(x, y, button, istouch, presses)
end

function love.wheelmoved(x, y)
	gui.mouseWheeled(x, y)
end

do
	local icon_time_start
	local icon_time_show
	local icon_time_next

	local icon_rotate = 0

	local canvas = love.graphics.newCanvas()

	function love.drawTrobber(game)
		local t = love.timer.getTime()
		local dt = love.timer.getDelta()

		local lx = 0
		local ly = math.sin(t*3) * 4
		local rx = icon_rotate

		local rotate_speed = 0
		
		if not game then
			if not icon_time_start or icon_time_next < t then
				icon_time_start = t
				icon_time_show = t + 1
				icon_time_next = t + 2
			end

			local anim = 0
			if icon_time_show > t then
				anim = ease.sigmoid(math.min(1, (t - icon_time_start)/1))
				lx = ease.lerp(0, -160, anim)
				ly = ease.lerp(0, 64, anim)
				rx = ease.lerp(0, -90, anim)
			else
				anim = ease.outback(math.min(1, (t - icon_time_show)/1))
				lx = ease.lerp(160, 0, anim)
				ly = ease.lerp(64, 0, anim)
				rx = ease.lerp(90, 0, anim)
			end
		else
			rotate_speed = math.sinlerp(0, 360*4*dt/2, t/2)
			icon_rotate = (icon_rotate + rotate_speed) % 360
		end

		graphics.setColor(255, 255, 255, 255)

		graphics.setCanvas(canvas)

		graphics.clear(0,0,0,0)
		if not game then
			graphics.setBlendMode("replace", "premultiplied")
		end

		graphics.setScissor(160-80-20, 0, 160+40, 160)

		local icon = game and MELEE or DOLPHIN

		graphics.setColor(255, 255, 255, 255)
		graphics.easyDraw(icon, 160+lx, 64+40+ly, math.rad(rx), 80, 80, 0.5, 0.5)
		
		if game then
			local p = rotate_speed/13

			for i=0, 16 do
				local j = rotate_speed - i
				graphics.setColor(255, 255, 255, rotate_speed*4)
				graphics.easyDraw(MELEELABEL, 160+lx, 64+40+ly, math.rad(rx-(i*p*4)), 80, 80, 0.5, 0.5)
			end
		end

		graphics.setScissor()

		if not game then
			graphics.setBlendMode("multiply", "premultiplied")

			graphics.easyDraw(GRADIENT, 160-80-20, 0, 0, 80, 256)
			graphics.easyDraw(GRADIENT, 160+80+20, 0, math.rad(180), 80, 256, 0, 1)
		end

		graphics.setCanvas()

		graphics.setBlendMode("alpha", "alphamultiply")

		if game then
			local sw = math.sinlerp(0.5, 1, t*3)
			graphics.setColor(125, 125, 125, 150)
			graphics.easyDraw(SHADOW, 160, 154, 0, 64*sw, 6*sw, 0.5, 0.5)
		end

		graphics.setColor(255, 255, 255, 255)
		graphics.draw(canvas)
	end
end

do
	local ellipses = {".", "..", "..."}

	function love.drawNotificationText(msg)
		local t = love.timer.getTime()

		local w = WAITING_FONT:getWidth(msg)
		local h = WAITING_FONT:getHeight()
		local x = 160 - (w/2)
		local y = 128+32

		local i = math.floor(t % #ellipses) + 1

		msg = msg .. ellipses[i]

		graphics.setFont(WAITING_FONT)
		graphics.setColor(0, 0, 0, 255)
		graphics.textOutline(msg, 3, x, y)
		graphics.setColor(255, 255, 255, 255)
		graphics.print(msg, x, y)
	end
end

function love.supportsGameCapture()
	return jit.os:lower() == "windows"
end

--[[memory.hook("stage.homerun_distance", "DISTANCE UPDATE", function(distance)
	log.info("Homerun distance: %f", distance/(12*2.54))
end)]]

function love.draw()
	if not love.supportsGameCapture() then
		graphics.setBackgroundColor(100, 100, 100, 255)
	else
		-- Default to completely transparent, makes the overlay completely invisible when not in a game!
		local alpha = 0

		if (memory.initialized and memory.game) or PANEL_SETTINGS:IsVisible() then
			-- Only apply transparency when we are watching a games memory.
			alpha = 255 - ((PANEL_SETTINGS:GetTransparency() / 100) * 255)
		end

		-- Transparent background for OBS
		graphics.setBackgroundColor(0, 0, 0, alpha)

		-- Show a preview for transparency
		if PANEL_SETTINGS:IsVisible() then
			graphics.setBackgroundColor(255, 255, 255, alpha)

			for x=0, 320/32 do
				for y=0, 448/32 do
					graphics.setColor(240, 240, 240, 255)
					graphics.rectangle("fill", 32 * (x + (y%2)), 32 * (y + (x%2)), 32, 32)
				end
			end

			graphics.setColor(0, 0, 0, alpha)
			graphics.rectangle("fill", 0, 0, 320, 448)

			--[[graphics.setColor(0, 0, 0, 100)
			graphics.rectangle("fill", 512 - 20, 0, 20, 256)

			local rad = math.rad(90)

			graphics.setFont(DEBUG_FONT)
			graphics.setColor(0, 0, 0, 255)
			graphics.print(VERSION, 512 - 5, 5, rad)
			graphics.setColor(255, 255, 255, 255)
			graphics.print(VERSION, 512 - 4, 4, rad)]]
		end
	end

	if memory.initialized and memory.game and memory.controller then
		targets.drawSplits()
	else
		if memory.hooked then
			love.drawTrobber(true)
			love.drawNotificationText("Waiting for melee")
		else
			love.drawTrobber()
			love.drawNotificationText("Waiting for dolphin")
		end
	end

	gui.render()
	notification.draw()
end

local FPS_LIMIT = 60

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
 
	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end
 
	local dt = 0
 
	-- Main loop time.
	return function()
		local frame_start = love.timer.getTime()

		-- Process events.
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a or 0
					end
				end
				love.handlers[name](a,b,c,d,e,f)
			end
		end
 
		-- Update dt, as we'll be passing it to update
		if love.timer then dt = love.timer.step() end
 
		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled
 
		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
 
			if love.draw then love.draw() end
 
			love.graphics.present()
		end
 
		if love.timer then
			local frame_time = love.timer.getTime() - frame_start
			love.timer.sleep(1 / FPS_LIMIT - frame_time)
		end
	end
end

function love.quit()
	targets.endAttempt()
	PANEL_SETTINGS:SaveSettings()
	gui.shutdown()
end