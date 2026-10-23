-- Titles above players' names, like [OWNER]. The server decides who has one (by group) and sends the
-- list with extended opcode 110, so no names are stored in the client.
local OPCODE = 110
local FONT = "verdana-11px-rounded"

local byName = {}

-- The title text for a player name, or nil. The console uses it for broadcasts.
function getTitle(name)
  local title = name and byName[name:lower()]
  return title and title.text
end

local function applyTitle(creature)
  if not creature or not creature:isPlayer() then
    return
  end
  local title = byName[creature:getName():lower()]
  if title then
    creature:setTitle(title.text, FONT, title.color)
  end
end

local function forVisible(name, fn)
  local player = g_game.isOnline() and g_game.getLocalPlayer()
  if not player then
    return
  end
  for _, creature in ipairs(g_map.getSpectators(player:getPosition(), true)) do
    if creature:isPlayer() and (not name or creature:getName():lower() == name) then
      fn(creature)
    end
  end
end

local function onTitles(protocol, opcode, buffer)
  local lines = buffer:split("\n")
  local action = table.remove(lines, 1)
  if action == "set" then
    byName = {}
  end
  for _, line in ipairs(lines) do
    local name, text, color = unpack(line:split("\t"))
    if name and name ~= "" then
      name = name:lower()
      if action == "remove" then
        byName[name] = nil
        forVisible(name, function(creature) creature:setTitle("", FONT, "#ffffff") end)
      elseif text then
        byName[name] = { text = text, color = color or "#ffffff" }
        forVisible(name, applyTitle)
      end
    end
  end
end

-- Ask for the list on entering the game too: the server only sends it by itself on a fresh login.
local function onGameStart()
  local protocol = g_game.getProtocolGame()
  if protocol then
    protocol:sendExtendedOpcode(OPCODE, "get")
  end
end

function init()
  ProtocolGame.registerExtendedOpcode(OPCODE, onTitles)
  connect(Creature, { onAppear = applyTitle })
  connect(g_game, { onGameStart = onGameStart })
end

function terminate()
  ProtocolGame.unregisterExtendedOpcode(OPCODE)
  disconnect(Creature, { onAppear = applyTitle })
  disconnect(g_game, { onGameStart = onGameStart })
end
