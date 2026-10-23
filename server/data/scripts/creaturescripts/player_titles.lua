-- Titles shown above players' names in our client, like [OWNER]. The server picks them by group and sends
-- them to each client (extended opcode 110), so the client folder holds no list of names.
-- Lines sent: "set" + every titled player online, "add" + one player, "remove" + one name.
-- Each player line is: name <tab> title <tab> colour. The client also asks with "get" when it enters the
-- game, because reconnecting to a character that is still in the game does not run onLogin.
local OPCODE = 110
local TITLES = {
	[7] = {text = "[OWNER]", color = "#4fa8ff"}, -- owner
}

local function titleLine(player)
	local title = TITLES[player:getGroup():getId()]
	return title and (player:getName() .. "\t" .. title.text .. "\t" .. title.color)
end

local function sendAll(player)
	local lines, seen = {}, false
	for _, other in ipairs(Game.getPlayers()) do
		lines[#lines + 1] = titleLine(other)
		seen = seen or other == player
	end
	if not seen then
		lines[#lines + 1] = titleLine(player)
	end
	player:sendExtendedOpcode(OPCODE, "set\n" .. table.concat(lines, "\n"))
end

local login = CreatureEvent("PlayerTitlesLogin")
function login.onLogin(player)
	player:registerEvent("PlayerTitlesOpcode")
	sendAll(player)
	local mine = titleLine(player)
	if mine then
		for _, other in ipairs(Game.getPlayers()) do
			if other ~= player then
				other:sendExtendedOpcode(OPCODE, "add\n" .. mine)
			end
		end
	end
	return true
end
login:register()

local request = CreatureEvent("PlayerTitlesOpcode")
function request.onExtendedOpcode(player, opcode, buffer)
	if opcode == OPCODE and buffer == "get" then
		sendAll(player)
	end
end
request:register()

local logout = CreatureEvent("PlayerTitlesLogout")
function logout.onLogout(player)
	if titleLine(player) then
		for _, other in ipairs(Game.getPlayers()) do
			if other ~= player then
				other:sendExtendedOpcode(OPCODE, "remove\n" .. player:getName())
			end
		end
	end
	return true
end
logout:register()
