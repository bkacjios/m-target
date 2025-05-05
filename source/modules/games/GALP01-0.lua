-- Super Smash Bros. Melee (PAL)

local core = require("games.core")

local game = core.newGame()

game.memorymap[0x8046AB60] = { type = "u32", name = "frame" }
game.memorymap[0x8046AB38] = { type = "u8", name = "menu.major", debug = true }
game.memorymap[0x8046AB3B] = { type = "u8", name = "menu.minor", debug = true }
game.memorymap[0x804C7858] = { type = "u8", name = "menu.player_one_port", debug = true } -- What port is currently acting as "Player 1" in single player games
game.memorymap[0x80422E30] = { type = "bool", name = "menu.teams" }

local controllers = {
	[1] = 0x804B302C + 0x44 * 0,
	[2] = 0x804B302C + 0x44 * 1,
	[3] = 0x804B302C + 0x44 * 2,
	[4] = 0x804B302C + 0x44 * 3,
}

local controller_struct = {
	[0x00] = { type = "int",	name = "controller.%d.buttons.pressed" },
	--[0x04] = { type = "int",	name = "controller.%d.buttons.pressed_previous" },
	--[0x08] = { type = "int",	name = "controller.%d.buttons.instant" },
	--[0x10] = { type = "int",	name = "controller.%d.buttons.released" },
	--[0x1C] = { type = "byte",	name = "controller.%d.analog.byte.l" },
	--[0x1D] = { type = "byte",	name = "controller.%d.analog.byte.r" },
	[0x20] = { type = "float",	name = "controller.%d.joystick.x" },
	[0x24] = { type = "float",	name = "controller.%d.joystick.y" },
	[0x28] = { type = "float",	name = "controller.%d.cstick.x" },
	[0x2C] = { type = "float",	name = "controller.%d.cstick.y" },
	[0x30] = { type = "float",	name = "controller.%d.analog.l" },
	[0x34] = { type = "float",	name = "controller.%d.analog.r" },
	[0x41] = { type = "byte",	name = "controller.%d.plugged" },
}

for port, address in ipairs(controllers) do
	for offset, info in pairs(controller_struct) do
		game.memorymap[address + offset] = {
			type = info.type,
			debug = info.debug,
			name = info.name:format(port),
		}
	end
end

local player_static_addresses = {
	0x80443E23, -- Player 1
	0x80444CB3, -- Player 2
	0x80445B43, -- Player 3
	0x804469D3, -- Player 4
	0x80447863, -- Player 5
	0x804486F3, -- Player 6
}

local entity_pointer_offsets = {
	[0xB0] = "entity",
	[0xB4] = "partner", -- Partner entity (For sheik/zelda/iceclimbers)
}

local player_static_struct = {
	[0x004] = { type = "u32", name = "character" },
	[0x008] = { type = "u32", name = "mode" },
	[0x00C] = { type = "u16", name = "transformed" },
	[0x044] = { type = "u8", name = "skin" },
	--[0x045] = { type = "u8", name = "port" },
	[0x046] = { type = "u8", name = "color" },
	[0x047] = { type = "u8", name = "team" },
	[0xE8C] = { type = "u8", name = "movement" }
	--[0x048] = { type = "u8", name = "index" },
	--[0x049] = { type = "u8", name = "cpu_level", debug = true },
	--[0x04A] = { type = "u8", name = "cpu_type", debug = true }, -- 4 = 20XX, 22 = normalish, 19 = Alt Normal
}

for id, address in ipairs(player_static_addresses) do
	for offset, info in pairs(player_static_struct) do
		game.memorymap[address + offset] = {
			type = info.type,
			debug = info.debug,
			name = ("player.%i.%s"):format(id, info.name),
		}
	end

	for offset, name in pairs(entity_pointer_offsets) do
		game.memorymap[address + offset] = {
			type = "pointer",
			name = ("player.%i.%s"):format(id, name),
			struct = {
				[0x60 + 0x0004] = { type = "u32", name = "character" },
				--[0x60 + 0x000C] = { type = "u8", name = "port" },
				--[0x60 + 0x0618] = { type = "u8", name = "index" },
				[0x60 + 0x0619] = { type = "u8", name = "skin" },
				[0x60 + 0x061A] = { type = "u8", name = "color" },
				[0x60 + 0x061B] = { type = "u8", name = "team" },

				[0x60 + 0x0620] = { type = "float", name = "controller.joystick.x" },
				[0x60 + 0x0624] = { type = "float", name = "controller.joystick.y" },
				[0x60 + 0x0638] = { type = "float", name = "controller.cstick.x" },
				[0x60 + 0x063C] = { type = "float", name = "controller.cstick.y" },
				[0x60 + 0x0650] = { type = "float", name = "controller.analog.float" },
				[0x60 + 0x065C] = { type = "u32",	name = "controller.buttons.pressed" },
				[0x60 + 0x0660] = { type = "u32",	name = "controller.buttons.pressed_previous" },

				--[[
				[0x60 + 0x1A94] = { type = "u32", name = "cpu_type" },
				[0x60 + 0x1A98] = { type = "u32", name = "cpu_level" },
				]]
			},
		}
	end
