local targets = {
	TIME_FRAMES = {},
	MATCH_STARTED = false,
	BROKEN = 0,
	ATTEMPT_ID = nil,
	ATTEMPT_IN_PROGRESS = false,
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

local RESULT_NONE		= 0x0	-- Set at the start
local RESULT_FAILURE	= 0x4	-- Fell off the stage
local RESULT_COMPLETE	= 0x6	-- Successfully hit all targets
local RESULT_LRAS		= 0x7	-- Quit using L+R+A+Start

local function getMeleeTimpstamp(frame)
	local duration = frame/60
	local minutes = math.floor(duration/60)
	local seconds = math.floor(duration)
	local ms = (frame % 60) * 100 / 60
	return seconds, math.floor(ms)
end

local timedb = lsqlite3.open(string.format("%s/time.db", love.filesystem.getSaveDirectory()))

timedb:exec([[CREATE TABLE IF NOT EXISTS attempts (
	attempt		INTEGER PRIMARY KEY AUTOINCREMENT,
	character	INTEGER, -- character that was used
	tframes		INTEGER, -- #frames the timer spent active
	gframes		INTEGER, -- #frames in total (including before timer start)
	targets		INTEGER, -- #targets that were hit
	result		INTEGER	 -- result status at the end (complete, failure, retry, etc)
);]])

timedb:exec([[CREATE TABLE IF NOT EXISTS splits (
	attempt		INTEGER NOT NULL, -- the attempt_id that this split is tied to
	target		INTEGER, -- target number this split was for
	tframes		INTEGER, -- #frames the timer spent to achieve this split
	gframes		INTEGER,  -- #frames in total spent to achieve this split (including before timer start)
	UNIQUE(attempt,target) -- we should never have duplicate targets in a given attempt
);]])

timedb:exec([[CREATE TABLE IF NOT EXISTS milestones (
	character			INTEGER, -- character that was used
	target				INTEGER, -- target number this split was for
	best_attempt		INTEGER, -- what attempt we completed this best in
	best_tframes		INTEGER, -- #frames the timer spent to achieve this split
	best_gframes		INTEGER, -- #frames entire duration of the attempt
	worst_attempt		INTEGER, -- what attempt we completed this worst in
	worst_tframes		INTEGER, -- #frames the timer spent to achieve this split
	worst_gframes		INTEGER, -- #frames entire duration of the attempt
	UNIQUE(character,target)	 -- we should never have duplicate targets tied to a given character
);]])

function targets.getCharacter()
	return memory.player[1].select.character
end

function targets.getSumOfBest(character)
end

function targets.startAttempt()
	local stmt = timedb:prepare("INSERT INTO attempts (character) VALUES (?);")
	stmt:bind_values(targets.getCharacter())
	stmt:step()
	stmt:finalize()
	targets.ATTEMPT_ID = timedb:last_insert_rowid()
	return targets.ATTEMPT_ID
end

function targets.saveSplit(target)
	local stmt = timedb:prepare("INSERT INTO splits (attempt, target, tframes, gframes) VALUES (?,?,?,?);")
	stmt:bind_values(targets.ATTEMPT_ID, target, memory.match.timer.frame, memory.frame)
	stmt:step()
	stmt:finalize()
end

function targets.saveResults()
	local stmt = timedb:prepare("UPDATE attempts SET tframes=?, gframes=?, targets=?, result=? WHERE attempt=?;")
	stmt:bind_values(memory.match.timer.frame, memory.frame, 10 - memory.stage.targets, memory.match.result, targets.ATTEMPT_ID)
	stmt:step()
	stmt:finalize()
end

function targets.newAttempt()
	if not targets.ATTEMPT_IN_PROGRESS then
		targets.ATTEMPT_IN_PROGRESS = true
		log.debug("Started attempt #%d", targets.startAttempt())
		targets.TIME_FRAMES = {}
		targets.BROKEN = 0
	end
end

function targets.endAttempt()
	if targets.ATTEMPT_IN_PROGRESS then
		targets.ATTEMPT_IN_PROGRESS = false
		log.info("Ended attempt #%d at frame %d - time %02d.%02d", targets.ATTEMPT_ID, memory.match.timer.frame, getMeleeTimpstamp(memory.match.timer.frame))
		targets.saveResults()
	end
end

memory.hook("match.finished", "Targets - Check start of game", function(finished)
	if finished then
		targets.endAttempt()
	end
end)

local prev_remain
memory.hook("stage.targets", "Targets - Save Split", function(remain)
	if not prev_remain then
		prev_remain = remain
	end

	local num = 10 - remain
	if remain < prev_remain and memory.match.finished == false then
		-- Only log splits when the target count decreases
		local diff = prev_remain - remain
		if diff > 1 and memory.match.timer.frame == 0 then
			targets.endAttempt()
			targets.newAttempt()
		else
			for i=targets.BROKEN+1, num do
				-- We can hit more than one target in a single frame, so loop through and mark every single one as hit
				log.info("%d - Hit target #%d at frame %d - time %02d.%02d", remain, i, memory.match.timer.frame, getMeleeTimpstamp(memory.match.timer.frame))	
				targets.TIME_FRAMES[i] = memory.match.timer.frame
				targets.saveSplit(i)
			end
			targets.BROKEN = num
		end
	end

	prev_remain = remain
end)

memory.hook("match.playing", "Targets - Get End Time", function(playing)
	if playing then
		targets.MATCH_STARTED = true
		log.info("Started at game frame %d", memory.frame)
	end
end)

memory.hook("match.result", "Targets - Check Complete", function(result)
	targets.endAttempt()
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
	local port = memory.menu.player_one_port+1

	graphics.setColor(200, 200, 200, 100)
	melee.drawSeries(port, 8, 64, 0, 320, 320)
	graphics.setColor(255, 255, 255, 255)
	melee.drawStock(port, 320 - 24 - 8, 8, 0, 24, 24)

	local frame = string.format("%d", memory.match.timer.frame)

	graphics.setFont(FRAME_FONT)
	graphics.setColor(0, 0, 0, 255)
	graphics.print(frame, 4, 5)
	graphics.setColor(255, 255, 255, 255)
	graphics.print(frame, 4, 4)

	local seconds, ms = getMeleeTimpstamp(memory.match.timer.frame)
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
		if current == i then
			graphics.setColor(0, 100, 0, 150)
		elseif i%2 == 1 then
			graphics.setColor(100, 100, 100, 150)
		else
			graphics.setColor(50, 50, 50, 150)
		end
		graphics.rectangle("fill", 0, 4 + (36*i), 320, 32)

		local grey = 1
		if current == i then
			grey = 0.25
		elseif i >= current then
			grey = 0
		end
		greyscale:send("percent", grey)

			-- Draw greyscaled image

		local y = 14 + (36*i)
		local numstr = string.format("%2d", i)

		graphics.setFont(SPLIT_SEC)
		graphics.setColor(0, 0, 0, 255)
		graphics.print(numstr, 8, y)
		graphics.setColor(255, 255, 255, 255)
		graphics.print(numstr, 8, y-1)

		graphics.setShader(greyscale)
			graphics.setColor(255, 255, 255, 255)
			graphics.easyDraw(TARGET, 8 + 24, 8 + (36*i), 0, 24, 24)
		graphics.setShader()

		local t = current == i and memory.match.timer.frame or targets.TIME_FRAMES[i]
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
end

return targets