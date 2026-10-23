-- Titles above players' names, like [OWNER]. The client is not told who is staff, so the players are
-- listed here by character name (any capitalisation). Change a colour with any #rrggbb value.
local TITLES = {
  ["Kazz"] = { text = "[OWNER]", color = "#4fa8ff" },
  ["Angelo"] = { text = "[OWNER]", color = "#4fa8ff" },
}
local FONT = "verdana-11px-rounded"

local byName = {}
for name, title in pairs(TITLES) do
  byName[name:lower()] = title
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

function init()
  connect(Creature, { onAppear = applyTitle })
  -- Players already on screen when the mod loads (for example after a reload).
  local player = g_game.isOnline() and g_game.getLocalPlayer()
  if player then
    for _, creature in ipairs(g_map.getSpectators(player:getPosition(), false)) do
      applyTitle(creature)
    end
  end
end

function terminate()
  disconnect(Creature, { onAppear = applyTitle })
end