end


-- Where character ID's are stored in the CSS menu
local player_select_external_addresses = {
	0x80422E2B,
	0x80422E33,
	0x80422E3B,
	0x80422E43,
}

local player_select_external = {
	[0x04] = "character",
	[0x05] = "skin",
}

for id, address in ipairs(player_select_external_addresses) do
	for offset, name in pairs(player_select_external) do
		game.memorymap[address + offset] = {
			type = "u8",
			name = ("player.%i.select.%s"):format(id, name),
		}
	end
end

local player_card_addresses = {
	0x803F1C75,
	0x803F1C99,
	0x803F1CBD,
	0x803F1CE1,
}

local player_card = {
	[0x00] = "team",
	[0x01] = "mode",
	--[0x02] = "mode", -- Duplicate?
	[0x03] = "skin",
	[0x04] = "character",
	[0x05] = "hovered",
}

for id, address in ipairs(player_card_addresses) do
	for offset, name in pairs(player_card) do
		game.memorymap[address + offset] = {
			type = "byte",
			name = ("player.%i.card.%s"):format(id, name),
		}
	end
end

local startmatch_addr = 0x8045E970

local startmatch_struct = {
	[0x00] = { type = "u8", name = "match.flags.game" },
	[0x01] = { type = "u8", name = "match.flags.friendlyfire" },
	[0x02] = { type = "u8", name = "match.flags.other" },
	[0x07] = { type = "bool", name = "match.bombrain" },
	[0x08] = { type = "bool", name = "match.teams" },
	[0x0B] = { type = "s8", name = "match.settings.item_frequency" },
	[0x0C] = { type = "s8", name = "match.settings.self_destruct" },
	[0x0E] = { type = "short", name = "match.stage" },
}

for offset, info in pairs(startmatch_struct) do
	game.memorymap[startmatch_addr + offset] = info
end

game.memorymap[0x80492FF8] = { type = "bool", name = "match.paused" }

local match_info = 0x8045C4A8

local match_info_struct = {
	[0x0005] = { type = "bool", name = "match.playing", debug = true },
	[0x0008] = { type = "u8", name = "match.result", debug = true },
	[0x000E] = { type = "bool", name = "match.finished", debug = true },
	[0x0026] = { type = "u16", name = "match.timer.frame" },
	[0x0028] = { type = "int", name = "match.timer.seconds" },
	[0x002C] = { type = "short", name = "match.timer.millis" },
}

local stage_info_addr = 0x8048F750
local stage_info_struct = {
	[0x0088] = { type = "int", name = "stage.id" },
	[0x06D4] = { type = "short", name = "stage.targets" },
	[0x06E0] = { type = "float", name = "stage.homerun_distance" },
}
for offset, info in pairs(stage_info_struct) do
	game.memorymap[stage_info_addr + offset] = info
end

local player_cursors_pointers = {
	0x810FE144,
	0x810FE148,
	0x810FE14C,
	0x810FE150,
}

local player_cursor_struct = {
	--[0x00] = { type = "u32", name = "unknown_ptr" },
	[0x05] = { type = "u8", name = "state" }, -- The state of the pointer (0 = in the bottom area, 1 = holding coin, 2 = empty hand)
	[0x0B] = { type = "u8", name = "b_frame_counter" }, -- How many frames the player is holding B for (At 32, it will forcibly exit back to the menus)
	[0x0C] = { type = "float", name = "position.x" },
	[0x10] = { type = "float", name = "position.y" },
}

for port, addr in pairs(player_cursors_pointers) do
	game.memorymap[addr] = { type = "pointer", name = ("player.%i.cursor"):format(port), struct = player_cursor_struct }
end

for offset, info in pairs(match_info_struct) do
	game.memorymap[match_info + offset] = info
end




game.translateJoyStick = function(x, y) return x, y end
game.translateCStick = function(x, y) return x, y end
game.translateTriggers = function(l, r) return l, r end

return game