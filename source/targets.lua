local targets = {
	TIME_FRAMES = {},
	TIME_FRAMES_PB = {},
	TIME_FRAME = 0,
	BROKEN = 0,
	PREV_BROKEN_FRAME = 0,
	RUN_ID = nil,
	RUN_IN_PROGRESS = false,
	CHARACTER_DATA = {},
	IN_DISPLAY_MENU = nil,
	DISPLAY_MODE = 0x1,
}

local log = require("log")
local memory = require("memory")
local melee = require("melee")
local lsqlite3 = require("lsqlite3")

local graphics = love.graphics

local FRAME_FONT = graphics.newFont("fonts/melee-bold.otf", 14)
local SPLIT_SEC = FRAME_FONT
local SPLIT_MS = graphics.newFont("fonts/melee-bold.otf", 9)
local TOTAL_SEC = graphics.newFont("fonts/melee-bold.otf", 32)
local TOTAL_MS = graphics.newFont("fonts/melee-bold.otf", 20)

local TARGET = graphics.newImage("textures/target.png")

local DPAD_GATE = graphics.newImage("textures/buttons/d-pad-gate-filled.png")

local RESULT_NONE		= 0x0	-- Set at the start
local RESULT_FAILURE	= 0x4	-- Fell off the stage
local RESULT_COMPLETE	= 0x6	-- Successfully hit all targets
local RESULT_LRAS		= 0x7	-- Quit using L+R+A+Start
local RESULT_RESET		= 0x8	-- Reset using Z

local MODE_LAST_FAILED = 0x0
local MODE_LAST_COMPLETE = 0x1
local MODE_PB = 0x2
local MODE_BEST = 0x03

local function getMeleeTimpstamp(frame)
	local duration = frame/60
	local minutes = math.floor(duration/60)
	local seconds = math.floor(duration)
	local ms = (frame % 60) * 100 / 60
	return seconds, math.floor(ms)
end

local timedb = lsqlite3.open(string.format("%s/time.db", love.filesystem.getSaveDirectory()))

timedb:exec([[CREATE TABLE IF NOT EXISTS runs (
	run			INTEGER PRIMARY KEY AUTOINCREMENT,
	character	INTEGER, -- character that was used
	tframe		INTEGER, -- #frames the timer spent active
	gframe		INTEGER, -- #frames in total (including before timer start)
	targets		INTEGER, -- #targets that were hit
	result		INTEGER	 -- result status at the end (complete, failure, retry, etc)
);]])

timedb:exec([[CREATE TABLE IF NOT EXISTS splits (
	run			INTEGER NOT NULL, -- the RUN_ID that this split is tied to
	target		INTEGER, -- target number this split was for
	tframe		INTEGER, -- #frames the timer spent to achieve this split
	gframe		INTEGER,  -- #frames in total spent to achieve this split (including before timer start)
	time		INTEGER, -- #frames spent between last split and this split
	UNIQUE(run,target) -- we should never have duplicate targets in a given run
);]])

function targets.getCharacter()
	return memory.player[1].select.character
end

function targets.getActivePort()
	return memory.menu.player_one_port+1
end

function targets.updateCDATA(character, name, data)
	if not targets.CHARACTER_DATA[character] then
		targets.CHARACTER_DATA[character] = {}
	end
	targets.CHARACTER_DATA[character][name] = data
end

function targets.getCDATA(character, name)
	if targets.CHARACTER_DATA[character] then
		return targets.CHARACTER_DATA[character][name]
	end
end

function targets.updateCharRuns(character)
	local stmt = timedb:prepare("SELECT COUNT(*) FROM runs WHERE character=?")
	stmt:bind_values(character)
	stmt:step()
	targets.updateCDATA(character, "NumRuns", stmt[0])
	stmt:finalize()
end

function targets.getBestTime(character)
	local stmt = timedb:prepare("SELECT tframe FROM runs WHERE character=? AND gframe IS NOT NULL AND result=6 ORDER BY gframe ASC LIMIT 1;")
	stmt:bind_values(character)

	stmt:step()
	targets.updateCDATA(character, "BestTime", stmt[0])

	stmt:finalize()
	return data
end

function targets.loadLastFailedRun(character)
	local stmt = timedb:prepare([[
SELECT tframe
FROM splits
WHERE run = (SELECT run FROM runs WHERE character=? AND result<>6 ORDER BY run DESC LIMIT 1)
ORDER BY target;]])
	stmt:bind_values(character)

	targets.TIME_FRAMES = {}

	for row in stmt:rows() do
		table.insert(targets.TIME_FRAMES, row[1])
	end

	stmt:finalize()
end

