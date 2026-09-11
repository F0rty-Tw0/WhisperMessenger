local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")

return function()
  -- Separator should be the actual UTF-8 middle dot, not hex escape
  local contact = {
    displayName = "Arthas",
    className = "Hunter",
    factionName = "Horde",
  }
  local status = { status = "WrongFaction", canWhisper = false }
  local line1, line2 = StatusLine.Build(contact, status)

  -- Must NOT contain the literal string "xC2xB7"
  assert(not string.find(line1, "xC2xB7"), "separator should be UTF-8 middle dot, not literal hex: " .. line1)

  -- Should contain the actual middle dot character (U+00B7 = bytes 0xC2 0xB7)
  assert(string.find(line1, " - ", 1, true), "separator should contain ' - ': " .. line1)

  -- WrongFaction should display as "Wrong Faction" label, on line2 (not line1)
  assert(string.find(line2, "Wrong Faction", 1, true), "should show 'Wrong Faction' label on line2: " .. line2)
  assert(not string.find(line1, "Wrong Faction", 1, true), "'Wrong Faction' label should not appear on line1: " .. line1)

  -- Should include class and faction on line1, not line2
  assert(string.find(line1, "Hunter", 1, true), "should include className: " .. line1)
  assert(string.find(line1, "Horde", 1, true), "should include factionName: " .. line1)
  assert(not string.find(line2, "Hunter", 1, true), "className should not appear on line2: " .. line2)
  assert(not string.find(line2, "Horde", 1, true), "factionName should not appear on line2: " .. line2)

  -- XFaction (computed cross-faction guild/community) should show "X-Faction" label on line2
  do
    local xfContact = { displayName = "Thrall", factionName = "Horde" }
    local xfStatus = { status = "XFaction", canWhisper = true }
    local xfLine1, xfLine2, xfColor = StatusLine.Build(xfContact, xfStatus)
    assert(string.find(xfLine2, "X-Faction", 1, true), "should show 'X-Faction' label on line2: " .. xfLine2)
    assert(not string.find(xfLine1, "X-Faction", 1, true), "'X-Faction' label should not appear on line1: " .. xfLine1)
    assert(xfColor == "online", "X-Faction dot color should be 'online', got: " .. tostring(xfColor))
  end

  -- Away status should display as "Away" with away color, on line2
  do
    local awayContact = { displayName = "Jaina" }
    local awayStatus = { status = "Away", canWhisper = true }
    local awayLine1, awayLine2, awayColor = StatusLine.Build(awayContact, awayStatus)
    assert(string.find(awayLine2, "Away", 1, true), "should show 'Away' label on line2: " .. awayLine2)
    assert(not string.find(awayLine1, "Away", 1, true), "'Away' label should not appear on line1: " .. awayLine1)
    assert(awayColor == "away", "Away dot color should be 'away', got: " .. tostring(awayColor))
  end

  -- Busy status should display as "Busy" with dnd color, on line2
  do
    local busyContact = { displayName = "Thrall" }
    local busyStatus = { status = "Busy", canWhisper = true }
    local busyLine1, busyLine2, busyColor = StatusLine.Build(busyContact, busyStatus)
    assert(string.find(busyLine2, "Busy", 1, true), "should show 'Busy' label on line2: " .. busyLine2)
    assert(not string.find(busyLine1, "Busy", 1, true), "'Busy' label should not appear on line1: " .. busyLine1)
    assert(busyColor == "dnd", "Busy dot color should be 'dnd', got: " .. tostring(busyColor))
  end

  -- name-realm part belongs on line1; areaName present should be inserted on
  -- line2 after the availability label, and neither should cross lines
  do
    local locContact = {
      displayName = "Nergrom",
      realmName = "Kazzak",
      className = "Hunter",
      factionName = "Horde",
      areaName = "Voidscar Arena",
    }
    local locStatus = { status = "CanWhisper", canWhisper = true }
    local locLine1, locLine2 = StatusLine.Build(locContact, locStatus)

    -- line1: name-realm, class, faction
    assert(string.find(locLine1, "Kazzak", 1, true), "should include realm part on line1: " .. locLine1)
    assert(string.find(locLine1, "Hunter", 1, true), "should include className on line1: " .. locLine1)
    assert(string.find(locLine1, "Horde", 1, true), "should include factionName on line1: " .. locLine1)
    assert(not string.find(locLine1, "Voidscar Arena", 1, true), "areaName should not appear on line1: " .. locLine1)

    -- line2: availability label, then areaName
    local availPos = string.find(locLine2, "Online", 1, true)
    local areaPos = string.find(locLine2, "Voidscar Arena", 1, true)
    assert(availPos ~= nil, "should include availability label on line2: " .. locLine2)
    assert(areaPos ~= nil, "should include areaName on line2: " .. locLine2)
    assert(availPos < areaPos, "availability label should appear before areaName: " .. locLine2)
    assert(not string.find(locLine2, "Kazzak", 1, true), "realm part should not appear on line2: " .. locLine2)
  end

  -- areaName absent should leave line2 unchanged (no double separators)
  do
    local noLocContact = {
      displayName = "Nergrom",
      realmName = "Kazzak",
      className = "Hunter",
      factionName = "Horde",
    }
    local noLocStatus = { status = "CanWhisper", canWhisper = true }
    local _, noLocLine2 = StatusLine.Build(noLocContact, noLocStatus)
    assert(not string.find(noLocLine2, "-  -", 1, true), "should not have double separators: " .. noLocLine2)
  end
end
