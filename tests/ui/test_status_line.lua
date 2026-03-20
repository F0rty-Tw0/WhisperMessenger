local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")

return function()
  -- Separator should be the actual UTF-8 middle dot, not hex escape
  local contact = {
    displayName = "Arthas",
    className = "Hunter",
    factionName = "Horde",
  }
  local status = { status = "WrongFaction", canWhisper = false }
  local text = StatusLine.Build(contact, status)

  -- Must NOT contain the literal string "xC2xB7"
  assert(not string.find(text, "xC2xB7"), "separator should be UTF-8 middle dot, not literal hex: " .. text)

  -- Should contain the actual middle dot character (U+00B7 = bytes 0xC2 0xB7)
  local dot = string.char(194, 183)
  assert(string.find(text, dot, 1, true), "separator should contain UTF-8 middle dot: " .. text)

  -- WrongFaction should display as "Wrong Faction" label
  assert(string.find(text, "Wrong Faction", 1, true), "should show 'Wrong Faction' label: " .. text)

  -- Should include class and faction
  assert(string.find(text, "Hunter", 1, true), "should include className: " .. text)
  assert(string.find(text, "Horde", 1, true), "should include factionName: " .. text)
end