function targets.loadLastCompleteRun(character)
	local stmt = timedb:prepare([[
SELECT tframe
FROM splits
WHERE run = (SELECT run FROM runs WHERE character=? AND result=6 ORDER BY run DESC LIMIT 1)
ORDER BY target;]])
	stmt:bind_values(character)

	targets.TIME_FRAMES = {}

	for row in stmt:rows() do
		table.insert(targets.TIME_FRAMES, row[1])
	end

	stmt:finalize()
end

function targets.loadPersonalBestRun(character)
	local stmt = timedb:prepare([[
SELECT tframe
FROM splits
WHERE run = (SELECT run FROM runs WHERE character=? AND result=6 ORDER BY gframe LIMIT 1)
ORDER BY target;]])
	stmt:bind_values(character)

	targets.TIME_FRAMES_PB = {}

	for row in stmt:rows() do
		table.insert(targets.TIME_FRAMES_PB, row[1])
	end

	targets.TIME_FRAMES = targets.TIME_FRAMES_PB

	stmt:finalize()
end

function targets.loadPossibleBestRun(character)
	local stmt = timedb:prepare([[
SELECT min(splits.time) as time
FROM runs
INNER JOIN splits on splits.run = runs.run
WHERE runs.character=? AND runs.result=6
GROUP BY splits.target
ORDER BY splits.target]])
	stmt:bind_values(character)

	targets.TIME_FRAMES = {}

	local tframe = 0

	for row in stmt:nrows() do
		tframe = tframe + row.time
		table.insert(targets.TIME_FRAMES, tframe)
	end

	stmt:finalize()
end

function targets.getSumOfBest(character)
	local stmt = timedb:prepare([[
SELECT SUM(time) FROM (
	SELECT min(splits.time) AS time
	FROM runs
	INNER JOIN splits on splits.run = runs.run
	WHERE runs.character=? AND runs.result=6
	GROUP BY splits.target
	ORDER BY splits.target
)]])
	stmt:bind_values(character)

	stmt:step()
	targets.updateCDATA(character, "SumOfBestTime", stmt[0])

	stmt:finalize()
	return data
end

function targets.setDisplayMode(mode)
	targets.DISPLAY_MODE = mode
	targets.updateDisplayMode()
end

