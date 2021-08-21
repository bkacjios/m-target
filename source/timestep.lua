-- Should we limit the FPS
local LIMIT_FPS = true

-- How many frames per second we should cap at
local LIMIT_FPS_CAP = 120

-- How many updates per second there should be
local TICK_RATE = 120

-- How many frames we are allowed to skip at once
local TICK_FRAME_SKIP = 25

function love.graphics.setFrameLimit(i)
	LIMIT_FPS_CAP = tonumber(i)
end

function love.graphics.getFrameLimit()
	return LIMIT_FPS_CAP
end

function love.graphics.setFrameLimited(b)
	LIMIT_FPS = b == true
end

function love.graphics.getFrameLimited()
	return LIMIT_FPS
end

-- Get the current tickrate in seconds
function love.getTickRate()
	return 1 / TICK_RATE
end

function love.run()
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
 
	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end

	local rate = 0 -- The tickrate
	local accumulated = 0 -- How many ticks have accumulated this current frame
	local fstart = 0 -- Time the frame is started
	local ftime = 0 -- Time the frame took to complete
	local alpha = 0 -- Percentage the frame is in the current tick
 
	-- Main loop time.
	return function()
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

		rate = love.getTickRate()

		-- Step the timer
		if love.timer then accumulated = math.min(accumulated + love.timer.step(), rate * TICK_FRAME_SKIP) end
 
		if love.update then
			-- If we have any availble ticks..
			while accumulated >= rate do
				love.update(rate)
				accumulated = accumulated - rate
			end
		end
		
		if love.timer and LIMIT_FPS then fstart = love.timer.getTime() end
 
		if love.graphics and love.graphics.isActive() then
			love.graphics.origin()
			love.graphics.clear(love.graphics.getBackgroundColor())
 
			if love.draw then
				-- Calculate how far along in the tick we are
				alpha = accumulated / rate
				-- Draw the frame and pass along the alpha value used for interpolation
				love.draw(alpha)
			end
 
			love.graphics.present()
		end
 
		if love.timer then
			if LIMIT_FPS then
				-- Calculate how long it took for this frame to complete
				ftime = love.timer.getTime() - fstart
				-- Sleep based on the FPS limit, subtracting the current time it took for this frame to complete
				love.timer.sleep(1 / LIMIT_FPS_CAP - ftime)
			else
				-- Fallback to 1000fps cap
				love.timer.sleep(0.001)
			end
		end
	end
end 
