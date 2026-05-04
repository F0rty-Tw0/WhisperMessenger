local Identity = require("WhisperMessenger.Model.Identity.Identity")
local Factions = require("WhisperMessenger.Model.Identity.Factions")
local Availability = require("WhisperMessenger.Transport.Availability")
local StatusLine = require("WhisperMessenger.UI.ConversationPane.StatusLine")
local Localization = require("WhisperMessenger.Locale.Localization")

return function()
  -- test_russian_faction_names
  do
    Localization.Configure({ language = "ruRU" })
    -- Note: Factions.lua parses internal string tags, but the UI should translate them
    assert(Localization.Text("Alliance") == "Альянс", "Alliance should localize")
    assert(Localization.Text("Horde") == "Орда", "Horde should localize")

    -- Check availability states in StatusLine
    local status = { status = "BNetOnline" }
    local text, _ = StatusLine.Build({ displayName = "Bob" }, status)
    assert(string.find(text, "В сети %(прил.%)", 1, false), "BNetOnline should localize to 'В сети (прил.)', got: " .. tostring(text))

    status = { status = "WrongFaction" }
    text, _ = StatusLine.Build({ displayName = "Bob" }, status)
    assert(string.find(text, "Другая фракция", 1, true), "WrongFaction should localize to 'Другая фракция', got: " .. tostring(text))

    Localization.Configure({ language = "enUS" })
  end
end