function targets.updateDisplayMode()
	local character = targets.getCharacter()
	local mode = targets.DISPLAY_MODE
	if mode == MODE_LAST_FAILED then
		targets.loadLastFailedRun(character)
	elseif mode == MODE_LAST_COMPLETE then
		targets.loadLastCompleteRun(character)
	elseif mode == MODE_PB then
		targets.loadPersonalBestRun(character)
	elseif mode == MODE_BEST then
		targets.loadPossibleBestRun(character)
	end
	targets.BROKEN = #targets.TIME_FRAMES
	targets.TIME_FRAME = targets.TIME_FRAMES[#targets.TIME_FRAMES]
end

function targets.updateCharacterStats(character)
	targets.updateDisplayMode()
	targets.updateCharRuns(character)
	targets.getBestTime(character)
	targets.getSumOfBest(character)
end

function targets.startRun()
	local character = targets.getCharacter()
	local stmt = timedb:prepare("INSERT INTO runs (character) VALUES (?);")
	stmt:bind_values(character)
	stmt:step()
	stmt:finalize()
	targets.RUN_ID = timedb:last_insert_rowid()
	return targets.RUN_ID
end

function targets.saveSplit(target, frames)
	targets.newRun()
	targets.TIME_FRAMES[target] = frames
	local timespent = (targets.TIME_FRAMES[target] or 0) - (targets.TIME_FRAMES[target-1] or 0)
	local stmt = timedb:prepare("INSERT INTO splits (run, target, tframe, gframe, time) VALUES (?,?,?,?,?);")
	stmt:bind_values(targets.RUN_ID, target, memory.match.timer.frame, memory.frame, timespent)
	stmt:step()
	stmt:finalize()
	if target >= 10 then
		-- We force the RESULT_COMPLETE here instead of a match.result hook.
		-- This is because sometimes resetting back to RESULT_NONE is too fast for us to catch.
		-- So if you did two complete runs in a row, the change will never be detected
		-- and we would get stuck in a infinite run
		targets.endRun(RESULT_COMPLETE)
	end
end

function targets.saveResults(result)
	local stmt = timedb:prepare("UPDATE runs SET tframe=?, gframe=?, targets=?, result=? WHERE run=?;")
	stmt:bind_values(memory.match.timer.frame, memory.frame, 10 - memory.stage.targets, result or memory.match.result, targets.RUN_ID)
	stmt:step()
	stmt:finalize()
end

function targets.isValidRun()
	return targets.RUN_IN_PROGRESS
end

function targets.newRun()
	if not targets.isValidRun() then
		log.info("Started run #%d at game frame %d", targets.startRun(), memory.frame)
		targets.IN_DISPLAY_MENU = nil
		targets.DISPLAY_MODE = MODE_LAST_FAILED
		targets.RUN_IN_PROGRESS = true
		targets.TIME_FRAMES = {}
		targets.TIME_FRAME = 0
		targets.BROKEN = 0
	end
end

function targets.endRun(result)
	if targets.isValidRun() then
		targets.RUN_IN_PROGRESS = false
		log.info("Ended run #%d at frame %d - time %02d.%02d", targets.RUN_ID, memory.match.timer.frame, getMeleeTimpstamp(memory.match.timer.frame))
		targets.saveResults(result)
		targets.updateCharacterStats(character)
	end
end

memory.hook("player.1.select.character", "Targets - Update Count", function(character)
	targets.updateCharacterStats(character)
end)

memory.hook("match.result", "Targets - Check start of game", function(result)
	if result ~= RESULT_NONE then
		targets.endRun(result)
	end
end)

local prev_remain = 0

memory.hook("match.timer.frame", "Targets - Check restart", function(frame)
	if frame == 0 then
		targets.endRun()
		targets.newRun()
		prev_remain = 10
	end
end)

memory.hook("stage.targets", "Targets - Save Split", function(remain)
	local frame = memory.match.timer.frame

	-- Ignore when hitting 0 or 10 at frame 0, this is usally when loading into the target test or retrying
	if (remain == 10 or remain == 0) and frame == 0 then return end

	local count = prev_remain - remain
	local decresed = prev_remain > remain

	local endpos = 10-remain
	local startpos = 10-prev_remain

	prev_remain = remain

	if decresed and memory.match.finished == false then
		-- Only log splits when the target count decreases
		for i=startpos+1, endpos do
			-- We can hit more than one target in a single frame, so loop through and mark every single one as hit
			log.info("Hit target #%d at frame %d - time %02d.%02d", i, memory.match.timer.frame, getMeleeTimpstamp(memory.match.timer.frame))
			targets.saveSplit(i, memory.match.timer.frame)
		end
		targets.BROKEN = endpos
	end
end)

local DPAD = {
	[0x1] = MODE_LAST_FAILED,	-- LEFT
	[0x2] = MODE_LAST_COMPLETE,	-- RIGHT
	[0x4] = MODE_BEST,			-- DOWN
	[0x8] = MODE_PB,			-- UP
}

local MENU_TEXT = graphics.newImage("textures/buttons/labels.png")

local DPAD_TEXTURES = {
	[0x1] = graphics.newImage("textures/buttons/d-pad-pressed-left.png"),
	[0x2] = graphics.newImage("textures/buttons/d-pad-pressed-right.png"),
	[0x4] = graphics.newImage("textures/buttons/d-pad-pressed-down.png"),
	[0x8] = graphics.newImage("textures/buttons/d-pad-pressed-up.png"),
}

memory.hook("controller.*.buttons.pressed", "Targets - Mode Switcher", function(port, pressed)
	if port ~= targets.getActivePort() or targets.isValidRun() then return end

	if DPAD[pressed] then
		targets.IN_DISPLAY_MENU = DPAD[pressed]
	elseif targets.IN_DISPLAY_MENU and pressed == 0x0 then
		targets.setDisplayMode(targets.IN_DISPLAY_MENU)
		targets.IN_DISPLAY_MENU = nil
	end
end)

local greyscale = graphics.newShader[[
extern number percent;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 pixel = Texel(texture, texture_coords);
	float grey = 0.36 * pixel.r + 0.41 * pixel.g + 0.23 * pixel.b;
	pixel.r = pixel.r * percent + grey * (1.0 - percent);
	pixel.g = pixel.g * percent + grey * (1.0 - percent);
	pixel.b = pixel.b * percent + grey * (1.0 - percent);
	pixel.a = pixel.a * color.a;
	return pixel;
}
]]

