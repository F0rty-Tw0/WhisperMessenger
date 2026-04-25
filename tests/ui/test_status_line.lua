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

  -- XFaction (computed cross-faction guild/community) should show "X-Faction" label
  do
    local xfContact = { displayName = "Thrall", factionName = "Horde" }
    local xfStatus = { status = "XFaction", canWhisper = true }
    local xfText, xfColor = StatusLine.Build(xfContact, xfStatus)
    assert(string.find(xfText, "X-Faction", 1, true), "should show 'X-Faction' label: " .. xfText)
    assert(xfColor == "online", "X-Faction dot color should be 'online', got: " .. tostring(xfColor))
  end

  -- Away status should display as "Away" with away color
  do
    local awayContact = { displayName = "Jaina" }
    local awayStatus = { status = "Away", canWhisper = true }
    local awayText, awayColor = StatusLine.Build(awayContact, awayStatus)
    assert(string.find(awayText, "Away", 1, true), "should show 'Away' label: " .. awayText)
    assert(awayColor == "away", "Away dot color should be 'away', got: " .. tostring(awayColor))
  end

  -- Busy status should display as "Busy" with dnd color
  do
    local busyContact = { displayName = "Thrall" }
    local busyStatus = { status = "Busy", canWhisper = true }
    local busyText, busyColor = StatusLine.Build(busyContact, busyStatus)
    assert(string.find(busyText, "Busy", 1, true), "should show 'Busy' label: " .. busyText)
    assert(busyColor == "dnd", "Busy dot color should be 'dnd', got: " .. tostring(busyColor))
  end

  -- Ignored status should display as "Ignored" with dnd (red) color
  do
    local ignoredContact = { displayName = "Sylvanas" }
    local ignoredStatus = { status = "Ignored", canWhisper = false }
    local ignoredText, ignoredColor = StatusLine.Build(ignoredContact, ignoredStatus)
    assert(string.find(ignoredText, "Ignored", 1, true), "should show 'Ignored' label: " .. ignoredText)
    assert(ignoredColor == "dnd", "Ignored dot color should be 'dnd', got: " .. tostring(ignoredColor))
  end
end