function targets.drawSplits()
	local port = targets.getActivePort()
	local character = targets.getCharacter()

	graphics.setColor(200, 200, 200, 100)
	melee.drawSeries(port, 8, 64, 0, 320, 320)
	graphics.setColor(255, 255, 255, 255)
	melee.drawStock(port, 320 - 24 - 8, 8, 0, 24, 24)

	local runnum = string.format("#%d", targets.getCDATA(character, "NumRuns") or 0)

	local x = 320 - 24 - 12 - FRAME_FONT:getWidth(runnum)

	graphics.setFont(FRAME_FONT)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(runnum, x, 14)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(runnum, x, 13)

	local frame = targets.isValidRun() and memory.match.timer.frame or (targets.TIME_FRAME or 0)

	graphics.setFont(FRAME_FONT)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(frame, 4, 5)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(frame, 4, 4)

	local seconds, ms = getMeleeTimpstamp(frame)
	local secstr = string.format("%d", seconds)
	local msstr = string.format(".%02d", ms)

	local secw = TOTAL_SEC:getWidth(secstr)
	local totalw = secw + TOTAL_MS:getWidth(msstr)

	graphics.setFont(TOTAL_SEC)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(secstr, 160 - totalw/2, 5)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(secstr, 160 - totalw/2, 4)

	graphics.setFont(TOTAL_MS)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(msstr, 160 - totalw/2 + secw, 16)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(msstr, 160 - totalw/2 + secw, 15)

	local current = targets.BROKEN + 1

	for i=1,10 do
		if targets.isValidRun() and current == i then
			graphics.setColor(0, 100, 0, 150)
		elseif i%2 == 1 then
			graphics.setColor(100, 100, 100, 150)
		else
			graphics.setColor(50, 50, 50, 150)
		end
		graphics.rectangle("fill", 0, 4 + (36*i), 320, 32)

		local y = 14 + (36*i)
		local numstr = string.format("%2d", i)

		graphics.setFont(SPLIT_SEC)
		graphics.setColor(0, 0, 0, 255)
		graphics.print(numstr, 8, y)
		graphics.setColor(255, 255, 255, 255)
		graphics.print(numstr, 8, y-1)


		if current == i then
			greyscale:send("percent", 0.25)
		elseif i > current then
			greyscale:send("percent", 0)
		else
			greyscale:send("percent", 1)
		end

		graphics.setShader(greyscale)
			graphics.setColor(255, 255, 255, 255)
			graphics.easyDraw(TARGET, 8 + 24, 8 + (36*i), 0, 24, 24)
		graphics.setShader()

		local t = (targets.isValidRun() and current == i) and memory.match.timer.frame or targets.TIME_FRAMES[i]
		if t then
			local seconds, ms = getMeleeTimpstamp(t)

			local secstr = string.format("%d", seconds)
			local msstr = string.format(".%02d", ms)

			local secw = SPLIT_SEC:getWidth(secstr)
			local totalw = secw + SPLIT_MS:getWidth(msstr)

			graphics.setFont(SPLIT_SEC)
			graphics.setColor(0, 0, 0, 255)
			graphics.print(secstr, 320 - 8 - totalw, y)
			graphics.setColor(255, 255, 255, 255)
			graphics.print(secstr, 320 - 8 - totalw, y-1)

			graphics.setFont(SPLIT_MS)
			graphics.setColor(0, 0, 0, 255)
			graphics.print(msstr, 320 - 8 - totalw + secw, y+5)
			graphics.setColor(255, 255, 255, 255)
			graphics.print(msstr, 320 - 8 - totalw + secw, y+4)
		end
	end

	local besttime = targets.getCDATA(character, "BestTime") or 0

	local seconds, ms = getMeleeTimpstamp(besttime)
	local secstr = string.format("Personal Best: %d", seconds)
	local msstr = string.format(".%02d", ms)

	local secw = SPLIT_SEC:getWidth(secstr)
	local totalw = secw + TOTAL_MS:getWidth(msstr)

	graphics.setFont(SPLIT_SEC)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(secstr, 4, 448 - 46)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(secstr, 4, 448 - 45)

	graphics.setFont(SPLIT_MS)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(msstr, 4 + secw, 448 - 41)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(msstr, 4 + secw, 448 - 40)

	local sumtime = targets.getCDATA(character, "SumOfBestTime") or 0

	local seconds, ms = getMeleeTimpstamp(sumtime)
	local secstr = string.format("Sum of Best: %d", seconds)
	local msstr = string.format(".%02d", ms)

	local secw = SPLIT_SEC:getWidth(secstr)
	local totalw = secw + TOTAL_MS:getWidth(msstr)

	graphics.setFont(SPLIT_SEC)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(secstr, 4, 448 - 24)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(secstr, 4, 448 - 23)

	graphics.setFont(SPLIT_MS)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(msstr, 4 + secw, 448 - 19)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(msstr, 4 + secw, 448 - 18)

	if targets.IN_DISPLAY_MENU ~= nil then
		local controller = memory.controller[port].buttons
		graphics.easyDraw(DPAD_GATE, 320/2, 448/2, 0, 128, 128, 0.5, 0.5)
		graphics.easyDraw(MENU_TEXT, 320/2, 448/2, 0, 320, 320, 0.5, 0.5)
		for mask, tex in pairs(DPAD_TEXTURES) do
			if bit.band(controller.pressed, mask) == mask then
				graphics.easyDraw(tex, 320/2, 448/2, 0, 128, 128, 0.5, 0.5)
			end
		end
	end
end

return targets